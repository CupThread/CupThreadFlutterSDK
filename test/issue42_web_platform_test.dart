import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #42: `FeedbackClient.submit()` failed with
/// HTTP 400 on every Flutter Web submission because the SDK serialized
/// `platform: "web"`, which the API's `FeedbackSubmissionInput.platform`
/// enum (`ios` | `macos` | `android` | `universal`) does not accept.
/// The client-only `FeedbackPlatform.web` descriptor is now mapped to
/// `universal` at serialization time, while `metadata.platform` keeps the
/// precise runtime value for support triage.
void main() {
  group('issue #42 — FeedbackDraft.toJson platform wire mapping', () {
    test('a web draft serializes platform as universal and keeps web in '
        'metadata', () {
      final payload = const FeedbackDraft(
        title: 'Title',
        description: 'Description',
        platform: FeedbackPlatform.web,
      ).toJson(appKey: 'app_test_123', submittedAt: '2026-10-31T00:00:00.000Z');

      expect(payload['platform'], 'universal');
      expect((payload['metadata'] as Map<String, dynamic>)['platform'], 'web');
    });

    test('every platform enum value serializes to an API-accepted wire value',
        () {
      // The live API schema declares exactly these four platform values for
      // POST /api/v1/feedback — `web` is not accepted. This guards future
      // enum additions against drifting from the API contract.
      const acceptedWireValues = {'ios', 'macos', 'android', 'universal'};

      for (final platform in FeedbackPlatform.values) {
        final payload = FeedbackDraft(
          title: 'Title',
          description: 'Description',
          platform: platform,
        ).toJson(appKey: 'app_test_123', submittedAt: '2026-10-31T00:00:00.000Z');

        expect(
          payload['platform'],
          isIn(acceptedWireValues),
          reason: '${platform.name} must serialize to an API-accepted value',
        );
      }
    });

    test('a universal draft is sent unchanged', () {
      final payload = const FeedbackDraft(
        title: 'Title',
        description: 'Description',
        platform: FeedbackPlatform.universal,
      ).toJson(appKey: 'app_test_123', submittedAt: '2026-10-31T00:00:00.000Z');

      expect(payload['platform'], 'universal');
      expect((payload['metadata'] as Map<String, dynamic>)['platform'],
          'universal');
    });

    test('a web draft round-trips through the client with a 200 response',
        () async {
      Map<String, dynamic>? capturedBody;

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'submissionId': 'sub_1', 'forwardedToGithub': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await client.submit(const FeedbackDraft(
        title: 'Broken on web',
        description: 'Description',
        platform: FeedbackPlatform.web,
      ));

      expect(capturedBody, isNotNull);
      expect(capturedBody!['platform'], 'universal');
    });
  });
}
