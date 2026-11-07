import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #81: `subscribeToChangelog` and
/// `uploadAttachment` consulted the Turnstile token providers
/// unconditionally, so on deployments whose cached config shows Turnstile is
/// not configured (or before any config is cached) every call popped the
/// host's possibly-interactive verification flow and burned a single-use
/// token for a request the server would accept without one — silently
/// breaking the ungated invariant `castVote` established (issue #47).
///
/// Both methods now consult a provider only when the cached app config
/// publishes a Turnstile site key (`PublicAppConfig.turnstile != null`);
/// without a cached config the call stays fail-open and a gated server
/// answers with the canonical typed `403` → `TurnstileRequiredException`.
void main() {
  /// An ungated deployment: no site key published, no vote verification.
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
  /// before the issue #81 fix.
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

  /// The standard two-leg upload-session mock body.
  Map<String, dynamic> sessionResponse() => {
        'session': {
          'sessionId': 'ses_1',
          'sessionToken': 'sess_tok',
          'expiresAt': '2026-11-07T12:00:00Z',
          'maxFileSizeBytes': 10485760,
          'maxFiles': 8,
        },
        'files': [
          {
            'clientFileId': 'file-1',
            'uploadId': 'upl_slot_1',
            'uploadUrl': '/api/v1/uploads/upl_slot_1',
            'maxSizeBytes': 10485760,
          },
        ],
      };

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

  group('issue #81 — subscribeToChangelog consults providers only when gated',
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
            jsonEncode({'subscribed': true}),
            200,
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

      final result = await client.subscribeToChangelog(
        'reader@example.com',
        userToken: 'usr_tok_test',
      );

      // An ungated subscribe must never pop a possibly-interactive challenge.
      expect(legacyConsulted, isFalse);
      expect(challengeSeen, isNull);
      expect(result.subscribed, isTrue);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test('gated config: the binding-aware provider receives the exact '
        'challenge and its token is attached', () async {
      final challenges = <TurnstileChallenge>[];
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'subscribed': true}),
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

      await client.subscribeToChangelog(
        'reader@example.com',
        userToken: 'usr_tok_test',
      );

      expect(challenges.single.action, TurnstileAction.changelogSubscribe);
      expect(challenges.single.cdata, 'app_test_123');
      expect(capturedBody!['turnstileToken'], 'tok_bound');
    });
  });

  group('issue #81 — uploadAttachment consults providers only when gated',
      () {
    test('ungated config: no provider is consulted and the session is '
        'created without a token', () async {
      var legacyConsulted = false;
      TurnstileChallenge? challengeSeen;
      final bodies = <Map<String, dynamic>>[];
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path.endsWith('/uploads/sessions')) {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode(sessionResponse()),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'uploadId': 'upl_slot_1',
              'clientFileId': 'file-1',
              'filename': 'log.txt',
              'contentType': 'text/plain',
              'sizeBytes': 24,
              'sha256': 'cafebabe',
              'stored': true,
              'downloadUrl': null,
            }),
            200,
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

      final attachment = await client.uploadAttachment(
        bytes: List.filled(24, 0x61),
        filename: 'log.txt',
        mimeType: 'text/plain',
        userToken: 'user_1',
      );

      // An ungated upload must never pop a possibly-interactive challenge.
      expect(legacyConsulted, isFalse);
      expect(challengeSeen, isNull);
      expect(attachment.uploadId, 'upl_slot_1');
      expect(bodies.single.containsKey('turnstileToken'), isFalse);
    });

    test('gated config: the binding-aware provider receives the exact '
        'challenge and its token is attached to the session', () async {
      final challenges = <TurnstileChallenge>[];
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path.endsWith('/uploads/sessions')) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(sessionResponse()),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'uploadId': 'upl_slot_1',
              'clientFileId': 'file-1',
              'filename': 'log.txt',
              'contentType': 'text/plain',
              'sizeBytes': 24,
              'sha256': 'cafebabe',
              'stored': true,
              'downloadUrl': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        challengeProvider: (challenge) async {
          challenges.add(challenge);
          return 'tok_bound';
        },
        config: gatedConfig(),
      );

      await client.uploadAttachment(
        bytes: List.filled(24, 0x61),
        filename: 'log.txt',
        mimeType: 'text/plain',
        userToken: 'user_1',
      );

      expect(challenges.single.action, TurnstileAction.feedback);
      expect(challenges.single.cdata, 'app_test_123');
      expect(capturedBody!['turnstileToken'], 'tok_bound');
    });
  });

  group('issue #81 — no cached config stays fail-open', () {
    test('subscribeToChangelog without a cached config consults no provider',
        () async {
      var legacyConsulted = false;
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'subscribed': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
      );

      await client.subscribeToChangelog(
        'reader@example.com',
        userToken: 'usr_tok_test',
      );

      expect(legacyConsulted, isFalse);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test('uploadAttachment without a cached config consults no provider',
        () async {
      var legacyConsulted = false;
      Map<String, dynamic>? capturedBody;
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path.endsWith('/uploads/sessions')) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(sessionResponse()),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'uploadId': 'upl_slot_1',
              'clientFileId': 'file-1',
              'filename': 'log.txt',
              'contentType': 'text/plain',
              'sizeBytes': 24,
              'sha256': 'cafebabe',
              'stored': true,
              'downloadUrl': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async {
          legacyConsulted = true;
          return 'tok_legacy';
        },
      );

      await client.uploadAttachment(
        bytes: List.filled(24, 0x61),
        filename: 'log.txt',
        mimeType: 'text/plain',
        userToken: 'user_1',
      );

      expect(legacyConsulted, isFalse);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test('a gated server still rejects the tokenless subscribe with the '
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
        client.subscribeToChangelog(
          'reader@example.com',
          userToken: 'usr_tok_test',
        ),
        throwsA(isA<TurnstileRequiredException>()),
      );
    });

    test('a gated server still rejects the tokenless upload session with '
        'the typed 403', () async {
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
        client.uploadAttachment(
          bytes: List.filled(24, 0x61),
          filename: 'log.txt',
          mimeType: 'text/plain',
          userToken: 'user_1',
        ),
        throwsA(isA<TurnstileRequiredException>()),
      );
    });
  });
}
