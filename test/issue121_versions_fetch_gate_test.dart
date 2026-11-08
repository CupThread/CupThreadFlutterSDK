import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #121: `FeatureRequestsScreen._loadData`
/// paired `fetchVersions()` onto every refresh path — including the search
/// debounce, which re-invokes `_loadData` once per settled keystroke — so
/// typing a ten-character query fired ten `GET /api/v1/public/versions`
/// requests whose results were parsed and discarded. The version list only
/// feeds the filter chips and is app-scoped public data, so it is fetched
/// only when the screen has no version list yet.
void main() {
  PublicAppConfig createMockConfig() {
    return const PublicAppConfig(
      appId: 'app_123',
      appKey: 'app_test_123',
      slug: 'test-app',
      name: 'Test App',
      allowPublic: true,
      allowedPlatforms: [FeedbackPlatform.ios, FeedbackPlatform.android],
      maxAttachmentBytes: 1048576,
      allowAnonymousRoadmap: true,
      allowAnonymousVote: true,
      allowAnonymousFeedback: true,
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

  Map<String, dynamic> requestsPage() => {
        'requests': [
          {'id': 'fr_1', 'title': 'Dark mode'},
        ],
        'total': 1,
        'hasMore': false,
      };

  Map<String, dynamic> versionsPage() => {
        'versions': [
          {
            'id': 'ver_1',
            'appId': 'app_123',
            'label': '2.1.0',
            'position': 1,
            'released': true,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      };

  testWidgets(
      'search keystrokes refresh requests but fetch versions exactly once',
      (tester) async {
    final config = createMockConfig();
    final versionsCalls = <Uri>[];
    final requestsCalls = <Uri>[];

    final client = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          requestsCalls.add(request.url);
          return http.Response(jsonEncode(requestsPage()), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/v1/public/versions/app_test_123') {
          versionsCalls.add(request.url);
          return http.Response(jsonEncode(versionsPage()), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      initialConfig: config,
    );

    await tester.pumpWidget(MaterialApp(
      home: CupThreadTheme(
        client: client,
        config: config,
        platformOverride: FeedbackPlatform.ios,
        userToken: 'user_tok_1',
        child: const FeatureRequestsScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Initial load fetches both endpoints.
    expect(requestsCalls, hasLength(1));
    expect(versionsCalls, hasLength(1));

    // Three settled keystrokes: each debounce settles into one
    // feature-requests refresh, but the versions endpoint stays cold.
    for (final query in ['a', 'ab', 'abc']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    expect(requestsCalls, hasLength(4),
        reason: 'one feature-requests fetch per settled keystroke');
    expect(versionsCalls, hasLength(1),
        reason: 'the versions endpoint is fetched once, never per keystroke');
    expect(requestsCalls.last.queryParameters['q'], 'abc');
  });

  testWidgets(
      'a pull-to-refresh keeps the filter chips and stays off the versions endpoint',
      (tester) async {
    final config = createMockConfig();
    var versionsCalls = 0;
    var requestsCalls = 0;

    final client = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          requestsCalls++;
          return http.Response(jsonEncode(requestsPage()), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/v1/public/versions/app_test_123') {
          versionsCalls++;
          return http.Response(jsonEncode(versionsPage()), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      }),
      initialConfig: config,
    );

    await tester.pumpWidget(MaterialApp(
      home: CupThreadTheme(
        client: client,
        config: config,
        platformOverride: FeedbackPlatform.ios,
        userToken: 'user_tok_1',
        child: const FeatureRequestsScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // The version filter chips render from the first load.
    expect(find.text('2.1.0'), findsOneWidget);

    // Drive the pull-to-refresh path directly: RefreshIndicator wires
    // onRefresh to _loadData.
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    expect(refresh, isNotNull);
    await refresh();
    await tester.pumpAndSettle();

    expect(requestsCalls, 2, reason: 'the refresh re-fetches the requests');
    expect(versionsCalls, 1,
        reason: 'a refresh with a populated version list skips the versions '
            'fetch');
    expect(find.text('2.1.0'), findsOneWidget,
        reason: 'the chips keep their data source across the refresh');
  });
}
