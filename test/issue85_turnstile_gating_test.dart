import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #85: `submit` and `submitFeatureRequest`
/// consulted the Turnstile token providers unconditionally, so on
/// deployments whose cached config shows Turnstile is not configured (or
/// before any config is cached) every feedback submission and every
/// feature-request proposal from a host that configured a provider popped
/// the possibly-interactive verification flow and burned a single-use token
/// for a request the server would have accepted without one — contradicting
/// the invariant `castVote` (issue #47) and `subscribeToChangelog` /
/// `uploadAttachment` (issue #81) already established.
///
/// Both methods now consult a provider only when the cached app config
/// publishes a Turnstile site key (`PublicAppConfig.turnstile != null`);
/// the draft's explicit `turnstileToken` attaches in every case. Without a
/// cached config the call stays fail-open and a gated server answers with
/// the canonical typed `403` → `TurnstileRequiredException`.
void main() {
  /// An ungated deployment: no site key published, no verification.
  PublicAppConfig ungatedConfig() => const PublicAppConfig(
        appId: 'app_123',
        appKey: 'app_test_123',
        slug: 'test-app',
        name: 'Test App',
        allowPublic: true,
        allowedPlatforms: [FeedbackPlatform.ios],
        maxAttachmentBytes: 1048576,
        allowAnonymousRoadmap: true,
        allowAnonymousVote: true,
        allowAnonymousFeedback: true,
        allowAnonymousChangelog: true,
        turnstile: null,
        requireAnonymousVoteTurnstile: false,
        sdk: SdkAppearance(),
      );

  /// A Turnstile-configured deployment — providers are consulted exactly as
  /// before the issue #85 fix.
  PublicAppConfig gatedConfig() => const PublicAppConfig(
        appId: 'app_123',
        appKey: 'app_test_123',
        slug: 'test-app',
        name: 'Test App',
        allowPublic: true,
        allowedPlatforms: [FeedbackPlatform.ios],
        maxAttachmentBytes: 1048576,
        allowAnonymousRoadmap: true,
        allowAnonymousVote: true,
        allowAnonymousFeedback: true,
        allowAnonymousChangelog: true,
        turnstile: TurnstileConfig(siteKey: 'sk'),
        sdk: SdkAppearance(),
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

  group('issue #85 — submit consults providers only when gated', () {
    test('ungated config: no provider is consulted and no token is sent',
        () async {
      var legacyConsulted = false;
      TurnstileChallenge? challengeSeen;
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'submissionId': 'fb_1', 'forwardedToGithub': false}),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
        challengeProvider: (challenge) async {
          challengeSeen = challenge;
          return 'tok_bound';
        },
        config: ungatedConfig(),
      );

      final result = await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
        ),
      );

      // An ungated submission must never pop a possibly-interactive
      // challenge.
      expect(legacyConsulted, isFalse);
      expect(challengeSeen, isNull);
      expect(result.submissionId, 'fb_1');
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test('ungated config: the draft\'s explicit token still attaches without '
        'consulting a provider', () async {
      var legacyConsulted = false;
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'submissionId': 'fb_2', 'forwardedToGithub': false}),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
        config: ungatedConfig(),
      );

      await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
          turnstileToken: 'tok_explicit',
        ),
      );

      expect(legacyConsulted, isFalse);
      expect(capturedBody!['turnstileToken'], 'tok_explicit');
    });

    test('gated config: the binding-aware provider receives the exact '
        'challenge and its token is attached', () async {
      final challenges = <TurnstileChallenge>[];
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'submissionId': 'fb_3', 'forwardedToGithub': false}),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
        challengeProvider: (challenge) async {
          challenges.add(challenge);
          return 'tok_bound';
        },
        config: gatedConfig(),
      );

      await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
        ),
      );

      expect(challenges.single.action, TurnstileAction.feedback);
      expect(challenges.single.cdata, 'app_test_123');
      expect(capturedBody!['turnstileToken'], 'tok_bound');
    });

    test('gated config: the legacy provider still supplies the token when no '
        'binding-aware provider is configured', () async {
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'submissionId': 'fb_4', 'forwardedToGithub': false}),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async => 'tok_legacy',
        config: gatedConfig(),
      );

      await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
        ),
      );

      expect(capturedBody!['turnstileToken'], 'tok_legacy');
    });
  });

  group(
      'issue #85 — submitFeatureRequest consults providers only when gated',
      () {
    test('ungated config: no provider is consulted and no token is sent',
        () async {
      var legacyConsulted = false;
      TurnstileChallenge? challengeSeen;
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'id': 'fr_1'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
        challengeProvider: (challenge) async {
          challengeSeen = challenge;
          return 'tok_bound';
        },
        config: ungatedConfig(),
      );

      final result = await client.submitFeatureRequest(
        const FeatureRequestDraft(title: 't', description: 'd'),
        userToken: 'usr_tok_test',
      );

      expect(legacyConsulted, isFalse);
      expect(challengeSeen, isNull);
      expect(result, isNotNull);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test('ungated config: the draft\'s explicit token still attaches without '
        'consulting a provider', () async {
      var legacyConsulted = false;
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'id': 'fr_2'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
        config: ungatedConfig(),
      );

      await client.submitFeatureRequest(
        const FeatureRequestDraft(
          title: 't',
          description: 'd',
          turnstileToken: 'tok_explicit',
        ),
        userToken: 'usr_tok_test',
      );

      expect(legacyConsulted, isFalse);
      expect(capturedBody!['turnstileToken'], 'tok_explicit');
    });

    test('gated config: the binding-aware provider receives the exact '
        'challenge and its token is attached', () async {
      final challenges = <TurnstileChallenge>[];
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'id': 'fr_3'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        challengeProvider: (challenge) async {
          challenges.add(challenge);
          return 'tok_bound';
        },
        config: gatedConfig(),
      );

      await client.submitFeatureRequest(
        const FeatureRequestDraft(title: 't', description: 'd'),
        userToken: 'usr_tok_test',
      );

      expect(challenges.single.action, TurnstileAction.featureRequest);
      expect(challenges.single.cdata, 'app_test_123');
      expect(capturedBody!['turnstileToken'], 'tok_bound');
    });
  });

  group('issue #85 — no cached config stays fail-open', () {
    test('submit without a cached config consults no provider', () async {
      var legacyConsulted = false;
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'submissionId': 'fb_5', 'forwardedToGithub': false}),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
      );

      await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
        ),
      );

      expect(legacyConsulted, isFalse);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test('submitFeatureRequest without a cached config consults no provider',
        () async {
      var legacyConsulted = false;
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'id': 'fr_4'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
      );

      await client.submitFeatureRequest(
        const FeatureRequestDraft(title: 't', description: 'd'),
        userToken: 'usr_tok_test',
      );

      expect(legacyConsulted, isFalse);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test('a gated server still rejects the tokenless submission with the '
        'typed 403', () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 'turnstile_required'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async => 'tok_never_consulted',
        config: ungatedConfig(),
      );

      await expectLater(
        client.submit(
          const FeedbackDraft(
            title: 'Broken thing',
            description: 'It broke',
            platform: FeedbackPlatform.ios,
          ),
        ),
        throwsA(isA<TurnstileRequiredException>()),
      );
    });

    test('a gated server still rejects the tokenless feature-request '
        'proposal with the typed 403', () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 'turnstile_required'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async => 'tok_never_consulted',
        config: ungatedConfig(),
      );

      await expectLater(
        client.submitFeatureRequest(
          const FeatureRequestDraft(title: 't', description: 'd'),
          userToken: 'usr_tok_test',
        ),
        throwsA(isA<TurnstileRequiredException>()),
      );
    });
  });
}
