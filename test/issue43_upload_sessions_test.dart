import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #43: attachment uploads were silently
/// discarded because the API's upload responses no longer carry `key`/`url`
/// (an `uploadId` instead) and submissions never sent `uploadId`/`uploadIds`.
/// The SDK now speaks the governed upload-session flow and references stored
/// files through the submission's top-level `uploadIds`.
void main() {
  /// The `ImageUploadResponse` shape the live API returns from
  /// `POST /api/v1/uploads/images`: no object key, no delivery URL.
  Map<String, dynamic> imageUploadResponse() => {
        'kind': 'image',
        'uploadId': 'upl_img_1',
        'status': 'uploaded',
        'stored': true,
        'filename': 'screenshot.png',
        'mimeType': 'image/png',
        'size': 204800,
        'sha256': 'deadbeef',
      };

  /// Standard two-leg session-flow mock. Returns the client wrapper plus
  /// every captured request so tests can assert on both legs.
  ({FeedbackClient client, List<http.BaseRequest> requests})
      buildClient({
    Map<String, dynamic>? sessionResponse,
    Object? slotResponse,
    int sessionStatus = 201,
    int putStatus = 200,
    FeedbackClientConfig? config,
  }) {
    final requests = <http.BaseRequest>[];
    final mockClient = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/uploads/sessions')) {
        return http.Response(
          jsonEncode(sessionResponse ??
              {
                'session': {
                  'sessionId': 'ses_1',
                  'sessionToken': 'sess_tok',
                  'expiresAt': '2026-10-25T12:00:00Z',
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
              }),
          sessionStatus,
          headers: {'content-type': 'application/json'},
        );
      }
      if (slotResponse == null) {
        return http.Response(
          jsonEncode({
            'uploadId': 'upl_slot_1',
            'clientFileId': 'file-1',
            'filename': 'shot.png',
            'contentType': 'image/png',
            'sizeBytes': 204800,
            'sha256': 'cafebabe',
            'stored': true,
            'downloadUrl': null,
          }),
          putStatus,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        slotResponse is String ? slotResponse : jsonEncode(slotResponse),
        putStatus,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = FeedbackClient(
      config ??
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_test_123',
          ),
      httpClient: mockClient,
    );
    return (client: client, requests: requests);
  }

  setUp(() {
    // Isolate the shared identity store per test.
    UserTokenStore.configure(MemoryTokenStorage());
  });

  group('FeedbackAttachment parsing', () {
    test('parses the new ImageUploadResponse shape and preserves uploadId', () {
      final attachment = FeedbackAttachment.fromJson(imageUploadResponse());

      expect(attachment.uploadId, 'upl_img_1');
      expect(attachment.kind, AttachmentKind.image);
      expect(attachment.filename, 'screenshot.png');
      expect(attachment.mimeType, 'image/png');
      expect(attachment.size, 204800);
      // The response deliberately carries no key/url (PRIV-02).
      expect(attachment.key, '');
      expect(attachment.url, '');
    });

    test('parses the PUT UploadedFileResponse shape (contentType/sizeBytes)', () {
      final attachment = FeedbackAttachment.fromJson({
        'uploadId': 'upl_put_1',
        'clientFileId': 'file-1',
        'filename': 'crash.log',
        'contentType': 'text/plain',
        'sizeBytes': 4096,
        'sha256': 'abc',
        'stored': true,
        'downloadUrl': null,
      });

      expect(attachment.uploadId, 'upl_put_1');
      expect(attachment.kind, AttachmentKind.r2,
          reason: 'non-image content type maps to the generic kind');
      expect(attachment.mimeType, 'text/plain');
      expect(attachment.size, 4096);
    });

    test('still round-trips the legacy key/url shape', () {
      const legacy = {
        'kind': 'image',
        'key': 'img_123',
        'url': 'https://cdn.example.com/img_123.png',
        'filename': 'shot.png',
        'mimeType': 'image/png',
        'size': 512,
      };

      final attachment = FeedbackAttachment.fromJson(legacy);

      expect(attachment.uploadId, isNull);
      expect(attachment.key, 'img_123');
      expect(attachment.url, 'https://cdn.example.com/img_123.png');
      expect(attachment.kind, AttachmentKind.image);

      final json = attachment.toJson();
      expect(json['key'], 'img_123');
      expect(json['url'], 'https://cdn.example.com/img_123.png');
      expect(json.containsKey('uploadId'), isFalse);
    });

    test('toJson emits uploadId and omits empty key/url', () {
      final attachment = FeedbackAttachment.fromJson(imageUploadResponse());

      final json = attachment.toJson();

      expect(json['uploadId'], 'upl_img_1');
      expect(json['kind'], 'image');
      expect(json.containsKey('key'), isFalse,
          reason: "empty key must not be sent; AttachmentInput.url is format: uri");
      expect(json.containsKey('url'), isFalse);
      expect(json['filename'], 'screenshot.png');
    });
  });

  group('FeedbackDraft submission payload', () {
    test('emits top-level uploadIds and per-item uploadId for session uploads',
        () {
      const draft = FeedbackDraft(
        title: 'Broken export',
        description: 'Exported CSV misses the last row.',
        platform: FeedbackPlatform.ios,
        attachments: [
          FeedbackAttachment(
            kind: AttachmentKind.image,
            uploadId: 'upl_1',
            filename: 'a.png',
            mimeType: 'image/png',
            size: 10,
          ),
          FeedbackAttachment(
            kind: AttachmentKind.r2,
            uploadId: 'upl_2',
            filename: 'b.log',
            mimeType: 'text/plain',
          ),
        ],
      );

      final payload = draft.toJson(
        appKey: 'app_test_123',
        submittedAt: '2026-10-25T00:00:00Z',
      );

      expect(payload['uploadIds'], ['upl_1', 'upl_2']);
      final attachments = payload['attachments'] as List;
      expect((attachments[0] as Map)['uploadId'], 'upl_1');
      expect((attachments[1] as Map)['uploadId'], 'upl_2');
      expect((attachments[0] as Map).containsKey('key'), isFalse);
      expect((attachments[0] as Map).containsKey('url'), isFalse);
    });

    test('omits uploadIds when only legacy attachments are present', () {
      const draft = FeedbackDraft(
        title: 'Legacy attachment',
        description: 'Created before the upload-session flow.',
        platform: FeedbackPlatform.ios,
        attachments: [
          FeedbackAttachment(
            kind: AttachmentKind.image,
            key: 'img_legacy',
            url: 'https://cdn.example.com/img_legacy.png',
          ),
        ],
      );

      final payload = draft.toJson(
        appKey: 'app_test_123',
        submittedAt: '2026-10-25T00:00:00Z',
      );

      expect(payload.containsKey('uploadIds'), isFalse);
      expect(
        (payload['attachments'] as List).single as Map,
        containsPair('key', 'img_legacy'),
      );
    });

    test('throws ArgumentError on more than 8 session uploads', () {
      final draft = FeedbackDraft(
        title: 'Too many attachments',
        description: 'Nine attachments exceed the API cap.',
        platform: FeedbackPlatform.ios,
        attachments: List.generate(
          9,
          (i) => FeedbackAttachment(
            kind: AttachmentKind.image,
            uploadId: 'upl_$i',
          ),
        ),
      );

      expect(
        () => draft.toJson(
          appKey: 'app_test_123',
          submittedAt: '2026-10-25T00:00:00Z',
        ),
        throwsArgumentError,
      );
    });

    test('submit rejects more than 8 session uploads before any network call',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response('{}', 200);
      });
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockClient,
      );
      final draft = FeedbackDraft(
        title: 'Too many attachments',
        description: 'Nine attachments exceed the API cap.',
        platform: FeedbackPlatform.ios,
        attachments: List.generate(
          9,
          (i) => FeedbackAttachment(kind: AttachmentKind.image, uploadId: 'upl_$i'),
        ),
      );

      await expectLater(
        client.submit(draft, userToken: 'usr_1'),
        throwsArgumentError,
      );
    });
  });

  group('uploadAttachment session flow', () {
    test('hits /uploads/sessions then /uploads/{uploadId}, never the retired endpoints',
        () async {
      final (:client, :requests) = buildClient();

      final attachment = await client.uploadAttachment(
        bytes: [1, 2, 3],
        filename: 'shot.png',
        mimeType: 'image/png',
        userToken: 'usr_1',
        // ignore: deprecated_member_use_from_same_package
        preferredKind: AttachmentKind.r2,
      );

      expect(attachment.uploadId, 'upl_slot_1');
      expect(attachment.kind, AttachmentKind.image);
      expect(
        requests.map((r) => r.url.path),
        ['/api/v1/uploads/sessions', '/api/v1/uploads/upl_slot_1'],
      );
      expect(
        requests.where((r) =>
            r.url.path.endsWith('/uploads/r2') ||
            r.url.path.endsWith('/uploads/images')),
        isEmpty,
      );
    });

    test('streams raw bytes with the session bearer token and declared type',
        () async {
      final (:client, :requests) = buildClient();

      await client.uploadAttachment(
        bytes: [9, 8, 7],
        filename: 'shot.png',
        mimeType: 'image/png',
        userToken: 'usr_1',
      );

      final put = requests[1] as http.Request;
      expect(put.method, 'PUT');
      expect(put.headers['Authorization'], 'Bearer sess_tok');
      expect(put.headers['Content-Type'], 'image/png');
      expect(put.bodyBytes, [9, 8, 7]);
    });

    test('sends the explicit identity on session creation', () async {
      final (:client, :requests) = buildClient();

      await client.uploadAttachment(
        bytes: [1],
        filename: 'shot.png',
        mimeType: 'image/png',
        userToken: 'usr_explicit',
      );

      expect((requests[0] as http.Request).headers['X-User-Token'],
          'usr_explicit');
    });

    test('falls back to the shared store identity for anonymous callers',
        () async {
      final (:client, :requests) = buildClient();

      await client.uploadAttachment(
        bytes: [1],
        filename: 'shot.png',
        mimeType: 'image/png',
      );

      final sent = (requests[0] as http.Request).headers['X-User-Token'];
      expect(sent, isNotNull);
      expect(sent, await UserTokenStore.shared.getToken());
    });

    test('forwards a provider Turnstile token on session creation', () async {
      final (:client, :requests) = buildClient(
        config: FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
          turnstileTokenProvider: () async => 'turnstile_tok',
        ),
      );

      await client.uploadAttachment(
        bytes: [1],
        filename: 'shot.png',
        mimeType: 'image/png',
        userToken: 'usr_1',
      );

      final body =
          jsonDecode((requests[0] as http.Request).body) as Map<String, dynamic>;
      expect(body['turnstileToken'], 'turnstile_tok');
      expect(body['purpose'], 'feedback_attachment');
    });

    test('throws InvalidResponseException when the slot has no uploadId',
        () async {
      final (:client, :requests) = buildClient(
        sessionResponse: {
          'session': {
            'sessionId': 'ses_1',
            'sessionToken': 'sess_tok',
            'expiresAt': '2026-10-25T12:00:00Z',
            'maxFileSizeBytes': 10485760,
            'maxFiles': 8,
          },
          'files': [
            {
              'clientFileId': 'file-1',
              'uploadUrl': '/api/v1/uploads/upl_x',
              'maxSizeBytes': 10485760,
            },
          ],
        },
      );

      await expectLater(
        client.uploadAttachment(
          bytes: [1],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(isA<InvalidResponseException>()),
      );
      expect(requests, hasLength(1),
          reason: 'no bytes may be streamed without a slot id');
    });

    test('throws InvalidResponseException when sessionToken is missing',
        () async {
      final result = buildClient(
        sessionResponse: {
          'session': {
            'sessionId': 'ses_1',
            'expiresAt': '2026-10-25T12:00:00Z',
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
        },
      );

      await expectLater(
        result.client.uploadAttachment(
          bytes: [1],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('throws InvalidResponseException when no slot is allocated', () async {
      final result = buildClient(
        sessionResponse: {
          'session': {
            'sessionId': 'ses_1',
            'sessionToken': 'sess_tok',
            'expiresAt': '2026-10-25T12:00:00Z',
            'maxFileSizeBytes': 10485760,
            'maxFiles': 8,
          },
          'files': [],
        },
      );

      await expectLater(
        result.client.uploadAttachment(
          bytes: [1],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('enforces the session per-file limit before streaming bytes',
        () async {
      final (:client, :requests) = buildClient(
        sessionResponse: {
          'session': {
            'sessionId': 'ses_1',
            'sessionToken': 'sess_tok',
            'expiresAt': '2026-10-25T12:00:00Z',
            'maxFileSizeBytes': 2,
            'maxFiles': 8,
          },
          'files': [
            {
              'clientFileId': 'file-1',
              'uploadId': 'upl_slot_1',
              'uploadUrl': '/api/v1/uploads/upl_slot_1',
              'maxSizeBytes': 2,
            },
          ],
        },
      );

      await expectLater(
        client.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(isA<AttachmentTooLargeException>()),
      );
      expect(requests, hasLength(1), reason: 'bytes must not hit the wire');
    });

    test('maps HTTP 413 on the slot PUT to AttachmentTooLargeException',
        () async {
      final result = buildClient(putStatus: 413);

      await expectLater(
        result.client.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(isA<AttachmentTooLargeException>()),
      );
    });

    test('maps a Turnstile 403 on session creation to TurnstileRequiredException',
        () async {
      final result = buildClient(
        sessionStatus: 403,
        sessionResponse: {'error': 'turnstile_verification_failed'},
      );

      await expectLater(
        result.client.uploadAttachment(
          bytes: [1],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(isA<TurnstileRequiredException>()),
      );
    });

    test('enforces the local maxBytes cap before any request', () async {
      final (:client, :requests) = buildClient();

      await expectLater(
        client.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'shot.png',
          mimeType: 'image/png',
          maxBytes: 2,
          userToken: 'usr_1',
        ),
        throwsA(isA<AttachmentTooLargeException>()),
      );
      expect(requests, isEmpty);
    });
  });

  group('submit identity binding (SEC-28)', () {
    test('submissions referencing session uploads fall back to the store identity',
        () async {
      final requests = <http.BaseRequest>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'submissionId': 'sub_1', 'forwardedToGithub': false}),
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
      const draft = FeedbackDraft(
        title: 'Attached screenshot',
        description: 'The screenshot shows the broken layout.',
        platform: FeedbackPlatform.ios,
        attachments: [
          FeedbackAttachment(kind: AttachmentKind.image, uploadId: 'upl_1'),
        ],
      );

      await client.submit(draft);

      final request = requests.single as http.Request;
      expect(request.headers['X-User-Token'],
          await UserTokenStore.shared.getToken(),
          reason: 'the intake endpoint finalizes uploads only for the '
              'identity that created their session');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['uploadIds'], ['upl_1']);
    });

    test('submissions without session uploads stay fully anonymous', () async {
      final requests = <http.BaseRequest>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'submissionId': 'sub_2', 'forwardedToGithub': false}),
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
      const draft = FeedbackDraft(
        title: 'Plain feedback',
        description: 'No attachments in this draft.',
        platform: FeedbackPlatform.ios,
      );

      await client.submit(draft);

      expect((requests.single as http.Request).headers.containsKey('X-User-Token'),
          isFalse);
    });

    test('an explicit userToken wins over the store fallback', () async {
      final requests = <http.BaseRequest>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'submissionId': 'sub_3', 'forwardedToGithub': false}),
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
      const draft = FeedbackDraft(
        title: 'Attached screenshot',
        description: 'The screenshot shows the broken layout.',
        platform: FeedbackPlatform.ios,
        attachments: [
          FeedbackAttachment(kind: AttachmentKind.image, uploadId: 'upl_1'),
        ],
      );

      await client.submit(draft, userToken: 'usr_explicit');

      expect((requests.single as http.Request).headers['X-User-Token'],
          'usr_explicit');
    });
  });
}
