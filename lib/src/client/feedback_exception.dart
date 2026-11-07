/// Base exception for all CupThread SDK operations.
class FeedbackException implements Exception {
  final String message;
  const FeedbackException(this.message);

  @override
  String toString() => 'FeedbackException: $message';
}

/// Thrown when anonymous access is disabled and user token was not provided.
class AuthenticationRequiredException extends FeedbackException {
  const AuthenticationRequiredException([
    super.message = 'Anonymous access is disabled for this surface; a user token is required.',
  ]);
}

/// Thrown when the CupThread API returns an unexpected HTTP response status.
class UnexpectedStatusException extends FeedbackException {
  final int status;

  /// Raw response body, retained for host diagnostics and logging only.
  ///
  /// Deliberately excluded from [message] and [toString()] so rendering a
  /// caught exception (e.g. `e.toString()` in a host catch handler) can never
  /// surface internal JSON/HTML payloads to end users.
  final String responseBody;

  const UnexpectedStatusException(this.status, this.responseBody)
      : super('CupThread API responded with unexpected status HTTP $status');

  @override
  String toString() => 'UnexpectedStatusException($status): $message';
}

/// Thrown when an intake endpoint (`POST /api/v1/feedback`,
/// `POST /api/v1/feature-requests`) rejects the submission because Cloudflare
/// Turnstile human verification is required or the supplied token failed.
///
/// Retry with a fresh token resolved through
/// `FeedbackClientConfig.turnstileTokenProvider` or a draft-level
/// `turnstileToken`.
class TurnstileRequiredException extends FeedbackException {
  /// Stable machine-readable error code.
  final String code;

  /// HTTP status code returned by the server (typically 403).
  final int status;

  /// Raw response body for host diagnostics and logging.
  final String responseBody;

  const TurnstileRequiredException([
    this.status = 403,
    this.responseBody = '',
  ])  : code = 'turnstile_required',
        super(
          'CupThread API requires human verification (Turnstile) before accepting this submission.',
        );

  @override
  String toString() => 'TurnstileRequiredException($status): $message';
}

/// Why an intake endpoint rejected a submission with HTTP 402 Payment
/// Required.
enum SubmissionQuotaReason {
  /// The workspace reached its monthly submission quota
  /// (API error code `tier_limit_submissions`).
  tierLimitSubmissions,

  /// The workspace subscription is inactive or canceled
  /// (API error code `subscription_inactive`).
  subscriptionInactive,
}

/// Thrown when an intake endpoint (`POST /api/v1/feedback`,
/// `POST /api/v1/feature-requests`) rejects a submission with HTTP 402
/// Payment Required because the workspace reached its monthly submission
/// quota or its subscription is inactive.
class SubmissionQuotaException extends FeedbackException {
  /// Which quota condition the server reported.
  final SubmissionQuotaReason reason;

  /// Stable machine-readable error code from the API response
  /// (`tier_limit_submissions` or `subscription_inactive`). Falls back to
  /// the canonical code for [reason] when the response carries none.
  ///
  /// Preserved for host diagnostics and logging only; deliberately excluded
  /// from [message] and [toString()] so rendering a caught exception can
  /// never surface response-derived text to end users.
  final String code;

  /// HTTP status code returned by the server (402).
  final int status;

  /// Raw response body for host diagnostics and logging.
  ///
  /// Deliberately excluded from [message] and [toString()] so rendering a
  /// caught exception can never surface internal payloads to end users.
  final String responseBody;

  SubmissionQuotaException({
    required this.reason,
    String? code,
    this.status = 402,
    this.responseBody = '',
  })  : code = code != null && code.isNotEmpty
            ? code
            : (reason == SubmissionQuotaReason.subscriptionInactive
                ? 'subscription_inactive'
                : 'tier_limit_submissions'),
        super(
          reason == SubmissionQuotaReason.subscriptionInactive
              ? 'CupThread workspace subscription is inactive; the submission was rejected (HTTP 402).'
              : 'CupThread workspace reached its monthly submission quota (HTTP 402).',
        );

  @override
  String toString() => 'SubmissionQuotaException($status): $message';
}

/// Why a CupThread intake endpoint or upload slot deterministically rejected
/// the request. Every reason is stable across retries with the same input —
/// the remedy is to change the request (replace a file, fix the identity),
/// never to retry blindly.
enum FeedbackRejectionReason {
  /// Content inspection rejected the file. Either the upload slot answered
  /// HTTP 415 for the stored bytes, or a referenced attachment failed the
  /// scan at submission time (HTTP 422 `scan_rejected`). The same file fails
  /// again on retry — remove or replace it.
  contentRejected,

  /// The file type is not accepted (`unsupported_mime_type` or
  /// `executable_extension_prohibited` at session creation). Let the user
  /// pick a different file.
  unsupportedFileType,

  /// The file exceeds the configured attachment size limit (HTTP 413
  /// `file_too_large` at session creation).
  fileTooLarge,

  /// The upload identity changed between session creation and submission
  /// (`uploader_mismatch`) or the session was created without one
  /// (`uploader_identity_required`). Fix the identity, then retry.
  uploaderMismatch,

  /// The slot or referenced upload was already consumed
  /// (`already_uploaded`, `session_not_pending`, `already_finalized`).
  /// Never retry the same `uploadId` — the winner owns it.
  alreadyUsed,

  /// Raw attachment URLs or storage keys were rejected
  /// (`direct_attachment_forbidden`) — attachments must reference verified
  /// upload sessions via `uploadId`.
  directAttachmentForbidden,
}

/// Thrown when an intake endpoint (`POST /api/v1/feedback`,
/// `POST /api/v1/feature-requests`, `POST /api/v1/uploads/sessions`) or an
/// upload slot (`PUT /api/v1/uploads/{uploadId}`) rejects the request with a
/// deterministic, code-bearing error (`scan_rejected`, `uploader_mismatch`,
/// `already_finalized`, …) or the status-only 415 content-scan rejection.
///
/// These rejections are deterministic: [reason] tells the host what to do
/// (replace a file, fix the identity, drop the upload) and the bundled UI
/// renders a specific message through `CupThreadStrings`
/// instead of the generic retryable error. Never retry automatically.
class FeedbackRejectionException extends FeedbackException {
  /// What kind of deterministic rejection the server reported.
  final FeedbackRejectionReason reason;

  /// Stable machine-readable error code from the API response (e.g.
  /// `scan_rejected`). Empty when matched on the HTTP status alone (the 415
  /// content-scan rejection carries no code).
  final String code;

  /// HTTP status code returned by the server.
  final int status;

  /// Raw response body for host diagnostics and logging.
  ///
  /// Deliberately excluded from [message] and [toString()] so rendering a
  /// caught exception can never surface internal payloads to end users.
  final String responseBody;

  // Non-const like SubmissionQuotaException: the message is derived from the
  // runtime [reason] and cannot be a const initializer.
  FeedbackRejectionException({
    required this.reason,
    required this.status,
    this.code = '',
    this.responseBody = '',
  }) : super(switch (reason) {
          FeedbackRejectionReason.contentRejected =>
            'Content inspection rejected the upload (HTTP $status); remove or replace the file.',
          FeedbackRejectionReason.unsupportedFileType =>
            'The file type is not accepted (HTTP $status); pick a different file.',
          FeedbackRejectionReason.fileTooLarge =>
            'The file exceeds the attachment size limit (HTTP $status).',
          FeedbackRejectionReason.uploaderMismatch =>
            'The upload identity does not match the session creator (HTTP $status).',
          FeedbackRejectionReason.alreadyUsed =>
            'The upload slot was already consumed (HTTP $status); do not retry the same uploadId.',
          FeedbackRejectionReason.directAttachmentForbidden =>
            'Direct attachment URLs and keys are forbidden (HTTP $status); reference a verified uploadId.',
        });

  @override
  String toString() => 'FeedbackRejectionException($status, ${reason.name}): $message';
}

/// Thrown when response parsing or network transport fails.
class InvalidResponseException extends FeedbackException {
  final Object? cause;

  const InvalidResponseException([
    super.message = 'Failed to parse response from CupThread API',
    this.cause,
  ]);
}

/// Thrown when attachment upload response cannot be parsed.
class UnreadableUploadResponseException extends FeedbackException {
  const UnreadableUploadResponseException([
    super.message = 'Attachment upload completed but server response could not be parsed.',
  ]);
}

/// Thrown when an SDK surface or action is disabled by remote feature flags.
class FeatureDisabledException extends FeedbackException {
  final String feature;

  const FeatureDisabledException(this.feature, [String? message])
      : super(message ?? 'Feature "$feature" is disabled by remote configuration.');
}

/// Thrown when an uploaded attachment exceeds the maximum allowed byte size.
class AttachmentTooLargeException extends FeedbackException {
  final int actualBytes;
  final int maxBytes;

  const AttachmentTooLargeException(this.actualBytes, this.maxBytes)
      : super('Attachment size ($actualBytes bytes) exceeds allowed limit of $maxBytes bytes.');
}

