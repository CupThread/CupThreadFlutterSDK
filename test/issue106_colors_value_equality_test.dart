import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// A client whose transport throws if touched: every test in this file
/// supplies a host config, so no network call is ever legitimate — a hit
/// means the rebuild test accidentally triggered a config fetch.
FeedbackClient _neverCallClient() {
  return FeedbackClient(
    FeedbackClientConfig(
      baseUrl: 'https://api.cupthread.com',
      appKey: 'app_test_123',
    ),
    httpClient: MockClient((request) async {
      throw StateError('unexpected network call to ${request.url}');
    }),
  );
}

/// One instance shared by every scope pair compared below: the client is
/// compared by identity in `updateShouldNotify`, so a fresh client per
/// comparison would notify regardless of the palette under test.
final FeedbackClient _sharedClient = _neverCallClient();

/// A non-const copy of the canonical light palette: same 23 tokens, but a
/// distinct instance, as a host building a custom scope per frame would
/// produce.
CupThreadColors _freshLightCopy() {
  return CupThreadColors(
    background: CupThreadColors.light.background,
    card: CupThreadColors.light.card,
    cardBorder: CupThreadColors.light.cardBorder,
    textPrimary: CupThreadColors.light.textPrimary,
    textSecondary: CupThreadColors.light.textSecondary,
    textMuted: CupThreadColors.light.textMuted,
    primary: CupThreadColors.light.primary,
    primaryHover: CupThreadColors.light.primaryHover,
    primaryText: CupThreadColors.light.primaryText,
    border: CupThreadColors.light.border,
    inputBg: CupThreadColors.light.inputBg,
    inputBorder: CupThreadColors.light.inputBorder,
    accent: CupThreadColors.light.accent,
    voteActiveBg: CupThreadColors.light.voteActiveBg,
    voteActiveText: CupThreadColors.light.voteActiveText,
    voteInactiveBg: CupThreadColors.light.voteInactiveBg,
    voteInactiveText: CupThreadColors.light.voteInactiveText,
    chipBg: CupThreadColors.light.chipBg,
    chipText: CupThreadColors.light.chipText,
    divider: CupThreadColors.light.divider,
    danger: CupThreadColors.light.danger,
    dangerBg: CupThreadColors.light.dangerBg,
    dangerBorder: CupThreadColors.light.dangerBorder,
  );
}

CupThreadThemeScope _scope({CupThreadColors? colors, SdkTheme? theme, String? userToken}) {
  return CupThreadThemeScope(
    client: _sharedClient,
    userToken: userToken ?? 'token-1',
    colors: colors ?? CupThreadColors.resolve(SdkTheme.light),
    theme: theme ?? SdkTheme.light,
    appConfig: _mockConfig(),
    strings: CupThreadStrings.en,
    locale: const Locale('en'),
    child: const SizedBox.shrink(),
  );
}

class _RebuildCountingHost extends StatefulWidget {
  const _RebuildCountingHost({required this.countingChild});

  /// Stored as a field so host rebuilds hand [CupThreadTheme] the identical
  /// widget instance — without this, Flutter would rebuild the subtree for
  /// the new instance regardless of scope notification, and the count would
  /// measure the host instead of the scope.
  final Widget countingChild;

  @override
  State<_RebuildCountingHost> createState() => _RebuildCountingHostState();
}

class _RebuildCountingHostState extends State<_RebuildCountingHost> {
  int hostRebuilds = 0;

  /// Created once: a fresh client per build is itself a scope-notify trigger
  /// (`client != oldWidget.client` is an identity comparison) and would make
  /// this test measure the harness instead of the palette comparison.
  final FeedbackClient _client = _neverCallClient();

  void triggerRebuild() => setState(() => hostRebuilds++);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CupThreadTheme(
        client: _client,
        userToken: 'token-1',
        theme: SdkTheme.light,
        config: _mockConfig(),
        child: widget.countingChild,
      ),
    );
  }
}

void main() {
  group('CupThreadColors value equality (issue #106)', () {
    test('resolve returns the canonical palette for repeated calls', () {
      final first = CupThreadColors.resolve(SdkTheme.light);
      final second = CupThreadColors.resolve(SdkTheme.light);
      expect(first, equals(second));
      expect(identical(first, second), isTrue,
          reason: 'resolve must keep handing out the const canonical palette');
    });

    test('canonical palettes compare by value across themes', () {
      expect(CupThreadColors.resolve(SdkTheme.light),
          isNot(equals(CupThreadColors.resolve(SdkTheme.dark))));
      expect(CupThreadColors.resolve(SdkTheme.system),
          equals(CupThreadColors.resolve(SdkTheme.light)));
      expect(CupThreadColors.resolve(SdkTheme.system, isDarkMode: true),
          equals(CupThreadColors.resolve(SdkTheme.dark)));
    });

    test('every canonical palette is pairwise unequal', () {
      final palettes = [
        CupThreadColors.light,
        CupThreadColors.dark,
        CupThreadColors.midnight,
        CupThreadColors.ocean,
        CupThreadColors.forest,
        CupThreadColors.sunset,
        CupThreadColors.candy,
      ];
      for (var i = 0; i < palettes.length; i++) {
        for (var j = i + 1; j < palettes.length; j++) {
          expect(palettes[i], isNot(equals(palettes[j])),
              reason: 'palette #$i must differ from palette #$j');
          expect(palettes[i].hashCode, isNot(equals(0)));
        }
      }
    });

    test('a fresh non-const copy equals the canonical palette', () {
      final copy = _freshLightCopy();
      expect(identical(copy, CupThreadColors.light), isFalse,
          reason: 'the copy is a distinct instance');
      expect(copy, equals(CupThreadColors.light));
      expect(copy.hashCode, CupThreadColors.light.hashCode);
    });

    test('a tweaked token makes palettes unequal with distinct hashCodes', () {
      final tweaked = _freshLightCopy().copyWithForTest(
        primary: const Color(0x00000000),
      );
      expect(tweaked, isNot(equals(CupThreadColors.light)));
      expect(tweaked.hashCode, isNot(CupThreadColors.light.hashCode));
      expect(tweaked, isNot(equals(CupThreadColors.dark)));
    });

    test('equality is type-safe against foreign objects', () {
      expect(CupThreadColors.light == Object(), isFalse,
          reason: 'a foreign object must never compare equal to a palette');
    });
  });

  group('CupThreadThemeScope.updateShouldNotify (issue #106)', () {
    test('identical inputs with fresh-but-equal palettes do not notify', () {
      // Both scopes hand-construct their palette copy — the shape of a host
      // rebuilding a custom scope per frame. Without token-level value
      // equality this returned true and re-built every dependent.
      final a = _scope(colors: _freshLightCopy());
      final b = _scope(colors: _freshLightCopy());
      expect(a.updateShouldNotify(b), isFalse);
    });

    test('canonical palettes with identical inputs do not notify', () {
      final a = _scope();
      final b = _scope();
      expect(a.updateShouldNotify(b), isFalse);
    });

    test('a changed palette token notifies', () {
      final a = _scope(colors: _freshLightCopy());
      final b = _scope(
        colors: _freshLightCopy().copyWithForTest(
          primary: const Color(0x01020304),
        ),
      );
      expect(a.updateShouldNotify(b), isTrue);
    });

    test('any other consumed field change notifies', () {
      final base = _scope();

      expect(
        base.updateShouldNotify(_scope(theme: SdkTheme.dark)),
        isTrue,
        reason: 'theme change must notify',
      );
      expect(
        base.updateShouldNotify(_scope(userToken: 'token-2')),
        isTrue,
        reason: 'userToken change must notify',
      );
    });
  });

  group('dependent subtree rebuild suppression (issue #106)', () {
    testWidgets(
        'rebuilding CupThreadTheme with identical inputs builds the dependent once',
        (tester) async {
      var dependentBuilds = 0;
      final host = _RebuildCountingHost(
        countingChild: Builder(
          builder: (context) {
            dependentBuilds++;
            // Register the dependency so scope notification drives rebuilds.
            CupThreadTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(host);
      // The durable anonymous identity is resolved asynchronously: until it
      // lands the scope is not emitted and the dependent cannot build.
      await tester.pumpAndSettle();
      expect(dependentBuilds, 1,
          reason: 'the dependent builds once when the scope first mounts');

      final state = tester.state<_RebuildCountingHostState>(
        find.byType(_RebuildCountingHost),
      );
      state.triggerRebuild();
      await tester.pump();
      state.triggerRebuild();
      await tester.pump();

      expect(dependentBuilds, 1,
          reason:
              'byte-identical rebuilds must not notify dependents — the '
              'scope comparison sees the same canonical palette and inputs');
    });
  });
}

/// Test-only extension so tests can derive a tweaked palette without adding
/// public copy machinery to [CupThreadColors].
extension _CupThreadColorsTestCopy on CupThreadColors {
  CupThreadColors copyWithForTest({Color? primary}) {
    return CupThreadColors(
      background: background,
      card: card,
      cardBorder: cardBorder,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
      primary: primary ?? this.primary,
      primaryHover: primaryHover,
      primaryText: primaryText,
      border: border,
      inputBg: inputBg,
      inputBorder: inputBorder,
      accent: accent,
      voteActiveBg: voteActiveBg,
      voteActiveText: voteActiveText,
      voteInactiveBg: voteInactiveBg,
      voteInactiveText: voteInactiveText,
      chipBg: chipBg,
      chipText: chipText,
      divider: divider,
      danger: danger,
      dangerBg: dangerBg,
      dangerBorder: dangerBorder,
    );
  }
}
