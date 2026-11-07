import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #88: every list parser cast each element
/// unconditionally with `as Map<String, dynamic>`, so a single `null` or
/// non-object element anywhere in a server list response escaped as a raw
/// `TypeError` — outside `_sendJson`'s typed error mapping — instead of
/// being tolerated like the null-tolerant single-field parsers. One bad
/// element could take down the whole What's-New surface.
///
/// List parsing is now skip-and-tolerant: malformed elements (null,
/// strings, numbers) are dropped, well-formed neighbors survive, and page
/// containers (`hasMore` / `nextCursor` / `total`) stay intact so
/// pagination does not stall.
void main() {
  FeedbackClient clientWith(MockClient fn) => FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: fn,
      );

  http.Response jsonOk(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );

  group('issue #88 — fetchChangelogPage entries[]', () {
    test('skips null and non-object elements, keeps pagination metadata',
        () async {
      final client = clientWith(MockClient((request) async {
        expect(request.url.path,
            '/api/v1/public/apps/app_test_123/changelog');
        return jsonOk({
          'entries': [
            {'id': 'ch_1', 'title': 'First', 'body': 'A', 'publishedAt': '2026-01-01T00:00:00.000Z'},
            null,
            'junk',
            42,
            {'id': 'ch_2', 'title': 'Second', 'body': 'B', 'publishedAt': '2026-02-01T00:00:00.000Z'},
          ],
          'hasMore': true,
          'nextCursor': 'cur_next',
        });
      }));

      final page = await client.fetchChangelogPage();

      expect(page.entries.map((e) => e.id), ['ch_1', 'ch_2']);
      expect(page.hasMore, isTrue,
          reason: 'pagination metadata must survive malformed elements');
      expect(page.nextCursor, 'cur_next',
          reason: 'pagination must not stall on a bad element');
    });

    test('an all-malformed list yields an empty page without throwing',
        () async {
      final client = clientWith(MockClient((request) async {
        return jsonOk({
          'entries': [null, 7, 'oops'],
          'hasMore': false,
        });
      }));

      final page = await client.fetchChangelogPage();

      expect(page.entries, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('parses a well-formed page unchanged', () async {
      final client = clientWith(MockClient((request) async {
        return jsonOk({
          'entries': [
            {
              'id': 'ch_1',
              'title': 'Only',
              'body': 'Body',
              'publishedAt': '2026-01-01T00:00:00.000Z',
              'linkedRequests': [
                {'id': 'fr_1', 'title': 'Dark mode'},
                null,
                'junk',
              ],
            },
          ],
          'hasMore': false,
        });
      }));

      final page = await client.fetchChangelogPage();

      expect(page.entries, hasLength(1));
      expect(page.entries.single.id, 'ch_1');
      expect(
        page.entries.single.linkedRequests.map((r) => r.id),
        ['fr_1'],
        reason: 'nested linkedRequests[] must also skip malformed elements',
      );
    });
  });

  group('issue #88 — fetchFeatureRequests requests[]', () {
    test('skips null and non-object elements, keeps server total', () async {
      final client = clientWith(MockClient((request) async {
        expect(request.url.path, '/api/v1/feature-requests');
        return jsonOk({
          'requests': [
            {'id': 'fr_1', 'title': 'Dark mode'},
            null,
            'junk',
            {'id': 'fr_2', 'title': 'Offline sync'},
          ],
          'total': 4,
        });
      }));

      final result = await client.fetchFeatureRequests(userToken: 'tok');

      expect(result.requests.map((r) => r.id), ['fr_1', 'fr_2']);
      expect(result.total, 4,
          reason: 'the server-provided total is preserved untouched');
    });

    test('skips malformed elements inside nested recentCommenters[]',
        () async {
      final client = clientWith(MockClient((request) async {
        return jsonOk({
          'requests': [
            {
              'id': 'fr_1',
              'title': 'Dark mode',
              'recentCommenters': [
                {'authorName': 'Ada', 'clerkUserId': 'u_1'},
                null,
                123,
                {'authorName': 'Grace', 'clerkUserId': 'u_2'},
              ],
            },
          ],
          'total': 1,
        });
      }));

      final result = await client.fetchFeatureRequests(userToken: 'tok');

      final request = result.requests.single;
      expect(request.recentCommenters.map((c) => c.authorName),
          ['Ada', 'Grace']);
    });
  });

  group('issue #88 — fetchCommentsPage comments[]', () {
    test('skips null and non-object elements, keeps pagination metadata',
        () async {
      final client = clientWith(MockClient((request) async {
        expect(request.url.path,
            '/api/v1/feature-requests/fr_1/comments');
        return jsonOk({
          'comments': [
            {'id': 'cm_1', 'body': 'Hello'},
            null,
            'junk',
            {'id': 'cm_2', 'body': 'World'},
          ],
          'total': 2,
          'hasMore': true,
          'nextCursor': 'cur_2',
        });
      }));

      final page = await client.fetchCommentsPage('fr_1');

      expect(page.comments.map((c) => c.id), ['cm_1', 'cm_2']);
      expect(page.total, 2);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'cur_2');
    });
  });

  group('issue #88 — fetchColumns columns[]', () {
    test('skips null and non-object elements, still sorts by position',
        () async {
      final client = clientWith(MockClient((request) async {
        expect(request.url.path, '/api/v1/public/columns/app_test_123');
        return jsonOk({
          'columns': [
            {'id': 'col_2', 'name': 'In Progress', 'position': 2},
            null,
            'junk',
            {'id': 'col_1', 'name': 'Backlog', 'position': 1},
          ],
        });
      }));

      final columns = await client.fetchColumns();

      expect(columns.map((c) => c.id), ['col_1', 'col_2'],
          reason: 'surviving columns keep their position sort');
    });
  });

  group('issue #88 — fetchVersions versions[]', () {
    test('skips null and non-object elements, still sorts by position',
        () async {
      final client = clientWith(MockClient((request) async {
        expect(request.url.path, '/api/v1/public/versions/app_test_123');
        return jsonOk({
          'versions': [
            {'id': 'v_2', 'label': '2.0.0', 'position': 2},
            null,
            'junk',
            {'id': 'v_1', 'label': '1.0.0', 'position': 1},
          ],
        });
      }));

      final versions = await client.fetchVersions();

      expect(versions.map((v) => v.id), ['v_1', 'v_2'],
          reason: 'surviving versions keep their position sort');
    });
  });

  group('issue #88 — fetchUserProfile publicApps[] / recentComments[]', () {
    test('skips null and non-object elements in both lists', () async {
      final client = clientWith(MockClient((request) async {
        expect(request.url.path, '/api/v1/users/u_1/profile');
        return jsonOk({
          'profile': {'clerkUserId': 'u_1', 'displayName': 'Ada'},
          'publicApps': [
            {'id': 'app_1', 'name': 'My App'},
            null,
            'junk',
          ],
          'recentComments': [
            null,
            'junk',
            {'id': 'cm_1', 'body': 'Would love this!'},
          ],
        });
      }));

      final result = await client.fetchUserProfile('u_1');

      expect(result.profile.clerkUserId, 'u_1');
      expect(result.publicApps.map((a) => a.id), ['app_1']);
      expect(result.recentComments.map((c) => c.id), ['cm_1']);
    });
  });
}
