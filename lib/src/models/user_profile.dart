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
///
/// Mirrors the `UserProfile` schema of
/// `GET /api/v1/users/{userId}/profile`: profiles are opt-in, so unknown or
/// opted-out users come back as an anonymous placeholder (null display name,
/// null avatar/bio/website).
class PublicUserProfile {
  final String clerkUserId;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? websiteUrl;
  final String createdAt;

  const PublicUserProfile({
    required this.clerkUserId,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.websiteUrl,
    this.createdAt = '',
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      clerkUserId: json['clerkUserId'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// App summary card on a user profile.
///
/// Mirrors the `PublicUserProfileApp` schema: one public app of a workspace
/// the profile user owns.
class PublicAppSummary {
  final String id;
  final String name;
  final String appSlug;
  final String workspaceSlug;
  final String workspaceName;
  final String? iconUrl;
  final String? description;

  const PublicAppSummary({
    required this.id,
    required this.name,
    required this.appSlug,
    required this.workspaceSlug,
    required this.workspaceName,
    this.iconUrl,
    this.description,
  });

  factory PublicAppSummary.fromJson(Map<String, dynamic> json) {
    return PublicAppSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      appSlug: json['appSlug'] as String? ?? '',
      workspaceSlug: json['workspaceSlug'] as String? ?? '',
      workspaceName: json['workspaceName'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// Comment preview on a user profile.
///
/// Mirrors the `recentComments` items of the profile response: no `appId` is
/// disclosed, only the app and workspace slugs plus the display name.
class UserProfileComment {
  final String id;
  final String body;
  final String createdAt;
  final String featureRequestId;
  final String featureRequestTitle;
  final String workspaceSlug;
  final String appSlug;
  final String appName;

  const UserProfileComment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.featureRequestId,
    required this.featureRequestTitle,
    required this.workspaceSlug,
    required this.appSlug,
    required this.appName,
  });

  factory UserProfileComment.fromJson(Map<String, dynamic> json) {
    return UserProfileComment(
      id: json['id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      featureRequestId: json['featureRequestId'] as String? ?? '',
      featureRequestTitle: json['featureRequestTitle'] as String? ?? '',
      workspaceSlug: json['workspaceSlug'] as String? ?? '',
      appSlug: json['appSlug'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
    );
  }
}

/// Full public user profile response.
///
/// Mirrors the `PublicUserProfileResponse` schema. The API never discloses
/// the `hideComments` privacy flag (it gates `recentComments` server-side),
/// so there is deliberately no `hideComments` field here.
class PublicUserProfileResult {
  final PublicUserProfile profile;
  final List<PublicAppSummary> publicApps;
  final List<UserProfileComment> recentComments;

  const PublicUserProfileResult({
    required this.profile,
    this.publicApps = const [],
    this.recentComments = const [],
  });

  factory PublicUserProfileResult.fromJson(Map<String, dynamic> json) {
    final appsList = (json['publicApps'] as List<dynamic>? ?? [])
        .map((a) => PublicAppSummary.fromJson(a as Map<String, dynamic>))
        .toList();
    final commentsList = (json['recentComments'] as List<dynamic>? ?? [])
        .map((c) => UserProfileComment.fromJson(c as Map<String, dynamic>))
        .toList();

    return PublicUserProfileResult(
      profile: PublicUserProfile.fromJson(json['profile'] as Map<String, dynamic>? ?? {}),
      publicApps: appsList,
      recentComments: commentsList,
    );
  }
}
