import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Builds a minimal feature-request JSON record.
Map<String, dynamic> frItem(
  int i, {
  int voteCount = 0,
  bool hasVoted = false,
  String? columnId,
}) {
  return {
    'id': 'fr_$i',
    'title': 'Request $i',
    'description': 'Description number $i',
    'voteCount': voteCount,
    'hasVoted': hasVoted,
    if (columnId != null) 'columnId': columnId,
  };
}

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

FeedbackClient buildClient(http.Client httpClient) => FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      httpClient: httpClient,
    );

Widget wrap(Widget child, FeedbackClient client) => MaterialApp(
      home: CupThreadTheme(
        client: client,
        userToken: 'user_token_abc',
        child: child,
      ),
    );

/// Pumps enough frames for the config fetch + initial list load to finish
/// without using pumpAndSettle (indeterminate spinners never settle).
Future<void> pumpInitialLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('formatRelativeDate clock skew handling', () {
    String absolute(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    test('null and empty input return empty string', () {
      expect(formatRelativeDate(null), '');
      expect(formatRelativeDate(''), '');
    });

    test('recent past timestamps render relative labels', () {
      final now = DateTime.now().toUtc();
      expect(
        formatRelativeDate(
            now.subtract(const Duration(seconds: 30)).toIso8601String()),
        'Just now',
      );
      expect(
        formatRelativeDate(
            now.subtract(const Duration(minutes: 5)).toIso8601String()),
        '5m ago',
      );
      expect(
        formatRelativeDate(
            now.subtract(const Duration(hours: 3)).toIso8601String()),
        '3h ago',
      );
      expect(
        formatRelativeDate(
            now.subtract(const Duration(days: 3)).toIso8601String()),
        '3d ago',
      );
    });

    test('a timestamp 5 minutes in the future does not render as "Just now"',
        () {
      final future = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final out = formatRelativeDate(future.toIso8601String());
      expect(out, isNot('Just now'));
      expect(out, absolute(future));
    });

    test('a timestamp a day in the future renders the absolute date', () {
      final future =
          DateTime.now().toUtc().add(const Duration(days: 1, hours: 2));
      expect(formatRelativeDate(future.toIso8601String()), absolute(future));
    });

    test('far past timestamps render the absolute date', () {
      final past = DateTime.now().toUtc().subtract(const Duration(days: 30));
      expect(formatRelativeDate(past.toIso8601String()), absolute(past));
    });
  });

  group('FeatureRequestsScreen error, pagination, debounce, vote locking', () {
    testWidgets(
        'network failure shows error state with Retry, not the empty-list copy',
        (tester) async {
      var failRequests = true;
      final client = buildClient(MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          if (failRequests) {
            return jsonResponse({'error': 'boom'}, 500);
          }
          return jsonResponse({
            'requests': [frItem(0), frItem(1)],
            'total': 2,
          });
        }
        if (request.url.path.contains('/versions')) {
          return jsonResponse({'versions': []});
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const FeatureRequestsScreen(), client));
      await pumpInitialLoad(tester);

      expect(find.text('Failed to load requests'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No feature requests found'), findsNothing);

      failRequests = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Failed to load requests'), findsNothing);
      expect(find.text('Request 0'), findsOneWidget);
      expect(find.text('Request 1'), findsOneWidget);
    });

    testWidgets(
        'Load more fetches the next page with offset until total is reached',
        (tester) async {
      final offsets = <String>[];
      final client = buildClient(MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          final offset = request.url.queryParameters['offset'] ?? '0';
          offsets.add(offset);
          if (offset == '0') {
            return jsonResponse({
              'requests': [frItem(0), frItem(1)],
              'total': 5
            });
          }
          return jsonResponse({
            'requests': [frItem(2), frItem(3), frItem(4)],
            'total': 5,
          });
        }
        if (request.url.path.contains('/versions')) {
          return jsonResponse({'versions': []});
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const FeatureRequestsScreen(), client));
      await pumpInitialLoad(tester);

      expect(offsets, ['0']);
      expect(find.text('Load more'), findsOneWidget);
      expect(find.text('Request 0'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(offsets, ['0', '2']);
      // 5 of 5 loaded, so the Load more affordance disappears.
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets(
        'search input is debounced: rapid edits issue a single query per window',
        (tester) async {
      final searchQueries = <String?>[];
      final client = buildClient(MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          searchQueries.add(request.url.queryParameters['q']);
          return jsonResponse(
              {'requests': <Map<String, dynamic>>[], 'total': 0});
        }
        if (request.url.path.contains('/versions')) {
          return jsonResponse({'versions': []});
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const FeatureRequestsScreen(), client));
      await pumpInitialLoad(tester);
      expect(searchQueries, [null]); // initial load only

      // Type two edits quickly, inside the same debounce window.
      await tester.enterText(find.byType(TextField), 'csv');
      await tester.pump(const Duration(milliseconds: 150));
      expect(searchQueries, [null]); // debounce still pending

      await tester.enterText(find.byType(TextField), 'csv export');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(searchQueries, [null, 'csv export']);
    });

    testWidgets(
        'double-tapping vote fires a single cast until the first call completes',
        (tester) async {
      var votePosts = 0;
      final voteGate = Completer<void>();
      final client = buildClient(MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests/fr_0/vote' &&
            request.method == 'POST') {
          votePosts++;
          await voteGate.future;
          return jsonResponse({'voted': true, 'voteCount': 7});
        }
        if (request.url.path == '/api/v1/feature-requests') {
          return jsonResponse({
            'requests': [frItem(0, voteCount: 3)],
            'total': 1,
          });
        }
        if (request.url.path.contains('/versions')) {
          return jsonResponse({'versions': []});
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const FeatureRequestsScreen(), client));
      await pumpInitialLoad(tester);
      expect(find.text('3'), findsOneWidget);

      // Rapid double tap with no frame in between: the second tap must be
      // ignored while the first request is still in flight.
      await tester.tap(find.byType(VoteButton));
      await tester.tap(find.byType(VoteButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(votePosts, 1);

      voteGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(votePosts, 1); // second tap never fired another request
      // Server-confirmed count (7) replaced the optimistic value.
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets(
        'a stale Load more response is discarded after a newer refresh applied',
        (tester) async {
      final loadMoreGate = Completer<void>();
      final refreshGate = Completer<void>();
      final client = buildClient(MockClient((request) async {
        if (request.url.path == '/api/v1/feature-requests') {
          final q = request.url.queryParameters['q'];
          final offset = request.url.queryParameters['offset'] ?? '0';
          if (q == null && offset == '0') {
            // Initial load: page 1 with more pages available.
            return jsonResponse({
              'requests': [frItem(0), frItem(1)],
              'total': 5,
            });
          }
          if (q == null) {
            // Stale Load more response, released after the refresh lands.
            await loadMoreGate.future;
            return jsonResponse({
              'requests': [frItem(2)],
              'total': 5,
            });
          }
          // Search-triggered refresh, released before the stale append.
          await refreshGate.future;
          return jsonResponse({
            'requests': [frItem(10)],
            'total': 1,
          });
        }
        if (request.url.path.contains('/versions')) {
          return jsonResponse({'versions': []});
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const FeatureRequestsScreen(), client));
      await pumpInitialLoad(tester);
      expect(find.text('Load more'), findsOneWidget);

      // Start a Load more and hold its response.
      await tester.tap(find.text('Load more'));
      await tester.pump();

      // Then trigger a fresh search refresh and hold its response too.
      await tester.enterText(find.byType(TextField), 'csv');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      // The refresh lands first and replaces the list…
      refreshGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Request 10'), findsOneWidget);

      // …then the stale page-2 response arrives; it must be discarded
      // instead of appending old-filter items to the refreshed list.
      loadMoreGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Request 2'), findsNothing);
      expect(find.text('Request 10'), findsOneWidget);
    });
  });

  group('RoadmapBoardScreen error state and pagination', () {
    Map<String, dynamic> columnJson() => {
          'id': 'col_1',
          'appId': 'app_test_123',
          'name': 'Planned',
          'slug': 'planned',
          'position': 1,
          'isVisible': true,
        };

    testWidgets(
        'network failure shows error state with Retry instead of empty board',
        (tester) async {
      var failLoad = true;
      final client = buildClient(MockClient((request) async {
        if (request.url.path.contains('/public/columns/')) {
          if (failLoad) return jsonResponse({'error': 'boom'}, 500);
          return jsonResponse({
            'columns': [columnJson()]
          });
        }
        if (request.url.path == '/api/v1/feature-requests') {
          return jsonResponse({
            'requests': [frItem(0, columnId: 'col_1')],
            'total': 1,
          });
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const RoadmapBoardScreen(), client));
      await pumpInitialLoad(tester);

      expect(find.text('Failed to load requests'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No items in this column'), findsNothing);

      failLoad = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Failed to load requests'), findsNothing);
      expect(find.text('Request 0'), findsOneWidget);
    });

    testWidgets(
        'Load more fetches board pages with offset until total is reached',
        (tester) async {
      final offsets = <String>[];
      final client = buildClient(MockClient((request) async {
        if (request.url.path.contains('/public/columns/')) {
          return jsonResponse({
            'columns': [columnJson()]
          });
        }
        if (request.url.path == '/api/v1/feature-requests') {
          final offset = request.url.queryParameters['offset'] ?? '0';
          offsets.add(offset);
          if (offset == '0') {
            return jsonResponse({
              'requests': [frItem(0, columnId: 'col_1')],
              'total': 2,
            });
          }
          return jsonResponse({
            'requests': [frItem(1, columnId: 'col_1')],
            'total': 2,
          });
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const RoadmapBoardScreen(), client));
      await pumpInitialLoad(tester);

      expect(offsets, ['0']);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(offsets, ['0', '1']);
      expect(find.text('Load more'), findsNothing);
      expect(find.text('Request 1'), findsOneWidget);
    });

    testWidgets(
        'a column with no items on the current page offers Load more instead of the empty copy',
        (tester) async {
      final offsets = <String>[];
      final client = buildClient(MockClient((request) async {
        if (request.url.path.contains('/public/columns/')) {
          return jsonResponse({
            'columns': [columnJson()]
          });
        }
        if (request.url.path == '/api/v1/feature-requests') {
          final offset = request.url.queryParameters['offset'] ?? '0';
          offsets.add(offset);
          if (offset == '0') {
            // Page 1 only contains an item from a different column.
            return jsonResponse({
              'requests': [frItem(0, columnId: 'col_other')],
              'total': 2,
            });
          }
          return jsonResponse({
            'requests': [frItem(1, columnId: 'col_1')],
            'total': 2,
          });
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const RoadmapBoardScreen(), client));
      await pumpInitialLoad(tester);

      // The selected column is empty on this page, but more pages exist:
      // the Load more row must stay reachable, not hidden behind the
      // "No items in this column" placeholder.
      expect(find.text('No items in this column'), findsNothing);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(offsets, ['0', '1']);
      expect(find.text('Request 1'), findsOneWidget);
      expect(find.text('No items in this column'), findsNothing);
    });

    testWidgets(
        'a stale board page response is discarded when a pull-to-refresh reload applied',
        (tester) async {
      final loadMoreGate = Completer<void>();
      final refreshGate = Completer<void>();
      var dataLoads = 0;
      final client = buildClient(MockClient((request) async {
        if (request.url.path.contains('/public/columns/')) {
          return jsonResponse({
            'columns': [columnJson()]
          });
        }
        if (request.url.path == '/api/v1/feature-requests') {
          final offset = request.url.queryParameters['offset'] ?? '0';
          if (offset != '0') {
            // Stale Load more page, released after the refresh lands.
            await loadMoreGate.future;
            return jsonResponse({
              'requests': [frItem(1, columnId: 'col_1')],
              'total': 2,
            });
          }
          dataLoads++;
          if (dataLoads == 1) {
            return jsonResponse({
              'requests': [frItem(0, columnId: 'col_1')],
              'total': 2,
            });
          }
          // Pull-to-refresh reload, released before the stale page.
          await refreshGate.future;
          return jsonResponse({
            'requests': [frItem(5, columnId: 'col_1')],
            'total': 1,
          });
        }
        if (request.url.path.contains('/public/config/')) {
          return jsonResponse({});
        }
        return jsonResponse({'error': 'not found'}, 404);
      }));

      await tester.pumpWidget(wrap(const RoadmapBoardScreen(), client));
      await pumpInitialLoad(tester);
      expect(find.text('Load more'), findsOneWidget);

      // Start a Load more and hold its response.
      await tester.tap(find.text('Load more'));
      await tester.pump();

      // Pull to refresh and hold the reload response too.
      final cardsList = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      );
      await tester.fling(cardsList, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The reload lands first and replaces the board…
      refreshGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Request 5'), findsOneWidget);

      // …then the stale page-2 response arrives and must be discarded
      // instead of appending pre-refresh items and reviving the old total.
      loadMoreGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Request 1'), findsNothing);
      expect(find.text('Request 5'), findsOneWidget);
    });
  });
}
