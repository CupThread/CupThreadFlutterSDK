import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #51: `POST /api/v1/feature-requests/:id/comments`
/// answers with the created comment wrapped in a `{ "comment": { … } }`
/// envelope (`FeatureRequestCommentCreated`), so `postComment` must unwrap
/// the envelope — parsing it as the comment itself yielded an all-defaulted
/// ghost comment (`id: ''`, `body: ''`) that could not be replied to.
void main() {
  FeedbackClient clientWith(MockClient fn) => FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: fn,
      );

  Map<String, dynamic> createdCommentJson() => {
        'id': 'cm_9',
        'featureRequestId': 'fr_1',
        'authorName': 'Alice',
        'body': 'Hello world',
        'createdAt': '2026-05-02T00:00:00.000Z',
      };

  group('issue #51 — FeedbackClient.postComment envelope', () {
    test('unwraps the { comment: … } envelope and returns the inner comment',
        () async {
      final client = clientWith(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/feature-requests/fr_1/comments');
        return http.Response(
          jsonEncode({
            'comment': createdCommentJson(),
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }));

      final comment = await client.postComment(
        'fr_1',
        const CommentDraft(body: 'Hello world'),
        userToken: 'user_tok_1',
      );

      expect(comment.id, 'cm_9');
      expect(comment.featureRequestId, 'fr_1');
      expect(comment.authorName, 'Alice');
      expect(comment.body, 'Hello world');
      expect(comment.createdAt, '2026-05-02T00:00:00.000Z');
    });

    test('still parses a legacy flat comment object without the envelope',
        () async {
      final client = clientWith(MockClient((request) async {
        return http.Response(
          jsonEncode(createdCommentJson()),
          201,
          headers: {'content-type': 'application/json'},
        );
      }));

      final comment = await client.postComment(
        'fr_1',
        const CommentDraft(body: 'Hello world'),
        userToken: 'user_tok_1',
      );

      expect(comment.id, 'cm_9');
      expect(comment.body, 'Hello world');
    });
  });

  group('issue #51 — CommentsView posting and replying', () {
    Widget host(FeedbackClient client) => MaterialApp(
          home: CupThreadTheme(
            client: client,
            userToken: 'user_tok_1',
            isAnonymousOverride: false,
            child: const Scaffold(
              body: SingleChildScrollView(
                child: CommentsView(featureRequestId: 'fr_1'),
              ),
            ),
          ),
        );

    MockClient commentsFeedMock({
      required List<Map<String, dynamic>> Function() thread,
      http.Response Function(http.Request)? onPost,
      void Function(http.Request)? onPostCapture,
    }) {
      return MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/feature-requests/fr_1/comments') {
          return http.Response(
            jsonEncode({
              'comments': thread(),
              'total': thread().length,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/feature-requests/fr_1/comments') {
          onPostCapture?.call(request);
          return onPost?.call(request) ?? http.Response('{"error":"nope"}', 404);
        }
        return http.Response('{"error":"not found"}', 404);
      });
    }

    testWidgets(
        'posting renders the server-returned comment, and replying to it sends its id as parentId',
        (tester) async {
      final postBodies = <Map<String, dynamic>>[];
      final client = clientWith(commentsFeedMock(
        thread: () => [],
        onPostCapture: (request) =>
            postBodies.add(jsonDecode(request.body) as Map<String, dynamic>),
        onPost: (request) => http.Response(
          jsonEncode({'comment': createdCommentJson()}),
          201,
          headers: {'content-type': 'application/json'},
        ),
      ));

      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();

      // Post the top-level comment against the real envelope response.
      await tester.enterText(find.byType(TextField), 'Hello world');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // The rendered bubble carries the server values — no empty ghost.
      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);

      // Reply to the freshly posted comment: the reference must be the
      // server-returned id, not a blank string.
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A reply');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(postBodies, hasLength(2));
      expect(postBodies.last['body'], 'A reply');
      expect(postBodies.last['parentId'], 'cm_9');
    });

    testWidgets('a comment without an id offers no reply affordance',
        (tester) async {
      final client = clientWith(commentsFeedMock(
        thread: () => [
          {
            'id': '',
            'featureRequestId': 'fr_1',
            'body': 'ghost',
            'createdAt': '2026-05-01T00:00:00.000Z',
          },
        ],
      ));

      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();

      expect(find.text('ghost'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
    });
  });
}
