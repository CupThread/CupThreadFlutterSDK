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
void main() {
  FeedbackClient clientWith(
    MockClient fn, {
    String appKey = 'app_test_123',
    String Function()? turnstileTokenProvider,
  }) =>
      FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: appKey,
          turnstileTokenProvider: turnstileTokenProvider,
        ),
        httpClient: fn,
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
