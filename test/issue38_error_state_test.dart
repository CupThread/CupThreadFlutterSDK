import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

PublicAppConfig _testConfig() {
  return const PublicAppConfig(
    appId: 'app_123',
    appKey: 'app_test_123',
    slug: 'test-app',
    name: 'Test App',
    allowPublic: true,
    allowedPlatforms: [FeedbackPlatform.ios, FeedbackPlatform.android],
    maxAttachmentBytes: 1048576,
    allowAnonymousVote: true,
    allowAnonymousFeedback: true,
    allowAnonymousRoadmap: true,
    allowAnonymousChangelog: true,
    sdk: SdkAppearance(
      features: SdkFeatures(
        feedback: true,
        featureRequests: true,
        roadmap: true,
        changelog: true,
      ),
    ),
  );
}

FeedbackClient _buildClient(http.Client httpClient) {
  return FeedbackClient(
    FeedbackClientConfig(
      baseUrl: 'https://api.cupthread.com',
      appKey: 'app_test_123',
    ),
    initialConfig: _testConfig(),
    httpClient: httpClient,
  );
}

Widget _wrap(Widget child, FeedbackClient client, {bool? isAnonymousOverride}) {
  return MaterialApp(
    home: CupThreadTheme(
      client: client,
      config: _testConfig(),
      userToken: isAnonymousOverride == false ? 'user_tok_1' : 'user_token_abc',
      isAnonymousOverride: isAnonymousOverride,
      child: child,
    ),
  );
}

Map<String, dynamic> _changelogItem(String id, String title) {
  return {
    'id': id,
    'appId': 'app_123',
    'title': title,
    'body': 'Notes for $title',
    'versionLabel': '1.0.0',
    'publishedAt': '2026-05-01T00:00:00.000Z',
    'status': 'published',
  };
}

Map<String, dynamic> _commentItem(
  String id,
  String body, {
  String featureRequestId = 'fr_1',
}) {
  return {
    'id': id,
    'featureRequestId': featureRequestId,
    'body': body,
    'createdAt': '2026-05-01T00:00:00.000Z',
  };
}

void main() {
  group('issue #38 — WhatsNewScreen fetch failure error handling', () {
    testWidgets('network failure shows error state with Retry instead of empty changelog',
        (tester) async {
      var fail = true;
      final client = _buildClient(MockClient((request) async {
        if (request.url.path.endsWith('/changelog')) {
          if (fail) {
            return http.Response(jsonEncode({'error': 'server error'}), 500,
                headers: {'content-type': 'application/json'});
          }
          return http.Response(
            jsonEncode({
              'entries': [_changelogItem('ch_1', 'Version 1.0 Release')],
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(_wrap(const WhatsNewScreen(), client));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load requests'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // The subscribe card / empty changelog list is not shown in the error state.
      expect(find.text(CupThreadStrings.en.subscribeToUpdates), findsNothing);

      // Now recover and tap Retry.
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load requests'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.text('Version 1.0 Release'), findsOneWidget);
      expect(find.text(CupThreadStrings.en.subscribeToUpdates), findsOneWidget);
    });

    testWidgets('successful empty changelog displays normal view without error state',
        (tester) async {
      final client = _buildClient(MockClient((request) async {
        if (request.url.path.endsWith('/changelog')) {
          return http.Response(
            jsonEncode({'entries': [], 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(_wrap(const WhatsNewScreen(), client));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load requests'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.text(CupThreadStrings.en.subscribeToUpdates), findsOneWidget);
    });

    testWidgets('auth error on changelog fetch shows sign-in guidance without Retry',
        (tester) async {
      final client = _buildClient(MockClient((request) async {
        if (request.url.path.endsWith('/changelog')) {
          return http.Response(
            jsonEncode({'error': 'Unauthorized', 'code': 'authentication_required'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(_wrap(const WhatsNewScreen(), client));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in is required.'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text(CupThreadStrings.en.subscribeToUpdates), findsNothing);
    });

    testWidgets('failed pull-to-refresh does not wipe out already-loaded entries',
        (tester) async {
      var fail = false;
      var changelogRequests = 0;
      final client = _buildClient(MockClient((request) async {
        if (request.url.path.endsWith('/changelog')) {
          changelogRequests++;
          if (fail) {
            return http.Response(jsonEncode({'error': 'transient 500'}), 500,
                headers: {'content-type': 'application/json'});
          }
          return http.Response(
            jsonEncode({
              'entries': [_changelogItem('ch_1', 'Version 1.0 Release')],
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(_wrap(const WhatsNewScreen(), client));
      await tester.pumpAndSettle();

      expect(find.text('Version 1.0 Release'), findsOneWidget);
      expect(changelogRequests, equals(1));

      // Now flip to failing and trigger pull-to-refresh.
      fail = true;
      final before = changelogRequests;
      final listView = find.byType(ListView);
      await tester.fling(listView, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Assert that a refresh request was executed.
      expect(changelogRequests, greaterThan(before));

      // The entries are preserved, not replaced by the error screen.
      expect(find.text('Version 1.0 Release'), findsOneWidget);
      expect(find.text('Failed to load requests'), findsNothing);
    });
  });

  group('issue #38 — CommentsView fetch failure error handling', () {
    testWidgets('network failure shows error state with Retry instead of "No comments yet"',
        (tester) async {
      var fail = true;
      final client = _buildClient(MockClient((request) async {
        if (request.url.path.endsWith('/comments')) {
          if (fail) {
            return http.Response(jsonEncode({'error': 'server error'}), 500,
                headers: {'content-type': 'application/json'});
          }
          return http.Response(
            jsonEncode({
              'comments': [_commentItem('c_1', 'Great idea!')],
              'total': 1,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_1'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load requests'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // "No comments yet..." should NOT be shown.
      expect(find.text(CupThreadStrings.en.noCommentsYet), findsNothing);
      // The compose box should NOT be shown while in error state.
      expect(find.byType(TextField), findsNothing);

      // Now recover and tap Retry.
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load requests'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.text('Great idea!'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('successful empty comments display "No comments yet" without error state',
        (tester) async {
      final client = _buildClient(MockClient((request) async {
        if (request.url.path.endsWith('/comments')) {
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
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_1'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load requests'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.text(CupThreadStrings.en.noCommentsYet), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('failed reload of comments keeps already-loaded comments visible',
        (tester) async {
      var fail = false;
      var commentRequests = 0;
      final client = _buildClient(MockClient((request) async {
        if (request.url.path.endsWith('/comments')) {
          commentRequests++;
          if (fail) {
            return http.Response(jsonEncode({'error': 'server error'}), 500,
                headers: {'content-type': 'application/json'});
          }
          return http.Response(
            jsonEncode({
              'comments': [_commentItem('c_1', 'Great idea!')],
              'total': 1,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_1'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Great idea!'), findsOneWidget);
      expect(commentRequests, equals(1));

      // Now trigger reload failure via the reload hook
      fail = true;
      final before = commentRequests;
      await tester.state<CommentsViewState>(find.byType(CommentsView)).reload();
      await tester.pumpAndSettle();

      expect(commentRequests, greaterThan(before));
      expect(find.text('Great idea!'), findsOneWidget);
      expect(find.text('Failed to load requests'), findsNothing);
    });

    testWidgets('updating featureRequestId reloads comments', (tester) async {
      final client = _buildClient(MockClient((request) async {
        if (request.url.path.contains('/fr_1/comments')) {
          return http.Response(
            jsonEncode({
              'comments': [_commentItem('c_1', 'Comment on request 1')],
              'total': 1,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/fr_2/comments')) {
          return http.Response(
            jsonEncode({
              'comments': [
                _commentItem('c_2', 'Comment on request 2',
                    featureRequestId: 'fr_2'),
              ],
              'total': 1,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_1'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Comment on request 1'), findsOneWidget);
      expect(find.text('Comment on request 2'), findsNothing);

      // Rebuild with a different featureRequestId
      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_2'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Comment on request 1'), findsNothing);
      expect(find.text('Comment on request 2'), findsOneWidget);
    });

    testWidgets('discards a stale comments response after switching requests',
        (tester) async {
      final staleResponse = Completer<http.Response>();
      final client = _buildClient(MockClient((request) {
        if (request.url.path.contains('/fr_1/comments')) {
          return staleResponse.future;
        }
        if (request.url.path.contains('/fr_2/comments')) {
          return Future.value(http.Response(
            jsonEncode({
              'comments': [
                _commentItem('c_2', 'Comment on request 2',
                    featureRequestId: 'fr_2'),
              ],
              'total': 1,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
        }
        return Future.value(http.Response('{}', 200,
            headers: {'content-type': 'application/json'}));
      }));

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_1'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pump();

      // Switch to fr_2 while the fr_1 request is still in flight.
      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_2'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Comment on request 2'), findsOneWidget);

      staleResponse.complete(http.Response(
        jsonEncode({
          'comments': [_commentItem('c_1', 'Comment on request 1')],
          'total': 1,
          'hasMore': false,
          'nextCursor': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Comment on request 2'), findsOneWidget);
      expect(find.text('Comment on request 1'), findsNothing);
      expect(find.text('Failed to load requests'), findsNothing);
    });

    testWidgets('discards a stale comments failure after switching requests',
        (tester) async {
      final staleResponse = Completer<http.Response>();
      final client = _buildClient(MockClient((request) {
        if (request.url.path.contains('/fr_1/comments')) {
          return staleResponse.future;
        }
        if (request.url.path.contains('/fr_2/comments')) {
          return Future.value(http.Response(
            jsonEncode({
              'comments': [
                _commentItem('c_2', 'Comment on request 2',
                    featureRequestId: 'fr_2'),
              ],
              'total': 1,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
        }
        return Future.value(http.Response('{}', 200,
            headers: {'content-type': 'application/json'}));
      }));

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_1'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_2'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Comment on request 2'), findsOneWidget);

      staleResponse.complete(http.Response(
        jsonEncode({'error': 'stale failure'}),
        500,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      // The stale failure must not replace the new request's loaded comments.
      expect(find.text('Comment on request 2'), findsOneWidget);
      expect(find.text('Failed to load requests'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('discards a stale post result after switching requests',
        (tester) async {
      final postResponse = Completer<http.Response>();
      final client = _buildClient(MockClient((request) {
        if (request.method == 'POST') {
          return postResponse.future;
        }
        if (request.url.path.contains('/fr_1/comments')) {
          return Future.value(http.Response(
            jsonEncode({
              'comments': [],
              'total': 0,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
        }
        if (request.url.path.contains('/fr_2/comments')) {
          return Future.value(http.Response(
            jsonEncode({
              'comments': [
                _commentItem('c_2', 'Comment on request 2',
                    featureRequestId: 'fr_2'),
              ],
              'total': 1,
              'hasMore': false,
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
        }
        return Future.value(http.Response('{}', 200,
            headers: {'content-type': 'application/json'}));
      }));

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_1'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Reply on request 1');
      await tester.tap(find.text('Send'));
      await tester.pump();

      // Switch requests while the post is still in flight.
      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: CommentsView(featureRequestId: 'fr_2'),
            ),
          ),
          client,
          isAnonymousOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      postResponse.complete(http.Response(
        jsonEncode(_commentItem('c_posted', 'Reply on request 1')),
        201,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      // The stale post must not append to fr_2's thread.
      expect(find.text('Reply on request 1'), findsNothing);
      expect(find.text('Comment on request 2'), findsOneWidget);
    });
  });
}
