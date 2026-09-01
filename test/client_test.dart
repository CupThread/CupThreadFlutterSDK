import 'package:flutter_test/flutter_test.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  group('FeedbackClient', () {
    test('normalizes baseUrl and config', () {
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com///',
          appKey: 'app_test_123',
          defaultPlatform: FeedbackPlatform.android,
        ),
      );

      expect(client.config.baseUrl, 'https://api.cupthread.com');
      expect(client.config.appKey, 'app_test_123');
      expect(client.config.defaultPlatform, FeedbackPlatform.android);
    });
  });
}
