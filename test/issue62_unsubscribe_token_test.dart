import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #62: the bare-email unsubscribe body
/// (`{"email": ...}`) is no longer accepted by the platform, so the old
/// `unsubscribeFromChangelog(email)` method could never succeed. The API only
/// honors a signed token from the emailed unsubscribe link, supplied through
/// the query string (RFC 8058 one-click budget) or a `{"token": ...}` JSON
/// body.
void main() {
  FeedbackClient clientWith(MockClient fn) => FeedbackClient(
    FeedbackClientConfig(
      baseUrl: 'https://api.cupthread.com',
      appKey: 'app_test_123',
    ),
    httpClient: fn,
  );

  group('issue #62 — unsubscribeFromChangelogToken', () {
    test('sends the token in the query string by default', () async {
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'unsubscribed': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.unsubscribeFromChangelogToken('tok_signed');

      expect(result.unsubscribed, isTrue);
      expect(captured.method, 'POST');
      expect(
        captured.url.path,
        '/api/v1/public/apps/app_test_123/changelog/unsubscribe',
      );
      expect(captured.url.queryParameters, {'token': 'tok_signed'});
      expect(captured.body, isEmpty);
    });

    test('sends the token in the JSON body when viaQuery is false', () async {
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'unsubscribed': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await client.unsubscribeFromChangelogToken('tok_signed', viaQuery: false);

      expect(captured.url.queryParameters, isEmpty);
      expect(jsonDecode(captured.body), {'token': 'tok_signed'});
    });

    test('trims surrounding whitespace from the token', () async {
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'unsubscribed': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await client.unsubscribeFromChangelogToken('  tok_signed  ');

      expect(captured.url.queryParameters, {'token': 'tok_signed'});
    });

    test('encodes tokens that contain URL-reserved characters', () async {
      late http.Request captured;
      final client = clientWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'unsubscribed': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await client.unsubscribeFromChangelogToken('a+b/c=d');

      expect(captured.url.queryParameters, {'token': 'a+b/c=d'});
      expect(captured.url.query, isNot(contains('a+b/c=d')));
    });

    test('rejects an empty or blank token before any request', () async {
      var requests = 0;
      final client = clientWith(
        MockClient((request) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.unsubscribeFromChangelogToken(''),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        client.unsubscribeFromChangelogToken('   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(requests, 0);
    });

    test(
      'parses an unsuccessful unsubscribe result without throwing',
      () async {
        final client = clientWith(
          MockClient((request) async {
            return http.Response(
              jsonEncode({'unsubscribed': false}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final result = await client.unsubscribeFromChangelogToken('tok_signed');

        expect(result.unsubscribed, isFalse);
      },
    );

    test(
      'maps HTTP 400 to UnexpectedStatusException without leaking the body',
      () async {
        const body = '{"error":"Invalid or expired unsubscribe token"}';
        final client = clientWith(
          MockClient((request) async {
            return http.Response(
              body,
              400,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        late UnexpectedStatusException caught;
        try {
          await client.unsubscribeFromChangelogToken('expired_tok');
          fail('expected UnexpectedStatusException');
        } on UnexpectedStatusException catch (e) {
          caught = e;
        }

        expect(caught.status, 400);
        expect(caught.responseBody, body);
        expect(caught.toString(), isNot(contains('Invalid or expired')));
      },
    );
  });
}
