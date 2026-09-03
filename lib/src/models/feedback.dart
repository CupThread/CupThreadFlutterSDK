import 'platform.dart';

/// Storage backend category of an uploaded attachment.
///
/// Indicates whether the file is stored in Cloudflare Images or Cloudflare R2 object storage.
///
/// ### Example
/// ```dart
/// final kind = AttachmentKind.fromWire('image'); // AttachmentKind.image
/// ```
enum AttachmentKind {
  /// Cloudflare Images storage for PNG, JPEG, WEBP, and GIF screenshots.
  image('image'),

  /// Cloudflare R2 object storage for logs, diagnostics, and generic files.
  r2('r2');

  /// Wire string identifier for API serialization.
  final String wireValue;

  /// Creates an [AttachmentKind] with the associated [wireValue].
  const AttachmentKind(this.wireValue);

  /// Parses a wire string representation into an [AttachmentKind].
  ///
  /// Returns [AttachmentKind.image] if [value] is `'image'`, otherwise defaults to [AttachmentKind.r2].
  ///
  /// ### Example
  /// ```dart
  /// final kind = AttachmentKind.fromWire('r2'); // AttachmentKind.r2
  /// ```
  static AttachmentKind fromWire(String? value) {
    if (value == 'image') return AttachmentKind.image;
    return AttachmentKind.r2;
  }
}

/// Metadata and URL describing an uploaded file or screenshot attachment.
///
/// Attached to [FeedbackDraft] submissions for bug reports and user feedback.
///
/// ### Example
/// ```dart
/// final attachment = FeedbackAttachment(
///   kind: AttachmentKind.image,
///   key: 'img_abc123',
///   url: 'https://imagedelivery.net/.../public',
///   filename: 'screenshot.png',
///   mimeType: 'image/png',
///   size: 102400,
/// );
/// ```
class FeedbackAttachment {
  /// Storage kind (image or generic R2 file).
  final AttachmentKind kind;

  /// Unique storage identifier or object key.
  final String key;

  /// Publicly accessible HTTPS URL of the hosted attachment.
  final String url;

  /// Original filename of the uploaded file.
  final String? filename;

  /// MIME type of the uploaded file (e.g. `'image/png'`).
  final String? mimeType;

  /// Size of the uploaded file in bytes.
  final int? size;

  /// Creates a [FeedbackAttachment] metadata record.
  const FeedbackAttachment({
    required this.kind,
    required this.key,
    required this.url,
    this.filename,
    this.mimeType,
    this.size,
  });

  /// Deserializes [FeedbackAttachment] from a JSON map.
  factory FeedbackAttachment.fromJson(Map<String, dynamic> json) {
    return FeedbackAttachment(
      kind: AttachmentKind.fromWire(json['kind'] as String?),
      key: json['key'] as String? ?? json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String?,
      mimeType: json['mimeType'] as String?,
      size: (json['size'] as num?)?.toInt(),
    );
  }

  /// Serializes [FeedbackAttachment] to a JSON map.
  Map<String, dynamic> toJson() => {
    'kind': kind.wireValue,
    'key': key,
    'url': url,
    if (filename != null) 'filename': filename,
    if (mimeType != null) 'mimeType': mimeType,
    if (size != null) 'size': size,
  };
}

/// Data payload for submitting user feedback, bug reports, and suggestions.
///
/// Encapsulates title, description, reporter info, platform runtime, and optional diagnostics.
///
/// ### Example
/// ```dart
/// final draft = FeedbackDraft(
///   title: 'Dark mode contrast is too low in settings',
///   description: 'The toggle button text is hard to read when dark mode is enabled.',
///   reporterName: 'Jordan',
///   reporterEmail: 'jordan@example.com',
///   platform: FeedbackPlatform.current,
///   appVersion: '1.2.0',
///   buildNumber: '42',
///   metadata: {'screen': 'SettingsView', 'osVersion': '17.4'},
/// );
///
/// final result = await client.submit(draft);
/// print('Submitted ID: ${result.submissionId}');
/// ```
class FeedbackDraft {
  /// Short title summarizing the feedback or issue.
  final String title;

  /// Detailed description of the user feedback or steps to reproduce.
  final String description;

  /// Optional self-reported name of the submitting user.
  final String? reporterName;

  /// Optional email address for reply notifications.
  final String? reporterEmail;

  /// Target platform where the feedback was generated.
  final FeedbackPlatform platform;

  /// Application version string (e.g. `'1.0.4'`).
  final String? appVersion;

  /// Application build or compilation number (e.g. `'12'`).
  final String? buildNumber;

  /// Custom key-value diagnostic metadata (device info, screen names, state).
  final Map<String, String> metadata;

  /// List of uploaded screenshot or log attachments.
  final List<FeedbackAttachment> attachments;

  /// Creates a [FeedbackDraft] ready for submission.
  const FeedbackDraft({
    required this.title,
    required this.description,
    this.reporterName,
    this.reporterEmail,
    required this.platform,
    this.appVersion,
    this.buildNumber,
    this.metadata = const {},
    this.attachments = const [],
  });

  /// Serializes [FeedbackDraft] to a JSON payload ready for `POST /api/v1/feedback`.
  ///
  /// Injects SDK branding, platform wire value, and ISO 8601 submission timestamp into [metadata].
  Map<String, dynamic> toJson({required String appKey, required String submittedAt}) {
    final meta = Map<String, String>.from(metadata);
    meta['sdk'] = 'cupthread-flutter';
    meta['platform'] = platform.wireValue;
    meta['submittedAt'] = submittedAt;

    return {
      'appKey': appKey,
      'title': title.trim(),
      'description': description.trim(),
      if (reporterName != null && reporterName!.trim().isNotEmpty)
        'reporterName': reporterName!.trim(),
      if (reporterEmail != null && reporterEmail!.trim().isNotEmpty)
        'reporterEmail': reporterEmail!.trim(),
      'platform': platform.wireValue,
      if (appVersion != null && appVersion!.trim().isNotEmpty)
        'appVersion': appVersion!.trim(),
      if (buildNumber != null && buildNumber!.trim().isNotEmpty)
        'buildNumber': buildNumber!.trim(),
      'metadata': meta,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }
}

/// Confirmation result returned after submitting feedback to the CupThread API.
///
/// Contains the newly generated submission ID and GitHub Discussion sync status if configured.
///
/// ### Example
/// ```dart
/// final result = await client.submit(draft);
/// if (result.forwardedToGithub) {
///   print('Synced to GitHub Discussion: ${result.githubDiscussionUrl}');
/// }
/// ```
class FeedbackSubmissionResult {
  /// Unique database ID of the created feedback record.
  final String submissionId;

  /// Whether the feedback was forwarded to a GitHub Discussion.
  final bool forwardedToGithub;

  /// GitHub Discussion ID if forwarded.
  final String? githubDiscussionId;

  /// Public web URL of the created GitHub Discussion if forwarded.
  final String? githubDiscussionUrl;

  /// Optional non-fatal warning message from the server.
  final String? warning;

  /// Creates a [FeedbackSubmissionResult] record.
  const FeedbackSubmissionResult({
    required this.submissionId,
    required this.forwardedToGithub,
    this.githubDiscussionId,
    this.githubDiscussionUrl,
    this.warning,
  });

  /// Deserializes [FeedbackSubmissionResult] from a server JSON response.
  factory FeedbackSubmissionResult.fromJson(Map<String, dynamic> json) {
    return FeedbackSubmissionResult(
      submissionId: json['submissionId'] as String? ?? json['id'] as String? ?? '',
      forwardedToGithub: json['forwardedToGithub'] as bool? ?? false,
      githubDiscussionId: json['githubDiscussionId'] as String?,
      githubDiscussionUrl: json['githubDiscussionUrl'] as String?,
      warning: json['warning'] as String?,
    );
  }
}
