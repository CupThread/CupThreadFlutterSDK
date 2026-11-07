import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #78: the widget-level vote preflight
/// (`resolveVoteTurnstileToken`) consulted only the legacy, context-free
/// `FeedbackClientConfig.turnstileTokenProvider`, so a host configuring only
/// the preferred binding-aware `turnstileChallengeTokenProvider` (the
/// migration path issue #75 documented) dead-ended every anonymous vote in
/// the bundled voting surfaces — the preflight found no legacy provider and
/// aborted with the verification notice even though `castVote` itself would
/// have resolved a token correctly. The preflight now mirrors the client's
/// `_resolveTurnstileToken` precedence: the binding-aware provider receives
/// exactly `TurnstileChallenge.vote(appKey)` first (an empty result ends
/// resolution — no fall-through to the legacy provider), and the legacy
/// provider resolves only when no binding-aware provider is configured.
void main() {
  // ---------- Fixtures ----------

  PublicAppConfig widgetConfig() => const PublicAppConfig(
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

  Map<String, dynamic> featureRequestJson({bool hasVoted = false}) => {
        'id': 'fr_1',
        'appId': 'app_123',
        'title': 'Dark mode',
        'description': 'Ship a dark theme',
        'status': 'backlog',
        'approved': true,
        'voteCount': 5,
        'hasVoted': hasVoted,
        'isOwnRequest': false,
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      };

  Widget host(FeedbackClient client, PublicAppConfig config) => MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          platformOverride: FeedbackPlatform.ios,
          child: const FeatureRequestsScreen(),
        ),
      );

  FeedbackClient clientWith(
    MockClient fn, {
    TurnstileTokenProvider? provider,
    TurnstileChallengeTokenProvider? challengeProvider,
  }) =>
      FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: provider,
          turnstileChallengeTokenProvider: challengeProvider,
        ),
        httpClient: fn,
        initialConfig: widgetConfig(),
      );

  /// Mock transport serving the request list the voting screens load.
  MockClient mockTransport(
    List<http.Request> requests, {
    Map<String, Object Function()> extraRoutes = const {},
  }) =>
      MockClient((request) async {
        requests.add(request);
        for (final entry in extraRoutes.entries) {
          if (request.url.path.endsWith(entry.key)) {
            return http.Response(
              jsonEncode(entry.value()),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({
              'requests': [featureRequestJson()],
              'totalCount': 1,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions') ||
            request.url.path.endsWith('/columns')) {
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      });

  group('issue #78 — FeatureRequestsScreen preflight resolves the binding-aware provider', () {
    testWidgets('challenge-only host can cast an anonymous vote; provider receives the vote binding',
        (tester) async {
      final requests = <http.Request>[];
      TurnstileChallenge? receivedChallenge;
      final client = clientWith(
        mockTransport(requests, extraRoutes: {
          '/vote': () => {'voted': true, 'voteCount': 6},
        }),
        challengeProvider: (challenge) async {
          receivedChallenge = challenge;
          return 'tok_binding';
        },
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      // The binding-aware provider received exactly the vote binding.
      expect(receivedChallenge, isNotNull);
      expect(receivedChallenge!.action, TurnstileAction.vote);
      expect(receivedChallenge!.cdata, 'app_test_123');

      // The vote left the client carrying the provider-minted token.
      final voteRequests =
          requests.where((r) => r.url.path.endsWith('/vote')).toList();
      expect(voteRequests, hasLength(1));
      expect(jsonDecode(voteRequests.single.body)['turnstileToken'],
          'tok_binding');
      expect(find.text('6'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'binding-aware provider wins over the legacy one when both are configured',
        (tester) async {
      final requests = <http.Request>[];
      var legacyConsulted = false;
      final client = clientWith(
        mockTransport(requests, extraRoutes: {
          '/vote': () => {'voted': true, 'voteCount': 6},
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
        challengeProvider: (challenge) async => 'tok_binding',
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      expect(legacyConsulted, isFalse);
      final voteRequests =
          requests.where((r) => r.url.path.endsWith('/vote')).toList();
      expect(voteRequests, hasLength(1));
      expect(jsonDecode(voteRequests.single.body)['turnstileToken'],
          'tok_binding');
    });

    testWidgets(
        'an empty binding-aware result ends resolution without falling through to the legacy provider',
        (tester) async {
      final requests = <http.Request>[];
      var legacyConsulted = false;
      final client = clientWith(
        mockTransport(requests),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
        challengeProvider: (challenge) async => '   ',
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      // Mirrors FeedbackClient._resolveTurnstileToken: an empty result from
      // the binding-aware provider must not surface a second verification
      // flow through the legacy provider.
      expect(legacyConsulted, isFalse);
      expect(
        requests.where((r) => r.url.path.endsWith('/vote')),
        isEmpty,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Human verification is required'),
          findsOneWidget);
    });

    testWidgets(
        'a throwing binding-aware provider surfaces the notice instead of crashing',
        (tester) async {
      final requests = <http.Request>[];
      final client = clientWith(
        mockTransport(requests),
        challengeProvider: (challenge) async => throw StateError('mint failed'),
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      expect(
        requests.where((r) => r.url.path.endsWith('/vote')),
        isEmpty,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'with neither provider configured the vote still aborts with the notice',
        (tester) async {
      final requests = <http.Request>[];
      final client = clientWith(mockTransport(requests));

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      expect(
        requests.where((r) => r.url.path.endsWith('/vote')),
        isEmpty,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('5'), findsWidgets);
      expect(find.text('6'), findsNothing);
    });
  });

  group('issue #78 — RoadmapBoardScreen preflight resolves the binding-aware provider', () {
    testWidgets('challenge-only host can cast an anonymous vote', (tester) async {
      final requests = <http.Request>[];
      TurnstileChallenge? receivedChallenge;
      final client = clientWith(
        mockTransport(requests, extraRoutes: {
          '/vote': () => {'voted': true, 'voteCount': 6},
        }),
        challengeProvider: (challenge) async {
          receivedChallenge = challenge;
          return 'tok_board';
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: widgetConfig(),
            platformOverride: FeedbackPlatform.ios,
            child: const RoadmapBoardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      expect(receivedChallenge!.action, TurnstileAction.vote);
      expect(receivedChallenge!.cdata, 'app_test_123');
      final voteRequests =
          requests.where((r) => r.url.path.endsWith('/vote')).toList();
      expect(voteRequests, hasLength(1));
      expect(jsonDecode(voteRequests.single.body)['turnstileToken'],
          'tok_board');
    });
  });
}
