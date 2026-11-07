import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Regression tests for issue #93: `_CupThreadThemeState._loadConfig` used to
/// guard its fetched result with `mounted` only, so a slow in-flight fetch
/// could overwrite a host-supplied config (Race A) or let a superseded
/// client's config win a client swap (Race B). The load now claims a
/// generation and re-validates the widget inputs it was started against after
/// the await, mirroring `_resolveToken`'s explicit-input-wins rule.

final _clientConfig = FeedbackClientConfig(
  baseUrl: 'https://api.cupthread.com',
  appKey: 'app_93',
);

const _hostConfig = PublicAppConfig(
  appId: 'app_93_host',
  appKey: 'app_93',
  slug: 'host-app',
  name: 'host-config',
  allowPublic: true,
  allowedPlatforms: [],
  maxAttachmentBytes: 1048576,
  allowAnonymousRoadmap: true,
  allowAnonymousVote: true,
  allowAnonymousFeedback: true,
  allowAnonymousChangelog: true,
  sdk: SdkAppearance(features: SdkFeatures(changelog: true)),
);

/// A config backend whose `/public/config` responses are gated by
/// [Completer]s so a test controls exactly when — and in which order —
/// concurrent fetches resolve. Outcomes are consumed per request: a String
/// responds with a 200 config named accordingly, anything else is thrown.
class _GatedConfigBackend {
  final List<Completer<void>> _gates = [];
  final List<Object> outcomes = [];
  int _requestCount = 0;

  Completer<void> gateFor(int index) {
    while (_gates.length <= index) {
      _gates.add(Completer<void>());
    }
    return _gates[index];
  }

  http.Client toClient() {
    return MockClient((request) async {
      if (!request.url.path.contains('/public/config/')) {
        return http.Response('{"error":"not found"}', 404);
      }
      final index = _requestCount++;
      final gate = gateFor(index);
      await gate.future;
      final outcome =
          index < outcomes.length ? outcomes[index] : 'network-config-$index';
      if (outcome is String) {
        return http.Response(
          jsonEncode({
            'appId': 'app_93_$index',
            'appKey': 'app_93',
            'slug': 'network-app',
            'name': outcome,
            'sdk': <String, dynamic>{},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      throw outcome;
    });
  }
}

FeedbackClient _buildClient(_GatedConfigBackend backend) {
  return FeedbackClient(_clientConfig, httpClient: backend.toClient());
}

/// Renders the effective config state as text so tests can assert against it.
Widget _stateText(BuildContext context) {
  final name = CupThreadTheme.configOf(context)?.name ?? 'none';
  final loading = CupThreadTheme.isConfigLoading(context);
  final error = CupThreadTheme.configErrorOf(context);
  final clientAppKey = CupThreadTheme.clientOf(context).config.appKey;
  return Text('name:$name|loading:$loading'
      '|error:${error?.runtimeType ?? 'none'}'
      '|client:$clientAppKey');
}

Widget _probe(FeedbackClient client, {PublicAppConfig? config}) {
  return MaterialApp(
    home: CupThreadTheme(
      client: client,
      config: config,
      child: const Builder(builder: _stateText),
    ),
  );
}

String _probeText(WidgetTester tester) {
  final matcher = find.textContaining(RegExp(r'^name:.*\|loading:'));
  expect(matcher, findsOneWidget);
  return tester.widget<Text>(matcher).data!;
}

void main() {
  setUp(() {
    UserTokenStore.configure(MemoryTokenStorage());
  });

  testWidgets(
      'Race A: a host-supplied config is not clobbered by the in-flight fetch '
      'it supersedes', (tester) async {
    final backend = _GatedConfigBackend();
    final client = _buildClient(backend);

    await tester.pumpWidget(_probe(client));
    await tester.pumpAndSettle();
    expect(_probeText(tester), contains('name:none|loading:true'));

    // The host supplies its own config while the fetch is still pending.
    await tester.pumpWidget(_probe(client, config: _hostConfig));
    await tester.pumpAndSettle();
    expect(_probeText(tester), contains('name:host-config|loading:false'));

    // The stale fetch resolves afterwards with a different config.
    backend.outcomes.add('stale-network-config');
    backend.gateFor(0).complete();
    await tester.pumpAndSettle();

    expect(_probeText(tester),
        contains('name:host-config|loading:false|error:none'));
  });

  testWidgets(
      'Race B: a swapped client wins over the old client\'s in-flight fetch '
      'even when the old response lands last', (tester) async {
    final backendA = _GatedConfigBackend();
    final backendB = _GatedConfigBackend();
    final clientA = _buildClient(backendA);
    final clientB = _buildClient(backendB);

    await tester.pumpWidget(_probe(clientA));
    await tester.pumpAndSettle();

    // Swap to client B while A's fetch is still pending.
    await tester.pumpWidget(_probe(clientB));

    // B's fetch resolves immediately; A's superseded one lands last.
    backendB.outcomes.add('config-b');
    backendB.gateFor(0).complete();
    await tester.pumpAndSettle();
    backendA.outcomes.add('config-a');
    backendA.gateFor(0).complete();
    await tester.pumpAndSettle();

    expect(_probeText(tester),
        contains('name:config-b|loading:false|error:none|client:app_93'));
  });

  testWidgets(
      'a superseded fetch failure neither clobbers a host config nor surfaces '
      'as a config error', (tester) async {
    final backend = _GatedConfigBackend();
    final client = _buildClient(backend);

    await tester.pumpWidget(_probe(client));
    await tester.pumpAndSettle();

    // The host takes over while the fetch is pending...
    await tester.pumpWidget(_probe(client, config: _hostConfig));
    await tester.pumpAndSettle();

    // ...and the pending fetch then fails.
    backend.outcomes.add(StateError('network gone'));
    backend.gateFor(0).complete();
    await tester.pumpAndSettle();

    expect(_probeText(tester),
        contains('name:host-config|loading:false|error:none'));
  });

  testWidgets(
      'a superseded fetch failure after a client swap does not surface as a '
      'config error for the new client', (tester) async {
    final backendA = _GatedConfigBackend();
    final backendB = _GatedConfigBackend();
    final clientA = _buildClient(backendA);
    final clientB = _buildClient(backendB);

    await tester.pumpWidget(_probe(clientA));
    await tester.pumpAndSettle();

    // Swap clients, let B's fetch succeed, then fail A's stale fetch.
    await tester.pumpWidget(_probe(clientB));
    backendB.outcomes.add('config-b');
    backendB.gateFor(0).complete();
    await tester.pumpAndSettle();

    backendA.outcomes.add(StateError('stale client failure'));
    backendA.gateFor(0).complete();
    await tester.pumpAndSettle();

    expect(_probeText(tester),
        contains('name:config-b|loading:false|error:none|client:app_93'));
  });

  testWidgets(
      'a client swap drops the old client\'s config — its policy never '
      'outlives the swap, even when the new client\'s fetch fails',
      (tester) async {
    final backendA = _GatedConfigBackend();
    final backendB = _GatedConfigBackend();
    final clientA = _buildClient(backendA);
    final clientB = _buildClient(backendB);

    await tester.pumpWidget(_probe(clientA));
    // Client A's config loads.
    backendA.outcomes.add('config-a');
    backendA.gateFor(0).complete();
    await tester.pumpAndSettle();
    expect(_probeText(tester),
        contains('name:config-a|loading:false|error:none|client:app_93'));

    // Swap to client B (no cached config) while B's fetch then fails.
    await tester.pumpWidget(_probe(clientB));
    backendB.outcomes.add(StateError('client b offline'));
    backendB.gateFor(0).complete();
    await tester.pumpAndSettle();

    expect(_probeText(tester),
        contains('name:none|loading:false|error:InvalidResponseException'));
  });

  testWidgets(
      'a client swap seeds from the new client\'s cached config before its '
      'refresh completes', (tester) async {
    final backendA = _GatedConfigBackend();
    final backendB = _GatedConfigBackend();
    final clientA = _buildClient(backendA);
    final clientB = _buildClient(backendB);

    // Client B already has a cached config from an earlier fetch.
    backendB.outcomes.add('config-b-cached');
    backendB.gateFor(0).complete();
    await clientB.fetchAppConfig();

    await tester.pumpWidget(_probe(clientA));
    await tester.pumpAndSettle();

    // Swap to B while A's fetch is still pending and B's force-refresh is
    // gated: the cached config must be visible immediately.
    await tester.pumpWidget(_probe(clientB));
    await tester.pumpAndSettle();
    expect(_probeText(tester),
        contains('name:config-b-cached|loading:true|error:none|client:app_93'));

    // The refresh supersedes the cache, and A's stale response — released
    // last — is still ignored.
    backendB.outcomes.add('config-b-refreshed');
    backendB.gateFor(1).complete();
    await tester.pumpAndSettle();
    backendA.outcomes.add('config-a');
    backendA.gateFor(0).complete();
    await tester.pumpAndSettle();
    expect(_probeText(tester),
        contains('name:config-b-refreshed|loading:false|error:none'));
  });

  testWidgets(
      'retryConfig supersedes the earlier in-flight load — the last current '
      'writer wins, not the last writer', (tester) async {
    final backend = _GatedConfigBackend();
    final client = _buildClient(backend);

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: CupThreadTheme(
          client: client,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return _stateText(context);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A second load starts while the first is still gated: it supersedes it.
    CupThreadTheme.retryConfig(capturedContext);

    // The retry's fetch resolves first; the superseded one lands last.
    backend.outcomes.addAll(<Object>['superseded-older', 'retry-latest']);
    backend.gateFor(1).complete();
    await tester.pumpAndSettle();
    backend.gateFor(0).complete();
    await tester.pumpAndSettle();

    expect(_probeText(tester),
        contains('name:retry-latest|loading:false|error:none'));
  });
}
