import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  // API behavior (issue #16): a private app (allowPublic = false) receives
  // HTTP 404 with an "App not found" body on the public config endpoints —
  // identical to an unknown app — instead of a 200 config payload. The SDK
  // must treat any config-fetch failure as fail-closed and never construct
  // or cache a config from such a response.
  final privateAppBody = jsonEncode({'error': 'App not found'});

  http.Response jsonResponse(Map<String, dynamic> body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  group('issue #16: fetchAppConfig 404 contract (private/unknown app)', () {
    test('throws fail-closed UnexpectedStatusException with status 404',
        () async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_private_1',
        ),
        httpClient: MockClient((request) async =>
            jsonResponse({'error': 'App not found'}, 404)),
      );

      await expectLater(
        client.fetchAppConfig(),
        throwsA(isA<UnexpectedStatusException>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.responseBody, 'responseBody', privateAppBody)),
      );
    });

    test('never embeds the 404 body in message or toString', () async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_private_1',
        ),
        httpClient: MockClient(
            (request) async => jsonResponse({'error': 'App not found'}, 404)),
      );

      UnexpectedStatusException? caught;
      try {
        await client.fetchAppConfig();
      } catch (e) {
        caught = e as UnexpectedStatusException;
      }

      expect(caught, isNotNull);
      expect(caught!.message, isNot(contains('App not found')));
      expect(caught.toString(), isNot(contains('App not found')));
    });

    test('a 404 is never parsed or cached as a PublicAppConfig', () async {
      var configRequests = 0;
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_private_1',
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/public/config/')) {
            configRequests++;
            // First call: private app (404). Second call: the app became
            // public, so the endpoint starts serving the real config.
            return configRequests == 1
                ? jsonResponse({'error': 'App not found'}, 404)
                : jsonResponse({});
          }
          return jsonResponse({'error': 'not found'}, 404);
        }),
      );

      // The failed fetch must throw…
      await expectLater(
        client.fetchAppConfig(),
        throwsA(isA<UnexpectedStatusException>()),
      );
      // …and must not poison the cache: the next call re-issues the request
      // and succeeds once the app is public.
      final config = await client.fetchAppConfig();
      expect(configRequests, 2);
      expect(config.appKey, '');
      expect(config.allowedPlatforms, isEmpty);
    });
  });

  group('issue #16: surfaces fail closed on config 404', () {
    testWidgets(
        'FeatureRequestsScreen shows the config error state for a private app',
        (tester) async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_private_1',
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/public/config/')) {
            return jsonResponse({'error': 'App not found'}, 404);
          }
          return jsonResponse({'error': 'not found'}, 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            failClosed: true,
            child: const FeatureRequestsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load configuration.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('prepareChangelogOverlay returns null for a private app',
        (tester) async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_private_1',
        ),
        httpClient: MockClient((request) async =>
            jsonResponse({'error': 'App not found'}, 404)),
      );

      final overlay = await client.prepareChangelogOverlay(isAnonymous: true);
      expect(overlay, isNull);
    });
  });
}
