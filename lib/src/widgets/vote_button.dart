import 'package:flutter/material.dart';
import '../theme/cupthread_theme.dart';

/// Upvote button with optimistic UI state.
class VoteButton extends StatelessWidget {
  final int voteCount;
  final bool hasVoted;
  final VoidCallback onPress;
  final bool disabled;

  const VoteButton({
    super.key,
    required this.voteCount,
    required this.hasVoted,
    required this.onPress,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);

    final bg = hasVoted ? colors.voteActiveBg : colors.voteInactiveBg;
    final border = hasVoted ? colors.primary : colors.border;
    final fg = hasVoted ? colors.voteActiveText : colors.voteInactiveText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          constraints: const BoxConstraints(minWidth: 44),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '▲',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                voteCount.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
