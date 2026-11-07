import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #111: `Avatar._buildFallback` derived the
/// initials fallback with `substring(0, 1)`, which takes a single UTF-16
/// code unit. For a display name starting outside the BMP (emoji, flags,
/// CJK Extension-B) that code unit is a lone high surrogate, rendered by
/// `Text` as U+FFFD instead of the leading character. The fix takes the
/// first grapheme cluster (`String.characters.first`) so the full code pair
/// survives.
void main() {
  String fallbackText(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).data!;

  Future<void> pumpAvatar(WidgetTester tester, String? name) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // `CupThreadTheme.of` falls back to the ambient Material theme when
          // no CupThreadThemeScope is installed, so a bare host is enough.
          body: Avatar(name: name),
        ),
      ),
    );
    await tester.pump();
  }

  group('issue #111 — avatar initial is surrogate-pair aware', () {
    testWidgets('a non-BMP emoji renders the full code pair, not a lone '
        'high surrogate', (tester) async {
      await pumpAvatar(tester, '🦉 Lex');

      final text = fallbackText(tester);
      // 🦉 = U+1F989 → UTF-16 surrogate pair D83E DD89.
      expect(text, String.fromCharCode(0xD83E) + String.fromCharCode(0xDD89));
      expect(text.codeUnits.first, inInclusiveRange(0xD800, 0xDBFF),
          reason: 'a lone high surrogate renders as U+FFFD');
      expect(text.codeUnits, hasLength(2),
          reason: 'high surrogate must be followed by its low surrogate');
      expect(text.codeUnits.last, inInclusiveRange(0xDC00, 0xDFFF));
    });

    testWidgets('a flag emoji renders complete regional-indicator pairs '
        'with no unpaired surrogate', (tester) async {
      await pumpAvatar(tester, '🇨🇳 Chen');

      final text = fallbackText(tester);
      // The first grapheme is the whole flag (both regional indicators),
      // i.e. four code units forming two complete surrogate pairs.
      expect(text.codeUnits, hasLength(4));
      for (var i = 0; i < text.codeUnits.length; i += 2) {
        expect(text.codeUnits[i], inInclusiveRange(0xD800, 0xDBFF),
            reason: 'code unit $i must be a high surrogate');
        expect(text.codeUnits[i + 1], inInclusiveRange(0xDC00, 0xDFFF),
            reason: 'code unit ${i + 1} must be the matching low surrogate');
      }
    });

    testWidgets('a CJK Extension-B ideograph renders in full',
        (tester) async {
      await pumpAvatar(tester, '𠀀 Ping');

      final text = fallbackText(tester);
      // 𠀀 = U+20000 → surrogate pair D840 DC00.
      expect(text, String.fromCharCode(0xD840) + String.fromCharCode(0xDC00));
    });

    testWidgets('ASCII names keep their current behavior', (tester) async {
      await pumpAvatar(tester, 'Ada');
      expect(fallbackText(tester), 'A');
    });

    testWidgets('BMP CJK names keep their current behavior', (tester) async {
      await pumpAvatar(tester, '唐');
      expect(fallbackText(tester), '唐');
    });

    testWidgets('names with a combining mark keep the base+mark cluster '
        'intact', (tester) async {
      // Decomposed é: base 'e' followed by U+0301 COMBINING ACUTE ACCENT.
      await pumpAvatar(tester, 'e\u0301clair');

      final text = fallbackText(tester);
      // The accent must travel with its base letter — a bare combining mark
      // without a base renders as U+FFFD.
      expect(text.codeUnits, [0x45, 0x0301]);
    });

    testWidgets('empty and null names still fall back to "?"',
        (tester) async {
      await pumpAvatar(tester, '');
      expect(fallbackText(tester), '?');

      await pumpAvatar(tester, '   ');
      expect(fallbackText(tester), '?');

      await pumpAvatar(tester, null);
      expect(fallbackText(tester), '?');
    });
  });
}
