import 'package:flutter/material.dart';
import '../client/feedback_client.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';

/// Turnstile preflight for the voting surfaces.
///
/// Apps whose config enables `requireAnonymousVoteTurnstile` reject anonymous
/// votes without a Cloudflare Turnstile token (403
/// [TurnstileRequiredException]). The voting surfaces resolve the token
/// ahead of the network call so a missing token never causes a doomed
/// request followed by an optimistic-update rollback flicker.

/// Whether casting [isCastingNewVote] as an anonymous user on [config]
/// requires a Turnstile token before the vote request. Removing a vote is
/// never verified, and an unresolved config fails open (the server still
/// rejects, surfacing the localized verification copy through the exception
/// mapping).
bool voteNeedsTurnstilePreflight(
  PublicAppConfig? config,
  bool isAnon,
  bool isCastingNewVote,
) =>
    config != null &&
    config.requireAnonymousVoteTurnstile &&
    isAnon &&
    isCastingNewVote;

/// Resolves a Turnstile token for an anonymous vote through the client's
/// configured provider.
///
/// Returns null — after surfacing the localized verification notice — when
/// no provider is configured, the provider yields nothing, or it throws.
/// The messenger and the copy are captured before the provider runs so the
/// [BuildContext] is never touched across the async gap.
Future<String?> resolveVoteTurnstileToken(
  BuildContext context,
  FeedbackClient client,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final verificationCopy =
      CupThreadTheme.stringsOf(context).verificationRequired;
  final provider = client.config.turnstileTokenProvider;
  String? token;
  if (provider != null) {
    try {
      token = (await provider())?.trim();
    } catch (_) {
      token = null;
    }
  }
  if (token != null && token.isNotEmpty) return token;
  messenger?.showSnackBar(SnackBar(content: Text(verificationCopy)));
  return null;
}
