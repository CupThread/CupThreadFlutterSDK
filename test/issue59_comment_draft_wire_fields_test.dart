import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #59: `CommentDraft.toJson` used to emit
/// four keys the live `CreateFeatureRequestCommentInput` schema never
/// declared (`authorName`, `authorEmail`, `authorAvatarUrl`,
/// `replyToClerkId`). The server tolerates-and-strips them today, but any
/// hardening of the input schema would turn every comment post from this
/// SDK into a 400 while the reference Swift SDK kept working. The wire
/// payload is now exactly the declared shape: `body`, `parentId`,
/// `replyToAuthorName`.
void main() {
  Map<String, dynamic> createdCommentJson() => {
        'id': 'cm_9',
        'featureRequestId': 'fr_1',
        'authorName': 'Alice',
        'body': 'Hello world',
        'createdAt': '2026-05-02T00:00:00.000Z',
      };

  group('issue #59 — CommentDraft.toJson wire shape', () {
    test('a fully populated draft emits exactly the declared keys', () {
      // Every stripped field is populated to prove the omission is
      // unconditional, not a consequence of null values.
      const draft = CommentDraft(
        body: '  hello world  ',
        authorName: 'Lex',
        authorEmail: 'lex@example.com',
        authorAvatarUrl: 'https://example.com/avatar.png',
        parentId: 'cm_1',
        replyToClerkId: 'user_456',
        replyToAuthorName: 'Alice',
      );

      final json = draft.toJson();

      expect(json.keys.toSet(), {'body', 'parentId', 'replyToAuthorName'},
          reason: 'the wire payload is exactly the '
              'CreateFeatureRequestCommentInput properties');
      expect(json['body'], 'hello world');
      expect(json['parentId'], 'cm_1');
      expect(json['replyToAuthorName'], 'Alice');
    });

    test('optional declared keys stay conditional', () {
      // A top-level comment with a blank reply name: only `body` remains.
      const draft = CommentDraft(
        body: 'top level',
        authorName: 'ghost',
        replyToAuthorName: '   ',
      );

      expect(draft.toJson(), {'body': 'top level'});
    });

    test('reply fields are sent together when populated', () {
      const draft = CommentDraft(
        body: 'reply',
        parentId: 'cm_2',
        replyToAuthorName: ' Bob ',
      );

      expect(draft.toJson(), {
        'body': 'reply',
        'parentId': 'cm_2',
        'replyToAuthorName': 'Bob',
      });
    });
  });

  test('postComment sends only the declared keys on the wire', () async {
    http.Request? captured;
    final client = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'comment': createdCommentJson()}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    const draft = CommentDraft(
      body: 'Hello world',
      authorName: 'Lex',
      authorEmail: 'lex@example.com',
      authorAvatarUrl: 'https://example.com/avatar.png',
      parentId: 'cm_1',
      replyToClerkId: 'user_456',
      replyToAuthorName: 'Alice',
    );
    await client.postComment('fr_1', draft, userToken: 'user_tok_1');

    expect(captured, isNotNull);
    expect(captured!.url.path, '/api/v1/feature-requests/fr_1/comments');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body.keys.toSet(), {'body', 'parentId', 'replyToAuthorName'},
        reason: 'no authorName, authorEmail, authorAvatarUrl, or '
            'replyToClerkId key ever reaches the request body');
  });
}
