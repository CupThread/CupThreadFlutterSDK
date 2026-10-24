import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  group('FeatureRequestComposeSheet', () {
    testWidgets('renders input fields and submits request', (tester) async {
      bool apiCalled = false;
      Map<String, dynamic>? postedBody;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests' && request.method == 'POST') {
          apiCalled = true;
          postedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'featureRequestId': 'fr_new_123', 'pending': false}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/public/config/')) {
          return http.Response('{}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"error":"not found"}', 404);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      FeatureRequestSubmissionResult? submissionResult;

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            userToken: 'user_token_abc',
            child: Scaffold(
              body: FeatureRequestComposeSheet(
                onSubmitSuccess: (res) {
                  submissionResult = res;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify fields exist
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Title *'), findsOneWidget);
      expect(find.text('Details *'), findsOneWidget);

      // Enter data
      await tester.enterText(find.byType(TextField).at(0), 'Export CSV feature');
      await tester.enterText(find.byType(TextField).at(1), 'Please allow exporting analytics to CSV format');
      await tester.enterText(find.byType(TextField).at(2), 'Alice Developer');

      // Tap submit button
      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(apiCalled, isTrue);
      expect(postedBody?['title'], 'Export CSV feature');
      expect(postedBody?['description'], 'Please allow exporting analytics to CSV format');
      expect(postedBody?['requesterName'], 'Alice Developer');
      expect(postedBody?['appKey'], 'app_test_123');
      expect(postedBody?['requesterToken'], 'user_token_abc');
      expect(submissionResult?.featureRequestId, 'fr_new_123');
    });

    testWidgets('FeatureRequestsScreen launches FeatureRequestComposeSheet on add button tap', (tester) async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            child: const FeatureRequestsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify "+" button is present in AppBar
      final addButton = find.byIcon(Icons.add).first;
      expect(addButton, findsOneWidget);

      // Tap "+" button to open proposal sheet
      await tester.tap(addButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Ensure FeatureRequestComposeSheet opened (with "Submit Request" button)
      expect(find.byType(FeatureRequestComposeSheet), findsOneWidget);
      expect(find.text('Submit Request'), findsOneWidget);
    });
  });

  group('FeedbackComposer with attachments', () {
    testWidgets('renders attachment list and triggers onPickAttachment callback', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool pickCalled = false;
      const testAttachment = FeedbackAttachment(
        kind: AttachmentKind.image,
        key: 'img_test_key_1',
        url: 'https://example.com/screenshot.png',
        filename: 'my_screenshot.png',
        mimeType: 'image/png',
        size: 204800,
      );

      final mockHttpClient = MockClient((request) async {
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            child: Scaffold(
              body: FeedbackComposer(
                onPickAttachment: () async {
                  pickCalled = true;
                  return testAttachment;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attachments'), findsOneWidget);
      expect(find.text('Add Attachment'), findsOneWidget);

      // Tap Add Attachment
      await tester.tap(find.text('Add Attachment'));
      await tester.pumpAndSettle();

      expect(pickCalled, isTrue);
      expect(find.text('my_screenshot.png'), findsOneWidget);
      expect(find.textContaining('200.0 KB'), findsOneWidget);

      // Verify delete button removes attachment
      expect(find.byTooltip('Remove'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('my_screenshot.png'), findsNothing);
    });
  });

  group('Changelog seen persistence', () {
    testWidgets('marks changelog seen when overlay is closed', (tester) async {
      final storage = MemoryTokenStorage();
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        storage: storage,
      );

      const entry = ChangelogEntry(
        id: 'cl_1',
        title: 'Release 2.0.0',
        body: 'Big updates in this release',
        publishedAt: '2026-09-01T12:00:00Z',
        versionLabel: '2.0.0',
      );

      expect(await client.hasSeenChangelog('2.0.0'), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            child: const Scaffold(
              body: ChangelogOverlay(
                entries: [entry],
                config: ChangelogOverlayConfig(),
                autoMarkSeen: true,
              ),
            ),
          ),
        ),
      );
      // One extra frame for CupThreadTheme to restore the anonymous
      // identity from storage before building its child.
      await tester.pump();

      expect(find.text('Release 2.0.0'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Tap primary action button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(await client.hasSeenChangelog('2.0.0'), isTrue);
    });
  });

  group('Voting in UI widgets (castVote vs removeVote)', () {
    Map<String, dynamic> createRequestJson({
      String id = 'fr_1',
      int voteCount = 5,
      bool hasVoted = false,
      String? columnId,
    }) {
      return {
        'id': id,
        'appId': 'app_123',
        'title': 'Dark mode support',
        'description': 'Add full dark mode theme',
        'status': 'under_review',
        'approved': true,
        'voteCount': voteCount,
        'hasVoted': hasVoted,
        'isOwnRequest': false,
        if (columnId != null) 'columnId': columnId,
        'createdAt': '2026-09-01T12:00:00Z',
        'updatedAt': '2026-09-01T12:00:00Z',
      };
    }

    testWidgets('FeatureRequestsScreen sends POST to cast vote and DELETE to remove vote', (tester) async {
      final voteMethods = <String>[];

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({
              'requests': [createRequestJson(voteCount: 5, hasVoted: false)],
              'totalCount': 1,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/feature-requests/fr_1/vote') {
          voteMethods.add(request.method);
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'voted': true, 'voteCount': 6}),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (request.method == 'DELETE') {
            return http.Response(
              jsonEncode({'voted': false, 'voteCount': 5}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            userToken: 'user_tok_1',
            child: const FeatureRequestsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);

      // First tap: casts vote via POST
      await tester.tap(find.byType(VoteButton));
      await tester.pumpAndSettle();

      expect(voteMethods, ['POST']);
      expect(find.text('6'), findsOneWidget);

      // Second tap: removes vote via DELETE
      await tester.tap(find.byType(VoteButton));
      await tester.pumpAndSettle();

      expect(voteMethods, ['POST', 'DELETE']);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('RoadmapBoardScreen sends POST to cast vote and DELETE to remove vote', (tester) async {
      final voteMethods = <String>[];

      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/columns/')) {
          return http.Response(
            jsonEncode({
              'columns': [
                {'id': 'col_1', 'name': 'Planned', 'position': 0}
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({
              'requests': [createRequestJson(voteCount: 10, hasVoted: true, columnId: 'col_1')],
              'totalCount': 1,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/feature-requests/fr_1/vote') {
          voteMethods.add(request.method);
          if (request.method == 'DELETE') {
            return http.Response(
              jsonEncode({'voted': false, 'voteCount': 9}),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'voted': true, 'voteCount': 10}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            userToken: 'user_tok_1',
            child: const RoadmapBoardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts voted (10) -> first tap removes vote via DELETE
      await tester.tap(find.byType(VoteButton));
      await tester.pumpAndSettle();

      expect(voteMethods, ['DELETE']);
      expect(find.text('9'), findsOneWidget);

      // Second tap casts vote via POST
      await tester.tap(find.byType(VoteButton));
      await tester.pumpAndSettle();

      expect(voteMethods, ['DELETE', 'POST']);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('FeatureRequestDetailSheet sends POST to cast vote and DELETE to remove vote', (tester) async {
      final voteMethods = <String>[];

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests/fr_1/vote') {
          voteMethods.add(request.method);
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'voted': true, 'voteCount': 8}),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (request.method == 'DELETE') {
            return http.Response(
              jsonEncode({'voted': false, 'voteCount': 7}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        if (request.url.path.contains('/comments')) {
          return http.Response(jsonEncode({'comments': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      final item = FeatureRequestItem.fromJson(createRequestJson(voteCount: 7, hasVoted: false));

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            userToken: 'user_tok_1',
            child: FeatureRequestDetailSheet(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap vote button -> POST
      await tester.tap(find.byType(VoteButton));
      await tester.pumpAndSettle();

      expect(voteMethods, ['POST']);
      expect(find.text('8'), findsOneWidget);

      // Tap vote button again -> DELETE
      await tester.tap(find.byType(VoteButton));
      await tester.pumpAndSettle();

      expect(voteMethods, ['POST', 'DELETE']);
      expect(find.text('7'), findsOneWidget);
    });
  });
}
