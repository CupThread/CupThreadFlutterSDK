import 'platform.dart';

/// Supported SDK theme identifiers.
enum SdkTheme {
  system('system'),
  light('light'),
  dark('dark'),
  midnight('midnight'),
  ocean('ocean'),
  forest('forest'),
  sunset('sunset'),
  candy('candy');

  final String wireValue;
  const SdkTheme(this.wireValue);

  static SdkTheme fromWire(String? value) {
    for (final t in SdkTheme.values) {
      if (t.wireValue == value) return t;
    }
    return SdkTheme.system;
  }
}

/// Feature flags for user-facing SDK surfaces.
class SdkFeatures {
  final bool feedback;
  final bool featureRequests;
  final bool roadmap;
  final bool changelog;

  const SdkFeatures({
    this.feedback = true,
    this.featureRequests = true,
    this.roadmap = true,
    this.changelog = true,
  });

  factory SdkFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SdkFeatures();
    return SdkFeatures(
      feedback: json['feedback'] as bool? ?? true,
      featureRequests: json['featureRequests'] as bool? ?? true,
      roadmap: json['roadmap'] as bool? ?? true,
      changelog: json['changelog'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'feedback': feedback,
    'featureRequests': featureRequests,
    'roadmap': roadmap,
    'changelog': changelog,
  };
}

/// Configuration for What's New changelog overlay.
class ChangelogOverlayConfig {
  final String title;
  final String subtitle;
  final int entryCount;
  final String primaryButton;
  final String closeButton;

  const ChangelogOverlayConfig({
    this.title = "What's New",
    this.subtitle = '',
    this.entryCount = 3,
    this.primaryButton = 'Continue',
    this.closeButton = 'Close',
  });

  int get clampedEntryCount => entryCount.clamp(1, 10);

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

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'entryCount': entryCount,
    'primaryButton': primaryButton,
    'closeButton': closeButton,
  };
}

/// Appearance settings configured in Developer Console.
class SdkAppearance {
  final SdkTheme theme;
  final SdkFeatures features;
  final ChangelogOverlayConfig changelogOverlay;

  const SdkAppearance({
    this.theme = SdkTheme.system,
    this.features = const SdkFeatures(),
    this.changelogOverlay = const ChangelogOverlayConfig(),
  });

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

  Map<String, dynamic> toJson() => {
    'theme': theme.wireValue,
    'features': features.toJson(),
    'changelogOverlay': changelogOverlay.toJson(),
  };
}

/// Public app configuration from GET /api/v1/public/config/:appKey.
class PublicAppConfig {
  final String appId;
  final String appKey;
  final String slug;
  final String name;
  final String? storeUrl;
  final String? storeKind;
  final String? iconUrl;
  final bool allowPublic;
  final List<FeedbackPlatform> allowedPlatforms;
  final int maxAttachmentBytes;
  final bool allowAnonymousRoadmap;
  final bool allowAnonymousVote;
  final bool allowAnonymousFeedback;
  final bool allowAnonymousChangelog;
  final SdkAppearance sdk;

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
