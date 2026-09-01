import 'platform.dart';

/// Storage kind of attachment.
enum AttachmentKind {
  image('image'),
  r2('r2');

  final String wireValue;
  const AttachmentKind(this.wireValue);

  static AttachmentKind fromWire(String? value) {
    if (value == 'image') return AttachmentKind.image;
    return AttachmentKind.r2;
  }
}

/// An uploaded file attachment.
class FeedbackAttachment {
  final AttachmentKind kind;
  final String key;
  final String url;
  final String? filename;
  final String? mimeType;
  final int? size;

  const FeedbackAttachment({
    required this.kind,
    required this.key,
    required this.url,
    this.filename,
    this.mimeType,
    this.size,
  });

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

  Map<String, dynamic> toJson() => {
    'kind': kind.wireValue,
    'key': key,
    'url': url,
    if (filename != null) 'filename': filename,
    if (mimeType != null) 'mimeType': mimeType,
    if (size != null) 'size': size,
  };
}

/// Draft feedback submission.
class FeedbackDraft {
  final String title;
  final String description;
  final String? reporterName;
  final String? reporterEmail;
  final FeedbackPlatform platform;
  final String? appVersion;
  final String? buildNumber;
  final Map<String, String> metadata;
  final List<FeedbackAttachment> attachments;

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

/// Result of submitting feedback.
class FeedbackSubmissionResult {
  final String submissionId;
  final bool forwardedToGithub;
  final String? githubDiscussionId;
  final String? githubDiscussionUrl;
  final String? warning;

  const FeedbackSubmissionResult({
    required this.submissionId,
    required this.forwardedToGithub,
    this.githubDiscussionId,
    this.githubDiscussionUrl,
    this.warning,
  });

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
