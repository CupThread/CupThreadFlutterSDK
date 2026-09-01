import 'dart:io' show Platform;

/// Platform value accepted by the CupThread API.
enum FeedbackPlatform {
  ios('ios'),
  macos('macos'),
  android('android'),
  universal('universal'),
  web('web');

  final String wireValue;
  const FeedbackPlatform(this.wireValue);

  /// Returns the platform for the current running runtime.
  static FeedbackPlatform get current {
    try {
      if (Platform.isIOS) return FeedbackPlatform.ios;
      if (Platform.isMacOS) return FeedbackPlatform.macos;
      if (Platform.isAndroid) return FeedbackPlatform.android;
    } catch (_) {
      // In web or unsupported platform
      return FeedbackPlatform.web;
    }
    return FeedbackPlatform.universal;
  }

  /// Parses wire string value to enum.
  static FeedbackPlatform? fromWire(String? value) {
    if (value == null) return null;
    for (final p in FeedbackPlatform.values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}
