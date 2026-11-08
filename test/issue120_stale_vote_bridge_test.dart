import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #120 and the review follow-ups on its fix:
///
/// * A stale sheet vote response landing after a session-change reload must
///   not overwrite the reloaded identity's `hasVoted` — it reconciles only
///   the global `voteCount` (the original #120 fix).
/// * The discriminator is the session identity, not the request generation:
///   a same-identity reload (a config refresh or a search) must not strip
///   the confirmed response's session-valid `hasVoted` from the reloaded
///   row.
/// * The sheet's optimistic and rollback events are projections of the
///   sheet-open snapshot — after a reload they must leave the reloaded row
///   alone; only [FeatureRequestVoteEventKind.confirmed] carries server
///   truth and participates in reconciliation.
/// * The list screens' own `_handleToggleVote` applies the response's
///   `voted` under the same identity rule.
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

  /// A distinct config instance whose only difference is the display name:
  /// rebuilding the host with it reloads the screens (a config change in
  /// `_checkAndLoad`) while keeping the session identity (same `userToken`)
  /// — the same-identity reload the identity generation exists to
  /// recognize.
  const reloadedConfig = PublicAppConfig(
    appId: 'app_123',
    appKey: 'app_test_123',
    slug: 'test-app',
    name: 'Test App Reloaded',
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

  /// The same configs with anonymous-vote Turnstile verification required,
  /// so a row vote parks inside the preflight token provider — the async
  /// window the stale optimistic projection must be guarded against.
  const turnstileConfig = PublicAppConfig(
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
    requireAnonymousVoteTurnstile: true,
    sdk: SdkAppearance(
      features: SdkFeatures(
        feedback: true,
        featureRequests: true,
        roadmap: true,
        changelog: true,
      ),
    ),
  );

  const turnstileReloadedConfig = PublicAppConfig(
    appId: 'app_123',
    appKey: 'app_test_123',
    slug: 'test-app',
    name: 'Test App Reloaded',
    allowPublic: true,
    allowedPlatforms: [FeedbackPlatform.ios, FeedbackPlatform.android],
    maxAttachmentBytes: 1048576,
    allowAnonymousRoadmap: true,
    allowAnonymousVote: true,
    allowAnonymousFeedback: true,
    allowAnonymousChangelog: true,
    requireAnonymousVoteTurnstile: true,
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
    String columnName = 'Planned',
    String title = 'Dark mode support',
  }) =>
      {
        'id': 'fr_1',
        'appId': 'app_123',
        'title': title,
        'description': 'Add full dark mode theme',
        'status': 'under_review',
        'columnName': columnName,
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

    /// List requests serve the anonymous row (count 5) first and a
    /// re-refreshed row (count 7) afterwards, so a same-identity reload is
    /// observable. The vote endpoint parks on [voteResponse] when given,
    /// else fails with [voteStatus].
    FeedbackClient clientWithSameIdentityReload({
      required ValueNotifier<int> requestsServed,
      Completer<http.Response>? voteResponse,
      int voteStatus = 500,
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
            final reloaded = requestsServed.value >= 2;
            return http.Response(
              jsonEncode({
                'requests': [
                  requestJson(
                    voteCount: reloaded ? 7 : 5,
                    hasVoted: true,
                    // The reload carries refreshed moderation fields so the
                    // same-identity confirmed merge is observable: only the
                    // vote fields may change, the refreshed column must
                    // survive.
                    columnName: reloaded ? 'Shipped' : 'Planned',
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
            final parked = voteResponse;
            if (parked != null) return parked.future;
            return http.Response(
              jsonEncode({'error': 'vote failed'}),
              voteStatus,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    }

    Widget listHost(
      FeedbackClient client,
      String? userToken, [
      PublicAppConfig cfg = config,
    ]) =>
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: cfg,
            platformOverride: FeedbackPlatform.ios,
            userToken: userToken,
            child: const FeatureRequestsScreen(),
          ),
        );

    /// An unvoted anonymous row (count 5) served first and a re-refreshed
    /// unvoted row (count 7) afterwards. The config requires anonymous-vote
    /// Turnstile verification and the challenge provider parks on
    /// [challenge], so a new vote hangs inside the preflight — the async
    /// window between the tap and the optimistic write. The vote request
    /// itself parks on [voteResponse].
    FeedbackClient clientWithParkedPreflight({
      required Completer<String> challenge,
      required Completer<http.Response> voteResponse,
      required ValueNotifier<int> requestsServed,
    }) {
      return FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileChallengeTokenProvider: (_) => challenge.future,
        ),
        initialConfig: turnstileConfig,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/feature-requests') {
            requestsServed.value += 1;
            final reloaded = requestsServed.value >= 2;
            return http.Response(
              jsonEncode({
                'requests': [
                  requestJson(
                    voteCount: reloaded ? 7 : 5,
                    hasVoted: false,
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
      // the confirmed item (including `hasVoted`) must land on the row. The
      // response's `voted` deliberately disagrees with the optimistic value
      // so the assertion proves the confirmed response landed, not the
      // optimistic echo.
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
      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'the optimistic event applies in full within the same '
              'generation');
      expect(rowVoteButton(tester).voteCount, 4);

      voteResponse.complete(http.Response(
        jsonEncode({'voted': true, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(requestsServed.value, 1,
          reason: 'no reload happened in the control case');
      expect(rowVoteButton(tester).hasVoted, isTrue,
          reason: 'the confirmed response value — not the optimistic false — '
              'is applied wholesale within the same generation');
      expect(rowVoteButton(tester).voteCount, 5);
    });

    testWidgets('a stale confirmed response after a same-identity reload '
        'still applies its hasVoted — the identity, not the request '
        'generation, gates the voted flag', (tester) async {
      // A config refresh reloads the list while the sheet's removal vote is
      // in flight, but under the same anonymous identity: the confirmed
      // response's `voted: false` describes exactly the reloaded row, so it
      // must apply in full — the pre-identity-generation guard dropped it
      // because the request generation had advanced.
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithSameIdentityReload(
        requestsServed: requestsServed,
        voteResponse: voteResponse,
      );

      await tester.pumpWidget(listHost(client, null));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 5);

      await tester.tap(find.text('Dark mode support'));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isFalse);
      expect(rowVoteButton(tester).voteCount, 4);

      // Same identity, new config instance: the list reloads (the server
      // has not applied the removal yet — count 7, still voted).
      await tester.pumpWidget(listHost(client, null, reloadedConfig));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isTrue,
          reason: 'the reload replaced the optimistic projection with fresh '
              'server state');
      expect(rowVoteButton(tester).voteCount, 7);

      // The confirmed response lands: same identity, so `voted: false` is
      // valid for the reloaded row and must be applied together with the
      // authoritative count.
      voteResponse.complete(http.Response(
        jsonEncode({'voted': false, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'a same-identity reload must not strip the confirmed '
              'voted flag from the reloaded row');
      expect(rowVoteButton(tester).voteCount, 5);
      // The confirmed event merged only the vote fields: the refreshed
      // moderation column survives (the wholesale snapshot would have
      // reverted it to 'Planned').
      expect(find.text('Shipped'), findsOneWidget);
    });

    testWidgets('stale optimistic and rollback events after a reload leave '
        'the reloaded row untouched', (tester) async {
      // The reload completes before the sheet's vote is even attempted, so
      // the sheet's optimistic projection and its failure rollback are both
      // stale from the row's point of view: neither may reconcile the
      // reloaded count (the pre-kind guard stamped the stale snapshot's
      // count 4 onto the reloaded row).
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithSameIdentityReload(
        requestsServed: requestsServed,
        // The vote endpoint fails outright so the sheet rolls back.
        voteStatus: 500,
      );

      await tester.pumpWidget(listHost(client, null));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 5);

      await tester.tap(find.text('Dark mode support'));
      await tester.pumpAndSettle();

      // Same-identity reload while the sheet idles open.
      await tester.pumpWidget(listHost(client, null, reloadedConfig));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 7);

      // Tap to vote: the optimistic event fires stale, the request fails,
      // the rollback event fires stale.
      await tester.tap(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isTrue,
          reason: 'neither the stale optimistic nor the stale rollback event '
              'may touch the reloaded identity state');
      expect(rowVoteButton(tester).voteCount, 7,
          reason: 'the stale snapshot counts (4 and 5) must not stamp over '
              'the reloaded count');
      // The sheet itself rolled back to its own snapshot.
      expect(sheetVoteButton(tester).hasVoted, isTrue);
      expect(sheetVoteButton(tester).voteCount, 5);
    });

    testWidgets('a list vote response landing after a same-identity reload '
        'still applies its voted flag', (tester) async {
      // The row's own toggle vote races a same-identity reload instead of a
      // session change: the response's `voted` stays valid for the reloaded
      // row and must not be dropped.
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithSameIdentityReload(
        requestsServed: requestsServed,
        voteResponse: voteResponse,
      );

      await tester.pumpWidget(listHost(client, null));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 5);

      // Tap the row's vote: optimistic false/4, request parks.
      await tester.tap(find.byType(VoteButton));
      await tester.pump();

      // Same-identity reload: the optimistic projection is replaced by the
      // reloaded server state.
      await tester.pumpWidget(listHost(client, null, reloadedConfig));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 7);

      voteResponse.complete(http.Response(
        jsonEncode({'voted': false, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'the response voted flag is the same identity\'s truth and '
              'must survive the intervening reload');
      expect(rowVoteButton(tester).voteCount, 5);
    });

    testWidgets('a reload landing inside the Turnstile preflight skips the '
        'stale optimistic projection', (tester) async {
      // The preflight parks while a same-identity reload replaces the list.
      // The optimistic projection is computed from the pre-preflight row —
      // writing it onto the reloaded row would flip the reloaded hasVoted
      // and stamp the stale count, and its failure rollback would be
      // skipped as stale, persisting the wrong state until the next
      // refresh.
      final challenge = Completer<String>();
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithParkedPreflight(
        challenge: challenge,
        voteResponse: voteResponse,
        requestsServed: requestsServed,
      );

      await tester.pumpWidget(listHost(client, null, turnstileConfig));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isFalse);
      expect(rowVoteButton(tester).voteCount, 5);

      // Tap to vote: the Turnstile preflight parks before the optimistic
      // write (a new vote is verified; the row is not voted yet).
      await tester.tap(find.byType(VoteButton));
      await tester.pump();

      // The same-identity reload lands while the verification is pending.
      await tester.pumpWidget(listHost(client, null, turnstileReloadedConfig));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isFalse);
      expect(rowVoteButton(tester).voteCount, 7);

      // The verification resolves: the stale optimistic projection
      // (voted true, count 5 + 1) must not be written onto the reloaded
      // row; the vote request itself proceeds.
      challenge.complete('turnstile_token');
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'the pre-preflight optimistic projection must be skipped '
              'after a reload replaced the list');
      expect(rowVoteButton(tester).voteCount, 7,
          reason: 'the stale 5 + 1 count must not stamp over the reloaded '
              'count');

      // The confirmed response still reconciles the reloaded row under the
      // same identity.
      voteResponse.complete(http.Response(
        jsonEncode({'voted': true, 'voteCount': 8}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 8);
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

    /// Board requests serve the anonymous row (count 5) first and a
    /// re-refreshed row (count 7) afterwards; the vote endpoint parks on
    /// [voteResponse] when given, else fails with [voteStatus].
    FeedbackClient clientWithSameIdentityReload({
      required ValueNotifier<int> requestsServed,
      Completer<http.Response>? voteResponse,
      int voteStatus = 500,
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
            final reloaded = requestsServed.value >= 2;
            return http.Response(
              jsonEncode({
                'requests': [
                  requestJson(
                    voteCount: reloaded ? 7 : 5,
                    hasVoted: true,
                    // The board renders one selected column at a time, so
                    // the refreshed field must be one the visible card
                    // renders: the title. The same-identity confirmed merge
                    // must keep it instead of reverting to the sheet-open
                    // snapshot.
                    title: reloaded
                        ? 'Dark mode support (refreshed)'
                        : 'Dark mode support',
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
            final parked = voteResponse;
            if (parked != null) return parked.future;
            return http.Response(
              jsonEncode({'error': 'vote failed'}),
              voteStatus,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    }

    Widget boardHost(
      FeedbackClient client,
      String? userToken, [
      PublicAppConfig cfg = config,
    ]) =>
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: cfg,
            platformOverride: FeedbackPlatform.ios,
            userToken: userToken,
            child: const RoadmapBoardScreen(),
          ),
        );

    /// Board variant of the parked-preflight client: an unvoted anonymous
    /// row (count 5) served first and a re-refreshed unvoted row (count 7)
    /// afterwards, the challenge provider parked on [challenge], and the
    /// vote request parked on [voteResponse]. Mirrors the requests-screen
    /// builder.
    FeedbackClient clientWithParkedPreflight({
      required Completer<String> challenge,
      required Completer<http.Response> voteResponse,
      required ValueNotifier<int> requestsServed,
    }) {
      return FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileChallengeTokenProvider: (_) => challenge.future,
        ),
        initialConfig: turnstileConfig,
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
            final reloaded = requestsServed.value >= 2;
            return http.Response(
              jsonEncode({
                'requests': [
                  requestJson(
                    voteCount: reloaded ? 7 : 5,
                    hasVoted: false,
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

    testWidgets('without an intervening reload the bridge still applies the '
        'sheet item in full', (tester) async {
      // Control case mirroring the requests screen: the response's `voted`
      // disagrees with the optimistic value so the assertion proves the
      // confirmed response landed.
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithParkedVote(
        voteResponse: voteResponse,
        requestsServed: requestsServed,
      );

      await tester.pumpWidget(boardHost(client, null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark mode support'));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));
      await tester.pump();
      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'the optimistic event applies in full within the same '
              'generation');
      expect(rowVoteButton(tester).voteCount, 4);

      voteResponse.complete(http.Response(
        jsonEncode({'voted': true, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(requestsServed.value, 1,
          reason: 'no reload happened in the control case');
      expect(rowVoteButton(tester).hasVoted, isTrue,
          reason: 'the confirmed response value — not the optimistic false — '
              'is applied wholesale within the same generation');
      expect(rowVoteButton(tester).voteCount, 5);
    });

    testWidgets('a stale confirmed response after a same-identity reload '
        'still applies its hasVoted', (tester) async {
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithSameIdentityReload(
        requestsServed: requestsServed,
        voteResponse: voteResponse,
      );

      await tester.pumpWidget(boardHost(client, null));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 5);

      await tester.tap(find.text('Dark mode support'));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isFalse);
      expect(rowVoteButton(tester).voteCount, 4);

      // Same identity, new config instance: the board reloads.
      await tester.pumpWidget(boardHost(client, null, reloadedConfig));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 7);

      voteResponse.complete(http.Response(
        jsonEncode({'voted': false, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'a same-identity reload must not strip the confirmed '
              'voted flag from the reloaded row');
      expect(rowVoteButton(tester).voteCount, 5);
      // Only the vote fields merged: the refreshed title survives, so the
      // card does not revert to the sheet-open snapshot.
      expect(find.text('Dark mode support (refreshed)'), findsOneWidget);
    });

    testWidgets('stale optimistic and rollback events after a reload leave '
        'the reloaded row untouched', (tester) async {
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithSameIdentityReload(
        requestsServed: requestsServed,
        voteStatus: 500,
      );

      await tester.pumpWidget(boardHost(client, null));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 5);

      await tester.tap(find.text('Dark mode support'));
      await tester.pumpAndSettle();

      // Same-identity reload while the sheet idles open.
      await tester.pumpWidget(boardHost(client, null, reloadedConfig));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 7);

      await tester.tap(find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isTrue,
          reason: 'neither the stale optimistic nor the stale rollback event '
              'may touch the reloaded identity state');
      expect(rowVoteButton(tester).voteCount, 7,
          reason: 'the stale snapshot counts must not stamp over the '
              'reloaded count');
      expect(sheetVoteButton(tester).hasVoted, isTrue);
      expect(sheetVoteButton(tester).voteCount, 5);
    });

    testWidgets('a list vote response landing after a same-identity reload '
        'still applies its voted flag', (tester) async {
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithSameIdentityReload(
        requestsServed: requestsServed,
        voteResponse: voteResponse,
      );

      await tester.pumpWidget(boardHost(client, null));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 5);

      // Tap the row's vote: optimistic false/4, request parks.
      await tester.tap(find.byType(VoteButton));
      await tester.pump();

      // Same-identity reload replaces the optimistic projection.
      await tester.pumpWidget(boardHost(client, null, reloadedConfig));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 7);

      voteResponse.complete(http.Response(
        jsonEncode({'voted': false, 'voteCount': 5}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'the response voted flag is the same identity\'s truth and '
              'must survive the intervening reload');
      expect(rowVoteButton(tester).voteCount, 5);
    });

    testWidgets('a reload landing inside the Turnstile preflight skips the '
        'stale optimistic projection', (tester) async {
      final challenge = Completer<String>();
      final voteResponse = Completer<http.Response>();
      final requestsServed = ValueNotifier<int>(0);
      final client = clientWithParkedPreflight(
        challenge: challenge,
        voteResponse: voteResponse,
        requestsServed: requestsServed,
      );

      await tester.pumpWidget(boardHost(client, null, turnstileConfig));
      await tester.pumpAndSettle();
      expect(rowVoteButton(tester).hasVoted, isFalse);
      expect(rowVoteButton(tester).voteCount, 5);

      // Tap to vote: the Turnstile preflight parks before the optimistic
      // write.
      await tester.tap(find.byType(VoteButton));
      await tester.pump();

      // The same-identity reload lands while the verification is pending.
      await tester
          .pumpWidget(boardHost(client, null, turnstileReloadedConfig));
      await tester.pumpAndSettle();
      expect(requestsServed.value, 2);
      expect(rowVoteButton(tester).hasVoted, isFalse);
      expect(rowVoteButton(tester).voteCount, 7);

      // The verification resolves: the stale optimistic projection must
      // not be written onto the reloaded row; the vote request proceeds.
      challenge.complete('turnstile_token');
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isFalse,
          reason: 'the pre-preflight optimistic projection must be skipped '
              'after a reload replaced the board');
      expect(rowVoteButton(tester).voteCount, 7,
          reason: 'the stale 5 + 1 count must not stamp over the reloaded '
              'count');

      // The confirmed response still reconciles the reloaded row under the
      // same identity.
      voteResponse.complete(http.Response(
        jsonEncode({'voted': true, 'voteCount': 8}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(rowVoteButton(tester).hasVoted, isTrue);
      expect(rowVoteButton(tester).voteCount, 8);
    });
  });
}
