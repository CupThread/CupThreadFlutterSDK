import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #65: the intake endpoints and upload slots
/// answer deterministic, code-bearing rejections (`scan_rejected`,
/// `uploader_mismatch`, `already_finalized`, single-shot `409`s, the status-
/// only 415 content-scan rejection, …) that the SDK previously collapsed into
/// a generic `UnexpectedStatusException`, so hosts could only ever show
/// "Something went wrong". The client now parses the `code` field (never the
/// message text) and maps known codes to a typed
/// `FeedbackRejectionException`; the bundled UI renders a specific localized
/// message per reason instead of inviting a pointless retry.
void main() {
  setUp(() {
    // Isolate the shared identity store per test.
    UserTokenStore.configure(MemoryTokenStorage());
  });

  FeedbackClient clientWith(MockClient fn) => FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: fn,
      );

  FeedbackDraft draftWithUpload() => const FeedbackDraft(
        title: 'Broken export',
        description: 'Steps to reproduce…',
        platform: FeedbackPlatform.universal,
        attachments: [
          FeedbackAttachment(
            kind: AttachmentKind.r2,
            uploadId: 'upl_slot_1',
            filename: 'log.txt',
            mimeType: 'text/plain',
            size: 1200,
          ),
        ],
      );

  group('issue #65 — upload slot (PUT /api/v1/uploads/{uploadId})', () {
    test('415 content-scan rejection maps on status alone (no code)', () async {
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          if (request.url.path.endsWith('/uploads/sessions')) {
            return http.Response(
              jsonEncode({
                'session': {
                  'sessionId': 'ses_1',
                  'sessionToken': 'cpt_up_tok',
                  'maxFileSizeBytes': 10485760,
                },
                'files': [
                  {
                    'clientFileId': 'file-1',
                    'uploadId': 'upl_slot_1',
                    'maxSizeBytes': 10485760,
                  },
                ],
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          // The slot answers 415 with a human-readable inspection reason and
          // deliberately no machine-readable code.
          return http.Response(
            'File content does not match declared image type (image/png).',
            415,
          );
        }),
      );

      await expectLater(
        client.uploadAttachment(
          bytes: List.filled(16, 0),
          filename: 'shot.png',
          mimeType: 'image/png',
        ),
        throwsA(
          isA<FeedbackRejectionException>()
              .having((e) => e.reason, 'reason', FeedbackRejectionReason.contentRejected)
              .having((e) => e.status, 'status', 415)
              .having((e) => e.code, 'code', ''),
        ),
      );
      expect(captured.method, 'PUT');
    });

    test('409 already_uploaded maps to alreadyUsed', () async {
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path.endsWith('/uploads/sessions')) {
            return http.Response(
              jsonEncode({
                'session': {'sessionToken': 'cpt_up_tok'},
                'files': [
                  {'uploadId': 'upl_slot_1'},
                ],
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'error': 'Upload slot was already filled',
              'code': 'already_uploaded',
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        client.uploadAttachment(
          bytes: const [1, 2, 3],
          filename: 'log.txt',
          mimeType: 'text/plain',
        ),
        throwsA(
          isA<FeedbackRejectionException>()
              .having((e) => e.reason, 'reason', FeedbackRejectionReason.alreadyUsed)
              .having((e) => e.code, 'code', 'already_uploaded')
              .having((e) => e.status, 'status', 409),
        ),
      );
    });

    test('session-create 400 unsupported_mime_type maps to unsupportedFileType',
        () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'MIME type text/plain is not accepted for attachments',
              'code': 'unsupported_mime_type',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        client.uploadAttachment(
          bytes: const [1, 2, 3],
          filename: 'log.txt',
          mimeType: 'text/plain',
        ),
        throwsA(
          isA<FeedbackRejectionException>()
              .having(
                (e) => e.reason,
                'reason',
                FeedbackRejectionReason.unsupportedFileType,
              )
              .having((e) => e.code, 'code', 'unsupported_mime_type'),
        ),
      );
    });

    test('session-create 413 file_too_large maps to fileTooLarge', () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'File exceeds the configured attachment limit',
              'code': 'file_too_large',
            }),
            413,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        client.uploadAttachment(
          bytes: List.filled(64, 0),
          filename: 'dump.bin',
          mimeType: 'application/octet-stream',
        ),
        throwsA(
          isA<FeedbackRejectionException>()
              .having((e) => e.reason, 'reason', FeedbackRejectionReason.fileTooLarge)
              .having((e) => e.code, 'code', 'file_too_large'),
        ),
      );
    });
  });

  group('issue #65 — feedback submit (POST /api/v1/feedback)', () {
    Future<Object?> submitError(FeedbackClient client) async {
      try {
        await client.submit(draftWithUpload());
      } catch (e) {
        return e;
      }
      return null;
    }

    test('422 scan_rejected maps to contentRejected', () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error':
                  'Upload object upl_slot_1 was rejected by content scan: EICAR',
              'code': 'scan_rejected',
            }),
            422,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final error = await submitError(client);
      expect(
        error,
        isA<FeedbackRejectionException>()
            .having((e) => e.reason, 'reason', FeedbackRejectionReason.contentRejected)
            .having((e) => e.code, 'code', 'scan_rejected')
            .having((e) => e.status, 'status', 422),
      );
    });

    test('400 uploader_mismatch maps to uploaderMismatch', () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Upload session was created by a different uploader',
              'code': 'uploader_mismatch',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        await submitError(client),
        isA<FeedbackRejectionException>()
            .having((e) => e.reason, 'reason', FeedbackRejectionReason.uploaderMismatch)
            .having((e) => e.code, 'code', 'uploader_mismatch'),
      );
    });

    test('409 already_finalized maps to alreadyUsed', () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error':
                  'Upload object upl_slot_1 has already been finalized into another submission',
              'code': 'already_finalized',
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        await submitError(client),
        isA<FeedbackRejectionException>()
            .having((e) => e.reason, 'reason', FeedbackRejectionReason.alreadyUsed)
            .having((e) => e.code, 'code', 'already_finalized'),
      );
    });

    test('400 direct_attachment_forbidden maps to directAttachmentForbidden',
        () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Direct attachment URLs and keys are forbidden.',
              'code': 'direct_attachment_forbidden',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        await submitError(client),
        isA<FeedbackRejectionException>()
            .having(
              (e) => e.reason,
              'reason',
              FeedbackRejectionReason.directAttachmentForbidden,
            )
            .having((e) => e.code, 'code', 'direct_attachment_forbidden'),
      );
    });

    test('unknown 400 code still surfaces as UnexpectedStatusException',
        () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Validation failed',
              'code': 'some_future_code',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        await submitError(client),
        isA<UnexpectedStatusException>()
            .having((e) => e.status, 'status', 400),
      );
    });

    test('coded rejection keeps the body out of message and toString',
        () async {
      final client = clientWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Upload object upl_slot_1 was rejected by content scan',
              'code': 'scan_rejected',
            }),
            422,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      try {
        await client.submit(draftWithUpload());
        fail('expected FeedbackRejectionException');
      } on FeedbackRejectionException catch (e) {
        expect(e.responseBody, contains('scan'));
        expect(e.message, isNot(contains('scan_rejected')));
        expect(e.toString(), isNot(contains('content scan')));
      }
    });
  });

  group('issue #65 — localized messages for deterministic rejections', () {
    test('every reason maps to its dedicated English string', () {
      const strings = CupThreadStrings.en;
      FeedbackRejectionException rejection(
        FeedbackRejectionReason reason, {
        int status = 400,
        String code = '',
      }) =>
          FeedbackRejectionException(
            reason: reason,
            status: status,
            code: code,
          );

      expect(
        strings.localizedErrorMessage(
          rejection(FeedbackRejectionReason.contentRejected,
              status: 415, code: 'scan_rejected'),
        ),
        strings.attachmentRejected,
      );
      expect(
        strings.localizedErrorMessage(
          rejection(FeedbackRejectionReason.unsupportedFileType),
        ),
        strings.unsupportedFileType,
      );
      expect(
        strings.localizedErrorMessage(
          rejection(FeedbackRejectionReason.fileTooLarge,
              status: 413, code: 'file_too_large'),
        ),
        strings.attachmentTooLarge,
      );
      expect(
        strings.localizedErrorMessage(
          rejection(FeedbackRejectionReason.uploaderMismatch),
        ),
        strings.uploadIdentityMismatch,
      );
      expect(
        strings.localizedErrorMessage(
          rejection(FeedbackRejectionReason.alreadyUsed,
              status: 409, code: 'already_finalized'),
        ),
        strings.attachmentAlreadyUsed,
      );
      expect(
        strings.localizedErrorMessage(
          rejection(FeedbackRejectionReason.directAttachmentForbidden),
        ),
        strings.attachmentAlreadyUsed,
      );
    });

    test('translations exist outside English (Simplified Chinese)', () {
      const strings = CupThreadStrings.zhHans;
      final rejection = FeedbackRejectionException(
        reason: FeedbackRejectionReason.contentRejected,
        status: 415,
      );

      expect(
        strings.localizedErrorMessage(rejection),
        strings.attachmentRejected,
      );
      expect(strings.attachmentRejected, isNot(CupThreadStrings.en.attachmentRejected));
      expect(strings.unsupportedFileType,
          isNot(CupThreadStrings.en.unsupportedFileType));
      expect(strings.attachmentAlreadyUsed,
          isNot(CupThreadStrings.en.attachmentAlreadyUsed));
      expect(strings.uploadIdentityMismatch,
          isNot(CupThreadStrings.en.uploadIdentityMismatch));
    });
  });
}
