import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import '../utils/formatters.dart';
import 'avatar.dart';
import 'badge.dart';
import 'comments_view.dart';
import 'markdown_text.dart';
import 'vote_button.dart';
import 'vote_turnstile.dart';

/// How a [FeatureRequestDetailSheet] vote change reached the host.
enum FeatureRequestVoteEventKind {
  /// The in-sheet optimistic projection computed before the vote request
  /// was sent — not server truth.
  optimistic,

  /// The server's vote response — the only kind that carries an
  /// authoritative `hasVoted`/`voteCount` pair.
  confirmed,

  /// The pre-vote snapshot restored after the vote request failed.
  rollback,
}

/// Signature for [FeatureRequestDetailSheet.onVoteEvent].
typedef FeatureRequestVoteEventHandler = void Function(
  FeatureRequestVoteEventKind kind,
  FeatureRequestItem item,
);

/// Bottom sheet presenting complete feature request details and discussion.
class FeatureRequestDetailSheet extends StatefulWidget {
  final FeatureRequestItem item;

  /// Called for every vote-state change regardless of origin. Prefer
  /// [onVoteEvent], which distinguishes optimistic projections, confirmed
  /// responses, and rollbacks — this callback reports all three alike.
  final ValueChanged<FeatureRequestItem>? onVoteChange;

  /// Called for every vote-state change together with the [kind] that
  /// produced it. Hosts that reconcile list rows from this callback need
  /// the kind: a stale [FeatureRequestVoteEventKind.confirmed] item
  /// reconciles a reloaded row's global `voteCount`, while
  /// [FeatureRequestVoteEventKind.optimistic] and
  /// [FeatureRequestVoteEventKind.rollback] items are projections of the
  /// sheet-open snapshot and must never overwrite a reloaded row.
  final FeatureRequestVoteEventHandler? onVoteEvent;

  const FeatureRequestDetailSheet({
    super.key,
    required this.item,
    this.onVoteChange,
    this.onVoteEvent,
  });

  static Future<void> show(
    BuildContext context, {
    required FeatureRequestItem item,
    ValueChanged<FeatureRequestItem>? onVoteChange,
    FeatureRequestVoteEventHandler? onVoteEvent,
  }) {
    // Capture the host scope (theme, strings, locale, session, config,
    // policies) before pushing the route so the sheet renders identically.
    final sheet = CupThreadTheme.carryScope(
      context,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (sheetCtx, scrollController) => Container(
          decoration: BoxDecoration(
            color: CupThreadTheme.of(sheetCtx).background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: FeatureRequestDetailSheet(
            item: item,
            onVoteChange: onVoteChange,
            onVoteEvent: onVoteEvent,
          ),
        ),
      ),
    );

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => sheet,
    );
  }

  @override
  State<FeatureRequestDetailSheet> createState() => _FeatureRequestDetailSheetState();
}

class _FeatureRequestDetailSheetState extends State<FeatureRequestDetailSheet> {
  late FeatureRequestItem _item;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _handleToggleVote() async {
    if (_item.isOwnRequest || _isVoting) return;

    // Mirror the list screens' anonymous-vote gate. Config and anonymity are
    // read through the sheet context, which resolves the scope carried in by
    // [FeatureRequestDetailSheet.show] — so the host's policy applies even
    // though the route re-wraps the content in a fresh [CupThreadTheme].
    final config = CupThreadTheme.configOf(context, listen: false);
    final isAnon = CupThreadTheme.isAnonymous(context);
    if (config != null && !config.allowAnonymousVote && isAnon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(CupThreadTheme.stringsOf(context).signInRequiredToVote)),
      );
      return;
    }

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    // Lock the sheet first so taps during a pending Turnstile preflight
    // cannot start overlapping verification or vote requests. The lock is
    // released on every exit path below.
    setState(() {
      _isVoting = true;
    });

    // The pre-vote snapshot: null until the optimistic update ran, so a
    // preflight that bailed early has nothing to roll back.
    FeatureRequestItem? previousItem;
    try {
      // Turnstile preflight, mirroring the list screens: casting a new vote
      // on an app that requires anonymous-vote verification resolves the
      // token before the optimistic update. Removing a vote is never
      // verified.
      String? voteToken;
      if (voteNeedsTurnstilePreflight(config, isAnon, !_item.hasVoted)) {
        voteToken = await resolveVoteTurnstileToken(context, client);
        if (!mounted || voteToken == null) return;
      }

      previousItem = _item;
      final nextVoted = !_item.hasVoted;
      final nextCount = _item.voteCount + (nextVoted ? 1 : -1);
      final optimistic = _item.copyWith(
        hasVoted: nextVoted,
        voteCount: nextCount < 0 ? 0 : nextCount,
      );

      setState(() {
        _item = optimistic;
      });
      widget.onVoteChange?.call(optimistic);
      widget.onVoteEvent?.call(FeatureRequestVoteEventKind.optimistic, optimistic);

      final res = previousItem.hasVoted
          ? await client.removeVote(previousItem.id, userToken: userToken)
          : await client.castVote(previousItem.id,
              userToken: userToken, turnstileToken: voteToken);
      final confirmed = _item.copyWith(
        hasVoted: res.voted,
        voteCount: res.voteCount,
      );
      if (mounted) {
        setState(() {
          _item = confirmed;
        });
        widget.onVoteChange?.call(confirmed);
        widget.onVoteEvent?.call(FeatureRequestVoteEventKind.confirmed, confirmed);
      }
    } catch (_) {
      // Copy out so the null check promotes: a local written inside a try
      // block is not promotable in the catch clause.
      final rollbackTarget = previousItem;
      if (mounted && rollbackTarget != null) {
        setState(() {
          _item = rollbackTarget;
        });
        widget.onVoteChange?.call(rollbackTarget);
        widget.onVoteEvent?.call(FeatureRequestVoteEventKind.rollback, rollbackTarget);
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);
    final strings = CupThreadTheme.stringsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          strings.featureRequests,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _item.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        children: [
                          if (_item.columnName != null)
                            BadgeChip(
                              label: _item.columnName!,
                              colorHex: _item.columnColor,
                            ),
                          if (_item.versionLabel != null)
                            BadgeChip(
                              label: 'v${_item.versionLabel}',
                              isOutline: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                VoteButton(
                  voteCount: _item.voteCount,
                  hasVoted: _item.hasVoted,
                  onPress: _handleToggleVote,
                  disabled: _item.isOwnRequest || _isVoting,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Avatar(
                  url: _item.requesterAvatarUrl,
                  name: _item.requesterName,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text(
                  _item.requesterName ?? strings.anonymous,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text('•', style: TextStyle(color: colors.textMuted)),
                const SizedBox(width: 6),
                Text(
                  formatRelativeDate(_item.createdAt, strings: strings),
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.cardBorder),
              ),
              child: MarkdownText(content: _item.description),
            ),
            const SizedBox(height: 20),
            CommentsView(featureRequestId: _item.id),
          ],
        ),
      ),
    );
  }
}
