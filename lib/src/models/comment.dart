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

/// Draft for posting a new comment.
class CommentDraft {
  final String body;
  final String? authorName;
  final String? authorEmail;
  final String? authorAvatarUrl;
  final String? parentId;
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
    return {
      'body': body.trim(),
      if (authorName != null && authorName!.trim().isNotEmpty)
        'authorName': authorName!.trim(),
      if (authorEmail != null && authorEmail!.trim().isNotEmpty)
        'authorEmail': authorEmail!.trim(),
      if (authorAvatarUrl != null && authorAvatarUrl!.trim().isNotEmpty)
        'authorAvatarUrl': authorAvatarUrl!.trim(),
      if (parentId != null) 'parentId': parentId,
      if (replyToClerkId != null) 'replyToClerkId': replyToClerkId,
      if (replyToAuthorName != null && replyToAuthorName!.trim().isNotEmpty)
        'replyToAuthorName': replyToAuthorName!.trim(),
    };
  }
}
