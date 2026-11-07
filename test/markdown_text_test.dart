import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Flattens a span tree into every [TextSpan] node (including the root).
List<TextSpan> flattenSpans(InlineSpan span) {
  final result = <TextSpan>[];
  void visit(TextSpan s) {
    result.add(s);
    final children = s.children;
    if (children == null) return;
    for (final child in children) {
      if (child is TextSpan) visit(child);
    }
  }

  if (span is TextSpan) visit(span);
  return result;
}

/// Span tree of a [Text] widget; plain-text widgets carry [Text.style] on the
/// widget itself, so it is folded into the root span for style assertions.
TextSpan spanTreeOf(Text w) {
  if (w.textSpan != null) return w.textSpan! as TextSpan;
  return TextSpan(text: w.data ?? '', style: w.style);
}

/// Plain text of every [Text] widget in the tree (span texts joined per widget).
List<String> renderedTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => flattenSpans(spanTreeOf(w)).map((s) => s.text ?? '').join())
      .toList();
}

bool hasSpanWith(
  WidgetTester tester,
  bool Function(String text, TextStyle? style) predicate,
) {
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    for (final span in flattenSpans(spanTreeOf(w))) {
      if (predicate(span.text ?? '', span.style)) return true;
    }
  }
  return false;
}

Future<void> pumpMarkdown(WidgetTester tester, String content,
    {TextStyle? style}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MarkdownText(content: content, style: style),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('MarkdownText inline spans', () {
    testWidgets('renders **bold** and `code` without literal markers',
        (tester) async {
      await pumpMarkdown(tester, 'A **bold** and `code` bit');

      final texts = renderedTexts(tester).join();
      expect(texts, contains('bold'));
      expect(texts, contains('code'));
      expect(texts, isNot(contains('**')));
      expect(texts, isNot(contains('`')));

      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'bold' && style?.fontWeight == FontWeight.bold),
        isTrue,
        reason: 'bold segment should carry a bold TextStyle',
      );
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'code' && style?.fontFamily == 'monospace'),
        isTrue,
        reason: 'code segment should carry a monospace TextStyle',
      );
    });

    testWidgets('renders __bold__ (double-underline variant)', (tester) async {
      await pumpMarkdown(tester, 'a __loud__ word');

      expect(renderedTexts(tester).join(), isNot(contains('__')));
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'loud' && style?.fontWeight == FontWeight.bold),
        isTrue,
      );
    });

    testWidgets('code span styling uses the theme chip colors and background',
        (tester) async {
      await pumpMarkdown(tester, 'run `flutter test` now');

      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'flutter test' &&
            style?.fontFamily == 'monospace' &&
            style?.background != null),
        isTrue,
        reason: 'code span should carry a subtle background paint',
      );
    });

    testWidgets('markers inside a code span render literally', (tester) async {
      await pumpMarkdown(tester, 'keep `**not bold**` verbatim');

      expect(
        hasSpanWith(tester, (text, style) =>
            text == '**not bold**' && style?.fontFamily == 'monospace'),
        isTrue,
        reason: 'bold markers inside code spans must not be interpreted',
      );
      expect(
        hasSpanWith(tester, (text, style) =>
            style?.fontWeight == FontWeight.bold),
        isFalse,
      );
    });

    testWidgets('code span wins over bold at the same position',
        (tester) async {
      await pumpMarkdown(tester, 'mix `code` and **bold** and `**both**`');

      final texts = renderedTexts(tester).join();
      expect(texts, contains('code and '));
      expect(
        hasSpanWith(tester, (text, style) =>
            text == '**both**' && style?.fontFamily == 'monospace'),
        isTrue,
      );
    });

    testWidgets('unmatched markers render the original text unchanged',
        (tester) async {
      await pumpMarkdown(tester, 'a * b ** c');

      final texts = renderedTexts(tester);
      expect(texts, contains('a * b ** c'));
    });

    testWidgets('lone backtick and empty bold markers render literally',
        (tester) async {
      await pumpMarkdown(tester, 'tick ` and **** empty');

      expect(renderedTexts(tester), contains('tick ` and **** empty'));
    });

    testWidgets('*italic* is intentionally not parsed and renders literally',
        (tester) async {
      await pumpMarkdown(tester, 'stay *literal* here');

      expect(
        hasSpanWith(tester, (text, _) => text.contains('*literal*')),
        isTrue,
      );
    });

    testWidgets('adjacent bold and code spans keep all text in order',
        (tester) async {
      await pumpMarkdown(tester, '**one**`two`three');

      final texts = renderedTexts(tester).join();
      expect(texts, 'onetwothree');
    });
  });

  group('MarkdownText line-level rendering', () {
    testWidgets('headers and bullets keep their sizes and support inline spans',
        (tester) async {
      await pumpMarkdown(
        tester,
        '# Top **hot**\n'
        '## Mid __warm__\n'
        '### Deep `tiny`\n'
        '- bullet **alpha**\n'
        '* bullet `beta`\n'
        'plain **gamma** tail',
      );

      // Header text is preserved without markers.
      final texts = renderedTexts(tester).join();
      expect(texts, contains('Top hot'));
      expect(texts, contains('Mid warm'));
      expect(texts, contains('Deep tiny'));
      expect(texts, contains('bullet alpha'));
      expect(texts, contains('bullet beta'));
      expect(texts, contains('plain gamma tail'));
      expect(texts, isNot(contains('**')));
      expect(texts, isNot(contains('__')));

      // Bullets still render their marker.
      expect(find.text('• '), findsNWidgets(2));

      // Header base sizes survive on the inline spans.
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'hot' && style?.fontSize == 20),
        isTrue,
        reason: '# header inline spans inherit the 20pt header size',
      );
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'warm' && style?.fontSize == 17),
        isTrue,
      );
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'tiny' && style?.fontSize == 15),
        isTrue,
      );
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'gamma' && style?.fontSize == 14),
        isTrue,
      );
    });

    testWidgets('custom style flows into body text and inline spans',
        (tester) async {
      await pumpMarkdown(
        tester,
        'body **strong**',
        style: const TextStyle(fontSize: 22, color: Color(0xFF123456)),
      );

      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'strong' &&
            style?.fontSize == 22 &&
            style?.color == const Color(0xFF123456) &&
            style?.fontWeight == FontWeight.bold),
        isTrue,
        reason: 'bold span should extend the custom style, only overriding weight',
      );
    });

    testWidgets('blank lines still produce spacing paragraphs', (tester) async {
      await pumpMarkdown(tester, 'first\n\nsecond');

      expect(find.byType(SizedBox), findsWidgets);
      expect(renderedTexts(tester), containsAll(['first', 'second']));
    });
  });

  group('MarkdownText fenced code blocks', () {
    testWidgets('renders a fenced block as monospace code without the fences',
        (tester) async {
      await pumpMarkdown(
        tester,
        'before\n'
        '```dart\n'
        'main() {\n'
        '  print("hi");\n'
        '}\n'
        '```\n'
        'after',
      );

      final texts = renderedTexts(tester).join();
      expect(texts, contains('main() {\n  print("hi");\n}'));
      expect(texts, isNot(contains('```')));
      expect(texts, isNot(contains('dart\n')));
      expect(texts, contains('before'));
      expect(texts, contains('after'));

      final codeText = tester.widget<Text>(find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('main()'),
      ));
      expect(codeText.style?.fontFamily, 'monospace');
      final blockContainer = tester.widget<Container>(find.ancestor(
        of: find.byWidget(codeText),
        matching: find.byType(Container),
      ).first);
      expect(
        (blockContainer.decoration as BoxDecoration?)?.color,
        CupThreadColors.light.chipBg,
        reason: 'fenced block should sit on a subtle chip background',
      );
    });

    testWidgets('blank lines inside a fenced block are preserved',
        (tester) async {
      await pumpMarkdown(
        tester,
        '```\nline1\n\nline3\n```',
      );

      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'line1\n\nline3' && style?.fontFamily == 'monospace'),
        isTrue,
      );
    });

    testWidgets('an unclosed fence renders the remaining lines as code',
        (tester) async {
      await pumpMarkdown(
        tester,
        'intro\n```\nstill code\nmore code',
      );

      final texts = renderedTexts(tester).join();
      expect(texts, contains('intro'));
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'still code\nmore code' &&
            style?.fontFamily == 'monospace'),
        isTrue,
      );
    });

    testWidgets('markers inside a fenced block are not interpreted',
        (tester) async {
      await pumpMarkdown(tester, '```\n**not bold** `not code`\n```');

      expect(
        hasSpanWith(tester, (text, style) =>
            text == '**not bold** `not code`' &&
            style?.fontFamily == 'monospace'),
        isTrue,
      );
    });
  });

  group('WhatsNewScreen changelog markdown', () {
    testWidgets('bold in release notes renders without visible asterisks',
        (tester) async {
      PublicAppConfig testConfig() => const PublicAppConfig(
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

      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        initialConfig: testConfig(),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/changelog')) {
            return http.Response(
              jsonEncode({
                'entries': [
                  {
                    'id': 'ch_1',
                    'appId': 'app_123',
                    'title': 'Version 2.0',
                    'body': '## Highlights\n\n- **Ship** notifications\n- `flutter pub upgrade` support',
                    'versionLabel': '2.0.0',
                    'publishedAt': '2026-05-01T00:00:00.000Z',
                    'status': 'published',
                  },
                ],
                'hasMore': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CupThreadTheme(
            client: client,
            config: testConfig(),
            platformOverride: FeedbackPlatform.ios,
            userToken: 'user_token_abc',
            child: const Scaffold(body: WhatsNewScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version 2.0'), findsOneWidget);
      // No authoring artifacts leak into the rendered changelog.
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('`'), findsNothing);
      expect(find.textContaining('Ship'), findsOneWidget);

      // And the bold styling is really applied to the "Ship" run.
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'Ship' && style?.fontWeight == FontWeight.bold),
        isTrue,
      );
      expect(
        hasSpanWith(tester, (text, style) =>
            text == 'flutter pub upgrade' &&
            style?.fontFamily == 'monospace'),
        isTrue,
      );
    });
  });
}
