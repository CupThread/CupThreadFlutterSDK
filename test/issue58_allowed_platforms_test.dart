import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression coverage for issue #58: `PublicAppConfig.allowedPlatforms` was
/// deserialized but enforced by no code path — unauthorized platforms (any
/// Flutter Web deployment, desktops outside the policy) rendered every
/// surface and submitted records the server would reject or tag with an
/// unauthorized platform. The SDK now gates the four surface entry points on
/// `CupThreadTheme.isPlatformAllowed` once config resolves, fail-open before
/// that and for empty host-built lists.
void main() {
  // The wire enum has no `web`, so `['ios']` authorizes iOS only.
  PublicAppConfig configWith(
    List<FeedbackPlatform> allowedPlatforms, {
    bool allowAnonymousRoadmap = true,
  }) =>
      PublicAppConfig(
        appId: 'app_123',
        appKey: 'app_test_123',
        slug: 'test-app',
        name: 'Test App',
        allowPublic: true,
        allowedPlatforms: allowedPlatforms,
        maxAttachmentBytes: 1048576,
        allowAnonymousRoadmap: allowAnonymousRoadmap,
        allowAnonymousVote: true,
        allowAnonymousFeedback: true,
        allowAnonymousChangelog: true,
        sdk: const SdkAppearance(
          features: SdkFeatures(
            feedback: true,
            featureRequests: true,
            roadmap: true,
            changelog: true,
          ),
        ),
      );

  /// Client whose every request is recorded; surfaces a requests list, an
  /// empty versions list, and an empty changelog so an allowed platform
  /// renders normally. [configJson] is served for the config endpoint when
  /// the theme has to resolve the policy itself.
  (FeedbackClient, List<String>) recordingClient({
    PublicAppConfig? config,
    String configJson = '{}',
  }) {
    final requests = <String>[];
    final client = FeedbackClient(
      FeedbackClientConfig(
        baseUrl: 'https://api.cupthread.com',
        appKey: 'app_test_123',
      ),
      initialConfig: config,
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path.contains('/public/config/')) {
          return http.Response(configJson, 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/v1/feature-requests') {
          return http.Response(
            jsonEncode({'requests': [], 'totalCount': 0, 'hasMore': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/versions')) {
          return http.Response(jsonEncode({'versions': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path.endsWith('/changelog')) {
          return http.Response(jsonEncode({'entries': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    return (client, requests);
  }

  Widget host(
    FeedbackClient client, {
    required FeedbackPlatform? platformOverride,
    required PublicAppConfig? config,
    required Widget child,
  }) =>
      MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          platformOverride: platformOverride,
          child: child,
        ),
      );

  /// A host button that invokes [open] with a context inside the scope,
  /// mirroring how hosts present modal surfaces.
  Widget hostWithOpener(
    FeedbackClient client, {
    required FeedbackPlatform? platformOverride,
    required PublicAppConfig? config,
    required void Function(BuildContext) open,
  }) =>
      MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: config,
          platformOverride: platformOverride,
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

  group('FeatureRequestsScreen platform gate', () {
    testWidgets('web override on an ios-only app renders the notice and never fetches',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      await tester.pumpWidget(host(
        client,
        platformOverride: FeedbackPlatform.web,
        config: configWith([FeedbackPlatform.ios]),
        child: const FeatureRequestsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not available on this platform.'), findsOneWidget);
      expect(find.byIcon(Icons.devices), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      // Zero gated requests leave the client.
      expect(requests.where((r) => r.contains('/feature-requests')), isEmpty);
      expect(requests.where((r) => r.contains('/versions')), isEmpty);
    });

    testWidgets('ios override on the same app loads normally (no over-gating)',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      await tester.pumpWidget(host(
        client,
        platformOverride: FeedbackPlatform.ios,
        config: configWith([FeedbackPlatform.ios]),
        child: const FeatureRequestsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not available on this platform.'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(
          requests.where((r) => r.contains('/feature-requests')), isNotEmpty);
    });

    testWidgets('an empty allowedPlatforms list never gates (host-built config)',
        (tester) async {
      final (client, requests) = recordingClient(config: configWith([]));

      await tester.pumpWidget(host(
        client,
        // Even the never-authorized web platform runs under an empty policy.
        platformOverride: FeedbackPlatform.web,
        config: configWith([]),
        child: const FeatureRequestsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not available on this platform.'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(
          requests.where((r) => r.contains('/feature-requests')), isNotEmpty);
    });

    testWidgets('gates once a late-resolved policy forbids the platform',
        (tester) async {
      // No initialConfig: the theme fetches a config whose policy authorizes
      // only iOS. While unresolved nothing is gated; once it resolves the
      // web-overridden surface must land on the notice.
      final (client, requests) = recordingClient(
        configJson: '{"allowedPlatforms":["ios"]}',
      );

      await tester.pumpWidget(host(
        client,
        platformOverride: FeedbackPlatform.web,
        config: null,
        child: const FeatureRequestsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not available on this platform.'), findsOneWidget);
      expect(requests.where((r) => r.contains('/feature-requests')), isEmpty);
      expect(
          requests.where((r) => r.contains('/public/config/')), isNotEmpty);
    });
  });

  group('RoadmapBoardScreen platform gate', () {
    testWidgets('web override on an ios-only app renders the notice and never fetches',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      await tester.pumpWidget(host(
        client,
        platformOverride: FeedbackPlatform.web,
        config: configWith([FeedbackPlatform.ios]),
        child: const RoadmapBoardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not available on this platform.'), findsOneWidget);
      expect(requests.where((r) => r.contains('/columns')), isEmpty);
      expect(requests.where((r) => r.contains('/feature-requests')), isEmpty);
    });

    testWidgets('universal override loads the board on a policy that allows it',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.universal]));

      await tester.pumpWidget(host(
        client,
        platformOverride: FeedbackPlatform.universal,
        config: configWith([FeedbackPlatform.universal]),
        child: const RoadmapBoardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not available on this platform.'), findsNothing);
      expect(requests.where((r) => r.contains('/columns')), isNotEmpty);
    });
  });

  group('WhatsNewScreen platform gate', () {
    testWidgets('web override on an ios-only app renders the notice and never fetches',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      await tester.pumpWidget(host(
        client,
        platformOverride: FeedbackPlatform.web,
        config: configWith([FeedbackPlatform.ios]),
        child: const WhatsNewScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not available on this platform.'), findsOneWidget);
      expect(requests.where((r) => r.endsWith('/changelog')), isEmpty);
    });

    testWidgets('macos override on a macos-authorizing app loads the changelog',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.macos]));

      await tester.pumpWidget(host(
        client,
        platformOverride: FeedbackPlatform.macos,
        config: configWith([FeedbackPlatform.macos]),
        child: const WhatsNewScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not available on this platform.'), findsNothing);
      expect(requests.where((r) => r.endsWith('/changelog')), isNotEmpty);
    });
  });

  group('modal surfaces platform gate', () {
    testWidgets('FeedbackComposer.showModal resolves null without presenting on web',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      await tester.pumpWidget(hostWithOpener(
        client,
        platformOverride: FeedbackPlatform.web,
        config: configWith([FeedbackPlatform.ios]),
        open: (ctx) => FeedbackComposer.showModal(ctx),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackComposer), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(requests, isEmpty);
    });

    testWidgets('FeedbackComposer.showModal presents on an authorized platform',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      await tester.pumpWidget(hostWithOpener(
        client,
        platformOverride: FeedbackPlatform.ios,
        config: configWith([FeedbackPlatform.ios]),
        open: (ctx) => FeedbackComposer.showModal(ctx),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackComposer), findsOneWidget);
      expect(requests, isEmpty); // composing posts nothing yet
    });

    testWidgets('FeatureRequestComposeSheet.show resolves null without presenting on web',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      await tester.pumpWidget(hostWithOpener(
        client,
        platformOverride: FeedbackPlatform.web,
        config: configWith([FeedbackPlatform.ios]),
        open: (ctx) => FeatureRequestComposeSheet.show(ctx),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureRequestComposeSheet), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(requests, isEmpty);
    });

    testWidgets('ChangelogOverlay.show never fetches or presents on web',
        (tester) async {
      final (client, requests) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      await tester.pumpWidget(hostWithOpener(
        client,
        platformOverride: FeedbackPlatform.web,
        config: configWith([FeedbackPlatform.ios]),
        open: (ctx) => ChangelogOverlay.show(ctx),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(ChangelogOverlay), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(requests.where((r) => r.endsWith('/changelog')), isEmpty);
    });
  });

  group('CupThreadTheme.isPlatformAllowed semantics', () {
    /// A scope probe built directly so each semantics assertion is
    /// deterministic (no async config-fetch timing involved).
    Widget probe({
      PublicAppConfig? appConfig,
      FeedbackPlatform? platformOverride,
      required void Function(BuildContext) onBuild,
    }) {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
      );
      return MaterialApp(
        home: CupThreadThemeScope(
          client: client,
          userToken: 'usr_tok_probe',
          colors: CupThreadColors.resolve(SdkTheme.system),
          theme: SdkTheme.system,
          appConfig: appConfig,
          platformOverride: platformOverride,
          strings: CupThreadStrings.en,
          child: Builder(
            builder: (ctx) {
              onBuild(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    testWidgets('fail-open while config is unresolved', (tester) async {
      bool? allowed;
      await tester.pumpWidget(probe(
        platformOverride: FeedbackPlatform.web,
        onBuild: (ctx) => allowed = CupThreadTheme.isPlatformAllowed(ctx),
      ));
      expect(allowed, isTrue,
          reason: 'no resolved policy must never gate rendering');
    });

    testWidgets('web is never authorized by a non-empty policy', (tester) async {
      bool? allowed;
      await tester.pumpWidget(probe(
        appConfig: configWith([FeedbackPlatform.ios]),
        platformOverride: FeedbackPlatform.web,
        onBuild: (ctx) => allowed = CupThreadTheme.isPlatformAllowed(ctx),
      ));
      expect(allowed, isFalse,
          reason: 'the wire enum has no web value, so a non-empty policy '
              'never authorizes web');
    });

    testWidgets('an empty allowedPlatforms list is unrestricted', (tester) async {
      bool? allowed;
      await tester.pumpWidget(probe(
        appConfig: configWith([]),
        platformOverride: FeedbackPlatform.web,
        onBuild: (ctx) => allowed = CupThreadTheme.isPlatformAllowed(ctx),
      ));
      expect(allowed, isTrue, reason: 'empty policy = no restriction');
    });

    testWidgets('carryScope forwards platformOverride into modal routes',
        (tester) async {
      final (client, _) =
          recordingClient(config: configWith([FeedbackPlatform.ios]));

      bool? carriedAllowed;
      await tester.pumpWidget(MaterialApp(
        home: CupThreadTheme(
          client: client,
          config: configWith([FeedbackPlatform.ios]),
          platformOverride: FeedbackPlatform.web,
          child: Scaffold(
            body: Builder(
              builder: (outerCtx) => Center(
                child: TextButton(
                  onPressed: () {
                    final carried = CupThreadTheme.carryScope(
                      outerCtx,
                      child: Builder(
                        builder: (innerCtx) {
                          carriedAllowed =
                              CupThreadTheme.isPlatformAllowed(innerCtx);
                          return const SizedBox.shrink();
                        },
                      ),
                    );
                    Navigator.of(outerCtx).push(MaterialPageRoute(
                      builder: (_) => Scaffold(body: carried),
                    ));
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(carriedAllowed, isFalse,
          reason: 'the carried scope keeps the host platform pin');
    });
  });
}
