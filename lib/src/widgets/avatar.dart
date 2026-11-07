import 'package:flutter/material.dart';
import '../theme/cupthread_theme.dart';

/// Avatar widget displaying image or initials.
class Avatar extends StatelessWidget {
  final String? url;
  final String? name;
  final double size;

  const Avatar({
    super.key,
    this.url,
    this.name,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);

    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(colors),
        ),
      );
    }

    return _buildFallback(colors);
  }

  Widget _buildFallback(dynamic colors) {
    final trimmed = name?.trim() ?? '';
    // First user-perceived character, not the first UTF-16 code unit: a
    // lone high surrogate renders as U+FFFD. `characters` (re-exported by
    // flutter/widgets) keeps emoji, flags, ZWJ sequences, and combining
    // marks intact.
    final initial = trimmed.isNotEmpty
        ? trimmed.characters.first.toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.chipBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
