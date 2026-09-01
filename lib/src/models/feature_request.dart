import 'comment.dart';

/// Single feature request proposal.
class FeatureRequestItem {
  final String id;
  final String appId;
  final String title;
  final String description;
  final String status;
  final String? columnId;
  final String? columnSlug;
  final String? columnName;
  final String? columnColor;
  final String? versionId;
  final String? versionLabel;
  final String? releasedVersion;
  final String? requesterName;
  final String? requesterAvatarUrl;
  final String? requesterClerkId;
  final bool approved;
  final int voteCount;
  final bool hasVoted;
  final bool isOwnRequest;
  final List<RecentCommenter> recentCommenters;
  final bool hasMoreCommenters;
  final String createdAt;
  final String updatedAt;

  const FeatureRequestItem({
    required this.id,
    required this.appId,
    required this.title,
    required this.description,
    required this.status,
    this.columnId,
    this.columnSlug,
    this.columnName,
    this.columnColor,
    this.versionId,
    this.versionLabel,
    this.releasedVersion,
    this.requesterName,
    this.requesterAvatarUrl,
    this.requesterClerkId,
    required this.approved,
    required this.voteCount,
    required this.hasVoted,
    required this.isOwnRequest,
    this.recentCommenters = const [],
    this.hasMoreCommenters = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get stageName => columnName ?? status;

  FeatureRequestItem copyWith({
    bool? hasVoted,
    int? voteCount,
  }) {
    return FeatureRequestItem(
      id: id,
      appId: appId,
      title: title,
      description: description,
      status: status,
      columnId: columnId,
      columnSlug: columnSlug,
      columnName: columnName,
      columnColor: columnColor,
      versionId: versionId,
      versionLabel: versionLabel,
      releasedVersion: releasedVersion,
      requesterName: requesterName,
      requesterAvatarUrl: requesterAvatarUrl,
      requesterClerkId: requesterClerkId,
      approved: approved,
      voteCount: voteCount ?? this.voteCount,
      hasVoted: hasVoted ?? this.hasVoted,
      isOwnRequest: isOwnRequest,
      recentCommenters: recentCommenters,
      hasMoreCommenters: hasMoreCommenters,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory FeatureRequestItem.fromJson(Map<String, dynamic> json) {
    final commentersRaw = json['recentCommenters'] as List<dynamic>? ?? [];
    final commenters = commentersRaw
        .map((c) => RecentCommenter.fromJson(c as Map<String, dynamic>))
        .toList();

    return FeatureRequestItem(
      id: json['id'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'backlog',
      columnId: json['columnId'] as String?,
      columnSlug: json['columnSlug'] as String?,
      columnName: json['columnName'] as String?,
      columnColor: json['columnColor'] as String?,
      versionId: json['versionId'] as String?,
      versionLabel: json['versionLabel'] as String?,
      releasedVersion: json['releasedVersion'] as String?,
      requesterName: json['requesterName'] as String?,
      requesterAvatarUrl: json['requesterAvatarUrl'] as String?,
      requesterClerkId: json['requesterClerkId'] as String?,
      approved: json['approved'] as bool? ?? true,
      voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
      hasVoted: json['hasVoted'] as bool? ?? false,
      isOwnRequest: json['isOwnRequest'] as bool? ?? false,
      recentCommenters: commenters,
      hasMoreCommenters: json['hasMoreCommenters'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// Draft for proposing a feature request.
class FeatureRequestDraft {
  final String title;
  final String description;
  final String? requesterName;

  const FeatureRequestDraft({
    required this.title,
    required this.description,
    this.requesterName,
  });

  Map<String, dynamic> toJson({required String appKey, required String requesterToken}) {
    return {
      'appKey': appKey,
      'title': title.trim(),
      'description': description.trim(),
      if (requesterName != null && requesterName!.trim().isNotEmpty)
        'requesterName': requesterName!.trim(),
      'requesterToken': requesterToken,
    };
  }
}

/// Result of submitting a feature request.
class FeatureRequestSubmissionResult {
  final String featureRequestId;
  final bool pending;

  const FeatureRequestSubmissionResult({
    required this.featureRequestId,
    required this.pending,
  });

  factory FeatureRequestSubmissionResult.fromJson(Map<String, dynamic> json) {
    return FeatureRequestSubmissionResult(
      featureRequestId: json['featureRequestId'] as String? ?? json['id'] as String? ?? '',
      pending: json['pending'] as bool? ?? false,
    );
  }
}

/// Result of toggling an upvote.
class VoteResult {
  final bool voted;
  final int voteCount;

  const VoteResult({
    required this.voted,
    required this.voteCount,
  });

  factory VoteResult.fromJson(Map<String, dynamic> json) {
    return VoteResult(
      voted: json['voted'] as bool? ?? false,
      voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Paged list of feature requests.
class ListFeatureRequestsResult {
  final List<FeatureRequestItem> requests;
  final int total;

  const ListFeatureRequestsResult({
    required this.requests,
    required this.total,
  });

  factory ListFeatureRequestsResult.fromJson(Map<String, dynamic> json) {
    final list = (json['requests'] as List<dynamic>? ?? [])
        .map((r) => FeatureRequestItem.fromJson(r as Map<String, dynamic>))
        .toList();
    return ListFeatureRequestsResult(
      requests: list,
      total: (json['total'] as num?)?.toInt() ?? list.length,
    );
  }
}
