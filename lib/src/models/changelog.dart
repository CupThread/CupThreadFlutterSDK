/// Reference to a completed feature request linked to a changelog release note.
///
/// Displayed as a pill or star badge within release notes to celebrate shipped user requests.
///
/// ### Example
/// ```dart
/// final linked = ChangelogLinkedRequest(
///   id: 'fr_123',
///   title: 'Support custom webhook notifications',
/// );
/// ```
class ChangelogLinkedRequest {
  /// Unique database ID of the linked feature request.
  final String id;

  /// Title of the linked feature request.
  final String title;

  /// Creates a [ChangelogLinkedRequest] record.
  const ChangelogLinkedRequest({
    required this.id,
    required this.title,
  });

  /// Deserializes [ChangelogLinkedRequest] from a JSON map.
  factory ChangelogLinkedRequest.fromJson(Map<String, dynamic> json) {
    return ChangelogLinkedRequest(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }
}

/// Published release note entry in the application changelog.
///
/// Displayed in [WhatsNewScreen] and [ChangelogOverlay]. Supports markdown formatting
/// and linked feature requests.
///
/// ### Example
/// ```dart
/// final entries = await client.fetchChangelog();
/// for (final entry in entries) {
///   print('${entry.title} (${entry.versionLabel ?? "latest"})');
///   print(entry.body);
/// }
/// ```
class ChangelogEntry {
  /// Unique database ID of the changelog entry.
  final String id;

  /// Headline title of the release note.
  final String title;

  /// Markdown-formatted body describing highlights, improvements, and fixes.
  final String body;

  /// Target release version string (e.g. `'2.1.0'`), if tagged.
  final String? versionLabel;

  /// ISO 8601 published date string.
  final String publishedAt;

  /// Feature requests shipped with this release note.
  final List<ChangelogLinkedRequest> linkedRequests;

  /// Creates a [ChangelogEntry] release note item.
  const ChangelogEntry({
    required this.id,
    required this.title,
    required this.body,
    this.versionLabel,
    required this.publishedAt,
    this.linkedRequests = const [],
  });

  /// Deserializes [ChangelogEntry] from a JSON map.
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

/// Confirmation result returned when subscribing an email to changelog notifications.
///
/// Returned by `POST /api/v1/public/apps/:appKey/changelog/subscribe`.
///
/// ### Example
/// ```dart
/// final result = await client.subscribeToChangelog('user@example.com', userToken: token);
/// if (result.alreadySubscribed) {
///   print('User was already subscribed');
/// } else if (result.subscribed) {
///   print('Successfully subscribed to email updates!');
/// }
/// ```
class ChangelogSubscriptionResult {
  /// Whether the email is now actively subscribed.
  final bool subscribed;

  /// Whether the email address had already been subscribed previously.
  final bool alreadySubscribed;

  /// Creates a [ChangelogSubscriptionResult] record.
  const ChangelogSubscriptionResult({
    required this.subscribed,
    required this.alreadySubscribed,
  });

  /// Deserializes [ChangelogSubscriptionResult] from a server JSON response.
  factory ChangelogSubscriptionResult.fromJson(Map<String, dynamic> json) {
    return ChangelogSubscriptionResult(
      subscribed: json['subscribed'] as bool? ?? false,
      alreadySubscribed: json['alreadySubscribed'] as bool? ?? false,
    );
  }
}

/// Confirmation result returned when unsubscribing from changelog updates.
///
/// Returned by `POST /api/v1/public/apps/:appKey/changelog/unsubscribe`.
///
/// ### Example
/// ```dart
/// final result = await client.unsubscribeFromChangelog('user@example.com');
/// if (result.unsubscribed) {
///   print('Unsubscribed from email updates.');
/// }
/// ```
class ChangelogUnsubscribeResult {
  /// Whether the email was successfully unsubscribed.
  final bool unsubscribed;

  /// Creates a [ChangelogUnsubscribeResult] record.
  const ChangelogUnsubscribeResult({
    required this.unsubscribed,
  });

  /// Deserializes [ChangelogUnsubscribeResult] from a server JSON response.
  factory ChangelogUnsubscribeResult.fromJson(Map<String, dynamic> json) {
    return ChangelogUnsubscribeResult(
      unsubscribed: json['unsubscribed'] as bool? ?? false,
    );
  }
}
