import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #125: the legacy offset walk of
/// `GET /api/v1/feature-requests` never stopped at the API's documented
/// clamp. The API contract (DATA-01 pagination note) clamps any `offset`
/// above 10000 back to 10000 and still answers `200`, so a legacy server
/// with more than 10000 rows answered every step past the ceiling with
/// the *same final page again* — the screens appended it repeatedly until
/// the reported total was reached, showing ~40 duplicate copies of the
/// last page instead of stopping. The client now mirrors the server
/// contract the way its `limit` clamp already mirrors the 1–200 contract:
/// it never sends an offset at or past `FeedbackClient.maxLegacyOffset`
/// and reports an exhausted page instead, which both screens' load-more
/// already treat as the end of the walk. Cursor walks are unaffected.
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

  group('client: offset clamp contract', () {
    FeedbackClient clampClient(
      List<http.Request> requestsSeen,
      http.Response Function() responder,
    ) {
      return FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          requestsSeen.add(request);
          return responder();
        }),
      );
    }

    http.Response emptyPage({int total = 0}) => http.Response(
          jsonEncode({'requests': <dynamic>[], 'total': total}),
          200,
          headers: {'content-type': 'application/json'},
        );

    test('an offset at the documented clamp reports exhaustion without a '
        'request', () async {
      final requestsSeen = <http.Request>[];
      final client = clampClient(requestsSeen, () => emptyPage(total: 99));

      final result = await client.fetchFeatureRequests(
        userToken: 'tok',
        offset: FeedbackClient.maxLegacyOffset,
      );

      expect(requestsSeen, isEmpty,
          reason: 'the server would clamp this offset and re-serve the '
              'same final page — it must never be sent');
      expect(result.requests, isEmpty);
      expect(result.pageRowCount, 0);
      expect(result.hasMore, isFalse);
      expect(result.nextCursor, isNull);
      expect(result.total, FeedbackClient.maxLegacyOffset,
          reason: 'total reports the addressable ceiling the caller '
              'reached, not the unknowable server total');
    });

    test('an offset past the clamp is refused the same way', () async {
      final requestsSeen = <http.Request>[];
      final client = clampClient(requestsSeen, () => emptyPage());

      final result = await client.fetchFeatureRequests(
        userToken: 'tok',
        offset: FeedbackClient.maxLegacyOffset + 500,
      );

      expect(requestsSeen, isEmpty);
      expect(result.requests, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.nextCursor, isNull);
    });

    test('the last addressable offset page is still served normally',
        () async {
      final requestsSeen = <http.Request>[];
      final client = clampClient(requestsSeen, () => emptyPage(total: 12000));

      await client.fetchFeatureRequests(
        userToken: 'tok',
        offset: FeedbackClient.maxLegacyOffset - 50,
      );

      expect(requestsSeen, hasLength(1));
      expect(requestsSeen.single.url.queryParameters['offset'],
          '${FeedbackClient.maxLegacyOffset - 50}');
    });

    test('cursor walks ignore the offset clamp entirely', () async {
      final requestsSeen = <http.Request>[];
      final client = clampClient(requestsSeen, () => emptyPage());

      // The screens always send the accumulated offset alongside the
      // cursor; a deep cursor walk must keep following the keyset page —
      // keyset cursors have no clamped offset at all.
      await client.fetchFeatureRequests(
        userToken: 'tok',
        offset: FeedbackClient.maxLegacyOffset * 3,
        cursor: 'cur_page_2',
      );

      expect(requestsSeen, hasLength(1));
      final params = requestsSeen.single.url.queryParameters;
      expect(params['cursor'], 'cur_page_2');
      expect(params.containsKey('offset'), isFalse);
    });
  });

  group('legacy offset walk stops at the clamp', () {
    /// A legacy (metadata-less) server with [total] rows that serves
    /// [pageSize] rows per page and clamps `offset` above the documented
    /// ceiling — any request past it receives the rows of offset 10000
    /// again, exactly like the real contract describes.
    FeedbackClient legacyServer({
      required int total,
      required int pageSize,
      required List<http.Request> requestsSeen,
      required List<String> servedIds,
    }) {
      return FeedbackClient(
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
            final requested =
                int.parse(request.url.queryParameters['offset'] ?? '0');
            // Server-side clamp: offsets above the documented ceiling are
            // clamped back to 10000 and still answer 200.
            final offset = requested > FeedbackClient.maxLegacyOffset
                ? FeedbackClient.maxLegacyOffset
                : requested;
            final end = (offset + pageSize).clamp(0, total);
            final ids = [
              for (var i = offset; i < end; i++) 'fr_$i',
            ];
            servedIds.addAll(ids);
            // Legacy response: no hasMore / nextCursor metadata at all.
            return http.Response(
              jsonEncode({
                'requests': ids.map(requestRow).toList(),
                'total': total,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
    }

    /// Drives the load-more control until it disappears (the walk ended),
    /// scrolling to the bottom before every tap. Bounded so a regression
    /// cannot hang the test — the buggy walk would exceed the bound.
    Future<void> driveWalkToEnd(WidgetTester tester, int maxTaps) async {
      ScrollableState verticalScrollable() {
        return tester
            .stateList<ScrollableState>(find.byType(Scrollable))
            .firstWhere((s) => s.widget.axis == Axis.vertical);
      }

      for (var tap = 0; tap < maxTaps; tap++) {
        final scroll = verticalScrollable().position;
        if (scroll.hasPixels &&
            scroll.hasContentDimensions &&
            scroll.maxScrollExtent > scroll.pixels) {
          scroll.jumpTo(scroll.maxScrollExtent);
          await tester.pump();
        }
        final loadMore = find.text('Load more');
        if (!tester.any(loadMore)) return;
        await tester.tap(loadMore);
        await tester.pumpAndSettle();
      }
      fail('the load-more walk did not terminate within $maxTaps taps');
    }

    testWidgets(
        'FeatureRequestsScreen: each row appears exactly once and the walk '
        'terminates at the clamp', (tester) async {
      const total = 12000; // beyond the 10000 ceiling
      const pageSize = 50; // the screen's default limit
      final requestsSeen = <http.Request>[];
      final servedIds = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: CupThreadTheme(
          client: legacyServer(
            total: total,
            pageSize: pageSize,
            requestsSeen: requestsSeen,
            servedIds: servedIds,
          ),
          config: config,
          platformOverride: FeedbackPlatform.ios,
          child: const FeatureRequestsScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // 10000 / 50 pages are addressable below the ceiling.
      await driveWalkToEnd(tester, 300);

      final offsets = requestsSeen
          .map((r) => int.parse(r.url.queryParameters['offset'] ?? '0'))
          .toList();
      expect(
          offsets,
          List.generate(
              FeedbackClient.maxLegacyOffset ~/ pageSize, (i) => i * pageSize),
          reason: 'the walk steps the legacy offset once per page and never '
              'sends an offset the server would clamp');
      expect(offsets.where((o) => o >= FeedbackClient.maxLegacyOffset),
          isEmpty);
      expect(servedIds, hasLength(FeedbackClient.maxLegacyOffset),
          reason: 'every addressable row is served');
      expect(servedIds.toSet().length, servedIds.length,
          reason: 'a clamped re-serve would duplicate the final page here');
      // The walk ended: no load-more row remains to tap.
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets(
        'RoadmapBoardScreen: each row appears exactly once and the walk '
        'terminates at the clamp', (tester) async {
      const total = 12000;
      const pageSize = 100; // the board's page size
      final requestsSeen = <http.Request>[];
      final servedIds = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: CupThreadTheme(
          client: legacyServer(
            total: total,
            pageSize: pageSize,
            requestsSeen: requestsSeen,
            servedIds: servedIds,
          ),
          config: config,
          platformOverride: FeedbackPlatform.ios,
          child: const RoadmapBoardScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      await driveWalkToEnd(tester, 200);

      final offsets = requestsSeen
          .map((r) => int.parse(r.url.queryParameters['offset'] ?? '0'))
          .toList();
      expect(
          offsets,
          List.generate(
              FeedbackClient.maxLegacyOffset ~/ pageSize, (i) => i * pageSize));
      expect(offsets.where((o) => o >= FeedbackClient.maxLegacyOffset),
          isEmpty);
      expect(servedIds, hasLength(FeedbackClient.maxLegacyOffset));
      expect(servedIds.toSet().length, servedIds.length);
      expect(find.text('Load more'), findsNothing);
    });
  });
}
