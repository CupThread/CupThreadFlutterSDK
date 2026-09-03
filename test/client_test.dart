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

    test('tracks and checks seen changelog versions', () async {
      final storage = MemoryTokenStorage();
      final client = FeedbackClient(
        FeedbackClientConfig(
          baseUrl: 'https://api.cupthread.com',
          appKey: 'app_test_123',
        ),
        storage: storage,
      );

      expect(await client.hasSeenChangelog('1.0.0'), isFalse);
      expect(await client.hasSeenChangelog('1.1.0'), isFalse);

      await client.markChangelogSeen('1.0.0');
      expect(await client.hasSeenChangelog('1.0.0'), isTrue);
      expect(await client.hasSeenChangelog('1.1.0'), isFalse);

      await client.markChangelogSeen('1.1.0');
      expect(await client.hasSeenChangelog('1.0.0'), isTrue);
      expect(await client.hasSeenChangelog('1.1.0'), isTrue);
    });
  });
}
