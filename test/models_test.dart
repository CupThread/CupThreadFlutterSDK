import 'package:flutter_test/flutter_test.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  group('Models Serialization', () {
    test('FeedbackPlatform fromWire handles valid wire values', () {
      expect(FeedbackPlatform.fromWire('ios'), FeedbackPlatform.ios);
      expect(FeedbackPlatform.fromWire('android'), FeedbackPlatform.android);
      expect(FeedbackPlatform.fromWire('macos'), FeedbackPlatform.macos);
      expect(FeedbackPlatform.fromWire('universal'), FeedbackPlatform.universal);
      expect(FeedbackPlatform.fromWire('unknown'), isNull);
    });

    test('SdkAppearance and SdkFeatures parse JSON', () {
      final json = {
        'theme': 'ocean',
        'features': {
          'feedback': true,
          'featureRequests': true,
          'roadmap': false,
          'changelog': true,
        },
        'changelogOverlay': {
          'title': 'New Updates!',
          'entryCount': 5,
          'primaryButton': 'Got it',
          'closeButton': 'Dismiss',
        },
      };

      final appearance = SdkAppearance.fromJson(json);
      expect(appearance.theme, SdkTheme.ocean);
      expect(appearance.features.roadmap, isFalse);
      expect(appearance.features.feedback, isTrue);
      expect(appearance.changelogOverlay.title, 'New Updates!');
      expect(appearance.changelogOverlay.clampedEntryCount, 5);
    });

    test('BoardColumn parse JSON', () {
      final json = {
        'id': 'col_123',
        'appId': 'app_123',
        'name': 'In Progress',
        'slug': 'in_progress',
        'position': 2,
        'isVisible': true,
        'isSystem': false,
        'kind': 'normal',
        'color': '#2563EB',
        'createdAt': '2026-09-01T00:00:00Z',
        'updatedAt': '2026-09-01T00:00:00Z',
      };

      final col = BoardColumn.fromJson(json);
      expect(col.id, 'col_123');
      expect(col.name, 'In Progress');
      expect(col.position, 2);
      expect(col.color, '#2563EB');
      expect(col.kind, BoardColumnKind.normal);
    });
  });
}
