import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #120: the detail sheet's `onVoteChange`
/// bridge replaced the list row wholesale, so a stale-session vote response
/// landing after a reload overwrote the reloaded identity's `hasVoted` —
/// exactly the overwrite the screens' own `_handleToggleVote` path refuses
/// to do. The bridge now captures the request generation when the card is
/// built and, on a mismatch, reconciles only the global `voteCount`.
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

  Map<String, dynamic> requestJson({
    required int voteCount,
    required bool hasVoted,
  }) =>
      {
        'id': 'fr_1',
        'appId': 'app_123',
        'title': 'Dark mode support',
        'description': 'Add full dark mode theme',
        'status': 'under_review',
        'columnName': 'Planned',
        'columnColor': '#3B82F6',
        'columnId': 'col_1',
        'approved': true,
        'voteCount': voteCount,
        'hasVoted': hasVoted,
        'isOwnRequest': false,
        'createdAt': '2026-09-01T12:00:00Z',
        'updatedAt': '2026-09-01T12:00:00Z',
      };

  /// The list row's vote button — the sheet has its own, and the sheet is
  /// not wrapped in a [RefreshIndicator].
  VoteButton rowVoteButton(WidgetTester tester) =>
      tester.widget<VoteButton>(find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(VoteButton),
      ));

  /// The detail sheet's vote button.
  VoteButton sheetVoteButton(WidgetTester tester) =>
      tester.widget<VoteButton>(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));

  group('FeatureRequestsScreen', () {
    FeedbackClient clientWithParkedVote({
      required Completer<http.Response> voteResponse,
      required ValueNotifier<int> requestsServed,
    }) {
      return FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: config,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/feature-requests') {
            requestsServed.value += 1;
            final signedIn = requestsServed.value >= 2;
            // Both identities have voted; the counts differ so the reload is
            // observable.
            return http.Response(
              jsonEncode({
                'requests': [
                  requestJson(
                    voteCount: signedIn ? 6 : 5,
                    hasVoted: true,
                  ),
                ],
                'totalCount': 1,
                'hasMore': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.contains('/versions')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          if (request.url.path == '/api/v1/feature-requests/fr_1/vote') {
            return voteResponse.future;
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    }

    Widget listHost(FeedbackClient client, String? userToken) => MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            platformOverride: FeedbackPlatform.ios,
            userToken: userToken,
            child: const FeatureRequestsScreen(),
          ),
        );

    testWidgets('a stale sheet vote response after a reload only reconciles '
        'the voteCount — the reloaded identity keeps its hasVoted',
        (tester) async {
      // The anonymous session has already voted (removal flow, so the
      // response's `voted: false` differs from the reloaded identity's
      // `hasVoted: true` — the sharpest overwrite signal).
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithParkedVote(
        voteResponse: voteResponse,
        requestsServed: requestsServed,
      );

      // Anonymous session: the row shows the anonymous vote state.
      await tester.pumpWidget(listHost(client, null));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 5);

      // Open the detail sheet and tap its vote button: the optimistic update
      // fires the bridge under the same generation and applies in full.
      await tester.tap(find.text('Dark mode support'));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureRequestDetailSheet), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isFalse);
      expect(rowVoteButton(tester).voteCount, 4);

      // The host signs the user in while the sheet's vote is in flight: the
      // screen reloads under the signed-in identity (hasVoted true, count 6)
      // and bumps the request generation.
      await tester.pumpWidget(listHost(client, 'usr_tok_signed_in'));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 6);

      // The stale vote response lands: `voted: false` belongs to the
      // anonymous session that removed the vote — it must NOT replace the
      // signed-in row's `hasVoted`, while the global count reconciles to 5.
      voteResponse.complete(http.Response(
        jsonEncode({'voted': false, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isTrue,
          reason: 'the reloaded identity hasVoted must survive the stale '
              'sheet vote response');
      expect(rowVoteButton(tester).voteCount, 5,
          reason: 'the global voteCount still reconciles');
      // The sheet itself keeps its own session's truth.
      expect(sheetVoteButton(tester).hasVoted, isFalse);
      expect(sheetVoteButton(tester).voteCount, 5);
    });

    testWidgets('without an intervening reload the bridge still applies the '
        'sheet item in full', (tester) async {
      // Control case: the vote flow runs entirely within one generation, so
      // the confirmed item (including `hasVoted`) must land on the row.
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithParkedVote(
        voteResponse: voteResponse,
        requestsServed: requestsServed,
      );

      await tester.pumpWidget(listHost(client, null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark mode support'));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));
      await tester.pump();

      voteResponse.complete(http.Response(
        jsonEncode({'voted': false, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(requestsServed.value, 1,
          reason: 'no reload happened in the control case');
      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'the sheet confirmed item is applied wholesale within the '
              'same generation');
      expect(rowVoteButton(tester).voteCount, 5);
    });
  });

  group('RoadmapBoardScreen', () {
    FeedbackClient clientWithParkedVote({
      required Completer<http.Response> voteResponse,
      required ValueNotifier<int> requestsServed,
    }) {
      return FeedbackClient(
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
            requestsServed.value += 1;
            final signedIn = requestsServed.value >= 2;
            return http.Response(
              jsonEncode({
                'requests': [
                  requestJson(
                    voteCount: signedIn ? 6 : 5,
                    hasVoted: true,
                  ),
                ],
                'totalCount': 1,
                'hasMore': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/feature-requests/fr_1/vote') {
            return voteResponse.future;
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    }

    Widget boardHost(FeedbackClient client, String? userToken) => MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            platformOverride: FeedbackPlatform.ios,
            userToken: userToken,
            child: const RoadmapBoardScreen(),
          ),
        );

    testWidgets('a stale sheet vote response after a reload only reconciles '
        'the voteCount — the reloaded identity keeps its hasVoted',
        (tester) async {
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithParkedVote(
        voteResponse: voteResponse,
        requestsServed: requestsServed,
      );

      // Anonymous session: the board row shows the anonymous vote state.
      await tester.pumpWidget(boardHost(client, null));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 5);

      // Open the detail sheet and tap its vote button.
      await tester.tap(find.text('Dark mode support'));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureRequestDetailSheet), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isFalse);
      expect(rowVoteButton(tester).voteCount, 4);

      // The host signs the user in while the sheet's vote is in flight: the
      // board reloads under the signed-in identity and bumps the generation.
      await tester.pumpWidget(boardHost(client, 'usr_tok_signed_in'));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 6);

      // The stale vote response lands: only the global count reconciles.
      voteResponse.complete(http.Response(
        jsonEncode({'voted': false, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isTrue,
          reason: 'the reloaded identity hasVoted must survive the stale '
              'sheet vote response');
      expect(rowVoteButton(tester).voteCount, 5,
          reason: 'the global voteCount still reconciles');
      expect(sheetVoteButton(tester).hasVoted, isFalse);
      expect(sheetVoteButton(tester).voteCount, 5);
    });
  });
}
