import 'comment.dart';

/// Single feature request proposal item on the roadmap or requests board.
///
/// Contains proposal details, board column status, milestone version tags,
/// upvote status, requester info, and recent commenter avatars.
///
/// ### Example
/// ```dart
/// final item = FeatureRequestItem(
///   id: 'fr_123',
///   appId: 'app_abc',
///   title: 'Add CSV export for analytics',
///   description: 'Allow exporting daily and monthly active user metrics to CSV.',
///   status: 'planned',
///   columnName: 'In Progress',
///   columnColor: '#3B82F6',
///   versionLabel: '1.4.0',
///   approved: true,
///   voteCount: 42,
///   hasVoted: true,
///   isOwnRequest: false,
///   createdAt: '2026-08-15T10:00:00Z',
///   updatedAt: '2026-08-20T14:30:00Z',
/// );
/// ```
class FeatureRequestItem {
  /// Unique database identifier for this feature request.
  final String id;

  /// Identifier of the parent application.
  final String appId;

  /// Feature request title.
  final String title;

  /// Full markdown-formatted feature description.
  final String description;

  /// Internal status slug (e.g. `'backlog'`, `'in_progress'`, `'completed'`).
  final String status;

  /// Associated Kanban column ID, if mapped.
  final String? columnId;

  /// Slug identifier of the assigned column.
  final String? columnSlug;

  /// Human-readable name of the assigned board column (e.g. `'Under Review'`).
  final String? columnName;

  /// Hex color code (e.g. `'#3B82F6'`) associated with the board column.
  final String? columnColor;

  /// ID of the target release milestone version, if assigned.
  final String? versionId;

  /// Human-readable label of the target release milestone (e.g. `'2.1.0'`).
  final String? versionLabel;

  /// Released version number if this feature has already shipped.
  final String? releasedVersion;

  /// Display name of the user who proposed this feature.
  final String? requesterName;

  /// Profile image URL of the proposing user.
  final String? requesterAvatarUrl;

  /// Clerk authentication user ID of the author, if authenticated.
  final String? requesterClerkId;

  /// Whether this request has been approved for public display by moderators.
  final bool approved;

  /// Total count of upvotes received.
  final int voteCount;

  /// Historical votes imported from the source provider, when available.
  final int? importedVotes;

  /// Whether the currently active user has upvoted this request.
  final bool hasVoted;

  /// Whether the currently active user created this request.
  final bool isOwnRequest;

  /// List of recent commenters for displaying avatar stacks.
  final List<RecentCommenter> recentCommenters;

  /// Whether there are additional commenters beyond [recentCommenters].
  final bool hasMoreCommenters;

  /// ISO 8601 creation timestamp string.
  final String createdAt;

  /// ISO 8601 last-update timestamp string.
  final String updatedAt;

  /// Creates a [FeatureRequestItem] data object.
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
    this.importedVotes,
    required this.hasVoted,
    required this.isOwnRequest,
    this.recentCommenters = const [],
    this.hasMoreCommenters = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Stage name for display, preferring [columnName] with fallback to [status].
  String get stageName => columnName ?? status;

  /// Creates a copy of this [FeatureRequestItem] with updated properties.
  ///
  /// Commonly used for optimistic vote toggles in UI widgets.
  ///
  /// ### Example
  /// ```dart
  /// final updated = item.copyWith(
  ///   hasVoted: true,
  ///   voteCount: item.voteCount + 1,
  /// );
  /// ```
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
      importedVotes: importedVotes,
      hasVoted: hasVoted ?? this.hasVoted,
      isOwnRequest: isOwnRequest,
      recentCommenters: recentCommenters,
      hasMoreCommenters: hasMoreCommenters,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Deserializes [FeatureRequestItem] from a JSON map.
  ///
  /// Malformed elements inside `recentCommenters` (null or non-object
  /// entries) are skipped rather than fatal, matching the null-tolerant
  /// field parsing used throughout the model layer.
  factory FeatureRequestItem.fromJson(Map<String, dynamic> json) {
    final commentersRaw = json['recentCommenters'] as List<dynamic>? ?? [];
    final commenters = commentersRaw
        .whereType<Map<String, dynamic>>()
        .map(RecentCommenter.fromJson)
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
      importedVotes: (json['importedVotes'] as num?)?.toInt(),
      hasVoted: json['hasVoted'] as bool? ?? false,
      isOwnRequest: json['isOwnRequest'] as bool? ?? false,
      recentCommenters: commenters,
      hasMoreCommenters: json['hasMoreCommenters'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// Draft proposal for creating a new feature request.
///
/// ### Example
/// ```dart
/// final draft = FeatureRequestDraft(
///   title: 'Dark Mode Theme',
///   description: 'Add system-wide OLED dark mode option.',
///   requesterName: 'Alex',
/// );
/// ```
class FeatureRequestDraft {
  /// Feature request title.
  final String title;

  /// Detailed description or use case explanation.
  final String description;

  /// Proposing user's self-declared name.
  final String? requesterName;

  /// Optional Cloudflare Turnstile verification token.
  final String? turnstileToken;

  /// Creates a [FeatureRequestDraft] proposal.
  const FeatureRequestDraft({
    required this.title,
    required this.description,
    this.requesterName,
    this.turnstileToken,
  });

  /// Serializes [FeatureRequestDraft] to JSON for `POST /api/v1/feature-requests`.
  Map<String, dynamic> toJson({required String appKey, required String requesterToken}) {
    return {
      'appKey': appKey,
      'title': title.trim(),
      'description': description.trim(),
      if (requesterName != null && requesterName!.trim().isNotEmpty)
        'requesterName': requesterName!.trim(),
      'requesterToken': requesterToken,
      if (turnstileToken != null && turnstileToken!.trim().isNotEmpty)
        'turnstileToken': turnstileToken!.trim(),
    };
  }
}

/// Result returned after submitting a new feature request.
///
/// Indicates whether the proposal is immediately visible or [pending] moderation review.
///
/// ### Example
/// ```dart
/// final result = await client.submitFeatureRequest(draft, userToken: token);
/// if (result.pending) {
///   print('Proposal submitted and waiting for moderation.');
/// }
/// ```
class FeatureRequestSubmissionResult {
  /// Database ID of the newly submitted feature request.
  final String featureRequestId;

  /// Whether the request is pending moderator approval before public display.
  final bool pending;

  /// Creates a [FeatureRequestSubmissionResult] record.
  const FeatureRequestSubmissionResult({
    required this.featureRequestId,
    required this.pending,
  });

  /// Deserializes [FeatureRequestSubmissionResult] from a server JSON response.
  factory FeatureRequestSubmissionResult.fromJson(Map<String, dynamic> json) {
    return FeatureRequestSubmissionResult(
      featureRequestId: json['featureRequestId'] as String? ?? json['id'] as String? ?? '',
      pending: json['pending'] as bool? ?? false,
    );
  }
}

/// Result of casting or removing an upvote on a feature request.
///
/// Returned by `POST /api/v1/feature-requests/:id/vote` ([FeedbackClient.castVote])
/// and `DELETE /api/v1/feature-requests/:id/vote` ([FeedbackClient.removeVote]).
///
/// ### Example
/// ```dart
/// final result = await client.castVote('fr_123', userToken: token);
/// print('Voted: ${result.voted}, Total count: ${result.voteCount}');
/// ```
class VoteResult {
  /// Whether the user has an active upvote after the operation.
  final bool voted;

  /// Updated total upvote count after the change.
  final int voteCount;

  /// Creates a [VoteResult] record.
  const VoteResult({
    required this.voted,
    required this.voteCount,
  });

  /// Deserializes [VoteResult] from a server JSON response.
  factory VoteResult.fromJson(Map<String, dynamic> json) {
    return VoteResult(
      voted: json['voted'] as bool? ?? false,
      voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Paginated list response for feature requests.
///
/// Returned by `GET /api/v1/feature-requests`. When the response carries
/// keyset metadata, follow [nextCursor] to fetch subsequent pages while
/// [hasMore] is true — cursor pages stay stable when moderation approves,
/// hides, or reorders rows between fetches, which offset pages do not.
///
/// ### Example
/// ```dart
/// final result = await client.fetchFeatureRequests(userToken: token);
/// print('Showing ${result.requests.length} of ${result.total} requests.');
/// if (result.hasMore && result.nextCursor != null) {
///   final next = await client.fetchFeatureRequests(
///       userToken: token, cursor: result.nextCursor);
/// }
/// ```
class ListFeatureRequestsResult {
  /// List of feature request items returned for the current page.
  final List<FeatureRequestItem> requests;

  /// Total count of matching feature requests across all pages.
  final int total;

  /// Raw number of rows the server sent in this page's `requests[]`
  /// array, including malformed elements that [requests] skips.
  ///
  /// Offset pagination must advance by this count, not by
  /// [requests.length]: the server skips rows by its own raw count, so
  /// after a dropped element, advancing by the filtered length would
  /// re-fetch the row right after it.
  final int pageRowCount;

  /// Whether more requests are available beyond this page.
  ///
  /// The API sends this field only for cursor-based requests; a legacy
  /// response without it parses as `false` so callers keep working.
  final bool hasMore;

  /// Opaque keyset cursor for the next page, or null on the last page.
  ///
  /// Pass it back via `fetchFeatureRequests(cursor: …)`; the cursor form
  /// omits the legacy `offset` parameter, which the API marks as
  /// deprecated for deep pages.
  final String? nextCursor;

  /// Creates a [ListFeatureRequestsResult] page container.
  const ListFeatureRequestsResult({
    required this.requests,
    required this.total,
    this.pageRowCount = 0,
    this.hasMore = false,
    this.nextCursor,
  });

  /// Deserializes [ListFeatureRequestsResult] from a JSON map.
  ///
  /// Malformed elements inside `requests` (null or non-object entries)
  /// are skipped rather than fatal, matching the null-tolerant field
  /// parsing used throughout the model layer. When the server omits
  /// `total`, it falls back to the raw row count of this page. Pagination
  /// metadata is tolerant too — [hasMore] defaults to false and
  /// [nextCursor] to null when a legacy server omits them.
  factory ListFeatureRequestsResult.fromJson(Map<String, dynamic> json) {
    final rawRows = json['requests'] as List<dynamic>? ?? const [];
    final list = rawRows
        .whereType<Map<String, dynamic>>()
        .map(FeatureRequestItem.fromJson)
        .toList();
    final cursor = json['nextCursor'] as String?;
    return ListFeatureRequestsResult(
      requests: list,
      total: (json['total'] as num?)?.toInt() ?? rawRows.length,
      pageRowCount: rawRows.length,
      hasMore: json['hasMore'] as bool? ?? false,
      nextCursor: (cursor != null && cursor.isNotEmpty) ? cursor : null,
    );
  }
}
