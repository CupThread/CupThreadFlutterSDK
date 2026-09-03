import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/cupthread_theme.dart';
import '../utils/formatters.dart';
import 'avatar.dart';
import 'badge.dart';
import 'comments_view.dart';
import 'markdown_text.dart';
import 'vote_button.dart';

/// Bottom sheet presenting complete feature request details and discussion.
class FeatureRequestDetailSheet extends StatefulWidget {
  final FeatureRequestItem item;
  final ValueChanged<FeatureRequestItem>? onVoteChange;

  const FeatureRequestDetailSheet({
    super.key,
    required this.item,
    this.onVoteChange,
  });

  static Future<void> show(
    BuildContext context, {
    required FeatureRequestItem item,
    ValueChanged<FeatureRequestItem>? onVoteChange,
  }) {
    final client = CupThreadTheme.clientOf(context);
    final token = CupThreadTheme.userTokenOf(context);

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CupThreadTheme(
        client: client,
        userToken: token,
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
            ),
          ),
        ),
      ),
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

    final client = CupThreadTheme.clientOf(context);
    final userToken = CupThreadTheme.userTokenOf(context);

    final nextVoted = !_item.hasVoted;
    final nextCount = _item.voteCount + (nextVoted ? 1 : -1);
    final optimistic = _item.copyWith(
      hasVoted: nextVoted,
      voteCount: nextCount < 0 ? 0 : nextCount,
    );

    setState(() {
      _item = optimistic;
      _isVoting = true;
    });
    widget.onVoteChange?.call(optimistic);

    try {
      final res = await client.toggleVote(_item.id, userToken: userToken);
      final confirmed = _item.copyWith(
        hasVoted: res.voted,
        voteCount: res.voteCount,
      );
      if (mounted) {
        setState(() {
          _item = confirmed;
          _isVoting = false;
        });
        widget.onVoteChange?.call(confirmed);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _item = widget.item;
          _isVoting = false;
        });
        widget.onVoteChange?.call(widget.item);
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
