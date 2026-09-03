import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cupthread_feedback_example/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the CupThread surfaces', (tester) async {
    app.main();
    await _settle(tester);

    await _captureSurface(
      tester,
      binding,
      openButton: 'Open Roadmap Board',
      readyText: 'Roadmap',
      screenshotName: 'roadmap',
    );
    await tester.tap(find.text('Browse Feature Requests'));
    await _settle(tester);
    expect(find.text('Feature Requests'), findsOneWidget);
    await binding.takeScreenshot('feature_requests');

    await tester.tap(find.byIcon(Icons.add).first);
    await _settle(tester);
    expect(find.text('Propose a Feature'), findsOneWidget);
    await binding.takeScreenshot('submit_request');
    await tester.tap(find.byIcon(Icons.close).last);
    await _settle(tester);
    await tester.pageBack();
    await _settle(tester);

    await _captureSurface(
      tester,
      binding,
      openButton: "What's New / Changelog",
      readyText: "What's New",
      screenshotName: 'whats_new',
    );

    await tester.tap(find.text("Show What's New Overlay"));
    await _settle(tester);
    expect(find.text("What's New in v2.4"), findsOneWidget);
    await binding.takeScreenshot('changelog_overlay');
    await tester.tap(find.text('Got It'));
    await _settle(tester);

    await tester.tap(find.text('Send Feedback'));
    await _settle(tester);
    expect(find.text('Send Feedback'), findsWidgets);
    await binding.takeScreenshot('feedback_composer');
  });
}

Future<void> _captureSurface(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required String openButton,
  required String readyText,
  required String screenshotName,
}) async {
  await tester.tap(find.text(openButton));
  await _settle(tester);
  expect(find.text(readyText), findsOneWidget);
  await binding.takeScreenshot(screenshotName);
  await tester.pageBack();
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await tester.pump();
}
