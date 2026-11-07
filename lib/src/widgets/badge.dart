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
        // ignore: deprecated_member_use
        : (customColor?.withOpacity(0.12) ?? colors.chipBg);
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

  /// Parses a 6-digit hex color, returning null (falling back to the theme's
  /// chip colors) for null, empty, wrong-length, or non-hex values. Total on
  /// purpose: `columnColor` is unvalidated server data and a throwing parse
  /// here would crash the whole screen build (issue #91).
  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }
}
