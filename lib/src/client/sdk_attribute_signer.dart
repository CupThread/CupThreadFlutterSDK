import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilities for canonicalizing and signing end-user payment attributes
/// for `PUT /api/v1/public/apps/:appKey/user` (cpt-user-attrs-v1 protocol).
///
/// End-user payment attributes (`isPaying`, `mrr`, `plan`) require an
/// HMAC-SHA256 signature produced with the app's per-app SDK signing secret.
class SdkAttributeSigner {
  const SdkAttributeSigner._();

  /// The domain tag version for this signature scheme.
  static const String version = 'cpt-user-attrs-v1';

  /// Default freshness window in seconds (±300s from server time).
  static const int freshnessSeconds = 300;

  /// Formats [value] to the canonical number string used by cpt-user-attrs-v1.
  ///
  /// The value is formatted with two fraction digits (round-half-even IEEE 754
  /// double formatting, `toFixed(2)` semantics), stripping trailing zeros
  /// and any trailing decimal point (e.g. `1200.00` -> `'1200'`, `99.50` -> `'99.5'`).
  static String canonicalNumber(num value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'mrr must be a finite number');
    }
    final fixed = value.toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    if (dot == -1) return fixed;
    var end = fixed.length;
    while (end > dot && fixed[end - 1] == '0') {
      end--;
    }
    if (end > dot && fixed[end - 1] == '.') {
      end--;
    }
    return fixed.substring(0, end);
  }

  static String _canonicalField(
    Map<String, dynamic> raw,
    String key, [
    String Function(dynamic)? render,
  ]) {
    if (!raw.containsKey(key)) {
      return 'unset';
    }
    final value = raw[key];
    if (value == null) {
      return 'null';
    }
    return render != null ? render(value) : value.toString();
  }

  /// Builds the newline-delimited canonical string (cpt-user-attrs-v1)
  /// without a trailing newline.
  ///
  /// Specification:
  /// ```text
  /// cpt-user-attrs-v1
  /// <appKey>
  /// <userToken>
  /// <isPaying: true|false|unset>
  /// <plan: value|null|unset>
  /// <mrr: canonicalNumber|null|unset>
  /// <currency: valueAsSent|unset>
  /// <timestamp: epochSeconds>
  /// ```
  static String canonicalize({
    required String appKey,
    required String userToken,
    required int timestamp,
    Map<String, dynamic>? raw,
    bool? isPaying,
    String? plan,
    num? mrr,
    String? currency,
  }) {
    final effectiveRaw = <String, dynamic>{};
    if (raw != null) {
      effectiveRaw.addAll(raw);
    } else {
      if (isPaying != null) effectiveRaw['isPaying'] = isPaying;
      if (plan != null) effectiveRaw['plan'] = plan;
      if (mrr != null) effectiveRaw['mrr'] = mrr;
      if (currency != null) effectiveRaw['currency'] = currency;
    }

    return [
      version,
      appKey,
      userToken,
      _canonicalField(
        effectiveRaw,
        'isPaying',
        (v) => (v == true || v == 'true') ? 'true' : 'false',
      ),
      _canonicalField(effectiveRaw, 'plan', (v) => v.toString()),
      _canonicalField(effectiveRaw, 'mrr', (v) {
        if (v is num) return canonicalNumber(v);
        final parsed = num.tryParse(v.toString());
        if (parsed != null) return canonicalNumber(parsed);
        throw ArgumentError.value(v, 'mrr', 'mrr must be a number');
      }),
      _canonicalField(effectiveRaw, 'currency', (v) => v.toString()),
      timestamp.toString(),
    ].join('\n');
  }

  /// Signs the payload using HMAC-SHA256 with [secret].
  ///
  /// Returns a 64-character lowercase hexadecimal digest.
  static String sign({
    required String secret,
    required String appKey,
    required String userToken,
    required int timestamp,
    Map<String, dynamic>? raw,
    bool? isPaying,
    String? plan,
    num? mrr,
    String? currency,
  }) {
    if (secret.isEmpty) {
      throw ArgumentError.value(secret, 'secret', 'SDK signing secret cannot be empty');
    }
    final canonical = canonicalize(
      appKey: appKey,
      userToken: userToken,
      timestamp: timestamp,
      raw: raw,
      isPaying: isPaying,
      plan: plan,
      mrr: mrr,
      currency: currency,
    );
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(canonical));
    return digest.toString();
  }

  /// Verifies a signature against expected input and freshness window.
  static bool verify({
    required String secret,
    required String signature,
    required String appKey,
    required String userToken,
    required int timestamp,
    Map<String, dynamic>? raw,
    bool? isPaying,
    String? plan,
    num? mrr,
    String? currency,
    int? currentEpochSeconds,
  }) {
    final now = currentEpochSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    if ((now - timestamp).abs() > freshnessSeconds) {
      return false;
    }
    final expected = sign(
      secret: secret,
      appKey: appKey,
      userToken: userToken,
      timestamp: timestamp,
      raw: raw,
      isPaying: isPaying,
      plan: plan,
      mrr: mrr,
      currency: currency,
    );
    return _constantTimeEquals(expected, signature.toLowerCase());
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
