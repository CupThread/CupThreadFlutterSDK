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

