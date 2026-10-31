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

/// Metadata describing an uploaded file or screenshot attachment.
///
/// Attached to [FeedbackDraft] submissions for bug reports and user feedback.
/// Files uploaded through the governed upload-session flow carry an
/// [uploadId], which [FeedbackDraft.toJson] forwards to the submission so the
/// stored bytes become reachable through the authorized
/// `/api/v1/feedback/attachments/{id}/download` route. Legacy deployments
/// that still return direct storage coordinates populate [key] and [url].
///
/// ### Example
/// ```dart
/// final attachment = FeedbackAttachment(
///   kind: AttachmentKind.image,
///   uploadId: 'upl_abc123',
///   filename: 'screenshot.png',
///   mimeType: 'image/png',
///   size: 102400,
/// );
/// ```
class FeedbackAttachment {
  /// Storage kind (image or generic R2 file).
  final AttachmentKind kind;

  /// Reserved upload-session file slot backing the stored attachment.
  ///
  /// Returned by `POST /api/v1/uploads/images` and
  /// `PUT /api/v1/uploads/{uploadId}`; [FeedbackDraft.toJson] sends it to the
  /// submission endpoint as the reference that ties the stored file to the
  /// feedback record. Null only for legacy descriptors created before the
  /// upload-session flow.
  final String? uploadId;

  /// Legacy storage identifier or object key.
  ///
  /// The current API deliberately never returns an object key (PRIV-02), so
  /// this stays empty for session uploads; kept for display fallbacks and
  /// older self-hosted deployments.
  final String key;

  /// Legacy publicly accessible HTTPS URL of the hosted attachment.
  ///
  /// Empty for session uploads: stored attachments are only reachable through
  /// the authorized download endpoint.
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
    this.uploadId,
    this.key = '',
    this.url = '',
    this.filename,
    this.mimeType,
    this.size,
  });

  /// Deserializes [FeedbackAttachment] from a JSON map.
  ///
  /// Understands both current upload shapes — `ImageUploadResponse` and
  /// `UploadedFileResponse` ([uploadId] plus file facts, no key/url) — and
  /// the legacy `key`/`url` shape.
  factory FeedbackAttachment.fromJson(Map<String, dynamic> json) {
    final uploadId = (json['uploadId'] as String?)?.trim();
    final mimeType = (json['mimeType'] ?? json['contentType']) as String?;
    final size = (json['size'] ?? json['sizeBytes']) as num?;
    return FeedbackAttachment(
      kind: AttachmentKind.fromWire(
        json['kind'] as String? ??
            (mimeType != null && mimeType.startsWith('image/')
                ? 'image'
                : null),
      ),
      uploadId: (uploadId == null || uploadId.isEmpty) ? null : uploadId,
      key: json['key'] as String? ?? json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String?,
      mimeType: mimeType,
      size: size?.toInt(),
    );
  }

  /// Serializes [FeedbackAttachment] to a JSON map.
  ///
  /// [uploadId] is trimmed so the serialized attachment reference matches the
  /// normalized IDs collected by [FeedbackDraft.toJson]; empty [key]/[url]
  /// values are omitted rather than sent as `''`, which the API's
  /// `AttachmentInput.url` (`format: uri`) would reject.
  Map<String, dynamic> toJson() {
    final normalizedUploadId = uploadId?.trim() ?? '';
    return {
      'kind': kind.wireValue,
      if (normalizedUploadId.isNotEmpty) 'uploadId': normalizedUploadId,
      if (key.isNotEmpty) 'key': key,
      if (url.isNotEmpty) 'url': url,
      if (filename != null) 'filename': filename,
      if (mimeType != null) 'mimeType': mimeType,
      if (size != null) 'size': size,
    };
  }
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
  /// Maximum number of attachments the submission endpoint accepts
  /// (`FeedbackSubmissionInput.attachments.uploadIds` `maxItems: 8`).
  static const int maxUploadIds = 8;

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

  /// Optional Cloudflare Turnstile verification token.
  final String? turnstileToken;

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
    this.turnstileToken,
  });

  /// Serializes [FeedbackDraft] to a JSON payload ready for `POST /api/v1/feedback`.
  ///
  /// Injects SDK branding, platform wire value, and ISO 8601 submission timestamp into [metadata].
  /// Attachments uploaded through the session flow are referenced by the
  /// top-level `uploadIds` array (the path the API uses to link stored files
  /// to the submission), and each `attachments` entry repeats its own
  /// `uploadId`. Throws [ArgumentError] when more than [maxUploadIds]
  /// attachments carry an upload ID — the API caps `uploadIds` at 8 and would
  /// reject the payload outright.
  ///
  /// The API's `platform` enum only accepts `ios`, `macos`, `android`, and
  /// `universal` — `web` is not accepted (a Flutter Web submission with
  /// `platform: "web"` is rejected with a schema-validation 400). The
  /// client-only [FeedbackPlatform.web] value is therefore serialized as
  /// `universal`, while `metadata.platform` keeps the precise runtime value
  /// (`web`) for support triage.
  Map<String, dynamic> toJson({required String appKey, required String submittedAt}) {
    final meta = Map<String, String>.from(metadata);
    meta['sdk'] = 'cupthread-flutter';
    meta['platform'] = platform.wireValue;
    meta['submittedAt'] = submittedAt;

    final uploadIds = [
      for (final attachment in attachments)
        if (attachment.uploadId != null && attachment.uploadId!.trim().isNotEmpty)
          attachment.uploadId!.trim(),
    ];
    if (uploadIds.length > maxUploadIds) {
      throw ArgumentError(
        'At most $maxUploadIds attachments can reference an uploadId; '
        'the submission endpoint caps uploadIds at ${FeedbackDraft.maxUploadIds}.',
      );
    }

    return {
      'appKey': appKey,
      'title': title.trim(),
      'description': description.trim(),
      if (reporterName != null && reporterName!.trim().isNotEmpty)
        'reporterName': reporterName!.trim(),
      if (reporterEmail != null && reporterEmail!.trim().isNotEmpty)
        'reporterEmail': reporterEmail!.trim(),
      // The API rejects `platform: "web"` at schema validation
      // (`universal` is the only cross-platform wire value), so the
      // client-only `web` descriptor maps to `universal` here;
      // `metadata.platform` above preserves the precise runtime platform.
      'platform': platform == FeedbackPlatform.web
          ? FeedbackPlatform.universal.wireValue
          : platform.wireValue,
      if (appVersion != null && appVersion!.trim().isNotEmpty)
        'appVersion': appVersion!.trim(),
      if (buildNumber != null && buildNumber!.trim().isNotEmpty)
        'buildNumber': buildNumber!.trim(),
      'metadata': meta,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      if (uploadIds.isNotEmpty) 'uploadIds': uploadIds,
      if (turnstileToken != null && turnstileToken!.trim().isNotEmpty)
        'turnstileToken': turnstileToken!.trim(),
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

  /// Optional machine-readable warning code from the server.
  final String? warningCode;

  /// Creates a [FeedbackSubmissionResult] record.
  const FeedbackSubmissionResult({
    required this.submissionId,
    required this.forwardedToGithub,
    this.githubDiscussionId,
    this.githubDiscussionUrl,
    this.warning,
    this.warningCode,
  });

  /// Deserializes [FeedbackSubmissionResult] from a server JSON response.
  factory FeedbackSubmissionResult.fromJson(Map<String, dynamic> json) {
    return FeedbackSubmissionResult(
      submissionId: json['submissionId'] as String? ?? json['id'] as String? ?? '',
      forwardedToGithub: json['forwardedToGithub'] as bool? ?? false,
      githubDiscussionId: json['githubDiscussionId'] as String?,
      githubDiscussionUrl: json['githubDiscussionUrl'] as String?,
      warning: json['warning'] as String?,
      warningCode: json['warningCode'] as String?,
    );
  }
}
