/// Cloudflare Turnstile widget bindings and the hosted challenge page URL.
///
/// Every Turnstile siteverify call is bound to the `(action, cdata)` pair the
/// widget was rendered with, and a token minted under a different binding —
/// or with no binding at all — fails verification. Hosts implementing a
/// `FeedbackClientConfig.turnstileTokenProvider` (or minting tokens
/// server-side) must render the widget under the exact binding the gated
/// endpoint validates:
///
/// | Endpoint | `action` | `cdata` |
/// | --- | --- | --- |
/// | `POST /api/v1/feedback` | [TurnstileAction.feedback] | app key |
/// | `POST /api/v1/uploads/sessions` | [TurnstileAction.feedback] | app key |
/// | `POST /api/v1/feature-requests` | [TurnstileAction.featureRequest] | app key |
/// | `POST /api/v1/feature-requests/:id/vote` | [TurnstileAction.vote] | app key |
/// | `POST /api/v1/feature-requests/:id/vote` + `shipNotifyEmail` | [TurnstileAction.shipNotify] | app key |
///
/// Upload sessions intentionally reuse the feedback action: the server pins
/// the upload-session gate to the same `(action, cdata)` binding as feedback
/// intake, so one binding covers a submission's attachments and its intake
/// alike. Tokens are single-use — every gated call presents its own freshly
/// minted token.
library;

/// Server-aligned Cloudflare Turnstile widget `action` values for the
/// Turnstile-gated intake endpoints.
///
/// Render the widget (or mint a token server-side) with one of these actions
/// and the client's app key as `cdata` — e.g.
/// `turnstile.render({ action: 'feedback', cdata: appKey })`. Tokens minted
/// without a binding, or under a different action, are rejected by the
/// server's verification gate, so a `feature-request`-minted token cannot be
/// spent on feedback or upload intake, and vice versa.
abstract final class TurnstileAction {
  /// Binding shared by `POST /api/v1/feedback` and
  /// `POST /api/v1/uploads/sessions`.
  static const String feedback = 'feedback';

  /// Binding for `POST /api/v1/feature-requests`.
  static const String featureRequest = 'feature-request';

  /// Binding for `POST /api/v1/feature-requests/:id/vote`.
  static const String vote = 'vote';

  /// Binding for the ship-notification opt-in carried on a vote
  /// (`POST /api/v1/feature-requests/:id/vote` with `shipNotifyEmail`).
  static const String shipNotify = 'ship-notify';
}

/// The Cloudflare Turnstile widget binding a gated intake endpoint expects.
///
/// The SDK passes one of these to hosts through [TurnstileAction] constants
/// and `FeedbackClientConfig.makeTurnstileChallengeUrl`, so a token is always
/// minted under the binding the failing call used.
class TurnstileChallenge {
  /// The Cloudflare widget `action` the server binds verification to.
  final String action;

  /// The Cloudflare widget `cdata` the server binds verification to —
  /// always the SDK client's app key.
  final String cdata;

  /// Creates a challenge from an explicit binding.
  const TurnstileChallenge({required this.action, required this.cdata});

  /// The binding for feedback intake (`POST /api/v1/feedback`) and
  /// attachment upload-session creation (`POST /api/v1/uploads/sessions`).
  const TurnstileChallenge.feedback(String appKey)
      : this(action: TurnstileAction.feedback, cdata: appKey);

  /// The binding for feature-request submission
  /// (`POST /api/v1/feature-requests`).
  const TurnstileChallenge.featureRequest(String appKey)
      : this(action: TurnstileAction.featureRequest, cdata: appKey);

  /// The binding for voting on a feature request
  /// (`POST /api/v1/feature-requests/:id/vote`).
  const TurnstileChallenge.vote(String appKey)
      : this(action: TurnstileAction.vote, cdata: appKey);

  /// The binding for the ship-notification opt-in carried on a vote
  /// (`POST /api/v1/feature-requests/:id/vote` with `shipNotifyEmail`).
  const TurnstileChallenge.shipNotify(String appKey)
      : this(action: TurnstileAction.shipNotify, cdata: appKey);
}

/// The hosted Turnstile challenge page path served by the CupThread portal.
const String kTurnstileChallengePath = '/turnstile/verify';

/// Derives the hosted challenge page URL from an API base URL: a leading
/// `api.` host label becomes `app.`
/// (`https://api.cupthread.com` → `https://app.cupthread.com/turnstile/verify`)
/// and any other host keeps its origin. Query and fragment are stripped.
///
/// Deployment-specific portals — or a self-hosted API origin whose portal
/// lives elsewhere — pass an explicit
/// `FeedbackClientConfig.turnstileChallengeUrl` instead.
Uri? deriveTurnstileChallengePageUrl(String baseUrl) {
  final base = Uri.tryParse(baseUrl);
  if (base == null || base.host.isEmpty) return null;
  final host = base.host.startsWith('api.')
      ? 'app.${base.host.substring('api.'.length)}'
      : base.host;
  return Uri(
    scheme: base.scheme.isEmpty ? 'https' : base.scheme,
    host: host,
    port: base.hasPort ? base.port : null,
    path: kTurnstileChallengePath,
  );
}
