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
    final initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim().substring(0, 1).toUpperCase()
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
