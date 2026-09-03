import 'package:flutter/material.dart';
import '../theme/cupthread_theme.dart';

/// Chip badge for column statuses and version tags.
class BadgeChip extends StatelessWidget {
  final String label;
  final String? colorHex;
  final bool isOutline;

  const BadgeChip({
    super.key,
    required this.label,
    this.colorHex,
    this.isOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CupThreadTheme.of(context);
    final customColor = _parseColor(colorHex);

    final bg = isOutline
        ? Colors.transparent
        : (customColor?.withValues(alpha: 0.12) ?? colors.chipBg);
    final textColor = customColor ?? colors.chipText;
    final borderColor = isOutline ? (customColor ?? colors.border) : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 6, bottom: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isOutline ? 1 : 0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return null;
  }
}
