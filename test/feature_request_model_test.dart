import 'package:flutter_test/flutter_test.dart';
import 'package:cupthread_feedback/cupthread_feedback.dart';

void main() {
  test('FeatureRequestItem decodes importedVotes', () {
    final item = FeatureRequestItem.fromJson({
      'id': 'fr_1',
      'appId': 'app_1',
      'title': 'Dark mode',
      'description': 'Please add dark mode',
      'status': 'open',
      'approved': true,
      'voteCount': 124,
      'importedVotes': 120,
      'hasVoted': false,
      'isOwnRequest': false,
      'createdAt': '2026-09-01T00:00:00Z',
      'updatedAt': '2026-09-01T00:00:00Z',
    });

    expect(item.voteCount, 124);
    expect(item.importedVotes, 120);
  });
}
