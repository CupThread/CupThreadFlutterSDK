import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #104: a transport-level failure on the upload
/// slot `PUT` (SocketException, http.ClientException, TLS handshake failure,
/// …) propagates past `_uploadToSlot`'s typed catch list into
/// `uploadAttachment`'s catch-all, which mislabeled a request that never
/// completed as `UnreadableUploadResponseException` — "upload completed but
/// server response could not be parsed" — and discarded the original error.
/// The slot PUT now mirrors `_sendJson`'s network-failure semantics:
/// `InvalidResponseException('Network failure requesting $uri', e)`.
void main() {
  setUp(() {
    // Isolate the shared identity store per test.
    UserTokenStore.configure(MemoryTokenStorage());
  });

  /// Mock whose session-creation leg always succeeds and whose slot `PUT`
  /// leg throws [putError] instead of returning a response.
  FeedbackClient buildClientWithFailingPut(Object putError) {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/uploads/sessions')) {
        return http.Response(
          jsonEncode({
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
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      throw putError;
    });
    return FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: mockClient,
    );
  }

  /// Mock whose session-creation leg itself throws [sessionError].
  FeedbackClient buildClientWithFailingSession(Object sessionError) {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/uploads/sessions')) {
        throw sessionError;
      }
      return http.Response('{}', 200);
    });
    return FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: mockClient,
    );
  }

  group('uploadAttachment transport failures (issue #104)', () {
    test('slot PUT http.ClientException maps to InvalidResponseException, '
        'not UnreadableUploadResponseException', () async {
      final original = http.ClientException('connection closed');
      final client = buildClientWithFailingPut(original);

      await expectLater(
        client.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(
          isA<InvalidResponseException>()
              .having(
                (e) => e.message,
                'message',
                contains('Network failure'),
              )
              .having(
                (e) => e.cause,
                'cause',
                same(original),
              ),
        ),
      );
    });

    test('slot PUT SocketException maps to InvalidResponseException with '
        'the original error preserved as cause', () async {
      final original = Exception('SocketException: connection reset');
      final client = buildClientWithFailingPut(original);

      await expectLater(
        client.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(
          isA<InvalidResponseException>()
              .having((e) => e.message, 'message', contains('Network failure'))
              .having((e) => e.cause, 'cause', same(original)),
        ),
      );
    });

    test('session-creation transport failure still maps to '
        'InvalidResponseException (unchanged contract)', () async {
      final original = http.ClientException('connection refused');
      final client = buildClientWithFailingSession(original);

      await expectLater(
        client.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(
          isA<InvalidResponseException>()
              .having((e) => e.message, 'message', contains('Network failure'))
              .having((e) => e.cause, 'cause', same(original)),
        ),
      );
    });

    test('malformed-JSON 200 from the slot PUT still maps to '
        'InvalidResponseException (parse branch, not network branch)',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/uploads/sessions')) {
          return http.Response(
            jsonEncode({
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
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '<html>not json</html>',
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

      await expectLater(
        client.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'shot.png',
          mimeType: 'image/png',
          userToken: 'usr_1',
        ),
        throwsA(
          isA<InvalidResponseException>().having(
            (e) => e.message,
            'message',
            contains('Failed to parse JSON response'),
          ),
        ),
      );
    });
  });
}
