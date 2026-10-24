import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

/// Storage adapter that returns a fixed snapshot from [getItem] (never the
/// value written later by [setItem]) and can gate reads, so tests can
/// observe resolution races deterministically. [writeGate] blocks only the
/// first [setItem] call, so write ordering can be observed.
class _InstrumentedStorage implements TokenStorageAdapter {
  _InstrumentedStorage({this.seeded, this.gate, this.writeGate});

  final String? seeded;
  final Completer<void>? gate;
  final Completer<void>? writeGate;
  final Map<String, String> written = {};
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<String?> getItem(String key) async {
    readCount++;
    if (gate != null && !gate!.isCompleted) await gate!.future;
    return seeded;
  }

  @override
  Future<void> setItem(String key, String value) async {
    final isFirstWrite = writeCount == 0;
    writeCount++;
    if (isFirstWrite && writeGate != null && !writeGate!.isCompleted) {
      await writeGate!.future;
    }
    written[key] = value;
  }
}

void main() {
  group('UserTokenStore', () {
    test('generates valid UUID v4 token', () {
      final store = UserTokenStore();
      final token = store.token;
      expect(token, isNotEmpty);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
                caseSensitive: false)
            .hasMatch(token),
        isTrue,
      );
    });

    test('caches token', () {
      final store = UserTokenStore();
      final token1 = store.token;
      final token2 = store.token;
      expect(token1, equals(token2));
    });

    test('resetToken generates new UUID', () async {
      final store = UserTokenStore();
      final token1 = store.token;
      final token2 = await store.resetToken();
      expect(token1, isNot(equals(token2)));
      expect(store.token, equals(token2));
    });

    test('recovers existing token from storage on getToken()', () async {
      final storage = MemoryTokenStorage();
      const existingToken = 'test-token-saved-12345';
      await storage.setItem(UserTokenStore.storageKey, existingToken);

      final store = UserTokenStore(storage);
      final retrieved = await store.getToken();
      expect(retrieved, equals(existingToken));
      expect(store.token, equals(existingToken));
    });

    test('generates and persists new token to storage when empty', () async {
      final storage = MemoryTokenStorage();
      final store = UserTokenStore(storage);

      expect(await storage.getItem(UserTokenStore.storageKey), isNull);
      final token = await store.getToken();
      expect(token, isNotEmpty);
      expect(await storage.getItem(UserTokenStore.storageKey), equals(token));
    });

    test('multiple store instances share persisted token', () async {
      final storage = MemoryTokenStorage();
      final store1 = UserTokenStore(storage);
      final token1 = await store1.getToken();

      final store2 = UserTokenStore(storage);
      final token2 = await store2.getToken();
      expect(token2, equals(token1));
    });

    test('sync token accessor never overrides a token persisted in storage',
        () async {
      final storage = MemoryTokenStorage();
      await storage.setItem(UserTokenStore.storageKey, 'persisted-token-abc');

      final store = UserTokenStore(storage);
      // Synchronous access happens before the storage read completes; it
      // must NOT mint-and-cache a UUID that shadows the persisted value.
      final syncToken = store.token;
      expect(syncToken, isNot(equals('persisted-token-abc')));

      expect(await store.getToken(), equals('persisted-token-abc'));
      expect(store.token, equals('persisted-token-abc'));
    });

    test('sync token accessor is stable while resolution is pending', () {
      final storage = _InstrumentedStorage(gate: Completer<void>());
      final store = UserTokenStore(storage);

      final a = store.token;
      final b = store.token;
      expect(a, equals(b));
      expect(a, isNotEmpty);
    });

    test('concurrent getToken() calls share a single storage read', () async {
      final storage = _InstrumentedStorage();
      final store = UserTokenStore(storage);

      final first = store.getToken();
      final second = store.getToken();
      expect(await first, equals(await second));
      expect(storage.readCount, 1);
    });

    test('setToken during in-flight resolution wins over stored value',
        () async {
      final storage =
          _InstrumentedStorage(seeded: 'stale-stored', gate: Completer<void>());
      final store = UserTokenStore(storage);

      final pending = store.getToken();
      await store.setToken('explicit-token');
      storage.gate!.complete();

      // Storage still reports the stale value, but the explicitly set token
      // must win the race and stay cached.
      expect(await pending, equals('explicit-token'));
      expect(store.token, equals('explicit-token'));
    });

    test('whitespace-only stored value is treated as absent', () async {
      final storage = _InstrumentedStorage(seeded: '   ');
      final store = UserTokenStore(storage);

      final token = await store.getToken();
      expect(token, isNot(equals('   ')));
      expect(storage.written[UserTokenStore.storageKey], equals(token));
    });

    test('in-flight mint write cannot overwrite a newer setToken in storage',
        () async {
      final storage = _InstrumentedStorage(writeGate: Completer<void>());
      final store = UserTokenStore(storage);

      // Mints a UUID whose persistence write is blocked on the gate.
      final resolved = store.getToken();
      // Pump until the mint path has reached its gated write.
      while (storage.writeCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      // Must not be awaited yet: it queues behind the gated mint write.
      final setDone = store.setToken('explicit-token');

      storage.writeGate!.complete();
      await resolved;
      await setDone;

      // The mint write landed first; the setToken write must land last.
      expect(
        storage.written[UserTokenStore.storageKey],
        equals('explicit-token'),
      );
    });

    test('getToken resolves to the newest identity after a racing setToken',
        () async {
      final storage = _InstrumentedStorage(writeGate: Completer<void>());
      final store = UserTokenStore(storage);

      final pending = store.getToken();
      // Pump until the mint path has reached its gated write.
      while (storage.writeCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final setDone = store.setToken('explicit-token');

      storage.writeGate!.complete();

      // While the mint write was pending, an explicit token was installed;
      // the in-flight getToken must surface that newer identity.
      expect(await pending, equals('explicit-token'));
      await setDone;
      expect(store.token, equals('explicit-token'));
    });
  });
}
