/// Recent commenter on a feature request card.
class RecentCommenter {
  final String? authorName;
  final String? clerkUserId;
  final String? avatarUrl;

  const RecentCommenter({
    this.authorName,
    this.clerkUserId,
    this.avatarUrl,
  });

  factory RecentCommenter.fromJson(Map<String, dynamic> json) {
    return RecentCommenter(
      authorName: json['authorName'] as String?,
      clerkUserId: json['clerkUserId'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Discussion comment on a feature request.
class FeatureRequestComment {
  final String id;
  final String featureRequestId;
  final String? authorName;
  final String? authorEmail;
  final String? authorAvatarUrl;
  final String? authorClerkId;
  final String body;
  final String? parentId;
  final String? replyToClerkId;
  final String? replyToAuthorName;
  final bool isHidden;
  final String createdAt;

  const FeatureRequestComment({
    required this.id,
    required this.featureRequestId,
    this.authorName,
    this.authorEmail,
    this.authorAvatarUrl,
    this.authorClerkId,
    required this.body,
    this.parentId,
    this.replyToClerkId,
    this.replyToAuthorName,
    this.isHidden = false,
    required this.createdAt,
  });

  factory FeatureRequestComment.fromJson(Map<String, dynamic> json) {
    return FeatureRequestComment(
      id: json['id'] as String? ?? '',
      featureRequestId: json['featureRequestId'] as String? ?? '',
      authorName: json['authorName'] as String?,
      authorEmail: json['authorEmail'] as String?,
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      authorClerkId: json['authorClerkId'] as String?,
      body: json['body'] as String? ?? '',
      parentId: json['parentId'] as String?,
      replyToClerkId: json['replyToClerkId'] as String?,
      replyToAuthorName: json['replyToAuthorName'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Paginated page of discussion comments on a feature request.
///
/// Returned by `GET /api/v1/feature-requests/:id/comments`. Follow
/// [nextCursor] to fetch subsequent pages while [hasMore] is true.
///
/// ### Example
/// ```dart
/// var page = await client.fetchCommentsPage('fr_123', limit: 100);
/// while (page.hasMore && page.nextCursor != null) {
///   page = await client.fetchCommentsPage('fr_123', cursor: page.nextCursor);
/// }
/// ```
class FeatureRequestCommentPage {
  /// Comments returned for the current page.
  final List<FeatureRequestComment> comments;

  /// Total number of comments in the thread, or null when the server omits it.
  final int? total;

  /// Whether more comments are available beyond this page.
  final bool hasMore;

  /// Opaque keyset cursor for the next page, or null on the last page.
  final String? nextCursor;

  /// Creates a [FeatureRequestCommentPage] container.
  const FeatureRequestCommentPage({
    required this.comments,
    this.total,
    required this.hasMore,
    this.nextCursor,
  });

  /// Deserializes [FeatureRequestCommentPage] from a server JSON response.
  ///
  /// Tolerates responses from servers that do not yet send pagination
  /// metadata: [total] defaults to null, [hasMore] to false and
  /// [nextCursor] to null. Malformed elements inside `comments` (null
  /// or non-object entries) are skipped rather than fatal, matching
  /// the null-tolerant field parsing used throughout the model layer.
  factory FeatureRequestCommentPage.fromJson(Map<String, dynamic> json) {
    final list = (json['comments'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(FeatureRequestComment.fromJson)
        .toList();
    final cursor = json['nextCursor'] as String?;
    return FeatureRequestCommentPage(
      comments: list,
      total: (json['total'] as num?)?.toInt(),
      hasMore: json['hasMore'] as bool? ?? false,
      nextCursor: (cursor != null && cursor.isNotEmpty) ? cursor : null,
    );
  }
}

/// Draft for posting a new comment.
///
/// The wire payload is exactly what the API's `CreateFeatureRequestCommentInput`
/// schema declares — [body], [parentId], [replyToAuthorName] — as [toJson]
/// emits. Author identity is always derived server-side from the
/// authenticated session or the public commenter token, so the deprecated
/// author fields below are kept only so existing host code keeps compiling
/// and never reach the wire.
class CommentDraft {
  final String body;

  /// Ignored by the server; authorship is resolved from the signed-in profile.
  @Deprecated('No longer sent: the comment schema has no author fields and '
      'the server derives authorship from the session.')
  final String? authorName;

  /// Ignored by the server; authorship is resolved from the signed-in profile.
  @Deprecated('No longer sent: the comment schema has no author fields and '
      'the server derives authorship from the session.')
  final String? authorEmail;

  /// Ignored by the server; the avatar is resolved from the signed-in profile.
  @Deprecated('No longer sent: the comment schema has no author fields and '
      'the server derives authorship from the session.')
  final String? authorAvatarUrl;
  final String? parentId;

  /// Never declared by the comment schema; the server ignores it.
  @Deprecated('No longer sent: the comment schema has no such property.')
  final String? replyToClerkId;
  final String? replyToAuthorName;

  const CommentDraft({
    required this.body,
    this.authorName,
    this.authorEmail,
    this.authorAvatarUrl,
    this.parentId,
    this.replyToClerkId,
    this.replyToAuthorName,
  });

  Map<String, dynamic> toJson() {
    // Exactly the properties `CreateFeatureRequestCommentInput` declares.
    // The server silently strips anything else today (the author fields
    // were documented as stripped; `replyToClerkId` was never a schema
    // property), so emitting only the declared shape costs nothing now and
    // keeps every comment post working if the API ever hardens input
    // validation — mirroring the strictness this SDK already applies to
    // response parsing.
    return {
      'body': body.trim(),
      if (parentId != null) 'parentId': parentId,
      if (replyToAuthorName != null && replyToAuthorName!.trim().isNotEmpty)
        'replyToAuthorName': replyToAuthorName!.trim(),
    };
  }
}
