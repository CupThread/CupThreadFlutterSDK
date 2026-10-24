import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Empty remote changelog copy forces the overlay to fall back to
/// [CupThreadStrings] for its title and primary button.
const _emptyChangelogCopyConfig = '{"sdk":{"changelogOverlay":{"title":"","primaryButton":""}}}';

FeedbackClient _mockClient({String configJson = '{}'}) {
  return FeedbackClient(
    FeedbackClientConfig(
      baseUrl: 'https://api.cupthread.com',
      appKey: 'app_test_123',
    ),
    httpClient: MockClient((request) async {
      if (request.url.path.contains('/public/config/')) {
        return http.Response(configJson, 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path.endsWith('/changelog')) {
        return http.Response(
          jsonEncode({
            'entries': [
              {
                'id': 'cl_1',
                'title': 'Release 2.0.0',
                'body': 'Big updates in this release',
                'publishedAt': '2026-09-01T12:00:00Z',
                'versionLabel': '2.0.0',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/comments')) {
        return http.Response(jsonEncode({'comments': []}), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    }),
  );
}

Widget _hostWithOverrides({
  required FeedbackClient client,
  SdkTheme? theme,
  CupThreadStrings? strings,
  Locale? locale,
  required void Function(BuildContext) open,
}) {
  return MaterialApp(
    home: CupThreadTheme(
      client: client,
      theme: theme,
      strings: strings,
      locale: locale,
      child: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => open(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Color _sheetDecorationColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  group('modal sheets carry host CupThreadTheme overrides', () {
    testWidgets('FeedbackComposer.showModal renders zhHans strings and midnight colors',
        (tester) async {
      final client = _mockClient();
      await tester.pumpWidget(_hostWithOverrides(
        client: client,
        theme: SdkTheme.midnight,
        strings: CupThreadStrings.zhHans,
        open: (ctx) => FeedbackComposer.showModal(ctx),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('问题与反馈'), findsOneWidget);
      expect(_sheetDecorationColor(tester), CupThreadColors.midnight.background);
    });

    testWidgets('FeatureRequestComposeSheet.show renders zhHans strings and midnight colors',
        (tester) async {
      final client = _mockClient();
      await tester.pumpWidget(_hostWithOverrides(
        client: client,
        theme: SdkTheme.midnight,
        strings: CupThreadStrings.zhHans,
        open: (ctx) => FeatureRequestComposeSheet.show(ctx),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('标题 *'), findsOneWidget);
      expect(find.text('提交建议'), findsOneWidget);
      expect(_sheetDecorationColor(tester), CupThreadColors.midnight.background);
    });

    testWidgets('FeatureRequestDetailSheet.show renders zhHans strings and midnight colors',
        (tester) async {
      const item = FeatureRequestItem(
        id: 'fr_1',
        appId: 'app_1',
        title: 'Dark mode support',
        description: 'Please add dark mode',
        status: 'open',
        approved: true,
        voteCount: 3,
        hasVoted: false,
        isOwnRequest: false,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-02T00:00:00Z',
      );

      final client = _mockClient();
      await tester.pumpWidget(_hostWithOverrides(
        client: client,
        theme: SdkTheme.midnight,
        strings: CupThreadStrings.zhHans,
        open: (ctx) => FeatureRequestDetailSheet.show(ctx, item: item),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('功能建议'), findsOneWidget);
      expect(find.text('讨论 (0)'), findsOneWidget);
      expect(_sheetDecorationColor(tester), CupThreadColors.midnight.background);
    });

    testWidgets('ChangelogOverlay.show renders zhHans strings and midnight colors',
        (tester) async {
      final client = _mockClient(configJson: _emptyChangelogCopyConfig);
      await tester.pumpWidget(_hostWithOverrides(
        client: client,
        theme: SdkTheme.midnight,
        strings: CupThreadStrings.zhHans,
        open: (ctx) => ChangelogOverlay.show(ctx),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('新版特性'), findsOneWidget);
      expect(find.text('我知道了'), findsOneWidget);
      expect(find.text('Release 2.0.0'), findsOneWidget);
      expect(_sheetDecorationColor(tester), CupThreadColors.midnight.card);

      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
    });
  });

  group('CupThreadTheme.carryScope', () {
    testWidgets('forwards theme, strings, locale and session into the carried scope',
        (tester) async {
      final client = _mockClient();
      BuildContext? carried;
      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            userToken: 'tok_123',
            theme: SdkTheme.midnight,
            strings: CupThreadStrings.zhHans,
            locale: const Locale('zh'),
            child: Builder(
              builder: (ctx) => CupThreadTheme.carryScope(
                ctx,
                child: Builder(
                  builder: (inner) {
                    carried = inner;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(CupThreadTheme.stringsOf(carried!), same(CupThreadStrings.zhHans));
      expect(CupThreadTheme.themeOf(carried!), SdkTheme.midnight);
      expect(CupThreadTheme.localeOf(carried!), const Locale('zh'));
      expect(CupThreadTheme.clientOf(carried!), same(client));
      expect(CupThreadTheme.userTokenOf(carried!), 'tok_123');
      expect(CupThreadTheme.isAnonymous(carried!), isFalse);
      expect(CupThreadTheme.failClosedOf(carried!), isTrue);
    });

    testWidgets('preserves anonymous sessions inside carried scopes', (tester) async {
      final client = _mockClient();
      BuildContext? carried;
      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            child: Builder(
              builder: (ctx) => CupThreadTheme.carryScope(
                ctx,
                child: Builder(
                  builder: (inner) {
                    carried = inner;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(CupThreadTheme.isAnonymous(carried!), isTrue);
    });

    testWidgets('returns the child unchanged when no scope is present', (tester) async {
      const probeChild = SizedBox(key: ValueKey('carry-scope-probe'));
      Widget? carried;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              carried = CupThreadTheme.carryScope(ctx, child: probeChild);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(carried, probeChild), isTrue);
    });

    testWidgets('applies a remote theme fetched after capture when host set no override',
        (tester) async {
      final configGate = Completer<void>();
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/public/config/')) {
            await configGate.future;
            return http.Response('{"sdk":{"theme":"midnight"}}', 200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('{}', 200, headers: {'content-type': 'application/json'});
        }),
      );
      BuildContext? carried;
      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            failClosed: false,
            child: Builder(
              builder: (ctx) => CupThreadTheme.carryScope(
                ctx,
                child: Builder(
                  builder: (inner) {
                    carried = inner;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // The scope was captured while config was still loading; the carried
      // scope must re-resolve and pick up the remote midnight theme instead
      // of freezing on the pre-config system default.
      configGate.complete();
      await tester.pumpAndSettle();

      expect(CupThreadTheme.themeOf(carried!), SdkTheme.midnight);
    });

    testWidgets('host theme override wins over the fetched config theme',
        (tester) async {
      final client = _mockClient(configJson: '{"sdk":{"theme":"midnight"}}');
      BuildContext? carried;
      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            theme: SdkTheme.light,
            child: Builder(
              builder: (ctx) => CupThreadTheme.carryScope(
                ctx,
                child: Builder(
                  builder: (inner) {
                    carried = inner;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(CupThreadTheme.themeOf(carried!), SdkTheme.light);
    });
  });

  group('modal sheets without host overrides', () {
    testWidgets('fall back to English strings and system (light) colors', (tester) async {
      final client = _mockClient();
      await tester.pumpWidget(_hostWithOverrides(
        client: client,
        open: (ctx) => FeedbackComposer.showModal(ctx),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Send Feedback'), findsOneWidget);
      expect(_sheetDecorationColor(tester), CupThreadColors.light.background);
    });
  });
}
