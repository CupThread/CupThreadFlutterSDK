import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #82: a throwing Turnstile token provider used
/// to escape every intake call as the raw host exception (`StateError`,
/// `PlatformException`, …), breaking the documented `FeedbackException`
/// error contract. `_resolveTurnstileToken` now treats a throwing provider
/// exactly like the widget preflight in `vote_turnstile.dart` does — as one
/// that yielded no token — so an ungated deployment proceeds without a token
/// and a gated server rejects the call with the canonical typed
/// `TurnstileRequiredException` instead of the provider's error bubbling out.
void main() {
  PublicAppConfig voteConfig() => const PublicAppConfig(
        appId: 'app_123',
        appKey: 'app_test_123',
        slug: 'test-app',
        name: 'Test App',
        allowPublic: true,
        allowedPlatforms: [
          FeedbackPlatform.ios,
          FeedbackPlatform.android
        ],
        maxAttachmentBytes: 1048576,
        allowAnonymousRoadmap: true,
        allowAnonymousVote: true,
        allowAnonymousFeedback: true,
        allowAnonymousChangelog: true,
        requireAnonymousVoteTurnstile: true,
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

  group('issue #82 — a throwing provider resolves to no token', () {
    test('submit proceeds without a token when the legacy provider throws',
        () async {
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
        provider: () async => throw StateError('WebView plugin crashed'),
        // Gated so the provider is actually consulted (issue #85): the
        // throw must still count as an unresolved token.
        config: voteConfig(),
      );

      final result = await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
        ),
      );

      expect(result.submissionId, 'fb_1');
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test(
        'submit: a throwing binding-aware provider ends resolution — '
        'the legacy provider is not consulted either', () async {
      var legacyConsulted = false;
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
        challengeProvider: (challenge) async =>
            throw StateError('hosted challenge failed to load'),
        // Gated so the provider is actually consulted (issue #85): the
        // throw must still end resolution before the legacy provider.
        config: voteConfig(),
      );

      await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
        ),
      );

      // Same semantics as an empty binding-aware result: resolution ends.
      expect(legacyConsulted, isFalse);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test('submit: an explicit token wins and the throwing provider is never '
        'consulted', () async {
      var providerConsulted = false;
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
          providerConsulted = true;
          return 'tok_legacy';
        },
        // Gated so the explicit-token short-circuit is exercised (issue #85).
        config: voteConfig(),
      );

      await client.submit(
        const FeedbackDraft(
          title: 'Broken thing',
          description: 'It broke',
          platform: FeedbackPlatform.ios,
          turnstileToken: 'tok_explicit',
        ),
      );

      expect(providerConsulted, isFalse);
      expect(capturedBody!['turnstileToken'], 'tok_explicit');
    });

    test(
        'submitFeatureRequest proceeds without a token when the provider '
        'throws', () async {
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
        provider: () async => throw StateError('no network while minting'),
        // Gated so the provider is actually consulted (issue #85): the
        // throw must still count as an unresolved token.
        config: voteConfig(),
      );

      final result = await client.submitFeatureRequest(
        const FeatureRequestDraft(title: 't', description: 'd'),
        userToken: 'user_1',
      );

      expect(result, isNotNull);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test(
        'subscribeToChangelog proceeds without a token when the provider '
        'throws', () async {
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
        provider: () async => throw StateError('provider bug'),
        // Gated so the provider is actually consulted (issue #81): the
        // throw must still count as an unresolved token.
        config: voteConfig(),
      );

      final result = await client.subscribeToChangelog(
        'reader@example.com',
        userToken: 'usr_tok_test',
      );

      expect(result.subscribed, isTrue);
      expect(capturedBody!.containsKey('turnstileToken'), isFalse);
    });

    test(
        'uploadAttachment proceeds through the session flow when the '
        'provider throws', () async {
      final paths = <String>[];
      final client = clientWith(
        MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/uploads/sessions')) {
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
        provider: () async => throw StateError('token minting exploded'),
        // Gated so the provider is actually consulted (issue #81): the
        // throw must still count as an unresolved token.
        config: voteConfig(),
      );

      final attachment = await client.uploadAttachment(
        bytes: List.filled(24, 0x61),
        filename: 'log.txt',
        mimeType: 'text/plain',
        userToken: 'user_1',
      );

      expect(attachment.uploadId, 'upl_slot_1');
      expect(
        paths,
        ['/api/v1/uploads/sessions', '/api/v1/uploads/upl_slot_1'],
      );
    });

    test(
        'castVote on a gated board surfaces the server\'s typed 403 — '
        'never the raw provider error', () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 'turnstile_required'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async => throw StateError('WebView gone'),
        config: voteConfig(),
      );

      await expectLater(
        client.castVote('fr_1', userToken: 'user_1'),
        throwsA(isA<TurnstileRequiredException>()),
      );
    });

    test(
        'uploadAttachment on a gated server surfaces the typed 403 from '
        'session creation — never UnreadableUploadResponseException',
        () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 'turnstile_required'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
        provider: () async => throw StateError('WebView gone'),
        config: voteConfig(),
      );

      await expectLater(
        client.uploadAttachment(
          bytes: List.filled(24, 0x61),
          filename: 'log.txt',
          mimeType: 'text/plain',
          userToken: 'user_1',
        ),
        // A FeedbackException subtype must escape; the method's catch block
        // rethrows those instead of wrapping them.
        throwsA(isA<TurnstileRequiredException>()),
      );
    });
  });
}
