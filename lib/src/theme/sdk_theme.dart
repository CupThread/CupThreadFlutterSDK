import 'package:flutter/material.dart';
import '../models/config.dart';

/// Resolved color palette for CupThread Flutter UI widgets.
class CupThreadColors {
  final Color background;
  final Color card;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primaryHover;
  final Color primaryText;
  final Color border;
  final Color inputBg;
  final Color inputBorder;
  final Color accent;
  final Color voteActiveBg;
  final Color voteActiveText;
  final Color voteInactiveBg;
  final Color voteInactiveText;
  final Color chipBg;
  final Color chipText;
  final Color divider;

  const CupThreadColors({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryHover,
    required this.primaryText,
    required this.border,
    required this.inputBg,
    required this.inputBorder,
    required this.accent,
    required this.voteActiveBg,
    required this.voteActiveText,
    required this.voteInactiveBg,
    required this.voteInactiveText,
    required this.chipBg,
    required this.chipText,
    required this.divider,
  });

  static const light = CupThreadColors(
    background: Color(0xFFF8FAFC),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    primary: Color(0xFF2563EB),
    primaryHover: Color(0xFF1D4ED8),
    primaryText: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFCBD5E1),
    accent: Color(0xFF3B82F6),
    voteActiveBg: Color(0xFFEFF6FF),
    voteActiveText: Color(0xFF2563EB),
    voteInactiveBg: Color(0xFFF1F5F9),
    voteInactiveText: Color(0xFF64748B),
    chipBg: Color(0xFFF1F5F9),
    chipText: Color(0xFF334155),
    divider: Color(0xFFE2E8F0),
  );

  static const dark = CupThreadColors(
    background: Color(0xFF090D16),
    card: Color(0xFF131B2E),
    cardBorder: Color(0xFF1E293B),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    primary: Color(0xFF3B82F6),
    primaryHover: Color(0xFF60A5FA),
    primaryText: Color(0xFFFFFFFF),
    border: Color(0xFF1E293B),
    inputBg: Color(0xFF0F172A),
    inputBorder: Color(0xFF334155),
    accent: Color(0xFF60A5FA),
    voteActiveBg: Color(0xFF1E3A8A),
    voteActiveText: Color(0xFF93C5FD),
    voteInactiveBg: Color(0xFF1E293B),
    voteInactiveText: Color(0xFF94A3B8),
    chipBg: Color(0xFF1E293B),
    chipText: Color(0xFFCBD5E1),
    divider: Color(0xFF1E293B),
  );

  static const midnight = CupThreadColors(
    background: Color(0xFF030712),
    card: Color(0xFF0F172A),
    cardBorder: Color(0xFF1F293D),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    primary: Color(0xFF6366F1),
    primaryHover: Color(0xFF818CF8),
    primaryText: Color(0xFFFFFFFF),
    border: Color(0xFF1F293D),
    inputBg: Color(0xFF0F172A),
    inputBorder: Color(0xFF334155),
    accent: Color(0xFF818CF8),
    voteActiveBg: Color(0xFF312E81),
    voteActiveText: Color(0xFFC7D2FE),
    voteInactiveBg: Color(0xFF1F293D),
    voteInactiveText: Color(0xFF94A3B8),
    chipBg: Color(0xFF1F293D),
    chipText: Color(0xFFCBD5E1),
    divider: Color(0xFF1F293D),
  );

  static const ocean = CupThreadColors(
    background: Color(0xFFF0FDFA),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFCCFBF1),
    textPrimary: Color(0xFF134E4A),
    textSecondary: Color(0xFF115E59),
    textMuted: Color(0xFF5EEAD4),
    primary: Color(0xFF0D9488),
    primaryHover: Color(0xFF0F766E),
    primaryText: Color(0xFFFFFFFF),
    border: Color(0xFFCCFBF1),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFF99F6E4),
    accent: Color(0xFF14B8A6),
    voteActiveBg: Color(0xFFCCFBF1),
    voteActiveText: Color(0xFF0F766E),
    voteInactiveBg: Color(0xFFF0FDFA),
    voteInactiveText: Color(0xFF115E59),
    chipBg: Color(0xFFE6FFFA),
    chipText: Color(0xFF0D9488),
    divider: Color(0xFFCCFBF1),
  );

  static const forest = CupThreadColors(
    background: Color(0xFFF7FEE7),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFD9F99D),
    textPrimary: Color(0xFF365314),
    textSecondary: Color(0xFF4D7C0F),
    textMuted: Color(0xFF84CC16),
    primary: Color(0xFF65A30D),
    primaryHover: Color(0xFF4D7C0F),
    primaryText: Color(0xFFFFFFFF),
    border: Color(0xFFD9F99D),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFBEF264),
    accent: Color(0xFF84CC16),
    voteActiveBg: Color(0xFFECFCCB),
    voteActiveText: Color(0xFF4D7C0F),
    voteInactiveBg: Color(0xFFF7FEE7),
    voteInactiveText: Color(0xFF4D7C0F),
    chipBg: Color(0xFFF7FEE7),
    chipText: Color(0xFF365314),
    divider: Color(0xFFD9F99D),
  );

  static const sunset = CupThreadColors(
    background: Color(0xFFFFF7ED),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFFFEDD5),
    textPrimary: Color(0xFF7C2D12),
    textSecondary: Color(0xFF9A3412),
    textMuted: Color(0xFFFDBA74),
    primary: Color(0xFFEA580C),
    primaryHover: Color(0xFFC2410C),
    primaryText: Color(0xFFFFFFFF),
    border: Color(0xFFFED7AA),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFFDBA74),
    accent: Color(0xFFF97316),
    voteActiveBg: Color(0xFFFFEDD5),
    voteActiveText: Color(0xFFC2410C),
    voteInactiveBg: Color(0xFFFFF7ED),
    voteInactiveText: Color(0xFF9A3412),
    chipBg: Color(0xFFFFEDD5),
    chipText: Color(0xFF7C2D12),
    divider: Color(0xFFFED7AA),
  );

  static const candy = CupThreadColors(
    background: Color(0xFFFDF4FF),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFFAE8FF),
    textPrimary: Color(0xFF701A75),
    textSecondary: Color(0xFF86198F),
    textMuted: Color(0xFFF0ABFC),
    primary: Color(0xFFC026D3),
    primaryHover: Color(0xFFA21CAF),
    primaryText: Color(0xFFFFFFFF),
    border: Color(0xFFF5D0FE),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFF0ABFC),
    accent: Color(0xFFD946EF),
    voteActiveBg: Color(0xFFFAE8FF),
    voteActiveText: Color(0xFFA21CAF),
    voteInactiveBg: Color(0xFFFDF4FF),
    voteInactiveText: Color(0xFF86198F),
    chipBg: Color(0xFFFAE8FF),
    chipText: Color(0xFF701A75),
    divider: Color(0xFFF5D0FE),
  );

  static CupThreadColors resolve(SdkTheme theme, {bool isDarkMode = false}) {
    switch (theme) {
      case SdkTheme.light:
        return light;
      case SdkTheme.dark:
        return dark;
      case SdkTheme.midnight:
        return midnight;
      case SdkTheme.ocean:
        return ocean;
      case SdkTheme.forest:
        return forest;
      case SdkTheme.sunset:
        return sunset;
      case SdkTheme.candy:
        return candy;
      case SdkTheme.system:
      default:
        return isDarkMode ? dark : light;
    }
  }
}
