import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #61: `fetchUserProfile` never sent the
/// required `appKey` query parameter, so every lookup of an app-scoped
/// `u_*` id answered 404 and `UserProfileView` could never render. The
/// endpoint also only resolves `u_*` ids from board/comment payloads and
/// requires the id to be URL-encoded since it is host-supplied.
void main() {
  const stubPayload = {
    'profile': {
      'clerkUserId': 'u_abc123',
      'displayName': 'Ada Lovelace',
      'bio': 'Building things.',
    },
    'apps': [
      {
        'id': 'app_1',
        'name': 'My App',
        'slug': 'my-app',
        'requestCount': 7,
      },
    ],
    'recentComments': [
      {
        'id': 'cm_1',
        'body': 'Would love this!',
        'createdAt': '2026-05-02T00:00:00.000Z',
        'featureRequestId': 'fr_1',
        'featureRequestTitle': 'Add dark mode',
        'appId': 'app_1',
        'appName': 'My App',
      },
    ],
    'hideComments': false,
  };

  FeedbackClient clientWith(
    MockClient fn, {
    String appKey = 'app_test_123',
  }) =>
      FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: appKey,
        ),
        httpClient: fn,
      );

  group('issue #61 — fetchUserProfile contract', () {
    test('sends the required appKey query parameter and parses the payload',
        () async {
      Uri? capturedUrl;

      final client = clientWith(MockClient((request) async {
        capturedUrl = request.url;
        return http.Response(
          jsonEncode(stubPayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      final result = await client.fetchUserProfile('u_abc123');

      expect(capturedUrl, isNotNull);
      expect(capturedUrl!.host, 'api.cupthread.com');
      expect(capturedUrl!.path, '/api/v1/users/u_abc123/profile');
      expect(capturedUrl!.queryParameters['appKey'], 'app_test_123');

      expect(result.profile.clerkUserId, 'u_abc123');
      expect(result.profile.displayName, 'Ada Lovelace');
      expect(result.apps.single.name, 'My App');
      expect(result.recentComments.single.body, 'Would love this!');
      expect(result.hideComments, isFalse);
    });

    test('an explicit appKey argument overrides the configured default',
        () async {
      Uri? capturedUrl;

      final client = clientWith(MockClient((request) async {
        capturedUrl = request.url;
        return http.Response(jsonEncode(stubPayload), 200,
            headers: {'content-type': 'application/json'});
      }), appKey: 'app_config_default');

      await client.fetchUserProfile('u_abc123', appKey: 'app_explicit');

      expect(capturedUrl!.queryParameters['appKey'], 'app_explicit');
    });

    test('URL-encodes the host-supplied userId and appKey', () async {
      Uri? capturedUrl;

      final client = clientWith(MockClient((request) async {
        capturedUrl = request.url;
        return http.Response(jsonEncode(stubPayload), 200,
            headers: {'content-type': 'application/json'});
      }));

      await client.fetchUserProfile('u_abc 123/45', appKey: 'app key+1');

      expect(capturedUrl!.path, '/api/v1/users/u_abc%20123%2F45/profile');
      expect(capturedUrl!.queryParameters['appKey'], 'app key+1');
    });
  });

  group('issue #61 — UserProfileView', () {
    Widget host(FeedbackClient client, {String userId = 'u_abc123'}) =>
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            child: Scaffold(body: UserProfileView(userId: userId)),
          ),
        );

    testWidgets('sends appKey and renders the profile card, apps, and comments',
        (tester) async {
      final capturedUrls = <Uri>[];

      final client = clientWith(MockClient((request) async {
        capturedUrls.add(request.url);
        return http.Response(jsonEncode(stubPayload), 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();

      // CupThreadTheme also fetches /api/v1/public/config/:appKey on mount;
      // only the profile lookup is under test here.
      final profileUrls =
          capturedUrls.where((u) => u.path.endsWith('/profile')).toList();
      expect(profileUrls, hasLength(1));
      expect(profileUrls.single.path, '/api/v1/users/u_abc123/profile');
      expect(profileUrls.single.queryParameters['appKey'], 'app_test_123');

      expect(find.text('User Profile'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Apps (1)'), findsOneWidget);
      expect(find.text('My App'), findsOneWidget);
      expect(find.text('Recent Comments'), findsOneWidget);
      expect(find.text('"Would love this!"'), findsOneWidget);
    });

    testWidgets('an unknown-id 404 still renders the userNotFound error state',
        (tester) async {
      final client = clientWith(MockClient((request) async {
        if (request.url.path == '/api/v1/users/u_abc123/profile') {
          return http.Response(
            jsonEncode({'error': 'User profile not found'}),
            404,
            headers: {'content-type': 'application/json'},
          );
        }
        // CupThreadTheme's own config fetch.
        return http.Response(jsonEncode({}), 200,
            headers: {'content-type': 'application/json'});
      }));

      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();

      expect(find.text('User not found.'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
    });
  });
}
