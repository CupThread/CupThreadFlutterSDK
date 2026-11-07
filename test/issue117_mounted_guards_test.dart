import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #117: the compose-sheet completion closures
/// and the detail sheet's `onVoteChange` bridges were the only async entry
/// points in the widget layer that could run against a disposed screen State.
/// A host can tear the screen's route down underneath an open sheet (nested
/// navigators, a "close all" flow, `Navigator.removeRoute`); when the sheet's
/// future then completes, the unguarded closures performed inherited-widget
/// lookups on a defunct element or called `setState` after dispose.
void main() {
  const config = PublicAppConfig(
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

  FeedbackClient client() {
    return FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      initialConfig: config,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({
              'requests': [
                {
                  'id': 'fr_1',
                  'appId': 'app_123',
                  'title': 'First request',
                  'description': 'A proposal',
                  'status': 'under_review',
                  'approved': true,
                  'voteCount': 1,
                  'hasVoted': false,
                  'isOwnRequest': false,
                  'createdAt': '2026-09-01T12:00:00Z',
                  'updatedAt': '2026-09-01T12:00:00Z',
                },
              ],
              'totalCount': 1,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/feature-requests/fr_1/vote' &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({'voted': true, 'voteCount': 2}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  /// Pumps a host whose inner navigator owns the screen's route, returning
  /// the navigator State and the route so a test can tear the screen's route
  /// down underneath an open sheet — the disposal scenario from the issue.
  Future<(NavigatorState, MaterialPageRoute<void>)> pumpHostWithTrackedRoute(
    WidgetTester tester,
  ) async {
    MaterialPageRoute<void>? screenRoute;
    final client_ = client();
    await tester.pumpWidget(
      MaterialApp(
        home: CupThreadTheme(
          client: client_,
          config: config,
          platformOverride: FeedbackPlatform.ios,
          userToken: 'usr_tok_signed_in',
          child: Navigator(
            onGenerateRoute: (settings) {
              screenRoute = MaterialPageRoute<void>(
                builder: (_) => const FeatureRequestsScreen(),
                settings: settings,
              );
              return screenRoute;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First request'), findsOneWidget,
        reason: 'the screen loaded its list before the test proceeds');
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    return (nav, screenRoute!);
  }

  testWidgets(
      'compose-sheet completion after the screen was disposed does not touch '
      'the defunct State', (tester) async {
    final (nav, screenRoute) = await pumpHostWithTrackedRoute(tester);

    // Open the compose sheet from the app bar.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(FeatureRequestComposeSheet), findsOneWidget);

    // Tear the screen's route down underneath the open sheet — the nested-
    // navigator / "close all" flow from the issue. The sheet stays up; the
    // screen State is gone.
    nav.removeRoute(screenRoute);
    await tester.pump();
    expect(find.byType(FeatureRequestsScreen), findsNothing);

    // Complete the sheet with a non-null result: the completion closure now
    // runs against a disposed State and must bail out on `!mounted`.
    nav.pop(const FeatureRequestSubmissionResult(
      featureRequestId: 'fr_new',
      pending: false,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'no defunct-element lookup or setState-after-dispose error');
  });

  testWidgets(
      'onVoteChange bridge after the screen was disposed does not call '
      'setState on the defunct State', (tester) async {
    final (nav, screenRoute) = await pumpHostWithTrackedRoute(tester);

    // Open the detail sheet for the loaded request.
    await tester.tap(find.text('First request'));
    await tester.pumpAndSettle();
    expect(find.byType(FeatureRequestDetailSheet), findsOneWidget);

    // Dispose the screen underneath the open sheet. The sheet outlives it,
    // so its vote flow can still complete and invoke the bridge.
    nav.removeRoute(screenRoute);
    await tester.pump();
    expect(find.byType(FeatureRequestsScreen), findsNothing);

    // Complete the vote flow inside the sheet: the optimistic update fires
    // the onVoteChange bridge immediately, the confirmed update fires it
    // again after the mocked network round-trip. Both must be no-ops now
    // that the screen is disposed.
    await tester.tap(find.byType(VoteButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'no setState-after-dispose error from the vote bridge');
  });
}
