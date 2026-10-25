import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #53: comment writes authenticate with a
/// Clerk end-user session only, so the SDK's anonymous X-User-Token identity
/// is always rejected with 401. The composer must be hidden for anonymous
/// sessions and a 401 must surface the sign-in message.
void main() {
  FeedbackClient clientWith(MockClient fn) => FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: fn,
      );

  MockClient commentsFeedMock({
    void Function(http.Request)? onRequest,
    http.Response Function(http.Request)? onPost,
  }) {
    return MockClient((request) async {
      onRequest?.call(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/feature-requests/fr_1/comments') {
        return http.Response(
          jsonEncode({
            'comments': [],
            'total': 0,
            'hasMore': false,
            'nextCursor': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/feature-requests/fr_1/comments') {
        return onPost?.call(request) ??
            http.Response('{"error":"not found"}', 404);
      }
      return http.Response('{"error":"not found"}', 404);
    });
  }

  Widget host(FeedbackClient client, {bool? isAnonymousOverride}) =>
      MaterialApp(
        home: CupThreadTheme(
          client: client,
          userToken: isAnonymousOverride == false ? 'user_tok_1' : null,
          isAnonymousOverride: isAnonymousOverride,
          child: const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_1'),
            ),
          ),
        ),
      );

  group('issue #53 — CommentsView composer gating', () {
    testWidgets('anonymous session sees a sign-in notice instead of the compose box',
        (tester) async {
      final client = clientWith(commentsFeedMock());

      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Sign-in is required to comment.'), findsOneWidget);
      expect(find.text('Send'), findsNothing);
    });

    testWidgets('authenticated session renders the composer and posts the comment',
        (tester) async {
      final postBodies = <Map<String, dynamic>>[];
      final postTokens = <String?>[];
      final client = clientWith(commentsFeedMock(onPost: (request) {
        postBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        postTokens.add(request.headers['X-User-Token']);
        return http.Response(
          jsonEncode({
            'id': 'cm_new',
            'featureRequestId': 'fr_1',
            'body': 'Hello world',
            'createdAt': '2026-05-02T00:00:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }));

      await tester.pumpWidget(host(client, isAnonymousOverride: false));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello world');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(postBodies, hasLength(1));
      expect(postBodies.single['body'], 'Hello world');
      // Author fields are resolved server-side and are no longer sent from
      // the composer.
      expect(postBodies.single.containsKey('authorName'), isFalse);
      expect(postTokens.single, 'user_tok_1');
      // The posted comment is appended to the rendered thread.
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('a 401 on post surfaces the sign-in message, not the generic failure',
        (tester) async {
      final client = clientWith(commentsFeedMock(onPost: (request) {
        return http.Response(
          jsonEncode({
            'error': 'Authentication required',
            'code': 'authentication_required',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      }));

      await tester.pumpWidget(host(client, isAnonymousOverride: false));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello world');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in is required to comment.'), findsOneWidget);
      expect(find.text('Failed to post comment. Please try again.'), findsNothing);
    });
  });

  group('issue #53 — FeedbackClient.postComment 401 mapping', () {
    test('throws AuthenticationRequiredException on HTTP 401', () async {
      final client = clientWith(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'Authentication required',
            'code': 'authentication_required',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      }));

      await expectLater(
        client.postComment(
          'fr_1',
          const CommentDraft(body: 'Hello world'),
          userToken: 'user_tok_1',
        ),
        throwsA(isA<AuthenticationRequiredException>()),
      );
    });
  });

  group('issue #53 — i18n coverage', () {
    test('all locales define non-empty signInRequiredToComment', () {
      final locales = [
        CupThreadStrings.en,
        CupThreadStrings.zhHans,
        CupThreadStrings.ja,
        CupThreadStrings.fr,
        CupThreadStrings.es,
        CupThreadStrings.de,
        CupThreadStrings.it,
        CupThreadStrings.pt,
        CupThreadStrings.zhHant,
        CupThreadStrings.ko,
        CupThreadStrings.pl,
        CupThreadStrings.no,
        CupThreadStrings.tr,
        CupThreadStrings.vi,
      ];
      for (final s in locales) {
        expect(s.signInRequiredToComment, isNotEmpty);
      }
      expect(
        CupThreadStrings.en.signInRequiredToComment,
        'Sign-in is required to comment.',
      );
    });
  });
}
