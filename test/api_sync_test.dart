import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  const turnstileBody = 'Human verification (Turnstile) is required';

  test('submit decodes the optional warningCode', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'submissionId': 'sub_warning',
          'forwardedToGithub': false,
          'warning': 'Attachments unavailable',
          'warningCode': 'attachment_signing_unconfigured',
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: mockClient,
    );

    final result = await client.submit(const FeedbackDraft(
      title: 'Attachment warning',
      description: 'The submission completed with a warning',
      platform: FeedbackPlatform.ios,
    ));

    expect(result.warningCode, 'attachment_signing_unconfigured');
  });

  group('Issue 7: Cloudflare Turnstile Intake', () {
    test('submit includes turnstileToken from draft', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'submissionId': 'sub_123', 'forwardedToGithub': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      const draft = FeedbackDraft(
        title: 'App crashed on startup',
        description: 'Crashed immediately after tapping icon',
        platform: FeedbackPlatform.ios,
        turnstileToken: 'tok_draft_explicit',
      );

      final result = await client.submit(draft);
      expect(result.submissionId, 'sub_123');

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['turnstileToken'], 'tok_draft_explicit');
    });

    test('submit resolves turnstileToken from provider when draft token is absent', () async {
      http.Request? capturedRequest;
      int providerCalls = 0;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'submissionId': 'sub_456', 'forwardedToGithub': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () async {
            providerCalls++;
            return 'tok_provider_dynamic';
          },
        ),
        httpClient: mockClient,
      );

      const draft = FeedbackDraft(
        title: 'Login button unresponsive',
        description: 'Nothing happens when tapping login',
        platform: FeedbackPlatform.android,
      );

      final result = await client.submit(draft);
      expect(result.submissionId, 'sub_456');
      expect(providerCalls, 1);

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['turnstileToken'], 'tok_provider_dynamic');
    });

    test('submit prefers draft turnstileToken over provider', () async {
      http.Request? capturedRequest;
      int providerCalls = 0;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'submissionId': 'sub_789', 'forwardedToGithub': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () async {
            providerCalls++;
            return 'tok_from_provider';
          },
        ),
        httpClient: mockClient,
      );

      const draft = FeedbackDraft(
        title: 'Theme toggle',
        description: 'Dark mode theme toggle issue',
        platform: FeedbackPlatform.ios,
        turnstileToken: 'tok_from_draft',
      );

      await client.submit(draft);
      expect(providerCalls, 0);

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['turnstileToken'], 'tok_from_draft');
    });

    test('submit omits turnstileToken when provider returns null or empty', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'submissionId': 'sub_empty', 'forwardedToGithub': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () => '   ',
        ),
        httpClient: mockClient,
      );

      await client.submit(const FeedbackDraft(
        title: 'Title',
        description: 'Description',
        platform: FeedbackPlatform.web,
      ));

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body.containsKey('turnstileToken'), isFalse);
    });

    test('submitFeatureRequest attaches turnstileToken from draft and provider', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'featureRequestId': 'fr_123', 'pending': false}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () => 'tok_feature_req_turnstile',
        ),
        httpClient: mockClient,
      );

      await client.submitFeatureRequest(
        const FeatureRequestDraft(
          title: 'Export to PDF',
          description: 'Need PDF export',
        ),
        userToken: 'usr_tok_test',
      );

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['turnstileToken'], 'tok_feature_req_turnstile');
      expect(body['requesterToken'], 'usr_tok_test');
    });

    test('Turnstile 403 error body maps to TurnstileRequiredException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(turnstileBody, 403);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      try {
        await client.submit(const FeedbackDraft(
          title: 'Title',
          description: 'Desc',
          platform: FeedbackPlatform.macos,
        ));
        fail('Expected TurnstileRequiredException');
      } on TurnstileRequiredException catch (e) {
        expect(e.status, 403);
        expect(e.code, 'turnstile_required');
        expect(e.responseBody, turnstileBody);
        expect(e.message, contains('CupThread API requires human verification'));
        expect(e.toString(), isNot(contains(turnstileBody)));
      }
    });

    test('JSON machine-readable turnstile code maps to TurnstileRequiredException', () async {
      for (final code in ['turnstile_required', 'turnstile_verification_failed']) {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'code': code}), 403);
        });

        final client = FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_test_123',
          ),
          httpClient: mockClient,
        );

        expect(
          () => client.submitFeatureRequest(
            const FeatureRequestDraft(title: 'T', description: 'D'),
            userToken: 'usr_tok',
          ),
          throwsA(isA<TurnstileRequiredException>()),
        );
      }
    });

    test('Non-Turnstile 403 error keeps raising UnexpectedStatusException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Forbidden app key'}), 403);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      expect(
        () => client.submit(const FeedbackDraft(
          title: 'Title',
          description: 'Desc',
          platform: FeedbackPlatform.ios,
        )),
        throwsA(isA<UnexpectedStatusException>()),
      );
    });

    test('Retrying after Turnstile challenge resolves fresh token from provider', () async {
      int providerCalls = 0;
      final tokens = ['tok_attempt_1', 'tok_attempt_2'];
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(turnstileBody, 403);
        }
        return http.Response(
          jsonEncode({'submissionId': 'sub_retry_ok', 'forwardedToGithub': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () {
            final tok = tokens[providerCalls];
            providerCalls++;
            return tok;
          },
        ),
        httpClient: mockClient,
      );

      const draft = FeedbackDraft(
        title: 'Title',
        description: 'Desc',
        platform: FeedbackPlatform.ios,
      );

      expect(() => client.submit(draft), throwsA(isA<TurnstileRequiredException>()));

      final res = await client.submit(draft);
      expect(res.submissionId, 'sub_retry_ok');
      expect(providerCalls, 2);

      final body1 = jsonDecode(requests[0].body) as Map<String, dynamic>;
      final body2 = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(body1['turnstileToken'], 'tok_attempt_1');
      expect(body2['turnstileToken'], 'tok_attempt_2');
    });

    testWidgets('FeedbackComposer shows verificationRequired on Turnstile challenge', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/public/config/')) {
          return http.Response('{}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(turnstileBody, 403);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            userToken: 'usr_tok_abc',
            child: const Scaffold(
              body: FeedbackComposer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Valid Feedback Title');
      await tester.enterText(find.byType(TextField).at(1), 'Valid feedback description text');

      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      expect(
        find.text('Human verification is required to submit. Please try again after completing verification.'),
        findsOneWidget,
      );
      // Draft fields remain populated for retry
      expect(find.text('Valid Feedback Title'), findsOneWidget);
    });

    testWidgets('FeatureRequestComposeSheet shows verificationRequired on Turnstile challenge', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/public/config/')) {
          return http.Response('{}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(turnstileBody, 403);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            userToken: 'usr_tok_abc',
            child: const Scaffold(
              body: FeatureRequestComposeSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Feature Request Title');
      await tester.enterText(find.byType(TextField).at(1), 'Feature request detailed description');

      await tester.tap(find.text('Submit Request'));
      await tester.pumpAndSettle();

      expect(
        find.text('Human verification is required to submit. Please try again after completing verification.'),
        findsOneWidget,
      );
      expect(find.text('Feature Request Title'), findsOneWidget);
    });
  });

  group('Issue 8: GET /api/v1/feature-requests userToken in header', () {
    test('fetchFeatureRequests transmits userToken via X-User-Token header and NOT in query string', () async {
      http.Request? capturedRequest;
      const testToken = 'usr_token_secret_12345';

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'requests': [],
            'total': 0,
            'limit': 50,
            'offset': 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      await client.fetchFeatureRequests(
        userToken: testToken,
        limit: 20,
        offset: 10,
        versionId: 'ver_1',
        query: 'search term',
      );

      expect(capturedRequest, isNotNull);
      final req = capturedRequest!;

      // Verify X-User-Token header is set
      expect(req.headers['X-User-Token'], testToken);

      // Verify URL query parameters do NOT contain userToken
      expect(req.url.queryParameters.containsKey('userToken'), isFalse);
      expect(req.url.query, isNot(contains(testToken)));
      expect(req.url.query, isNot(contains('userToken')));

      // Verify allowed query parameters are present
      expect(req.url.queryParameters['appKey'], 'app_test_123');
      expect(req.url.queryParameters['limit'], '20');
      expect(req.url.queryParameters['offset'], '10');
      expect(req.url.queryParameters['versionId'], 'ver_1');
      expect(req.url.queryParameters['q'], 'search term');
    });
  });

  group('Issue 2: uploadAttachment auth header, status 200/201, 401, timeouts', () {
    test('uploadAttachment sends X-User-Token header when provided', () async {
      http.BaseRequest? capturedRequest;
      const token = 'usr_token_upload_test';

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'kind': 'image',
            'key': 'img_123',
            'url': 'https://cdn.example.com/img_123.png',
            'filename': 'shot.png',
            'mimeType': 'image/png',
            'size': 512,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      final attachment = await client.uploadAttachment(
        bytes: [1, 2, 3, 4],
        filename: 'shot.png',
        mimeType: 'image/png',
        userToken: token,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.headers['X-User-Token'], token);
      expect(attachment.key, 'img_123');
      expect(attachment.kind, AttachmentKind.image);
    });

    test('uploadAttachment omits X-User-Token when null or empty', () async {
      http.BaseRequest? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'kind': 'r2',
            'key': 'log_123',
            'url': 'https://cdn.example.com/log_123.txt',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      await client.uploadAttachment(
        bytes: [1, 2],
        filename: 'log.txt',
        mimeType: 'text/plain',
        userToken: null,
      );
      expect(capturedRequest!.headers.containsKey('X-User-Token'), isFalse);

      await client.uploadAttachment(
        bytes: [1, 2],
        filename: 'log.txt',
        mimeType: 'text/plain',
        userToken: '   ',
      );
      expect(capturedRequest!.headers.containsKey('X-User-Token'), isFalse);
    });

    test('uploadAttachment accepts HTTP 200 and HTTP 201', () async {
      for (final status in [200, 201]) {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'kind': 'image',
              'key': 'img_$status',
              'url': 'https://cdn.example.com/img_$status.png',
            }),
            status,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_test_123',
          ),
          httpClient: mockClient,
        );

        final res = await client.uploadAttachment(
          bytes: [1],
          filename: 'test.png',
          mimeType: 'image/png',
        );
        expect(res.key, 'img_$status');
      }
    });

    test('uploadAttachment throws AuthenticationRequiredException on HTTP 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error":"unauthorized"}', 401);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );

      expect(
        () => client.uploadAttachment(
          bytes: [1, 2],
          filename: 'test.png',
          mimeType: 'image/png',
        ),
        throwsA(isA<AuthenticationRequiredException>()),
      );
    });

    test('uploadAttachment throws mapped FeedbackException on upload timeout', () async {
      final mockClient = MockClient((request) async {
        // Never completes
        final completer = Completer<http.Response>();
        return completer.future;
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          uploadTimeout: const Duration(milliseconds: 50),
        ),
        httpClient: mockClient,
      );

      expect(
        () => client.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'file.png',
          mimeType: 'image/png',
        ),
        throwsA(isA<FeedbackException>()),
      );
    });

    test('_sendJson throws mapped FeedbackException on request timeout', () async {
      final mockClient = MockClient((request) async {
        // Never completes
        final completer = Completer<http.Response>();
        return completer.future;
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          requestTimeout: const Duration(milliseconds: 50),
        ),
        httpClient: mockClient,
      );

      expect(
        () => client.fetchAppConfig(),
        throwsA(isA<FeedbackException>()),
      );
    });
  });
}
