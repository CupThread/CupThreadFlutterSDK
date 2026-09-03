import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputPath = Platform.environment['CUPTHREAD_SCREENSHOT_OUTPUT'];
  if (outputPath == null || outputPath.isEmpty) {
    throw StateError(
        'CUPTHREAD_SCREENSHOT_OUTPUT must point to the screenshot directory');
  }

  await integrationDriver(
    onScreenshot: (name, image, [args]) async {
      final outputFile = File('$outputPath/$name.png');
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(image, flush: true);
      return true;
    },
  );
}
