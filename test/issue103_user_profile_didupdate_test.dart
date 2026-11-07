import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #103: `UserProfileView` loaded its data
/// exactly once in `initState`, so rebuilding the same element with a
/// different `userId` kept rendering the previous user's profile. The fix
/// mirrors `CommentsView`: `didUpdateWidget` resets and reloads on an id
/// change, a generation guard drops stale responses, and the generic error
/// branch gains a Retry affordance (the unknown-id 404 copy stays static).
void main() {
  FeedbackClient clientWith(MockClient fn) => FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: fn,
      );

  Map<String, Object?> profilePayload(String id, String name) => {
        'profile': {
          'clerkUserId': id,
          'displayName': name,
          'bio': 'Bio of $name.',
          'createdAt': '2026-01-15T00:00:00.000Z',
        },
        'publicApps': [
          {
            'id': 'app_$id',
            'workspaceSlug': 'acme',
            'workspaceName': 'Acme Inc',
            'appSlug': 'my-app',
            'name': 'App of $name',
            'description': 'A delightful app.',
            'iconUrl': null,
          },
        ],
        'recentComments': <Object?>[],
      };

  Widget host(FeedbackClient client, String userId) => MaterialApp(
        home: CupThreadTheme(
          client: client,
          child: Scaffold(body: UserProfileView(userId: userId)),
        ),
      );

  group('issue #103 — userId change reloads', () {
    testWidgets('swapping the id in place issues a new request and renders '
        'the new user', (tester) async {
      final profileRequests = <Uri>[];

      final client = clientWith(MockClient((request) async {
        if (request.url.path.endsWith('/profile')) {
          profileRequests.add(request.url);
          final id = request.url.pathSegments[
              request.url.pathSegments.indexOf('users') + 1];
          return http.Response(
            jsonEncode(profilePayload(id, id == 'u_aaa' ? 'Alice' : 'Bob')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // CupThreadTheme's own config fetch.
        return http.Response(jsonEncode({}), 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(host(client, 'u_aaa'));
      await tester.pumpAndSettle();

      expect(profileRequests, hasLength(1));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);

      // Same element position, same runtime type, no key: the State must be
      // reused and react to the changed input.
      await tester.pumpWidget(host(client, 'u_bbb'));
      await tester.pumpAndSettle();

      expect(
        profileRequests.map((u) => u.path),
        contains('/api/v1/users/u_bbb/profile'),
      );
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('App of Bob'), findsOneWidget);
    });

    testWidgets('a late-arriving response for the old id cannot overwrite '
        'the new user\'s profile', (tester) async {
      final oldResponse = Completer<http.Response>();
      final newResponse = Completer<http.Response>();

      final client = clientWith(MockClient((request) async {
        if (request.url.path == '/api/v1/users/u_aaa/profile') {
          return oldResponse.future;
        }
        if (request.url.path == '/api/v1/users/u_bbb/profile') {
          return newResponse.future;
        }
        return http.Response(jsonEncode({}), 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(host(client, 'u_aaa'));
      // u_aaa's fetch is still in flight — do not settle.
      await tester.pump();

      // Swap to u_bbb while the u_aaa fetch is pending.
      await tester.pumpWidget(host(client, 'u_bbb'));
      await tester.pump();

      // The stale u_aaa response lands now; the generation guard must drop it.
      oldResponse.complete(
        http.Response(
          jsonEncode(profilePayload('u_aaa', 'Alice')),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Alice'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The current user's response renders.
      newResponse.complete(
        http.Response(
          jsonEncode(profilePayload('u_bbb', 'Bob')),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('a failed load offers Retry and a retry succeeding renders '
        'the profile', (tester) async {
      var attempt = 0;

      final client = clientWith(MockClient((request) async {
        if (request.url.path == '/api/v1/users/u_aaa/profile') {
          attempt++;
          if (attempt == 1) {
            return http.Response(jsonEncode({'error': 'boom'}), 500,
                headers: {'content-type': 'application/json'});
          }
          return http.Response(
            jsonEncode(profilePayload('u_aaa', 'Alice')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({}), 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(host(client, 'u_aaa'));
      await tester.pumpAndSettle();

      expect(attempt, 1);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Alice'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(attempt, 2);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('an unknown-id 404 keeps the static userNotFound copy with '
        'no Retry affordance', (tester) async {
      final client = clientWith(MockClient((request) async {
        if (request.url.path == '/api/v1/users/u_missing/profile') {
          return http.Response(
            jsonEncode({'error': 'User profile not found'}),
            404,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({}), 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(host(client, 'u_missing'));
      await tester.pumpAndSettle();

      expect(find.text('User not found.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });
  });
}
