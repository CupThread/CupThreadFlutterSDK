import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #47: `PublicAppConfig` silently dropped
/// `turnstile.siteKey` and `requireAnonymousVoteTurnstile`, so hosts on
/// Turnstile-enforced deployments could neither learn the site key a token
/// must be minted against nor know anonymous votes are gated — every intake
/// call surfaced `TurnstileRequiredException` and then dead-ended. The config
/// model now carries both fields, `FeedbackClientConfig.makeTurnstileChallengeUrl`
/// exposes the portal's hosted challenge page (mirroring the Swift SDK's
/// contract), `castVote` resolves a token through the configured provider,
/// and the voting screens preflight the token before the optimistic update.
void main() {
  // ---------- Fixtures ----------

  Map<String, dynamic> configJson({
    Map<String, dynamic>? turnstile,
    bool? requireAnonymousVoteTurnstile,
  }) =>
      {
        'appId': 'app_123',
        'appKey': 'app_test_123',
        'slug': 'test-app',
        'name': 'Test App',
        'allowPublic': true,
        'allowedPlatforms': ['ios', 'android'],
        'maxAttachmentBytes': 1048576,
        'allowAnonymousRoadmap': true,
        'allowAnonymousVote': true,
        'allowAnonymousFeedback': true,
        'allowAnonymousChangelog': true,
        if (turnstile != null) 'turnstile': turnstile,
        if (requireAnonymousVoteTurnstile != null)
          'requireAnonymousVoteTurnstile': requireAnonymousVoteTurnstile,
        'sdk': {
          'theme': 'system',
          'features': {
            'feedback': true,
            'featureRequests': true,
            'roadmap': true,
            'changelog': true,
          },
        },
      };

  PublicAppConfig widgetConfig({bool requireVoteTurnstile = true}) =>
      PublicAppConfig(
        appId: 'app_123',
        appKey: 'app_test_123',
        slug: 'test-app',
        name: 'Test App',
        allowPublic: true,
        allowedPlatforms: const [FeedbackPlatform.ios, FeedbackPlatform.android],
        maxAttachmentBytes: 1048576,
        allowAnonymousRoadmap: true,
        allowAnonymousVote: true,
        allowAnonymousFeedback: true,
        allowAnonymousChangelog: true,
        requireAnonymousVoteTurnstile: requireVoteTurnstile,
        sdk: const SdkAppearance(
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

  group('issue #47 — PublicAppConfig Turnstile fields', () {
    test('parses turnstile.siteKey and requireAnonymousVoteTurnstile', () {
      final config = PublicAppConfig.fromJson(configJson(
        turnstile: {'siteKey': '0x4AAAAAAA_sitekey'},
        requireAnonymousVoteTurnstile: true,
      ));

      expect(config.turnstile, isNotNull);
      expect(config.turnstile!.siteKey, '0x4AAAAAAA_sitekey');
      expect(config.requireAnonymousVoteTurnstile, isTrue);
    });

    test('defaults sanely when the fields are absent', () {
      final config = PublicAppConfig.fromJson(configJson());

      expect(config.turnstile, isNull);
      expect(config.requireAnonymousVoteTurnstile, isFalse);
    });

    test('accepts a turnstile object with a null site key', () {
      final config = PublicAppConfig.fromJson(configJson(
        turnstile: {'siteKey': null},
      ));

      expect(config.turnstile, isNotNull);
      expect(config.turnstile!.siteKey, isNull);
    });

    test('TurnstileConfig round-trips through toJson', () {
      final config = TurnstileConfig.fromJson({'siteKey': 'sk_1'});

      expect(config.toJson(), {'siteKey': 'sk_1'});
      expect(TurnstileConfig.fromJson(null).toJson(), {'siteKey': null});
    });
  });

  group('issue #47 — hosted challenge page URL', () {
    test('derives the portal origin from an api. host', () {
      final page = deriveTurnstileChallengePageUrl('https://api.cupthread.com');

      expect(page, Uri.parse('https://app.cupthread.com/turnstile/verify'));
    });

    test('keeps the origin for non-api hosts and strips query/fragment', () {
      final page = deriveTurnstileChallengePageUrl(
          'https://staging.example.com?stale=1#frag');

      expect(page, Uri.parse('https://staging.example.com/turnstile/verify'));
    });

    test('preserves an explicit port and rejects unusable base URLs', () {
      expect(
        deriveTurnstileChallengePageUrl('http://localhost:8080/api'),
        Uri.parse('http://localhost:8080/turnstile/verify'),
      );
      expect(deriveTurnstileChallengePageUrl('not a url'), isNull);
    });

    test('makeTurnstileChallengeUrl appends the widget binding', () {
      final config = FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      );

      final url = config.makeTurnstileChallengeUrl(
        const TurnstileChallenge.vote('app_test_123'),
        siteKey: ' 0x4AAAAAAA_sitekey ',
      );

      expect(url, isNotNull);
      expect(url!.host, 'app.cupthread.com');
      expect(url.path, '/turnstile/verify');
      expect(url.queryParameters, {
        'siteKey': '0x4AAAAAAA_sitekey',
        'action': 'vote',
        'cdata': 'app_test_123',
      });
    });

    test('makeTurnstileChallengeUrl appends theme and locale when given', () {
      final config = FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      );

      final url = config.makeTurnstileChallengeUrl(
        const TurnstileChallenge.feedback('app_test_123'),
        siteKey: 'sk',
        theme: 'dark',
        locale: 'zh-CN',
      );

      expect(url!.queryParameters['theme'], 'dark');
      expect(url.queryParameters['locale'], 'zh-CN');
      expect(url.queryParameters['action'], TurnstileAction.feedback);
    });

    test('explicit turnstileChallengeUrl overrides the derived page', () {
      final config = FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
        turnstileChallengeUrl: 'https://portal.example.com/challenge?legacy=1',
      );

      final url = config.makeTurnstileChallengeUrl(
        const TurnstileChallenge.featureRequest('app_test_123'),
        siteKey: 'sk',
      );

      expect(url.toString(),
          'https://portal.example.com/challenge?siteKey=sk&action=feature-request&cdata=app_test_123');
    });

    test('a blank site key yields no URL', () {
      final config = FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      );

      expect(
        config.makeTurnstileChallengeUrl(
          const TurnstileChallenge.vote('app_test_123'),
          siteKey: '   ',
        ),
        isNull,
      );
    });

    test('relative or scheme-less challenge overrides yield no URL', () {
      final relative = FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
        turnstileChallengeUrl: 'challenge/verify',
      );
      final schemeless = FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
        turnstileChallengeUrl: '//portal.example.com/challenge',
      );
      final empty = FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
        turnstileChallengeUrl: '',
      );

      for (final config in [relative, schemeless, empty]) {
        expect(
          config.makeTurnstileChallengeUrl(
            const TurnstileChallenge.vote('app_test_123'),
            siteKey: 'sk',
          ),
          isNull,
          reason: '${config.turnstileChallengeUrl} must not produce a URL',
        );
      }
    });
  });

  group('issue #47 — castVote Turnstile token resolution', () {
    PublicAppConfig voteConfig({
      bool requireAnonymousVoteTurnstile = true,
      bool withTurnstile = false,
    }) =>
        PublicAppConfig(
          appId: 'app_123',
          appKey: 'app_test_123',
          slug: 'test-app',
          name: 'Test App',
          allowPublic: true,
          allowedPlatforms: const [
            FeedbackPlatform.ios,
            FeedbackPlatform.android
          ],
          maxAttachmentBytes: 1048576,
          allowAnonymousRoadmap: true,
          allowAnonymousVote: true,
          allowAnonymousFeedback: true,
          allowAnonymousChangelog: true,
          requireAnonymousVoteTurnstile: requireAnonymousVoteTurnstile,
          turnstile:
              withTurnstile ? const TurnstileConfig(siteKey: 'sk') : null,
          sdk: const SdkAppearance(),
        );

    FeedbackClient clientWith(
      MockClient fn, {
      TurnstileTokenProvider? provider,
      TurnstileChallengeTokenProvider? challengeProvider,
      PublicAppConfig? config,
    }) =>
        FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_test_123',
            turnstileTokenProvider: provider,
            turnstileChallengeTokenProvider: challengeProvider,
          ),
          httpClient: fn,
          initialConfig: config,
        );

    test('attaches the provider-minted token to the vote body when gated',
        () async {
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'voted': true, 'voteCount': 6}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async => 'tok_vote',
        config: voteConfig(),
      );

      final result = await client.castVote('fr_1', userToken: 'user_1');

      expect(result.voted, isTrue);
      expect(result.voteCount, 6);
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/v1/feature-requests/fr_1/vote');
      expect(jsonDecode(captured.body), {
        'appKey': 'app_test_123',
        'userToken': 'user_1',
        'turnstileToken': 'tok_vote',
      });
    });

    test('does not consult a provider for ungated votes', () async {
      var providerConsulted = false;
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'voted': true, 'voteCount': 6}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          providerConsulted = true;
          return 'tok_vote';
        },
      );

      await client.castVote('fr_1', userToken: 'user_1');

      // An ungated vote must never pop a possibly-interactive challenge.
      expect(providerConsulted, isFalse);
      expect(jsonDecode(captured.body).containsKey('turnstileToken'), isFalse);
    });

    test('consults a provider when shipNotifyEmail is set on a gated board',
        () async {
      var providerConsulted = false;
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'voted': true, 'voteCount': 6}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          providerConsulted = true;
          return 'tok_ship';
        },
        config: voteConfig(requireAnonymousVoteTurnstile: false,
            withTurnstile: true),
      );

      await client.castVote('fr_1',
          userToken: 'user_1', shipNotifyEmail: 'me@example.com');

      expect(providerConsulted, isTrue);
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['turnstileToken'], 'tok_ship');
      expect(body['shipNotifyEmail'], 'me@example.com');
    });

    test('an explicit token wins and the provider is not consulted',
        () async {
      var providerConsulted = false;
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'voted': true, 'voteCount': 6}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          providerConsulted = true;
          return 'tok_from_provider';
        },
      );

      await client.castVote('fr_1',
          userToken: 'user_1', turnstileToken: 'tok_explicit');

      expect(providerConsulted, isFalse);
      expect(jsonDecode(captured.body)['turnstileToken'], 'tok_explicit');
    });

    test('binding-aware provider receives the exact challenge per endpoint',
        () async {
      final challenges = <TurnstileChallenge>[];
      final responses = {
        '/api/v1/feature-requests/fr_1/vote':
            jsonEncode({'voted': true, 'voteCount': 6}),
        '/api/v1/feedback':
            jsonEncode({'submissionId': 'fb_1', 'forwardedToGithub': false}),
        '/api/v1/feature-requests': jsonEncode({'id': 'fr_2'}),
        '/api/v1/public/apps/app_test_123/changelog/subscribe':
            jsonEncode({'subscribed': true}),
      };
      final client = clientWith(
        MockClient((request) async {
          final body = responses[request.url.path];
          if (body == null) {
            fail('unexpected request ${request.method} ${request.url.path}');
          }
          return http.Response(body, 200,
              headers: {'content-type': 'application/json'});
        }),
        challengeProvider: (challenge) async {
          challenges.add(challenge);
          return 'tok_bound';
        },
        config: voteConfig(),
      );

      await client.castVote('fr_1', userToken: 'user_1');
      await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
        ),
      );
      await client.submitFeatureRequest(
        const FeatureRequestDraft(title: 't', description: 'd'),
        userToken: 'user_1',
      );
      await client.subscribeToChangelog('me@example.com',
          userToken: 'user_1');

      expect(
        challenges.map((c) => c.action),
        [
          TurnstileAction.vote,
          TurnstileAction.feedback,
          TurnstileAction.featureRequest,
          TurnstileAction.changelogSubscribe,
        ],
      );
      expect(
        challenges.map((c) => c.cdata),
        everyElement('app_test_123'),
      );
    });

    test('binding-aware provider is preferred over the legacy provider',
        () async {
      var legacyConsulted = false;
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'voted': true, 'voteCount': 6}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
        challengeProvider: (challenge) async => 'tok_bound',
        config: voteConfig(),
      );

      await client.castVote('fr_1', userToken: 'user_1');

      expect(legacyConsulted, isFalse);
      expect(jsonDecode(captured.body)['turnstileToken'], 'tok_bound');
    });

    test('sends no turnstileToken when nothing resolves one', () async {
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'voted': true, 'voteCount': 6}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await client.castVote('fr_1',
          userToken: 'user_1', shipNotifyEmail: 'me@example.com');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('turnstileToken'), isFalse);
      expect(body['shipNotifyEmail'], 'me@example.com');
    });
  });

  group('issue #47 — FeatureRequestsScreen vote preflight', () {
    Widget host(FeedbackClient client, PublicAppConfig config) =>
        MaterialApp(
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
    }) =>
        FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_test_123',
            turnstileTokenProvider: provider,
          ),
          httpClient: fn,
          initialConfig: widgetConfig(),
        );

    testWidgets(
        'shows the verification notice and makes no request without a provider',
        (tester) async {
      final requests = <http.Request>[];
      final client = clientWith(
        MockClient((request) async {
          requests.add(request);
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
          if (request.url.path.contains('/versions')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      // No vote request left the client — the preflight stopped it.
      expect(
        requests.where((r) => r.url.path.endsWith('/vote')),
        isEmpty,
      );
      // The localized verification notice is surfaced instead.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Human verification is required'),
          findsOneWidget);
      // And no optimistic vote leaked into the rendered count.
      expect(find.text('5'), findsWidgets);
      expect(find.text('6'), findsNothing);
    });

    testWidgets(
        'resolves a token through the provider before the vote request',
        (tester) async {
      final requests = <http.Request>[];
      var providerConsulted = false;
      final client = clientWith(
        MockClient((request) async {
          requests.add(request);
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
          if (request.url.path.contains('/versions')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          if (request.url.path.endsWith('/vote')) {
            return http.Response(
              jsonEncode({'voted': true, 'voteCount': 6}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
        provider: () async {
          providerConsulted = true;
          return 'tok_widget';
        },
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      expect(providerConsulted, isTrue);
      final voteRequests =
          requests.where((r) => r.url.path.endsWith('/vote')).toList();
      expect(voteRequests, hasLength(1));
      expect(jsonDecode(voteRequests.single.body)['turnstileToken'],
          'tok_widget');
      expect(find.text('6'), findsWidgets);
    });

    testWidgets(
        'does not consult a provider when removing an existing vote',
        (tester) async {
      final requests = <http.Request>[];
      var providerConsulted = false;
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () async {
            providerConsulted = true;
            return 'tok_widget';
          },
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/v1/feature-requests') {
            return http.Response(
              jsonEncode({
                'requests': [featureRequestJson(hasVoted: true)],
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
          if (request.method == 'DELETE') {
            return http.Response(
              jsonEncode({'voted': false, 'voteCount': 5}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
        initialConfig: widgetConfig(),
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      expect(providerConsulted, isFalse);
      expect(
        requests.where((r) => r.method == 'DELETE' && r.url.path.endsWith('/vote')),
        hasLength(1),
      );
    });

    testWidgets('ignores taps while a Turnstile preflight is pending',
        (tester) async {
      final requests = <http.Request>[];
      var providerConsultations = 0;
      final providerGate = Completer<String?>();
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () async {
            providerConsultations++;
            return providerGate.future;
          },
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
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
          if (request.url.path.contains('/versions')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          if (request.url.path.endsWith('/vote')) {
            return http.Response(
              jsonEncode({'voted': true, 'voteCount': 6}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
        initialConfig: widgetConfig(),
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();

      // First tap starts the (pending) verification; second tap must be a
      // no-op while the row is locked.
      await tester.tap(find.byType(VoteButton).first);
      await tester.pump();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pump();

      providerGate.complete('tok_late');
      await tester.pumpAndSettle();

      expect(providerConsultations, 1);
      expect(
        requests.where((r) => r.url.path.endsWith('/vote')),
        hasLength(1),
      );
      expect(find.text('6'), findsWidgets);
    });

    testWidgets('resolving a preflight after unmount does not throw',
        (tester) async {
      final providerGate = Completer<String?>();
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () async => providerGate.future,
        ),
        httpClient: MockClient((request) async {
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
          if (request.url.path.contains('/versions')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('{}', 200);
        }),
        initialConfig: widgetConfig(),
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pump();

      // The host navigates away (or the sheet is dismissed) while the
      // provider is pending; the late token must not reach a setState.
      await tester.pumpWidget(const SizedBox.shrink());
      providerGate.complete('tok_late');
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('issue #47 — RoadmapBoardScreen vote preflight', () {
    Widget host(FeedbackClient client, PublicAppConfig config) =>
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            platformOverride: FeedbackPlatform.ios,
            child: const RoadmapBoardScreen(),
          ),
        );

    FeedbackClient clientWith(
      MockClient fn, {
      TurnstileTokenProvider? provider,
    }) =>
        FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_test_123',
            turnstileTokenProvider: provider,
          ),
          httpClient: fn,
          initialConfig: widgetConfig(),
        );

    testWidgets(
        'shows the verification notice and makes no request without a provider',
        (tester) async {
      final requests = <http.Request>[];
      final client = clientWith(
        MockClient((request) async {
          requests.add(request);
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
          if (request.url.path.endsWith('/columns')) {
            return http.Response(jsonEncode({'columns': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('{}', 200);
        }),
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
      expect(find.textContaining('Human verification is required'),
          findsOneWidget);
      expect(find.text('6'), findsNothing);
    });

    testWidgets(
        'sends the provider token with the vote when one resolves',
        (tester) async {
      final requests = <http.Request>[];
      final client = clientWith(
        MockClient((request) async {
          requests.add(request);
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
          if (request.url.path.endsWith('/columns')) {
            return http.Response(jsonEncode({'columns': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          if (request.url.path.endsWith('/vote')) {
            return http.Response(
              jsonEncode({'voted': true, 'voteCount': 6}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
        provider: () async => 'tok_board',
      );

      await tester.pumpWidget(host(client, widgetConfig()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VoteButton).first);
      await tester.pumpAndSettle();

      final voteRequests =
          requests.where((r) => r.url.path.endsWith('/vote')).toList();
      expect(voteRequests, hasLength(1));
      expect(
          jsonDecode(voteRequests.single.body)['turnstileToken'], 'tok_board');
    });
  });

  group('issue #47 — FeatureRequestDetailSheet vote preflight', () {
    testWidgets(
        'shows the verification notice and makes no request without a provider',
        (tester) async {
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
      final requests = <http.Request>[];
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
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
          if (request.url.path.contains('/versions')) {
            return http.Response(jsonEncode({'versions': []}), 200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('{}', 200);
        }),
        initialConfig: config,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            platformOverride: FeedbackPlatform.ios,
            child: const FeatureRequestsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the detail sheet the way users do: by tapping the request card.
      await tester.tap(find.text('Dark mode'));
      await tester.pumpAndSettle();

      // The list card behind the sheet still owns a VoteButton, so target the
      // one inside the sheet.
      final sheetVoteButton = find.descendant(
        of: find.byType(FeatureRequestDetailSheet),
        matching: find.byType(VoteButton),
      );
      expect(sheetVoteButton, findsOneWidget);
      await tester.tap(sheetVoteButton);
      await tester.pumpAndSettle();

      expect(
        requests.where((r) => r.url.path.endsWith('/vote')),
        isEmpty,
      );
      expect(find.textContaining('Human verification is required'),
          findsWidgets);
      expect(find.text('6'), findsNothing);
    });
  });
}
