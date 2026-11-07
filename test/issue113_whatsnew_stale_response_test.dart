import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #113: `WhatsNewScreen._loadData` applied
/// its result with only a `mounted` check, so whichever changelog fetch
/// completed last won regardless of which started last. A slow
/// pull-to-refresh or a stale `_checkAndLoad` reload (config swap) could
/// overwrite a newer load's entries with stale ones, land a stale failure
/// over a newer success, or truncate the newer load's spinner. The screen
/// now mirrors the sibling generation-guard pattern (`FeatureRequestsScreen`,
/// `RoadmapBoardScreen`, `CommentsView`, `UserProfileView`): a response is
/// applied only while its captured `_loadGeneration` still matches.
void main() {
  // Deliberately NOT a `const` constructor call: Dart canonicalizes const
  // instances, so two identical const configs would be the *same* instance
  // and `_checkAndLoad`'s `_lastConfig != appConfig` reload trigger could
  // never fire. Each call must yield a distinct-but-equal instance so a
  // swap while the first load is in flight starts a second, newer load.
  // ignore: prefer_const_constructors
  PublicAppConfig testConfig() => PublicAppConfig(
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
        // ignore: prefer_const_constructors
        sdk: SdkAppearance(
          // ignore: prefer_const_constructors
          features: SdkFeatures(
            feedback: true,
            featureRequests: true,
            roadmap: true,
            changelog: true,
          ),
        ),
      );

  Map<String, dynamic> changelogItem(String title) => {
        'id': 'ch_${title.hashCode.abs()}',
        'appId': 'app_123',
        'title': title,
        'body': 'Notes for $title',
        'versionLabel': '1.0.0',
        'publishedAt': '2026-05-01T00:00:00.000Z',
        'status': 'published',
      };

  /// A client whose first two `/changelog` fetches park on the given
  /// completers (in arrival order), later ones succeed immediately.
  FeedbackClient completerClient(
    Completer<http.Response> first,
    Completer<http.Response> second,
  ) {
    var changelogRequests = 0;
    return FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      initialConfig: testConfig(),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/changelog')) {
          changelogRequests += 1;
          if (changelogRequests == 1) return first.future;
          if (changelogRequests == 2) return second.future;
          return http.Response(
            jsonEncode({'entries': [], 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }),
    );
  }

  Widget host(FeedbackClient client) => MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: testConfig(),
          platformOverride: FeedbackPlatform.ios,
          child: const WhatsNewScreen(),
        ),
      );

  group('issue #113 — WhatsNewScreen stale-response guard', () {
    testWidgets('a stale success landing after a newer load must not '
        'overwrite the newer entries', (tester) async {
      final stale = Completer<http.Response>();
      final fresh = Completer<http.Response>();
      final client = completerClient(stale, fresh);

      // Load 1 (stale, older inputs) starts and parks on its completer.
      await tester.pumpWidget(host(client));
      await tester.pump();

      // A config swap while load 1 is still in flight starts load 2.
      await tester.pumpWidget(host(client));
      await tester.pump();

      // Load 2 completes first and renders.
      fresh.complete(http.Response(
        jsonEncode({
          'entries': [changelogItem('Fresh update')],
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();
      expect(find.text('Fresh update'), findsOneWidget);

      // The stale load 1 response lands last: the generation guard must
      // drop it instead of reverting the screen to the older fetch.
      stale.complete(http.Response(
        jsonEncode({
          'entries': [changelogItem('Stale update')],
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fresh update'), findsOneWidget);
      expect(find.text('Stale update'), findsNothing);
    });

    testWidgets('a stale failure landing after a newer load succeeded must '
        'not drop the screen into the error state', (tester) async {
      final stale = Completer<http.Response>();
      final fresh = Completer<http.Response>();
      final client = completerClient(stale, fresh);

      await tester.pumpWidget(host(client));
      await tester.pump();
      await tester.pumpWidget(host(client));
      await tester.pump();

      // The newer load succeeds and fills the list.
      fresh.complete(http.Response(
        jsonEncode({
          'entries': [changelogItem('Fresh update')],
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();
      expect(find.text('Fresh update'), findsOneWidget);

      // The older load then fails: the stale failure must be dropped —
      // the entries stay rendered, no error/Retry state appears.
      stale.complete(http.Response(
        jsonEncode({'error': 'server error'}),
        500,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fresh update'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.text('Failed to load requests'), findsNothing);
      expect(find.text(CupThreadStrings.en.retry), findsNothing);
    });

    testWidgets('a stale failure while the newer load is still pending must '
        'not truncate the loading spinner', (tester) async {
      final stale = Completer<http.Response>();
      final fresh = Completer<http.Response>();
      final client = completerClient(stale, fresh);

      await tester.pumpWidget(host(client));
      await tester.pump();
      await tester.pumpWidget(host(client));
      await tester.pump();
      // Both loads pending: the spinner shows.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The stale load fails first: with the guard this is dropped and
      // the spinner keeps spinning for the still-pending newer load.
      stale.complete(http.Response(
        jsonEncode({'error': 'server error'}),
        500,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing);

      // The newer load then succeeds and renders normally.
      fresh.complete(http.Response(
        jsonEncode({
          'entries': [changelogItem('Fresh update')],
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fresh update'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('a newer load failure is still applied (guard does not '
        'over-suppress the latest response)', (tester) async {
      final stale = Completer<http.Response>();
      final fresh = Completer<http.Response>();
      final client = completerClient(stale, fresh);

      await tester.pumpWidget(host(client));
      await tester.pump();
      await tester.pumpWidget(host(client));
      await tester.pump();

      // The stale load succeeds first — dropped for now since the newer
      // load is still pending and holds the current generation.
      stale.complete(http.Response(
        jsonEncode({
          'entries': [changelogItem('Stale update')],
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The newest load then fails: its generation matches, so the error
      // state must show — the guard only drops *superseded* responses.
      fresh.complete(http.Response(
        jsonEncode({'error': 'server error'}),
        500,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Failed to load requests'), findsOneWidget);
      expect(find.text('Stale update'), findsNothing);
    });
  });
}
