import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  PublicAppConfig createMockConfig({
    bool feedback = true,
    bool featureRequests = true,
    bool roadmap = true,
    bool changelog = true,
    int maxAttachmentBytes = 1048576, // 1 MB
    bool allowAnonymousVote = true,
    bool allowAnonymousFeedback = true,
    bool allowAnonymousRoadmap = true,
  }) {
    return PublicAppConfig(
      appId: 'app_123',
      appKey: 'app_test_123',
      slug: 'test-app',
      name: 'Test App',
      allowPublic: true,
      allowedPlatforms: [FeedbackPlatform.ios, FeedbackPlatform.android],
      maxAttachmentBytes: maxAttachmentBytes,
      allowAnonymousRoadmap: allowAnonymousRoadmap,
      allowAnonymousVote: allowAnonymousVote,
      allowAnonymousFeedback: allowAnonymousFeedback,
      allowAnonymousChangelog: true,
      sdk: SdkAppearance(
        features: SdkFeatures(
          feedback: feedback,
          featureRequests: featureRequests,
          roadmap: roadmap,
          changelog: changelog,
        ),
      ),
    );
  }

  group('FeatureRequestsScreen kill-switch', () {
    testWidgets(
        'mounting with features.featureRequests = false does not call fetchFeatureRequests and shows disabled state',
        (tester) async {
      bool fetchRequestsCalled = false;
      bool fetchVersionsCalled = false;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          fetchRequestsCalled = true;
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          fetchVersionsCalled = true;
          return http.Response(jsonEncode({'versions': []}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.contains('/public/config/')) {
          return http.Response(
            jsonEncode(createMockConfig(featureRequests: false).sdk.toJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
        initialConfig: createMockConfig(featureRequests: false),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: createMockConfig(featureRequests: false),
            child: const FeatureRequestsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert APIs were NEVER called
      expect(fetchRequestsCalled, isFalse);
      expect(fetchVersionsCalled, isFalse);

      // Assert disabled message is shown
      expect(find.text('Feature requests are currently disabled.'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);

      // Assert usable board is NOT shown (no search input, no '+' action)
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets(
        'mounting with features.featureRequests = true calls fetchFeatureRequests and shows board',
        (tester) async {
      bool fetchRequestsCalled = false;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          fetchRequestsCalled = true;
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
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
        initialConfig: createMockConfig(featureRequests: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: createMockConfig(featureRequests: true),
            child: const FeatureRequestsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchRequestsCalled, isTrue);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Propose Feature'), findsOneWidget);
    });
  });

  group('RoadmapBoardScreen kill-switch', () {
    testWidgets(
        'mounting with features.roadmap = false does not call fetchColumns or fetchFeatureRequests and shows disabled state',
        (tester) async {
      bool fetchColumnsCalled = false;
      bool fetchRequestsCalled = false;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/public/columns/')) {
          fetchColumnsCalled = true;
          return http.Response('{"columns":[]}', 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/v1/feature-requests') {
          fetchRequestsCalled = true;
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
        initialConfig: createMockConfig(roadmap: false),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: createMockConfig(roadmap: false),
            child: const RoadmapBoardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchColumnsCalled, isFalse);
      expect(fetchRequestsCalled, isFalse);
      expect(find.text('Roadmap is currently disabled.'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  });

  group('WhatsNewScreen kill-switch', () {
    testWidgets(
        'mounting with features.changelog = false does not call fetchChangelog and shows disabled state',
        (tester) async {
      bool fetchChangelogCalled = false;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/changelog')) {
          fetchChangelogCalled = true;
          return http.Response('{"entries":[]}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
        initialConfig: createMockConfig(changelog: false),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: createMockConfig(changelog: false),
            child: const WhatsNewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchChangelogCalled, isFalse);
      expect(find.text('Changelog is currently disabled.'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  });

  group('FeedbackComposer & FeatureRequestComposeSheet modal gates', () {
    testWidgets('FeedbackComposer.showModal returns null when features.feedback = false', (tester) async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: createMockConfig(feedback: false),
      );

      FeedbackSubmissionResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: createMockConfig(feedback: false),
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await FeedbackComposer.showModal(ctx);
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.byType(FeedbackComposer), findsNothing);
    });

    testWidgets('FeatureRequestComposeSheet.show returns null when features.featureRequests = false', (tester) async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: createMockConfig(featureRequests: false),
      );

      FeatureRequestSubmissionResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: createMockConfig(featureRequests: false),
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await FeatureRequestComposeSheet.show(ctx);
                },
                child: const Text('Open Proposal Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Proposal Sheet'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.byType(FeatureRequestComposeSheet), findsNothing);
    });
  });

  group('Fail-closed on config error', () {
    testWidgets(
        'when fetchAppConfig fails with failClosed = true, FeatureRequestsScreen shows config error and does not enable board',
        (tester) async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/public/config/')) {
          return http.Response('Server Error', 500);
        }
        return http.Response('{}', 200);
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
            failClosed: true,
            child: const FeatureRequestsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show config failure view and retry button, not a usable board
      expect(find.text('Failed to load configuration.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets(
        'when fetchAppConfig fails with failClosed = false host override, FeatureRequestsScreen proceeds fail-open',
        (tester) async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/public/config/')) {
          return http.Response('Server Error', 500);
        }
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
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
            failClosed: false, // Documented host override
            child: const FeatureRequestsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // With failClosed = false override, board is accessible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Propose Feature'), findsOneWidget);
    });
  });

  group('Attachment size enforcement', () {
    test('uploadAttachment throws AttachmentTooLargeException when exceeding maxAttachmentBytes', () async {
      final config = createMockConfig(maxAttachmentBytes: 100); // 100 bytes max
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: config,
      );

      final largeBytes = List<int>.filled(200, 42); // 200 bytes

      expect(
        () => client.uploadAttachment(
          bytes: largeBytes,
          filename: 'test.png',
          mimeType: 'image/png',
        ),
        throwsA(isA<AttachmentTooLargeException>()
            .having((e) => e.actualBytes, 'actualBytes', 200)
            .having((e) => e.maxBytes, 'maxBytes', 100)),
      );
    });

    testWidgets('FeedbackComposer rejects attachments exceeding maxAttachmentBytes in preflight', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const oversizedAttachment = FeedbackAttachment(
        kind: AttachmentKind.image,
        key: 'img_oversized',
        url: 'https://example.com/big.png',
        filename: 'big_image.png',
        mimeType: 'image/png',
        size: 5 * 1024 * 1024, // 5 MB
      );

      final config = createMockConfig(maxAttachmentBytes: 1 * 1024 * 1024); // 1 MB limit
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: config,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            child: Scaffold(
              body: FeedbackComposer(
                onPickAttachment: () async => oversizedAttachment,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Attachment'));
      await tester.pumpAndSettle();

      // Should show attachment error message and not add to list
      expect(find.textContaining('Attachment exceeds the maximum allowed size'), findsOneWidget);
      expect(find.text('big_image.png'), findsNothing);
    });
  });

  group('ChangelogOverlay fail-closed behavior', () {
    testWidgets('prepareChangelogOverlay returns null when changelog feature flag is false', (tester) async {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: createMockConfig(changelog: false),
      );

      final overlayData = await client.prepareChangelogOverlay();
      expect(overlayData, isNull);
    });

    testWidgets('prepareChangelogOverlay returns null when fetchAppConfig fails', (tester) async {
      final mockHttpClient = MockClient((request) async {
        return http.Response('500 Internal Error', 500);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      final overlayData = await client.prepareChangelogOverlay();
      expect(overlayData, isNull);
    });
  });

  group('Anonymous policy enforcement', () {
    testWidgets('FeatureRequestsScreen blocks anonymous vote when allowAnonymousVote = false', (tester) async {
      final config = createMockConfig(allowAnonymousVote: false);
      bool voteApiCalled = false;

      final testItemJson = {
        'id': 'fr_1',
        'appId': 'app_123',
        'title': 'Feature A',
        'description': 'Description A',
        'status': 'under_review',
        'approved': true,
        'voteCount': 5,
        'hasVoted': false,
        'isOwnRequest': false,
        'createdAt': '2026-09-01T12:00:00Z',
        'updatedAt': '2026-09-01T12:00:00Z',
      };

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({
              'requests': [testItemJson],
              'totalCount': 1,
              'hasMore': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/vote')) {
          voteApiCalled = true;
          return http.Response(jsonEncode({'voted': true, 'voteCount': 6}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
        initialConfig: config,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            userToken: null, // anonymous user
            child: const FeatureRequestsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find vote button and tap
      expect(find.byType(VoteButton), findsOneWidget);
      await tester.tap(find.byType(VoteButton));
      await tester.pumpAndSettle();

      // API should NOT have been called, and snackbar should be displayed
      expect(voteApiCalled, isFalse);
      expect(find.text('Sign-in is required to vote on feature requests.'), findsOneWidget);
    });

    testWidgets('FeedbackComposer blocks anonymous submission when allowAnonymousFeedback = false', (tester) async {
      final config = createMockConfig(allowAnonymousFeedback: false);
      bool submitCalled = false;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feedback') {
          submitCalled = true;
          return http.Response(jsonEncode({'feedbackId': 'fb_1', 'pending': false}), 201,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
        initialConfig: config,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
            userToken: null, // anonymous user
            child: const Scaffold(
              body: FeedbackComposer(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Valid feedback summary');
      await tester.enterText(find.byType(TextField).at(1), 'Valid feedback details description');

      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      expect(submitCalled, isFalse);
      expect(find.text('Sign-in is required to submit feedback.'), findsOneWidget);
    });
  });
}
