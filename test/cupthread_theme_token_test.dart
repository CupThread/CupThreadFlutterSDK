import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Storage adapter whose reads wait on a gate, to observe the cold-start
/// restoration race deterministically.
class _GatedStorage implements TokenStorageAdapter {
  _GatedStorage(this._seeded);

  final String? _seeded;
  final Map<String, String> _written = {};
  final Completer<void> gate = Completer<void>();
  int readCount = 0;

  @override
  Future<String?> getItem(String key) async {
    readCount++;
    await gate.future;
    return _seeded;
  }

  @override
  Future<void> setItem(String key, String value) async {
    _written[key] = value;
  }
}

FeedbackClient _mockClient() {
  return FeedbackClient(
    FeedbackClientConfig(
      baseUrl: 'https://api.cupthread.com',
      appKey: 'app_test_123',
    ),
    httpClient: MockClient((request) async {
      if (request.url.path.contains('/public/config/')) {
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{"error":"not found"}', 404);
    }),
  );
}

void main() {
  testWidgets(
      'CupThreadTheme defers child until the persisted token is restored',
      (tester) async {
    final storage = _GatedStorage('persisted-token-123');
    UserTokenStore.configure(storage);

    await tester.pumpWidget(
      MaterialApp(
        home: CupThreadTheme(
          client: _mockClient(),
          child: Builder(
            builder: (context) =>
                Text('token:${CupThreadTheme.userTokenOf(context)}'),
          ),
        ),
      ),
    );

    // While the durable identity is still loading, no child (and therefore
    // no throwaway identity) may be rendered.
    expect(find.textContaining('token:'), findsNothing);

    storage.gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('token:persisted-token-123'), findsOneWidget);
    expect(storage.readCount, 1);
  });

  testWidgets(
      'remounting CupThreadTheme with pre-seeded storage recovers the same identity',
      (tester) async {
    // First mount: mints a token and persists it.
    final storage = MemoryTokenStorage();
    UserTokenStore.configure(storage);

    String? firstToken;
    await tester.pumpWidget(
      MaterialApp(
        home: CupThreadTheme(
          client: _mockClient(),
          child: Builder(
            builder: (context) {
              firstToken = CupThreadTheme.userTokenOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(firstToken, isNotNull);

    // Unmount entirely.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    // Simulate a process restart: a brand-new store over the same
    // persisted storage.
    UserTokenStore.configure(storage);

    String? secondToken;
    await tester.pumpWidget(
      MaterialApp(
        home: CupThreadTheme(
          client: _mockClient(),
          child: Builder(
            builder: (context) {
              secondToken = CupThreadTheme.userTokenOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(secondToken, equals(firstToken));
  });

  testWidgets('explicit userToken is published without gating',
      (tester) async {
    // Even a never-completing storage must not delay an explicit token.
    final storage = _GatedStorage('persisted-token-123');
    UserTokenStore.configure(storage);

    await tester.pumpWidget(
      MaterialApp(
        home: CupThreadTheme(
          client: _mockClient(),
          userToken: 'explicit-token-xyz',
          child: Builder(
            builder: (context) =>
                Text('token:${CupThreadTheme.userTokenOf(context)}'),
          ),
        ),
      ),
    );

    expect(find.text('token:explicit-token-xyz'), findsOneWidget);
    expect(storage.readCount, 0);
  });
}
