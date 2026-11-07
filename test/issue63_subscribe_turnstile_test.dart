import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #63: `subscribeToChangelog` never resolved
/// or attached a Cloudflare Turnstile token, so anonymous changelog
/// subscription on Turnstile-gated deployments was a guaranteed 403 dead end
/// — the host's `turnstileTokenProvider` (already wired for the other three
/// intake-style writes by the issue #7 fix) was silently ignored on this
/// path. The subscribe call now resolves a token through the same
/// `_resolveTurnstileToken` helper and includes it in the request body when
/// non-empty.
///
/// Since the issue #81 fix, a provider is consulted only when the cached app
/// config shows a Turnstile-configured deployment — the consultation tests
/// below therefore run against a gated `initialConfig`.
void main() {
  /// A cached config whose `turnstile != null` — the deployment shape the
  /// subscribe endpoint verifies tokens on.
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
    String appKey = 'app_test_123',
    String Function()? turnstileTokenProvider,
    PublicAppConfig? config,
  }) =>
      FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: appKey,
          turnstileTokenProvider: turnstileTokenProvider,
        ),
        httpClient: fn,
        initialConfig: config,
      );

  group('issue #63 — subscribeToChangelog Turnstile token', () {
    test('attaches turnstileToken from the configured provider', () async {
      final bodies = <Map<String, dynamic>>[];

      final client = clientWith(
        MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({'subscribed': true}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        turnstileTokenProvider: () => 'tok_subscribe_turnstile',
        config: gatedConfig(),
      );

      final result = await client.subscribeToChangelog(
        'reader@example.com',
        userToken: 'usr_tok_test',
      );

      expect(result.subscribed, isTrue);
      expect(bodies.single['email'], 'reader@example.com');
      expect(bodies.single['turnstileToken'], 'tok_subscribe_turnstile');
    });

    test('omits turnstileToken entirely when no provider is configured',
        () async {
      Map<String, dynamic>? capturedBody;

      final client = clientWith(MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'subscribed': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      await client.subscribeToChangelog(
        'reader@example.com',
        userToken: 'usr_tok_test',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
      expect(capturedBody!['email'], 'reader@example.com');
    });

    test('omits turnstileToken when the provider returns null or blank',
        () async {
      final bodies = <Map<String, dynamic>>[];

      final client = clientWith(
        MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({'subscribed': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        // Provider mirrors real-world token exhaustion: empty value.
        turnstileTokenProvider: () => '   ',
        config: gatedConfig(),
      );

      await client.subscribeToChangelog(
        'reader@example.com',
        userToken: 'usr_tok_test',
      );

      expect(bodies.single.containsKey('turnstileToken'), isFalse);
    });

    test('consults the provider exactly once per call '
        '(single-use token semantics)', () async {
      var providerCalls = 0;

      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'subscribed': true}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        turnstileTokenProvider: () {
          providerCalls++;
          return 'tok_$providerCalls';
        },
        config: gatedConfig(),
      );

      await client.subscribeToChangelog(
        'first@example.com',
        userToken: 'usr_tok_test',
      );
      await client.subscribeToChangelog(
        'second@example.com',
        userToken: 'usr_tok_test',
      );

      expect(providerCalls, 2);
    });
  });
}
