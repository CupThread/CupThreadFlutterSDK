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

    test('fetchChangelogPage sends limit/cursor params and parses hasMore/nextCursor', () async {
      final capturedUrls = <Uri>[];

      final mockHttpClient = MockClient((request) async {
        capturedUrls.add(request.url);
        return http.Response(
          jsonEncode({
            'entries': [
              {
                'id': 'cl_1',
                'title': 'v1.2.0 Release',
                'body': 'Highlights',
                'versionLabel': '1.2.0',
                'publishedAt': '2026-09-18T12:00:00.000Z',
              }
            ],
            'hasMore': true,
            'nextCursor': 'MjAyNi0w',
          }),
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

      final page = await client.fetchChangelogPage(limit: 50, cursor: 'abc');

      expect(capturedUrls, hasLength(1));
      expect(capturedUrls.single.path, '/api/v1/public/apps/app_test_123/changelog');
      expect(capturedUrls.single.queryParameters['limit'], '50');
      expect(capturedUrls.single.queryParameters['cursor'], 'abc');
      expect(page.entries, hasLength(1));
      expect(page.entries.single.id, 'cl_1');
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'MjAyNi0w');
    });

    test('fetchChangelogPage clamps limit to the documented 1..100 range', () async {
      final capturedUrls = <Uri>[];

      final mockHttpClient = MockClient((request) async {
        capturedUrls.add(request.url);
        return http.Response(
          jsonEncode({'entries': [], 'hasMore': false, 'nextCursor': null}),
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

      await client.fetchChangelogPage(limit: 500);
      await client.fetchChangelogPage(limit: 0);

      expect(capturedUrls[0].queryParameters['limit'], '100');
      expect(capturedUrls[1].queryParameters['limit'], '1');
    });

    test('fetchChangelog follows all pages, merges and sorts newest first', () async {
      final cursorsSeen = <String?>[];
      final newEntries = List.generate(
        2,
        (i) => {
          'id': 'cl_new_$i',
          'title': 'New $i',
          'body': 'Body',
          'publishedAt': '2026-10-0${i + 1}T00:00:00.000Z',
        },
      );
      final oldEntries = List.generate(
        2,
        (i) => {
          'id': 'cl_old_$i',
          'title': 'Old $i',
          'body': 'Body',
          'publishedAt': '2026-01-0${i + 1}T00:00:00.000Z',
        },
      );

      final mockHttpClient = MockClient((request) async {
        final cursor = request.url.queryParameters['cursor'];
        cursorsSeen.add(cursor);
        if (cursor == null) {
          return http.Response(
            jsonEncode({'entries': newEntries, 'hasMore': true, 'nextCursor': 'page-2'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'entries': oldEntries, 'hasMore': false, 'nextCursor': null}),
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

      final entries = await client.fetchChangelog();

      expect(cursorsSeen, [null, 'page-2']);
      expect(entries, hasLength(4));
      expect(
        entries.map((e) => e.id).toList(),
        ['cl_new_1', 'cl_new_0', 'cl_old_1', 'cl_old_0'],
      );
    });

    test('fetchChangelog stays compatible with a legacy single-page response', () async {
      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'entries': [
              {
                'id': 'cl_only',
                'title': 'Only page',
                'body': 'Body',
                'publishedAt': '2026-05-01T00:00:00.000Z',
              }
            ],
          }),
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

      final entries = await client.fetchChangelog();

      expect(requestCount, 1);
      expect(entries, hasLength(1));
      expect(entries.single.id, 'cl_only');
    });

    test('fetchChangelog stops early on a server that never advances its cursor', () async {
      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'entries': [
              {
                'id': 'cl_$requestCount',
                'title': 'Entry $requestCount',
                'body': 'Body',
                'publishedAt': '2026-05-01T00:00:00.000Z',
              }
            ],
            'hasMore': true,
            'nextCursor': 'same-cursor',
          }),
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

      final entries = await client.fetchChangelog();

      // The repeated page is dropped, so no duplicate entries are appended.
      expect(requestCount, 2);
      expect(entries, hasLength(1));
      expect(entries.single.id, 'cl_1');
    });

    test('fetchChangelog stops on hasMore=true with a null nextCursor', () async {
      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'entries': [
              {
                'id': 'cl_$requestCount',
                'title': 'Entry $requestCount',
                'body': 'Body',
                'publishedAt': '2026-05-01T00:00:00.000Z',
              }
            ],
            'hasMore': true,
            'nextCursor': null,
          }),
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

      final entries = await client.fetchChangelog();

      expect(requestCount, 1);
      expect(entries, hasLength(1));
    });

    Map<String, dynamic> commentJson(String id) => {
          'id': id,
          'featureRequestId': 'fr_abc',
          'authorName': 'User $id',
          'body': 'Body of $id',
          'createdAt': '2026-05-01T00:00:00.000Z',
        };

    test('fetchCommentsPage sends limit/cursor params and parses total/hasMore/nextCursor', () async {
      final capturedUrls = <Uri>[];

      final mockHttpClient = MockClient((request) async {
        capturedUrls.add(request.url);
        return http.Response(
          jsonEncode({
            'comments': [commentJson('cm_1')],
            'total': 340,
            'hasMore': true,
            'nextCursor': 'next-page',
          }),
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

      final page = await client.fetchCommentsPage('fr_abc', limit: 100, cursor: 'cur-1');

      expect(capturedUrls, hasLength(1));
      expect(capturedUrls.single.path, '/api/v1/feature-requests/fr_abc/comments');
      expect(capturedUrls.single.queryParameters['limit'], '100');
      expect(capturedUrls.single.queryParameters['cursor'], 'cur-1');
      expect(page.comments, hasLength(1));
      expect(page.comments.single.id, 'cm_1');
      expect(page.total, 340);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'next-page');
    });

    test('fetchCommentsPage clamps limit to the documented 1..200 range', () async {
      final capturedUrls = <Uri>[];

      final mockHttpClient = MockClient((request) async {
        capturedUrls.add(request.url);
        return http.Response(
          jsonEncode({'comments': [], 'total': 0, 'hasMore': false, 'nextCursor': null}),
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

      await client.fetchCommentsPage('fr_abc', limit: 500);
      await client.fetchCommentsPage('fr_abc', limit: 0);

      expect(capturedUrls[0].queryParameters['limit'], '200');
      expect(capturedUrls[1].queryParameters['limit'], '1');
    });

    test('fetchComments follows all pages and concatenates them in server order', () async {
      final cursorsSeen = <String?>[];

      final mockHttpClient = MockClient((request) async {
        final cursor = request.url.queryParameters['cursor'];
        cursorsSeen.add(cursor);
        if (cursor == null) {
          return http.Response(
            jsonEncode({
              'comments': [commentJson('cm_1'), commentJson('cm_2')],
              'total': 3,
              'hasMore': true,
              'nextCursor': 'page-2',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'comments': [commentJson('cm_3')],
            'total': 3,
            'hasMore': false,
            'nextCursor': null,
          }),
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

      final comments = await client.fetchComments('fr_abc');

      expect(cursorsSeen, [null, 'page-2']);
      expect(comments.map((c) => c.id).toList(), ['cm_1', 'cm_2', 'cm_3']);
    });

    test('fetchComments stays compatible with a legacy single-page response', () async {
      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'comments': [commentJson('cm_only')],
          }),
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

      final comments = await client.fetchComments('fr_abc');

      expect(requestCount, 1);
      expect(comments, hasLength(1));
      expect(comments.single.id, 'cm_only');
    });

    test('fetchComments stops early on a server that repeats the same nextCursor', () async {
      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'comments': [commentJson('cm_$requestCount')],
            'total': 99,
            'hasMore': true,
            'nextCursor': 'same-cursor',
          }),
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

      final comments = await client.fetchComments('fr_abc');

      // The repeated page is dropped, so no duplicate comments are appended.
      expect(requestCount, 2);
      expect(comments, hasLength(1));
      expect(comments.single.id, 'cm_1');
    });

    test('fetchComments stops early on a server that revisits an earlier cursor', () async {
      final mockHttpClient = MockClient((request) async {
        final cursor = request.url.queryParameters['cursor'];
        // An alternating cursor cycle: null → b → a → b → a → …
        final next = cursor == 'a' ? 'b' : 'a';
        return http.Response(
          jsonEncode({
            'comments': [commentJson('cm_${cursor ?? 'first'}')],
            'total': 99,
            'hasMore': true,
            'nextCursor': next,
          }),
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

      final comments = await client.fetchComments('fr_abc');

      // Requests: first page, then 'a', then 'b' whose next cursor 'a' was
      // already visited — the loop stops there and drops that final page.
      expect(comments.map((c) => c.id).toList(), ['cm_first', 'cm_a']);
    });

    test('fetchComments stops on hasMore=true with a null nextCursor', () async {
      var requestCount = 0;

      final mockHttpClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'comments': [commentJson('cm_$requestCount')],
            'total': 99,
            'hasMore': true,
            'nextCursor': null,
          }),
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

      final comments = await client.fetchComments('fr_abc');

      expect(requestCount, 1);
      expect(comments, hasLength(1));
    });
  });
}
