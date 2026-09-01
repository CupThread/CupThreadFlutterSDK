/// Result of reporting user attributes.
class UserAttributesUpdateResult {
  final bool ok;
  final String updatedAt;

  const UserAttributesUpdateResult({
    required this.ok,
    required this.updatedAt,
  });

  factory UserAttributesUpdateResult.fromJson(Map<String, dynamic> json) {
    return UserAttributesUpdateResult(
      ok: json['ok'] as bool? ?? false,
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// Public profile of a developer or user.
class PublicUserProfile {
  final String clerkUserId;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? websiteUrl;
  final bool hideComments;
  final String createdAt;
  final String updatedAt;

  const PublicUserProfile({
    required this.clerkUserId,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.websiteUrl,
    this.hideComments = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      clerkUserId: json['clerkUserId'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      hideComments: json['hideComments'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// App summary card on a user profile.
class PublicAppSummary {
  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
  final String? description;
  final int requestCount;

  const PublicAppSummary({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    this.description,
    this.requestCount = 0,
  });

  factory PublicAppSummary.fromJson(Map<String, dynamic> json) {
    return PublicAppSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      description: json['description'] as String?,
      requestCount: (json['requestCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Comment preview on a user profile.
class UserProfileComment {
  final String id;
  final String body;
  final String createdAt;
  final String featureRequestId;
  final String featureRequestTitle;
  final String appId;
  final String appName;

  const UserProfileComment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.featureRequestId,
    required this.featureRequestTitle,
    required this.appId,
    required this.appName,
  });

  factory UserProfileComment.fromJson(Map<String, dynamic> json) {
    return UserProfileComment(
      id: json['id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      featureRequestId: json['featureRequestId'] as String? ?? '',
      featureRequestTitle: json['featureRequestTitle'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
    );
  }
}

/// Full public user profile response.
class PublicUserProfileResult {
  final PublicUserProfile profile;
  final List<PublicAppSummary> apps;
  final List<UserProfileComment> recentComments;
  final bool hideComments;

  const PublicUserProfileResult({
    required this.profile,
    this.apps = const [],
    this.recentComments = const [],
    this.hideComments = false,
  });

  factory PublicUserProfileResult.fromJson(Map<String, dynamic> json) {
    final appsList = (json['apps'] as List<dynamic>? ?? [])
        .map((a) => PublicAppSummary.fromJson(a as Map<String, dynamic>))
        .toList();
    final commentsList = (json['recentComments'] as List<dynamic>? ?? [])
        .map((c) => UserProfileComment.fromJson(c as Map<String, dynamic>))
        .toList();

    return PublicUserProfileResult(
      profile: PublicUserProfile.fromJson(json['profile'] as Map<String, dynamic>? ?? {}),
      apps: appsList,
      recentComments: commentsList,
      hideComments: json['hideComments'] as bool? ?? false,
    );
  }
}
