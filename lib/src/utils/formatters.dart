import 'dart:math';

import '../theme/cupthread_strings.dart';

/// Formats an ISO 8601 string to a human-friendly relative date.
String formatRelativeDate(String? isoString, {CupThreadStrings? strings}) {
  if (isoString == null || isoString.isEmpty) return '';
  final date = DateTime.tryParse(isoString);
  if (date == null) return isoString;

  final now = DateTime.now().toUtc();
  final diff = now.difference(date.toUtc());

  final s = strings ?? CupThreadStrings.en;
  if (diff.inSeconds < 60) return s.justNow;
  if (diff.inMinutes < 60) return '${diff.inMinutes}${s.minutesAgoSuffix}';
  if (diff.inHours < 24) return '${diff.inHours}${s.hoursAgoSuffix}';
  if (diff.inDays < 7) return '${diff.inDays}${s.daysAgoSuffix}';

  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Formats byte count into a human-readable file size string.
String formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Generates a standard RFC 4122 v4 compliant UUID in pure Dart.
String generateUuid() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));

  values[6] = (values[6] & 0x0f) | 0x40; // version 4
  values[8] = (values[8] & 0x3f) | 0x80; // variant RFC4122

  String hex(int val) => val.toRadixString(16).padLeft(2, '0');

  return '${hex(values[0])}${hex(values[1])}${hex(values[2])}${hex(values[3])}-'
      '${hex(values[4])}${hex(values[5])}-'
      '${hex(values[6])}${hex(values[7])}-'
      '${hex(values[8])}${hex(values[9])}-'
      '${hex(values[10])}${hex(values[11])}${hex(values[12])}${hex(values[13])}${hex(values[14])}${hex(values[15])}';
}

/// Returns current UTC timestamp in ISO 8601 format.
String iso8601Now() {
  return DateTime.now().toUtc().toIso8601String();
}
