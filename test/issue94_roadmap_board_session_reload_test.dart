import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #94: `RoadmapBoardScreen._checkAndLoad`
/// tracked only the config as its reload trigger, so a session change (the
/// host signing the user in and rebuilding `CupThreadTheme(userToken: …)`)
/// never reloaded the board. The rows kept the anonymous identity's
/// `hasVoted` / `isOwnRequest` while `_handleToggleVote` read the session
/// live, so the next tap was cast under the new identity against UI state
/// computed for the old one. The board now reloads on a session change,
/// mirroring `FeatureRequestsScreen._checkAndLoad`.
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

  FeedbackClient clientWithIdentityScopedRows({
    required ValueNotifier<int> fetchCount,
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
          fetchCount.value += 1;
          final n = fetchCount.value;
          // The server answers per identity: the anonymous session has not
          // voted (5), the authenticated one already has (6). Call-count
          // keyed because the client resolves its own anonymous
          // `X-User-Token` when none is supplied.
          final isSignedInIdentity = n >= 2;
          return http.Response(
            jsonEncode({
              'requests': [
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
                  'voteCount': isSignedInIdentity ? 6 : 5,
                  'hasVoted': isSignedInIdentity,
                  'isOwnRequest': false,
                  'createdAt': '2026-09-01T12:00:00Z',
                  'updatedAt': '2026-09-01T12:00:00Z',
                },
              ],
              'totalCount': 1,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );
  }

  Widget host(FeedbackClient client, {String? userToken}) => MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          platformOverride: FeedbackPlatform.ios,
          userToken: userToken,
          child: const RoadmapBoardScreen(),
        ),
      );

  testWidgets('a session change reloads the board with the new identity rows',
      (tester) async {
    final requestsServed = ValueNotifier<int>(0);
    final client = clientWithIdentityScopedRows(fetchCount: requestsServed);

    // Anonymous session: one fetch, rows show the anonymous vote state.
    await tester.pumpWidget(host(client, userToken: null));
    await tester.pumpAndSettle();

    expect(requestsServed.value, 1);
    expect(find.text('Dark mode support'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    // The host signs the user in and rebuilds the scope with the same
    // config instance — the session change alone must trigger a reload.
    await tester.pumpWidget(host(client, userToken: 'usr_tok_signed_in'));
    await tester.pumpAndSettle();

    expect(requestsServed.value, 2);
    // The board now renders the authenticated identity's row state.
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('a vote response landing after the reload does not overwrite '
      'the new identity rows', (tester) async {
    // An anonymous vote is in flight when the host signs the user in and
    // the board reloads under the signed-in identity. The response's
    // `voted` belongs to the anonymous session and must not replace the
    // reloaded row's `hasVoted`; the global `voteCount` still reconciles.
    final voteResponse = Completer<http.Response>();
    final requestsServed = ValueNotifier<int>(0);
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
          requestsServed.value += 1;
          final signedIn = requestsServed.value >= 2;
          return http.Response(
            jsonEncode({
              'requests': [
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
                  'voteCount': signedIn ? 6 : 5,
                  'hasVoted': false,
                  'isOwnRequest': false,
                  'createdAt': '2026-09-01T12:00:00Z',
                  'updatedAt': '2026-09-01T12:00:00Z',
                },
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
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );

    VoteButton voteButton(WidgetTester tester) =>
        tester.widget<VoteButton>(find.byType(VoteButton));

    // Anonymous session: row shows the anonymous vote state.
    await tester.pumpWidget(host(client, userToken: null));
    await tester.pumpAndSettle();
    expect(voteButton(tester).hasVoted, isFalse);
    expect(voteButton(tester).voteCount, 5);

    // Tap to vote: the optimistic update applies, then the vote request
    // parks on the completer.
    await tester.tap(find.byType(VoteButton));
    await tester.pump();

    // The user signs in while the vote is in flight: the board reloads
    // under the signed-in identity (rows show its unvoted state, count 6).
    await tester.pumpWidget(host(client, userToken: 'usr_tok_signed_in'));
    await tester.pumpAndSettle();
    expect(requestsServed.value, 2);
    expect(voteButton(tester).hasVoted, isFalse);
    expect(voteButton(tester).voteCount, 6);

    // The stale anonymous vote response lands: `voted: true` is the
    // anonymous identity's state and must NOT replace the signed-in row's
    // `hasVoted`, while the global count reconciles to 7.
    voteResponse.complete(http.Response(
      jsonEncode({'voted': true, 'voteCount': 7}),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await tester.pumpAndSettle();

    expect(voteButton(tester).hasVoted, isFalse);
    expect(voteButton(tester).voteCount, 7);
  });

  testWidgets('FeatureRequestsScreen: a vote response landing after the '
      'reload does not overwrite the new identity rows', (tester) async {
    // Same race as the board test, on the requests screen whose vote
    // handler shares the identical apply-response code path.
    final voteResponse = Completer<http.Response>();
    final requestsServed = ValueNotifier<int>(0);
    final client = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      initialConfig: config,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          requestsServed.value += 1;
          final signedIn = requestsServed.value >= 2;
          return http.Response(
            jsonEncode({
              'requests': [
                {
                  'id': 'fr_1',
                  'appId': 'app_123',
                  'title': 'Dark mode support',
                  'description': 'Add full dark mode theme',
                  'status': 'under_review',
                  'approved': true,
                  'voteCount': signedIn ? 6 : 5,
                  'hasVoted': false,
                  'isOwnRequest': false,
                  'createdAt': '2026-09-01T12:00:00Z',
                  'updatedAt': '2026-09-01T12:00:00Z',
                },
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
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );

    Widget listHost(String? userToken) => MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            platformOverride: FeedbackPlatform.ios,
            userToken: userToken,
            child: const FeatureRequestsScreen(),
          ),
        );

    VoteButton voteButton(WidgetTester tester) =>
        tester.widget<VoteButton>(find.byType(VoteButton));

    await tester.pumpWidget(listHost(null));
    await tester.pumpAndSettle();
    expect(voteButton(tester).hasVoted, isFalse);
    expect(voteButton(tester).voteCount, 5);

    await tester.tap(find.byType(VoteButton));
    await tester.pump();

    await tester.pumpWidget(listHost('usr_tok_signed_in'));
    await tester.pumpAndSettle();
    expect(requestsServed.value, 2);
    expect(voteButton(tester).hasVoted, isFalse);
    expect(voteButton(tester).voteCount, 6);

    voteResponse.complete(http.Response(
      jsonEncode({'voted': true, 'voteCount': 7}),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await tester.pumpAndSettle();

    expect(voteButton(tester).hasVoted, isFalse);
    expect(voteButton(tester).voteCount, 7);
  });
}
