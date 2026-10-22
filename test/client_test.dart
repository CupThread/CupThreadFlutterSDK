import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  group('FeedbackClient', () {
    test('normalizes baseUrl and config', () {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com///',
          appKey: 'app_test_123',
          defaultPlatform: FeedbackPlatform.android,
        ),
      );

      expect(client.config.baseUrl, 'https://api.cupthread.com');
      expect(client.config.appKey, 'app_test_123');
      expect(client.config.defaultPlatform, FeedbackPlatform.android);
    });

    test('tracks and checks seen changelog versions', () async {
      final storage = MemoryTokenStorage();
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        storage: storage,
      );

      expect(await client.hasSeenChangelog('1.0.0'), isFalse);
      expect(await client.hasSeenChangelog('1.1.0'), isFalse);

      await client.markChangelogSeen('1.0.0');
      expect(await client.hasSeenChangelog('1.0.0'), isTrue);
      expect(await client.hasSeenChangelog('1.1.0'), isFalse);

      await client.markChangelogSeen('1.1.0');
      expect(await client.hasSeenChangelog('1.0.0'), isTrue);
      expect(await client.hasSeenChangelog('1.1.0'), isTrue);
    });

    test('castVote sends POST /api/v1/feature-requests/:id/vote with body and X-User-Token header', () async {
      String? capturedMethod;
      String? capturedPath;
      String? capturedTokenHeader;
      Map<String, dynamic>? capturedBody;

      final mockHttpClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedPath = request.url.path;
        capturedTokenHeader = request.headers['X-User-Token'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'voted': true, 'voteCount': 42}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      final result = await client.castVote(
        'fr_abc',
        userToken: 'tok_user_1',
        shipNotifyEmail: '  dev@example.com  ',
      );

      expect(capturedMethod, 'POST');
      expect(capturedPath, '/api/v1/feature-requests/fr_abc/vote');
      expect(capturedTokenHeader, 'tok_user_1');
      expect(capturedBody, {
        'appKey': 'app_test_123',
        'userToken': 'tok_user_1',
        'shipNotifyEmail': 'dev@example.com',
      });
      expect(result.voted, isTrue);
      expect(result.voteCount, 42);
    });

    test('removeVote sends DELETE /api/v1/feature-requests/:id/vote with JSON body and X-User-Token header', () async {
      String? capturedMethod;
      String? capturedPath;
      String? capturedTokenHeader;
      Map<String, dynamic>? capturedBody;

      final mockHttpClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedPath = request.url.path;
        capturedTokenHeader = request.headers['X-User-Token'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'voted': false, 'voteCount': 41}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      final result = await client.removeVote(
        'fr_abc',
        userToken: 'tok_user_1',
      );

      expect(capturedMethod, 'DELETE');
      expect(capturedPath, '/api/v1/feature-requests/fr_abc/vote');
      expect(capturedTokenHeader, 'tok_user_1');
      expect(capturedBody, {
        'appKey': 'app_test_123',
        'userToken': 'tok_user_1',
      });
      expect(result.voted, isFalse);
      expect(result.voteCount, 41);
    });

    test('toggleVote delegates to castVote as a compatibility wrapper', () async {
      final methods = <String>[];

      final mockHttpClient = MockClient((request) async {
        methods.add(request.method);
        return http.Response(
          jsonEncode({'voted': true, 'voteCount': 10}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: mockHttpClient,
      );

      // ignore: deprecated_member_use_from_same_package
      final first = await client.toggleVote('fr_abc', userToken: 'tok_user_1');
      // ignore: deprecated_member_use_from_same_package
      final second = await client.toggleVote('fr_abc', userToken: 'tok_user_1');

      expect(methods, ['POST', 'POST']);
      expect(first.voted, isTrue);
      expect(second.voted, isTrue);
    });
  });
}
