/// Feature request linked to a changelog entry.
class ChangelogLinkedRequest {
  final String id;
  final String title;

  const ChangelogLinkedRequest({
    required this.id,
    required this.title,
  });

  factory ChangelogLinkedRequest.fromJson(Map<String, dynamic> json) {
    return ChangelogLinkedRequest(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }
}

/// A published changelog release note entry.
class ChangelogEntry {
  final String id;
  final String title;
  final String body;
  final String? versionLabel;
  final String publishedAt;
  final List<ChangelogLinkedRequest> linkedRequests;

  const ChangelogEntry({
    required this.id,
    required this.title,
    required this.body,
    this.versionLabel,
    required this.publishedAt,
    this.linkedRequests = const [],
  });

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) {
    final list = (json['linkedRequests'] as List<dynamic>? ?? [])
        .map((r) => ChangelogLinkedRequest.fromJson(r as Map<String, dynamic>))
        .toList();

    return ChangelogEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      versionLabel: json['versionLabel'] as String?,
      publishedAt: json['publishedAt'] as String? ?? '',
      linkedRequests: list,
    );
  }
}

/// Result of subscribing to changelog updates.
class ChangelogSubscriptionResult {
  final bool subscribed;
  final bool alreadySubscribed;

  const ChangelogSubscriptionResult({
    required this.subscribed,
    required this.alreadySubscribed,
  });

  factory ChangelogSubscriptionResult.fromJson(Map<String, dynamic> json) {
    return ChangelogSubscriptionResult(
      subscribed: json['subscribed'] as bool? ?? false,
      alreadySubscribed: json['alreadySubscribed'] as bool? ?? false,
    );
  }
}

/// Result of unsubscribing from changelog updates.
class ChangelogUnsubscribeResult {
  final bool unsubscribed;

  const ChangelogUnsubscribeResult({
    required this.unsubscribed,
  });

  factory ChangelogUnsubscribeResult.fromJson(Map<String, dynamic> json) {
    return ChangelogUnsubscribeResult(
      unsubscribed: json['unsubscribed'] as bool? ?? false,
    );
  }
}
