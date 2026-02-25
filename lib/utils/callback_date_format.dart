// lib/utils/callback_date_format.dart
// Format callback_at for display in 12-hour AM/PM.

import 'package:intl/intl.dart';

/// Formats a callback time (ISO string or DateTime) for display.
/// Returns e.g. "Wed, Feb 25, 2026 at 2:00 PM" (12-hour with AM/PM).
/// Returns empty string if raw is null or unparseable.
String formatCallbackTime12h(dynamic raw) {
  if (raw == null) return '';
  try {
    final dt = raw is DateTime
        ? raw.toLocal()
        : DateTime.parse(raw.toString()).toLocal();
    return DateFormat("EEE, MMM d, yyyy 'at' h:mm a").format(dt);
  } catch (_) {
    return raw.toString();
  }
}
