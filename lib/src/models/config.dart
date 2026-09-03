import 'platform.dart';

/// Predefined color themes supported by the CupThread SDK and Developer Console.
///
/// Use [SdkTheme] to customize the visual styling of CupThread screens and widgets,
/// or let the SDK automatically resolve the theme from [PublicAppConfig.sdk].
///
/// ### Example: Overriding SDK theme manually
/// ```dart
/// CupThreadTheme(
///   client: client,
///   theme: SdkTheme.midnight,
///   child: const RoadmapBoardScreen(),
/// )
/// ```
enum SdkTheme {
  /// Follows the host application's system dark/light mode brightness.
  system('system'),

  /// Modern light theme with clean neutral slate backgrounds.
  light('light'),

  /// Sleek dark theme with deep navy-slate backgrounds.
  dark('dark'),

  /// High-contrast ultra-dark theme with indigo accents.
  midnight('midnight'),

  /// Fresh teal/cyan oceanic color palette.
  ocean('ocean'),

  /// Vibrant lime and forest green color palette.
  forest('forest'),

  /// Warm orange and amber sunset color palette.
  sunset('sunset'),

  /// Playful fuchsia and pink candy color palette.
  candy('candy');

  /// Wire string identifier used in API JSON payloads.
  final String wireValue;

  /// Creates an [SdkTheme] with the associated [wireValue].
  const SdkTheme(this.wireValue);

  /// Parses a wire string representation into an [SdkTheme].
  ///
  /// Defaults to [SdkTheme.system] if [value] is null or unrecognised.
  ///
  /// ### Example
  /// ```dart
  /// final theme = SdkTheme.fromWire('ocean'); // SdkTheme.ocean
  /// ```
  static SdkTheme fromWire(String? value) {
    for (final t in SdkTheme.values) {
      if (t.wireValue == value) return t;
    }
    return SdkTheme.system;
  }
}

/// Feature flags controlling the visibility of user-facing SDK surfaces.
///
/// Configured in the CupThread Developer Console and synced at runtime.
///
/// ### Example
/// ```dart
/// const features = SdkFeatures(
///   feedback: true,
///   featureRequests: true,
///   roadmap: true,
///   changelog: false,
/// );
/// ```
class SdkFeatures {
  /// Whether in-app feedback collection form is enabled.
  final bool feedback;

  /// Whether the feature request voting and submission board is enabled.
  final bool featureRequests;

  /// Whether the public Kanban roadmap board is enabled.
  final bool roadmap;

  /// Whether changelog release notes and What's New screen are enabled.
  final bool changelog;

  /// Creates an [SdkFeatures] set with customizable surface toggles.
  const SdkFeatures({
    this.feedback = true,
    this.featureRequests = true,
    this.roadmap = true,
    this.changelog = true,
  });

  /// Deserializes [SdkFeatures] from a nullable JSON map.
  factory SdkFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SdkFeatures();
    return SdkFeatures(
      feedback: json['feedback'] as bool? ?? true,
      featureRequests: json['featureRequests'] as bool? ?? true,
      roadmap: json['roadmap'] as bool? ?? true,
      changelog: json['changelog'] as bool? ?? true,
    );
  }

  /// Serializes [SdkFeatures] to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'feedback': feedback,
    'featureRequests': featureRequests,
    'roadmap': roadmap,
    'changelog': changelog,
  };
}

/// Configuration options for the What's New changelog announcement modal.
///
/// Controls copy, max displayed entries, and call-to-action button labels.
///
/// ### Example
/// ```dart
/// const overlayConfig = ChangelogOverlayConfig(
///   title: "What's New in Version 2.0",
///   subtitle: "Check out our latest improvements!",
///   entryCount: 5,
///   primaryButton: "Got It",
/// );
/// ```
class ChangelogOverlayConfig {
  /// Header title shown at the top of the announcement modal.
  final String title;

  /// Optional descriptive subtitle text.
  final String subtitle;

  /// Number of recent changelog entries to display in the modal.
  final int entryCount;

  /// Label for the primary action button.
  final String primaryButton;

  /// Label for the secondary close button (if displayed).
  final String closeButton;

  /// Creates a [ChangelogOverlayConfig] with customizable modal options.
  const ChangelogOverlayConfig({
    this.title = "What's New",
    this.subtitle = '',
    this.entryCount = 3,
    this.primaryButton = 'Continue',
    this.closeButton = 'Close',
  });

  /// Entry count clamped to a safe range of 1 to 10 entries.
  int get clampedEntryCount => entryCount.clamp(1, 10);

  /// Deserializes [ChangelogOverlayConfig] from a nullable JSON map.
  factory ChangelogOverlayConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChangelogOverlayConfig();
    return ChangelogOverlayConfig(
      title: json['title'] as String? ?? "What's New",
      subtitle: json['subtitle'] as String? ?? '',
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 3,
      primaryButton: json['primaryButton'] as String? ?? 'Continue',
      closeButton: json['closeButton'] as String? ?? 'Close',
    );
  }

  /// Serializes [ChangelogOverlayConfig] to a JSON map.
  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'entryCount': entryCount,
    'primaryButton': primaryButton,
    'closeButton': closeButton,
  };
}

/// SDK appearance and feature settings configured in the CupThread Developer Console.
///
/// Bundles theme selection, feature toggles, and changelog overlay customization.
///
/// ### Example
/// ```dart
/// final appearance = SdkAppearance(
///   theme: SdkTheme.dark,
///   features: const SdkFeatures(feedback: true, roadmap: true),
/// );
/// ```
class SdkAppearance {
  /// Active theme for SDK UI rendering.
  final SdkTheme theme;

  /// Feature flags controlling enabled screens.
  final SdkFeatures features;

  /// Configuration for the What's New modal sheet.
  final ChangelogOverlayConfig changelogOverlay;

  /// Creates an [SdkAppearance] configuration object.
  const SdkAppearance({
    this.theme = SdkTheme.system,
    this.features = const SdkFeatures(),
    this.changelogOverlay = const ChangelogOverlayConfig(),
  });

  /// Deserializes [SdkAppearance] from a nullable JSON map.
  factory SdkAppearance.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SdkAppearance();
    return SdkAppearance(
      theme: SdkTheme.fromWire(json['theme'] as String?),
      features: SdkFeatures.fromJson(json['features'] as Map<String, dynamic>?),
      changelogOverlay: ChangelogOverlayConfig.fromJson(
        json['changelogOverlay'] as Map<String, dynamic>?,
      ),
    );
  }

  /// Serializes [SdkAppearance] to a JSON map.
  Map<String, dynamic> toJson() => {
    'theme': theme.wireValue,
    'features': features.toJson(),
    'changelogOverlay': changelogOverlay.toJson(),
  };
}

/// Public application configuration returned by `GET /api/v1/public/config/:appKey`.
///
/// Contains branding, permissions, allowed platforms, and SDK appearance settings.
///
/// ### Example
/// ```dart
/// final config = await client.fetchAppConfig();
/// print('App Name: ${config.name}');
/// print('Allowed platforms: ${config.allowedPlatforms}');
/// ```
class PublicAppConfig {
  /// Unique database ID of the registered application.
  final String appId;

  /// Public App Key identifier used for client API requests.
  final String appKey;

  /// URL-friendly slug of the application.
  final String slug;

  /// Display name of the application.
  final String name;

  /// App Store or Play Store product listing URL, if set.
  final String? storeUrl;

  /// Store ecosystem type (e.g. `'apple'`, `'google'`).
  final String? storeKind;

  /// URL of the application's logo or icon.
  final String? iconUrl;

  /// Whether public access to roadmap and feedback is permitted.
  final bool allowPublic;

  /// List of platforms where the SDK is authorized to run.
  final List<FeedbackPlatform> allowedPlatforms;

  /// Maximum allowed size in bytes for uploaded attachments (default 10 MB).
  final int maxAttachmentBytes;

  /// Whether unauthenticated users can view the roadmap board.
  final bool allowAnonymousRoadmap;

  /// Whether unauthenticated users can upvote feature requests.
  final bool allowAnonymousVote;

  /// Whether unauthenticated users can submit feedback drafts.
  final bool allowAnonymousFeedback;

  /// Whether unauthenticated users can browse the changelog.
  final bool allowAnonymousChangelog;

  /// SDK appearance and customization options.
  final SdkAppearance sdk;

  /// Creates a [PublicAppConfig] instance.
  const PublicAppConfig({
    required this.appId,
    required this.appKey,
    required this.slug,
    required this.name,
    this.storeUrl,
    this.storeKind,
    this.iconUrl,
    required this.allowPublic,
    required this.allowedPlatforms,
    required this.maxAttachmentBytes,
    required this.allowAnonymousRoadmap,
    required this.allowAnonymousVote,
    required this.allowAnonymousFeedback,
    required this.allowAnonymousChangelog,
    required this.sdk,
  });

  /// Deserializes [PublicAppConfig] from a server JSON response.
  factory PublicAppConfig.fromJson(Map<String, dynamic> json) {
    final platformsRaw = json['allowedPlatforms'] as List<dynamic>? ?? [];
    final platforms = platformsRaw
        .map((p) => FeedbackPlatform.fromWire(p.toString()))
        .whereType<FeedbackPlatform>()
        .toList();

    return PublicAppConfig(
      appId: json['appId'] as String? ?? json['id'] as String? ?? '',
      appKey: json['appKey'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      storeUrl: json['storeUrl'] as String?,
      storeKind: json['storeKind'] as String?,
      iconUrl: json['iconUrl'] as String?,
      allowPublic: json['allowPublic'] as bool? ?? true,
      allowedPlatforms: platforms,
      maxAttachmentBytes: (json['maxAttachmentBytes'] as num?)?.toInt() ?? 10485760,
      allowAnonymousRoadmap: json['allowAnonymousRoadmap'] as bool? ?? true,
      allowAnonymousVote: json['allowAnonymousVote'] as bool? ?? true,
      allowAnonymousFeedback: json['allowAnonymousFeedback'] as bool? ?? true,
      allowAnonymousChangelog: json['allowAnonymousChangelog'] as bool? ?? true,
      sdk: SdkAppearance.fromJson(json['sdk'] as Map<String, dynamic>?),
    );
  }
}
