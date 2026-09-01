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
  });
}
