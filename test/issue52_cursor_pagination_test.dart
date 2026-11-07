import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #52: the SDK dropped `hasMore`/`nextCursor`
/// from `GET /api/v1/feature-requests` responses and had no way to send the
/// `cursor` query parameter, pinning hosts — and the SDK's own
/// `FeatureRequestsScreen` / `RoadmapBoardScreen` load-more — to legacy offset
/// pagination that skips or duplicates rows when moderation approves, hides,
/// or reorders them between page fetches.
void main() {
  const config = PublicAppConfig(
    appId: 'app_123',
    appKey: 'app_test_123',
    slug: 'test-app',
    name: 'Test App',
    allowPublic: true,
    allowedPlatforms: [FeedbackPlatform.ios, FeedbackPlatform.android],
    maxAttachmentBytes: 1048576,
    allowAnonymousRoadmap: true,
    allowAnonymousVote: true,
    allowAnonymousFeedback: true,
    allowAnonymousChangelog: true,
    sdk: SdkAppearance(
      features: SdkFeatures(
        feedback: true,
        featureRequests: true,
        roadmap: true,
        changelog: true,
      ),
    ),
  );

  Map<String, dynamic> requestRow(String id) => {
        'id': id,
        'appId': 'app_123',
        'title': 'Request $id',
        'description': 'Description of $id',
        'status': 'under_review',
        'columnName': 'Planned',
        'columnColor': '#3B82F6',
        'columnId': 'col_1',
        'approved': true,
        'voteCount': 1,
        'hasVoted': false,
        'isOwnRequest': false,
        'createdAt': '2026-09-01T12:00:00Z',
        'updatedAt': '2026-09-01T12:00:00Z',
      };

  http.Response pageResponse({
    required List<String> ids,
    int total = 0,
    bool? hasMore,
    String? nextCursor,
  }) {
    return http.Response(
      jsonEncode({
        'requests': ids.map(requestRow).toList(),
        'total': total,
        if (hasMore != null) 'hasMore': hasMore,
        if (nextCursor != null) 'nextCursor': nextCursor,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  group('client: cursor contract', () {
    test('fetchFeatureRequests(cursor: …) sends cursor and omits offset',
        () async {
      final requestsSeen = <http.Request>[];
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          requestsSeen.add(request);
          return pageResponse(ids: ['fr_1'], total: 2, hasMore: true);
        }),
      );

      final result = await client.fetchFeatureRequests(
        userToken: 'tok',
        cursor: 'cur_page_2',
      );

      expect(requestsSeen, hasLength(1));
      final params = requestsSeen.first.url.queryParameters;
      expect(params['cursor'], 'cur_page_2');
      expect(params.containsKey('offset'), isFalse,
          reason: 'the API marks offset as legacy; sending both is ambiguous');
      // The keyset metadata is exposed verbatim.
      expect(result.hasMore, isTrue);
      expect(result.nextCursor, isNull);
      expect(result.requests.single.id, 'fr_1');
    });

    test('no cursor keeps the legacy offset parameter', () async {
      http.Request? captured;
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          captured = request;
          return pageResponse(ids: [], total: 0);
        }),
      );

      await client.fetchFeatureRequests(userToken: 'tok', offset: 10);

      final params = captured!.url.queryParameters;
      expect(params['offset'], '10');
      expect(params.containsKey('cursor'), isFalse);
    });

    test('limit is clamped to the documented 1–200 range', () async {
      final limitsSeen = <String>[];
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          limitsSeen.add(request.url.queryParameters['limit']!);
          return pageResponse(ids: [], total: 0);
        }),
      );

      await client.fetchFeatureRequests(userToken: 'tok', limit: 0);
      await client.fetchFeatureRequests(userToken: 'tok', limit: -5);
      await client.fetchFeatureRequests(userToken: 'tok', limit: 500);
      await client.fetchFeatureRequests(userToken: 'tok', limit: 50);

      expect(limitsSeen, ['1', '1', '200', '50']);
    });

    test('a blank cursor falls back to the offset form', () async {
      http.Request? captured;
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          captured = request;
          return pageResponse(ids: [], total: 0);
        }),
      );

      await client.fetchFeatureRequests(userToken: 'tok', cursor: '');

      final params = captured!.url.queryParameters;
      expect(params['offset'], '0');
      expect(params.containsKey('cursor'), isFalse);
    });
  });

  group('model: pagination metadata', () {
    test('parses hasMore and nextCursor verbatim', () {
      final result = ListFeatureRequestsResult.fromJson({
        'requests': [requestRow('fr_1')],
        'total': 5,
        'hasMore': true,
        'nextCursor': 'cur_next',
      });
      expect(result.hasMore, isTrue);
      expect(result.nextCursor, 'cur_next');
    });

    test('a legacy response without metadata parses tolerantly', () {
      final result = ListFeatureRequestsResult.fromJson({
        'requests': [requestRow('fr_1')],
        'total': 1,
      });
      expect(result.hasMore, isFalse);
      expect(result.nextCursor, isNull);
    });

    test('a blank nextCursor parses as null, and null total falls back',
        () {
      final result = ListFeatureRequestsResult.fromJson({
        'requests': [requestRow('fr_1'), requestRow('fr_2')],
        'nextCursor': '',
      });
      expect(result.nextCursor, isNull);
      expect(result.hasMore, isFalse);
      expect(result.total, 2, reason: 'falls back to the raw row count');
    });
  });

  group('FeatureRequestsScreen load-more', () {
    FeedbackClient cursorClient(List<http.Request> requestsSeen) {
      return FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: config,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/versions/')) {
            return http.Response(
              jsonEncode({'versions': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/feature-requests') {
            requestsSeen.add(request);
            final cursor = request.url.queryParameters['cursor'];
            if (cursor == null) {
              return pageResponse(
                ids: const ['fr_1', 'fr_2'],
                total: 4,
                hasMore: true,
                nextCursor: 'cur_page_2',
              );
            }
            if (cursor == 'cur_page_2') {
              return pageResponse(
                ids: const ['fr_3', 'fr_4'],
                total: 4,
                hasMore: false,
              );
            }
            // Unknown cursor: empty terminal page.
            return pageResponse(ids: const [], total: 4);
          }
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
    }

    Widget host(FeedbackClient client) => MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            platformOverride: FeedbackPlatform.ios,
            child: const FeatureRequestsScreen(),
          ),
        );

    testWidgets('page 2 is requested with page 1’s cursor and no offset',
        (tester) async {
      final requestsSeen = <http.Request>[];
      await tester.pumpWidget(host(cursorClient(requestsSeen)));
      await tester.pumpAndSettle();

      expect(requestsSeen, hasLength(1));
      expect(requestsSeen.first.url.queryParameters.containsKey('cursor'),
          isFalse);
      expect(find.text('Request fr_1'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(requestsSeen, hasLength(2));
      final page2 = requestsSeen.last.url.queryParameters;
      expect(page2['cursor'], 'cur_page_2');
      expect(page2.containsKey('offset'), isFalse);
      expect(find.text('Request fr_3'), findsOneWidget);
      expect(find.text('Request fr_4'), findsOneWidget);
      // Last page: no cursor, hasMore false, offset walk exhausted.
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('a repeated cursor from a misbehaving server ends the walk',
        (tester) async {
      final requestsSeen = <http.Request>[];
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: config,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/versions/')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          if (request.url.path == '/api/v1/feature-requests') {
            requestsSeen.add(request);
            // Every page — including the follow-up — re-sends the same
            // cursor: the server is stuck. The screen must not loop on it.
            return pageResponse(
              ids: const ['fr_1', 'fr_2'],
              total: 99,
              hasMore: true,
              nextCursor: 'cur_stuck',
            );
          }
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(requestsSeen, hasLength(2));
      expect(requestsSeen.last.url.queryParameters['cursor'], 'cur_stuck');
      // The stuck cursor was consumed, not adopted: no further hop exists.
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('a legacy server without metadata still walks by offset',
        (tester) async {
      final requestsSeen = <http.Request>[];
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: config,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/versions/')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          if (request.url.path == '/api/v1/feature-requests') {
            requestsSeen.add(request);
            final offset =
                int.parse(request.url.queryParameters['offset'] ?? '0');
            if (offset == 0) {
              // Legacy response: no hasMore / nextCursor at all.
              return http.Response(
                jsonEncode({
                  'requests': [requestRow('fr_1'), requestRow('fr_2')],
                  'total': 3,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return pageResponse(ids: const ['fr_3'], total: 3);
          }
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();

      expect(requestsSeen.single.url.queryParameters['offset'], '0');
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(requestsSeen, hasLength(2));
      final page2 = requestsSeen.last.url.queryParameters;
      expect(page2['offset'], '2');
      expect(page2.containsKey('cursor'), isFalse);
      expect(find.text('Request fr_3'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });
  });

  group('RoadmapBoardScreen load-more', () {
    testWidgets('page 2 is requested with page 1’s cursor', (tester) async {
      final requestsSeen = <http.Request>[];
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: config,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/columns/')) {
            return http.Response(
              jsonEncode({
                'columns': [
                  {'id': 'col_1', 'name': 'Planned', 'position': 0}
                ]
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/feature-requests') {
            requestsSeen.add(request);
            final cursor = request.url.queryParameters['cursor'];
            if (cursor == null) {
              return pageResponse(
                ids: const ['fr_1'],
                total: 2,
                hasMore: true,
                nextCursor: 'cur_board_2',
              );
            }
            if (cursor == 'cur_board_2') {
              return pageResponse(
                ids: const ['fr_2'],
                total: 2,
                hasMore: false,
              );
            }
            return pageResponse(ids: const [], total: 2);
          }
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      await tester.pumpWidget(MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          platformOverride: FeedbackPlatform.ios,
          child: const RoadmapBoardScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(requestsSeen, hasLength(1));
      expect(find.text('Request fr_1'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(requestsSeen, hasLength(2));
      final page2 = requestsSeen.last.url.queryParameters;
      expect(page2['cursor'], 'cur_board_2');
      expect(page2.containsKey('offset'), isFalse);
      expect(find.text('Request fr_2'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });
  });
}
