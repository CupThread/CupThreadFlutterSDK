import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #91: `BadgeChip._parseColor` used
/// `int.parse`, which throws `FormatException` on a 6-character
/// `columnColor` containing non-hex characters. `columnColor` is
/// unvalidated server data, so one malformed value crashed the whole
/// board build. The parse is now total: any value that does not parse
/// falls back to the theme's chip colors, exactly like a wrong-length
/// value already did.
void main() {
  // BadgeChip resolves colors via CupThreadTheme.of, which falls back to
  // CupThreadColors.resolve(SdkTheme.system, isDarkMode:) outside a scope.
  final fallbackColors = CupThreadColors.resolve(
    SdkTheme.system,
    isDarkMode: false,
  );

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  Color? badgeTextColor(WidgetTester tester) {
    final text = tester.widget<Text>(find.byType(Text));
    return text.style?.color;
  }

  Color? badgeBackground(WidgetTester tester) {
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    return decoration.color;
  }

  group('issue #91: BadgeChip never throws on malformed colorHex', () {
    testWidgets('a 6-char non-hex value renders with the fallback theme '
        'colors instead of throwing', (tester) async {
      await tester.pumpWidget(host(const BadgeChip(
        label: 'In Progress',
        colorHex: 'colors',
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('In Progress'), findsOneWidget);
      expect(badgeTextColor(tester), fallbackColors.chipText);
      expect(badgeBackground(tester), fallbackColors.chipBg);
    });

    testWidgets('a non-hex value with a leading # also falls back',
        (tester) async {
      await tester.pumpWidget(host(const BadgeChip(
        label: 'Blocked',
        colorHex: '#12g45z',
      )));

      expect(tester.takeException(), isNull);
      expect(badgeTextColor(tester), fallbackColors.chipText);
    });

    testWidgets('wrong-length, empty, and null colorHex keep the fallback',
        (tester) async {
      for (final colorHex in <String?>['3B8', 'FFFFFFFF', '', null]) {
        await tester.pumpWidget(host(BadgeChip(
          label: 'Stage',
          colorHex: colorHex,
        )));
        expect(tester.takeException(), isNull);
        expect(badgeTextColor(tester), fallbackColors.chipText);
      }
    });

    testWidgets('valid hex values keep resolving to the custom color, '
        'case-insensitively, with or without #', (tester) async {
      const expected = Color(0xFF3B82F6);
      for (final colorHex in const ['3B82F6', '#3B82F6', '3b82f6']) {
        await tester.pumpWidget(host(BadgeChip(
          label: 'Done',
          colorHex: colorHex,
        )));
        expect(tester.takeException(), isNull);
        expect(badgeTextColor(tester), expected);
      }
    });

    testWidgets('outline badges fall back to the theme border color',
        (tester) async {
      await tester.pumpWidget(host(const BadgeChip(
        label: 'v1.2.0',
        colorHex: 'nope12',
        isOutline: true,
      )));

      expect(tester.takeException(), isNull);
      expect(badgeTextColor(tester), fallbackColors.chipText);
      // Outline keeps the transparent background and falls back to the
      // theme border color for the stroke.
      expect(badgeBackground(tester), Colors.transparent);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border!.top.color, fallbackColors.border);
    });
  });

  group('issue #91: the board renders when the server sends a malformed '
      'columnColor', () {
    testWidgets('FeatureRequestsScreen renders the request card for a '
        'non-hex columnColor', (tester) async {
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

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: config,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/feature-requests') {
            return http.Response(
              jsonEncode({
                'requests': [
                  {
                    'id': 'fr_1',
                    'appId': 'app_123',
                    'title': 'Dark mode for the board',
                    'description': 'Please.',
                    'status': 'in_progress',
                    'columnName': 'In Progress',
                    // Malformed server value: 6 chars, not hex.
                    'columnColor': 'colors',
                    'approved': true,
                    'voteCount': 3,
                    'hasVoted': false,
                    'isOwnRequest': false,
                    'createdAt': '2026-11-01T12:00:00Z',
                    'updatedAt': '2026-11-01T12:00:00Z',
                  },
                ],
                'totalCount': 1,
                'hasMore': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.contains('/versions')) {
            return http.Response(
              jsonEncode({'versions': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          platformOverride: FeedbackPlatform.ios,
          userToken: 'usr_tok_signed_in',
          child: const FeatureRequestsScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // The card — and its stage badge — render despite the malformed color.
      expect(tester.takeException(), isNull);
      expect(find.text('Dark mode for the board'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
    });
  });
}
