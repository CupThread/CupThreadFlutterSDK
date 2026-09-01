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
    String message = 'Anonymous access is disabled for this surface; a user token is required.',
  ]) : super(message);
}

/// Thrown when the CupThread API returns an unexpected HTTP response status.
class UnexpectedStatusException extends FeedbackException {
  final int status;
  final String responseBody;

  const UnexpectedStatusException(this.status, this.responseBody)
      : super('CupThread API responded with unexpected status HTTP $status: $responseBody');
}

/// Thrown when response parsing or network transport fails.
class InvalidResponseException extends FeedbackException {
  final Object? cause;

  const InvalidResponseException([
    String message = 'Failed to parse response from CupThread API',
    this.cause,
  ]) : super(message);
}

/// Thrown when attachment upload response cannot be parsed.
class UnreadableUploadResponseException extends FeedbackException {
  const UnreadableUploadResponseException([
    String message = 'Attachment upload completed but server response could not be parsed.',
  ]) : super(message);
}
