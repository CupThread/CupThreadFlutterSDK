import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #116: `RoadmapBoardScreen._loadData` only
/// seeded `_selectedColumnId` when it was still null and never re-validated
/// it against the freshly fetched visible columns. When the selected column
/// disappeared from the server's visible set between loads (deleted or
/// hidden), the tab bar highlighted nothing while the card list silently
/// fell back to the first column's items — the selected-tab ↔ displayed-
/// items invariant was broken and the stale id never reconciled.
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

  /// Whether the board still serves `col_beta`: flipped to false to
  /// simulate a moderator deleting or hiding that column server-side.
  final betaVisible = ValueNotifier<bool>(true);

  FeedbackClient clientWithMutableColumns() {
    return FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      initialConfig: config,
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/columns/')) {
          final columns = [
            {'id': 'col_a', 'name': 'Alpha', 'position': 0},
            if (betaVisible.value)
              {'id': 'col_b', 'name': 'Beta', 'position': 1},
            {'id': 'col_c', 'name': 'Gamma', 'position': 2},
          ];
          return http.Response(
            jsonEncode({'columns': columns}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/feature-requests') {
          // One request per column: the rendered card list reveals which
          // column's items the screen is actually showing.
          return http.Response(
            jsonEncode({
              'requests': [
                {
                  'id': 'fr_a',
                  'appId': 'app_123',
                  'title': 'Request in Alpha',
                  'description': 'Alpha item',
                  'status': 'under_review',
                  'columnName': 'Alpha',
                  'columnColor': '#3B82F6',
                  'columnId': 'col_a',
                  'approved': true,
                  'voteCount': 1,
                  'hasVoted': false,
                  'isOwnRequest': false,
                  'createdAt': '2026-09-01T12:00:00Z',
                  'updatedAt': '2026-09-01T12:00:00Z',
                },
                {
                  'id': 'fr_b',
                  'appId': 'app_123',
                  'title': 'Request in Beta',
                  'description': 'Beta item',
                  'status': 'under_review',
                  'columnName': 'Beta',
                  'columnColor': '#10B981',
                  'columnId': 'col_b',
                  'approved': true,
                  'voteCount': 2,
                  'hasVoted': false,
                  'isOwnRequest': false,
                  'createdAt': '2026-09-01T12:00:00Z',
                  'updatedAt': '2026-09-01T12:00:00Z',
                },
                {
                  'id': 'fr_c',
                  'appId': 'app_123',
                  'title': 'Request in Gamma',
                  'description': 'Gamma item',
                  'status': 'under_review',
                  'columnName': 'Gamma',
                  'columnColor': '#F59E0B',
                  'columnId': 'col_c',
                  'approved': true,
                  'voteCount': 3,
                  'hasVoted': false,
                  'isOwnRequest': false,
                  'createdAt': '2026-09-01T12:00:00Z',
                  'updatedAt': '2026-09-01T12:00:00Z',
                },
              ],
              'totalCount': 3,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );
  }

  Widget host(FeedbackClient client, {required String? userToken}) =>
      MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          platformOverride: FeedbackPlatform.ios,
          userToken: userToken,
          child: const RoadmapBoardScreen(),
        ),
      );

  /// The tab text is `'name (count)'` with a bold weight on the selected
  /// tab and a 2px primary-colored underline beneath it.
  Text tabText(WidgetTester tester, String name) {
    final tabTextFinder = find.textContaining(RegExp('^$name \\(\\d+\\)\$'));
    return tester.widget<Text>(tabTextFinder);
  }

  testWidgets('a selection whose column disappears on reload reconciles to '
      'the first visible column', (tester) async {
    betaVisible.value = true;
    final client = clientWithMutableColumns();

    // Initial load: [Alpha, Beta, Gamma]; the first column is selected.
    await tester.pumpWidget(host(client, userToken: null));
    await tester.pumpAndSettle();
    expect(tabText(tester, 'Alpha').style?.fontWeight, FontWeight.bold,
        reason: 'the first column is selected after the initial load');
    expect(find.text('Request in Alpha'), findsOneWidget);

    // The user taps the Beta tab: its items are shown and the tab is bold.
    await tester.tap(find.text('Beta (1)'));
    await tester.pumpAndSettle();
    expect(tabText(tester, 'Beta').style?.fontWeight, FontWeight.bold);
    expect(find.text('Request in Beta'), findsOneWidget);
    expect(find.text('Request in Alpha'), findsNothing);

    // A moderator hides column Beta server-side; the next reload serves
    // [Alpha, Gamma] while the selection still points at the dead col_b.
    betaVisible.value = false;
    await tester.pumpWidget(host(client, userToken: 'usr_tok_signed_in'));
    await tester.pumpAndSettle();

    // The stale selection is reconciled to the first visible column: the
    // tab bar and the rendered items agree again.
    expect(tabText(tester, 'Alpha').style?.fontWeight, FontWeight.bold,
        reason: 'the dead selection must reconcile to the first column');
    expect(tabText(tester, 'Gamma').style?.fontWeight, FontWeight.w500,
        reason: 'exactly one tab is selected');
    final selectedTabs = [
      'Alpha',
      'Gamma',
    ].where((name) => tabText(tester, name).style?.fontWeight == FontWeight.bold);
    expect(selectedTabs.length, 1,
        reason: 'exactly one tab may be highlighted after the reload');
    expect(find.text('Request in Alpha'), findsOneWidget,
        reason: 'the rendered items belong to the reconciled column');
    expect(find.text('Request in Beta'), findsNothing);
    expect(find.text('Request in Gamma'), findsNothing);
  });

  testWidgets('a selection whose column still exists survives a reload',
      (tester) async {
    betaVisible.value = true;
    final client = clientWithMutableColumns();

    await tester.pumpWidget(host(client, userToken: null));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beta (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Request in Beta'), findsOneWidget);

    // Reload with Beta still visible (the common case — e.g. a session
    // change): the user's selection must NOT be reset to the first column.
    await tester.pumpWidget(host(client, userToken: 'usr_tok_signed_in'));
    await tester.pumpAndSettle();

    expect(tabText(tester, 'Beta').style?.fontWeight, FontWeight.bold,
        reason: 'an existing selection survives a reload');
    expect(tabText(tester, 'Alpha').style?.fontWeight, FontWeight.w500);
    expect(find.text('Request in Beta'), findsOneWidget);
    expect(find.text('Request in Alpha'), findsNothing);
  });
}
