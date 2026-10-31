import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #60: `FeatureRequestsScreen` ignored the
/// `allowAnonymousRoadmap` policy — anonymous users on sign-in-only boards
/// fired the two gated endpoints (`GET /api/v1/feature-requests`,
/// `GET /api/v1/public/versions/:appKey`), got a 401, and landed in a
/// "Failed to load requests" dead end whose Retry could never succeed.
/// The screen now mirrors `RoadmapBoardScreen`'s anonymous gate and renders
/// sign-in guidance for `AuthenticationRequiredException` in the fallback
/// error path.
void main() {
  PublicAppConfig createMockConfig({bool allowAnonymousRoadmap = true}) {
    return PublicAppConfig(
      appId: 'app_123',
      appKey: 'app_test_123',
      slug: 'test-app',
      name: 'Test App',
      allowPublic: true,
      allowedPlatforms: const [FeedbackPlatform.ios, FeedbackPlatform.android],
      maxAttachmentBytes: 1048576,
      allowAnonymousRoadmap: allowAnonymousRoadmap,
      allowAnonymousVote: true,
      allowAnonymousFeedback: true,
      allowAnonymousChangelog: true,
      sdk: const SdkAppearance(
        features: SdkFeatures(
          feedback: true,
          featureRequests: true,
          roadmap: true,
          changelog: true,
        ),
      ),
    );
  }

  FeedbackClient clientWith(
    MockClient fn, {
    required PublicAppConfig config,
  }) =>
      FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: fn,
        initialConfig: config,
      );

  Widget host(
    FeedbackClient client, {
    String? userToken,
    PublicAppConfig? config,
  }) =>
      MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          userToken: userToken,
          child: const FeatureRequestsScreen(),
        ),
      );

  testWidgets(
      'FeatureRequestsScreen blocks anonymous loading when allowAnonymousRoadmap = false',
      (tester) async {
    final config = createMockConfig(allowAnonymousRoadmap: false);
    var fetchRequestsCalled = false;
    var fetchVersionsCalled = false;

    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          fetchRequestsCalled = true;
          return http.Response(
            jsonEncode({
              'error': 'Sign in is required to view this roadmap',
              'code': 'authentication_required',
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          fetchVersionsCalled = true;
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      config: config,
    );

    await tester.pumpWidget(host(client, userToken: null, config: config));
    await tester.pumpAndSettle();

    // Zero gated requests leave the client for an anonymous session.
    expect(fetchRequestsCalled, isFalse);
    expect(fetchVersionsCalled, isFalse);

    // Sign-in panel instead of the board or the error state.
    expect(find.text('Sign-in is required.'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Failed to load requests'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'FeatureRequestsScreen loads normally when authenticated and allowAnonymousRoadmap = false',
      (tester) async {
    final config = createMockConfig(allowAnonymousRoadmap: false);
    var fetchRequestsCalled = false;

    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          fetchRequestsCalled = true;
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      config: config,
    );

    await tester.pumpWidget(host(client, userToken: 'usr_tok_signed_in', config: config));
    await tester.pumpAndSettle();

    expect(fetchRequestsCalled, isTrue);
    expect(find.text('Sign-in is required.'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
      'FeatureRequestsScreen loads normally for anonymous users on open boards (allowAnonymousRoadmap = true)',
      (tester) async {
    final config = createMockConfig(allowAnonymousRoadmap: true);
    var fetchRequestsCalled = false;

    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          fetchRequestsCalled = true;
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      config: config,
    );

    await tester.pumpWidget(host(client, userToken: null, config: config));
    await tester.pumpAndSettle();

    expect(fetchRequestsCalled, isTrue);
    expect(find.text('Sign-in is required.'), findsNothing);
  });

  testWidgets(
      'a 401 from the gated endpoint renders sign-in guidance, not the generic failure',
      (tester) async {
    // The AuthenticationRequiredException path is exercised through the
    // fallback render in _buildLoadError: mounting with an open-board
    // config whose client still 401s, as when the policy arrives late
    // or drifts from the server.
    final openConfig = createMockConfig(allowAnonymousRoadmap: true);
    final openClient = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({
              'error': 'Sign in is required to view this roadmap',
              'code': 'authentication_required',
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      initialConfig: openConfig,
    );

    await tester.pumpWidget(host(openClient, userToken: null, config: openConfig));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in is required.'), findsOneWidget);
    expect(find.text('Failed to load requests'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
      'signing in after a 401 reloads the list and leaves the error state',
      (tester) async {
    // Simulates the fallback window: an open-board config whose client
    // 401s (policy drifted or arrived late), then the user signs in —
    // the session change must trigger a reload that succeeds.
    final openConfig = createMockConfig(allowAnonymousRoadmap: true);
    var requestsServed = 0;
    final client = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          requestsServed++;
          if (requestsServed <= 1) {
            return http.Response(
              jsonEncode({
                'error': 'Sign in is required to view this roadmap',
                'code': 'authentication_required',
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      initialConfig: openConfig,
    );

    Widget hostFor(String? userToken) => MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: openConfig,
            userToken: userToken,
            child: const FeatureRequestsScreen(),
          ),
        );

    await tester.pumpWidget(hostFor(null));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in is required.'), findsOneWidget);

    // The user signs in: a new userToken must clear the stale error and
    // reload, surfacing the board instead of dead-end guidance.
    await tester.pumpWidget(hostFor('usr_tok_signed_in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in is required.'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(requestsServed, greaterThanOrEqualTo(2));
  });
}
