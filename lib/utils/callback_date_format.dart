// lib/utils/callback_date_format.dart
// Format callback_at for display in 12-hour AM/PM using user's selected timezone.

import '../services/user_timezone_service.dart';

/// Formats a callback time (ISO string or DateTime) for display in user's timezone.
/// Returns e.g. "Wed, Feb 25, 2026 at 2:00 PM" (12-hour with AM/PM).
/// Returns empty string if raw is null or unparseable.
String formatCallbackTime12h(dynamic raw) {
  if (raw == null) return '';
  final s = UserTimezoneService.formatCallback12h(raw);
  return s == '—' ? '' : s;
}
