import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  // Multi-kilobyte HTML payload as a real API gateway might return on a 5xx.
  final htmlBody = '<html><head><title> INTERNAL_ERROR dk9fj3 </title></head><body>'
      '${'stack-frame-0x4f2a ' * 200}</body></html>';

  group('UnexpectedStatusException sanitization', () {
    test('toString() and message never include the raw response body', () {
      final e = UnexpectedStatusException(502, htmlBody);

      expect(e.message, 'CupThread API responded with unexpected status HTTP 502');
      expect(e.toString(),
          'UnexpectedStatusException(502): CupThread API responded with unexpected status HTTP 502');
      expect(e.toString(), isNot(contains('INTERNAL_ERROR')));
      expect(e.toString(), isNot(contains('<html>')));
      expect(e.toString(), isNot(contains('stack-frame')));
      expect(e.message.length, lessThan(htmlBody.length));
    });

    test('responseBody stays available for host diagnostics', () {
      final e = UnexpectedStatusException(500, htmlBody);

      expect(e.responseBody, htmlBody);
      expect(e.status, 500);
      expect(e, isA<FeedbackException>());
    });

    test('client surfaces sanitized exception when a JSON endpoint fails with an HTML body', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(htmlBody, 503);
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      await expectLater(
        client.fetchAppConfig(forceRefresh: true),
        throwsA(isA<UnexpectedStatusException>()
            .having((e) => e.status, 'status', 503)
            .having((e) => e.responseBody, 'responseBody', htmlBody)
            .having(
              (e) => e.toString(),
              'toString',
              isNot(contains('INTERNAL_ERROR')),
            )),
      );
    });
  });

  group('Compose surfaces never render raw response bodies', () {
    testWidgets('FeedbackComposer submit failure shows the localized generic error, not the API body', (tester) async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/feedback') {
          return http.Response(htmlBody, 500);
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

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: config,
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

      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.textContaining('INTERNAL_ERROR'), findsNothing);
      expect(find.textContaining('stack-frame'), findsNothing);
    });
  });
}
