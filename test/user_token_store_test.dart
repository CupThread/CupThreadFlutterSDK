import 'package:flutter_test/flutter_test.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

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
  });
}
