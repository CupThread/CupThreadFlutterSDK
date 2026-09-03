import 'dart:io' show Platform;

/// Platform identifier accepted by the CupThread REST API and Developer Console.
///
/// Used to tag feedback submissions, filter feature requests, and define platform-specific
/// feature flags across iOS, macOS, Android, Web, and desktop environments.
///
/// ### Example: Inspecting current platform
/// ```dart
/// final currentPlatform = FeedbackPlatform.current;
/// print('Running on wire value: ${currentPlatform.wireValue}');
/// ```
///
/// ### Example: Parsing from server configuration
/// ```dart
/// final platform = FeedbackPlatform.fromWire('ios');
/// if (platform == FeedbackPlatform.ios) {
///   print('Targeting iOS platform');
/// }
/// ```
enum FeedbackPlatform {
  /// Apple iOS mobile platform.
  ios('ios'),

  /// Apple macOS desktop platform.
  macos('macos'),

  /// Google Android mobile platform.
  android('android'),

  /// Cross-platform or universal runtime.
  universal('universal'),

  /// Web browser runtime (HTML/CanvasKit/WASM).
  web('web');

  /// Wire string representation sent over HTTP payloads.
  final String wireValue;

  /// Creates a [FeedbackPlatform] enum entry with its associated [wireValue].
  const FeedbackPlatform(this.wireValue);

  /// Returns the detected [FeedbackPlatform] for the current host environment.
  ///
  /// Inspects `dart:io` [Platform] properties when running on native platforms.
  /// If running in Flutter Web or an environment where `dart:io` throws an `UnsupportedError`,
  /// safely catches the exception and returns [FeedbackPlatform.web].
  ///
  /// ### Example
  /// ```dart
  /// final platform = FeedbackPlatform.current;
  /// ```
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

  /// Parses a wire string value into its matching [FeedbackPlatform] enum instance.
  ///
  /// Returns `null` if [value] is null or does not match any known enum wire values.
  ///
  /// ### Example
  /// ```dart
  /// final p1 = FeedbackPlatform.fromWire('android'); // FeedbackPlatform.android
  /// final p2 = FeedbackPlatform.fromWire('unknown'); // null
  /// ```
  static FeedbackPlatform? fromWire(String? value) {
    if (value == null) return null;
    for (final p in FeedbackPlatform.values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}
