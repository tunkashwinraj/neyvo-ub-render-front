// lib/services/user_timezone_service.dart
// Caches user's timezone from Settings and provides timezone-aware date formatting.

import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Caches the user's selected timezone from Settings.
/// Updated when settings load (app init, settings page) and when user saves settings.
class UserTimezoneService {
  static String? _cachedTimezone;

  /// Current timezone (IANA, e.g. 'America/New_York'). Defaults to 'America/New_York' if not set.
  static String get currentTimezone =>
      (_cachedTimezone?.trim().isNotEmpty == true) ? _cachedTimezone! : 'America/New_York';

  /// Set the cached timezone (call when settings load or save).
  static void setTimezone(String? timezone) {
    final t = (timezone ?? '').trim();
    _cachedTimezone = t.isNotEmpty ? t : 'America/New_York';
  }

  /// Get tz.Location for current timezone. Returns UTC location if invalid.
  static tz.Location get _location {
    try {
      return tz.getLocation(currentTimezone);
    } catch (_) {
      return tz.UTC;
    }
  }

  /// Parse raw value to DateTime (UTC). Returns null if unparseable.
  /// API timestamps without 'Z' are treated as UTC.
  static DateTime? _parseUtc(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.isUtc ? raw : DateTime.utc(raw.year, raw.month, raw.day, raw.hour, raw.minute, raw.second, raw.millisecond);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    // Treat API timestamps without timezone as UTC
    final hasTz = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
    final toParse = hasTz ? s : '${s}Z';
    final dt = DateTime.tryParse(toParse);
    return dt;
  }

  /// Convert UTC DateTime to user's timezone as TZDateTime.
  static tz.TZDateTime _toUserTz(DateTime utc) {
    final loc = _location;
    return tz.TZDateTime.from(utc, loc);
  }

  /// Format a date/time in the user's selected timezone.
  /// [raw] can be ISO string, DateTime, or milliseconds since epoch.
  /// [pattern] is intl DateFormat pattern (default: 'yyyy-MM-dd HH:mm').
  /// Returns '—' if null/unparseable.
  static String format(dynamic raw, {String pattern = 'yyyy-MM-dd HH:mm'}) {
    final dt = _parseUtc(raw);
    if (dt == null) return '—';
    try {
      final tzDt = _toUserTz(dt);
      return DateFormat(pattern).format(tzDt);
    } catch (_) {
      return DateFormat(pattern).format(dt.toLocal());
    }
  }

  /// Short date+time: "Mar 4, 2025 2:30 PM"
  static String formatShort(dynamic raw) =>
      format(raw, pattern: "MMM d, yyyy h:mm a");

  /// Date only: "2025-03-04"
  static String formatDateOnly(dynamic raw) =>
      format(raw, pattern: 'yyyy-MM-dd');

  /// Full 12h: "Wed, Feb 25, 2026 at 2:00 PM" (for callbacks)
  static String formatCallback12h(dynamic raw) =>
      format(raw, pattern: "EEE, MMM d, yyyy 'at' h:mm a");
}
