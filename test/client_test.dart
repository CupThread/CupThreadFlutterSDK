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

    group('changelog-seen durability', () {
      late TokenStorageAdapter originalSharedAdapter;

      setUp(() {
        originalSharedAdapter = UserTokenStore.shared.adapter;
      });

      tearDown(() {
        UserTokenStore.configure(originalSharedAdapter);
      });

      test('seen state survives client reconstruction through the shared configured adapter',
          () async {
        final durable = MemoryTokenStorage();
        UserTokenStore.configure(durable);

        final first = FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_durable_1',
          ),
        );
        await first.markChangelogSeen('1.2.0');
        expect(await first.hasSeenChangelog('1.2.0'), isTrue);

        // Simulates a process restart: a brand-new client with no storage
        // argument must still see the persisted state.
        final second = FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_durable_1',
          ),
        );
        expect(await second.hasSeenChangelog('1.2.0'), isTrue);
        expect(await second.hasSeenChangelog('1.3.0'), isFalse);
      });

      test('client constructed before UserTokenStore.configure persists through the configured adapter',
          () async {
        final durable = MemoryTokenStorage();
        final early = FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_durable_2',
          ),
        );

        UserTokenStore.configure(durable);
        await early.markChangelogSeen('2.0.0');

        expect(
          await durable.getItem('cupthread_seen_changelog_app_durable_2'),
          contains('2.0.0'),
        );
      });

      test('explicit storage override wins over the shared adapter', () async {
        final durable = MemoryTokenStorage();
        UserTokenStore.configure(durable);

        final override = MemoryTokenStorage();
        final client = FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_override',
          ),
          storage: override,
        );
        await client.markChangelogSeen('3.0.0');

        expect(
          await override.getItem('cupthread_seen_changelog_app_override'),
          contains('3.0.0'),
        );
        expect(
          await durable.getItem('cupthread_seen_changelog_app_override'),
          isNull,
        );
      });

      test('seen keys are scoped per appKey', () async {
        final durable = MemoryTokenStorage();
        UserTokenStore.configure(durable);

        final clientA = FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_aaa',
          ),
        );
        final clientB = FeedbackClient(
          FeedbackClientConfig(
            baseUrl: 'https://api.cupthread.com',
            appKey: 'app_bbb',
          ),
        );

        await clientA.markChangelogSeen('9.9.9');
        expect(await clientA.hasSeenChangelog('9.9.9'), isTrue);
        expect(await clientB.hasSeenChangelog('9.9.9'), isFalse);
      });
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
