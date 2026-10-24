import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

PublicAppConfig _mockConfig() {
  return const PublicAppConfig(
    appId: 'app_123',
    appKey: 'app_test_123',
    slug: 'test-app',
    name: 'Test App',
    allowPublic: true,
    allowedPlatforms: [FeedbackPlatform.ios, FeedbackPlatform.android],
    maxAttachmentBytes: 1048576,
    allowAnonymousVote: true,
    allowAnonymousFeedback: true,
    allowAnonymousRoadmap: true,
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
}

FeedbackClient _mockClient({required bool failSubscription}) {
  return FeedbackClient(
    FeedbackClientConfig(
      baseUrl: 'https://api.cupthread.com',
      appKey: 'app_test_123',
    ),
    initialConfig: _mockConfig(),
    httpClient: MockClient((request) async {
      if (failSubscription &&
          request.url.path.endsWith('/changelog/subscribe')) {
        return http.Response('upstream exploded', 500);
      }
      return http.Response('{}', 200, headers: {
        'content-type': 'application/json',
      });
    }),
  );
}

void main() {
  group('CupThreadColors danger tokens (issue #6)', () {
    test('every palette resolves distinct danger tokens', () {
      for (final theme in SdkTheme.values) {
        final colors = CupThreadColors.resolve(theme);
        expect(colors.danger, isNot(colors.dangerBg),
            reason: '$theme renders danger text on background');
        expect(colors.dangerBorder, isNot(colors.dangerBg),
            reason: '$theme renders a visible banner border');
      }
    });

    test('dark and midnight banners drop the light pink palette', () {
      const lightBg = Color(0xFFFEF2F2);
      const lightBorder = Color(0xFFFCA5A5);
      const lightText = Color(0xFFB91C1C);

      for (final colors in [CupThreadColors.dark, CupThreadColors.midnight]) {
        expect(colors.dangerBg, isNot(lightBg));
        expect(colors.dangerBorder, isNot(lightBorder));
        expect(colors.danger, isNot(lightText));
      }
    });

    test('light-family palettes keep the established light danger trio', () {
      const expected = (
        danger: Color(0xFFB91C1C),
        dangerBg: Color(0xFFFEF2F2),
        dangerBorder: Color(0xFFFCA5A5),
      );
      for (final colors in [
        CupThreadColors.light,
        CupThreadColors.ocean,
        CupThreadColors.forest,
        CupThreadColors.sunset,
        CupThreadColors.candy,
      ]) {
        expect(colors.danger, expected.danger);
        expect(colors.dangerBg, expected.dangerBg);
        expect(colors.dangerBorder, expected.dangerBorder);
      }
    });
  });

  group('Error banners follow the active theme (issue #6)', () {
    testWidgets(
        'FeedbackComposer validation banner uses dark danger tokens under SdkTheme.dark',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: CupThreadTheme(
            client: _mockClient(failSubscription: false),
            userToken: 'user_token_abc',
            theme: SdkTheme.dark,
            child: const Scaffold(body: FeedbackComposer()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'no');
      await tester.enterText(
          find.byType(TextField).at(1), 'long enough description');
      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      final bannerText = find.textContaining('at least 3');
      expect(bannerText, findsOneWidget);

      final decorations = tester
          .widgetList<Container>(find.ancestor(
            of: bannerText,
            matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration is BoxDecoration),
          ))
          .map((c) => c.decoration as BoxDecoration)
          .toList();

      expect(decorations.map((d) => d.color),
          contains(CupThreadColors.dark.dangerBg));
      expect(decorations.map((d) => d.color),
          isNot(contains(const Color(0xFFFEF2F2))));
      expect(
        decorations.map((d) => d.border).whereType<Border>().expand((b) => [
              b.top.color,
              b.bottom.color,
            ]),
        contains(CupThreadColors.dark.dangerBorder),
      );
      expect(
        tester.widget<Text>(bannerText).style?.color,
        CupThreadColors.dark.danger,
      );
    });
  });

  group('Localized error copy (issue #6)', () {
    testWidgets(
        'WhatsNewScreen invalid-email snackbar renders Japanese under CupThreadStrings.ja',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: _mockClient(failSubscription: false),
            userToken: 'user_token_abc',
            strings: CupThreadStrings.ja,
            child: const WhatsNewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('購読する'));
      await tester.pump();

      expect(find.text('有効なメールアドレスを入力してください。'), findsOneWidget);
      expect(find.textContaining('valid email'), findsNothing);
    });

    testWidgets(
        'WhatsNewScreen subscription failure hides the raw API response body',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: _mockClient(failSubscription: true),
            userToken: 'user_token_abc',
            child: const WhatsNewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'alex@example.com');
      await tester.tap(find.text('Subscribe'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
          find.text('Subscription failed. Please try again.'), findsOneWidget);
      expect(find.textContaining('upstream exploded'), findsNothing);
    });
  });
}
