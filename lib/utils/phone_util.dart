// lib/utils/phone_util.dart
// Single source of truth for US phone normalization to E.164.
// Accepts: (123) 456-7890, 123-456-7890, 123.456.7890, +1 (123) 456-7890,
// 1-123-456-7890, 1234567890, +11234567890, Excel scientific (1.56E+10, 5.55E+09).

/// Extracts digits from raw input. Handles Excel scientific notation.
String _extractDigits(String raw) {
  if (raw.isEmpty) return '';
  final s = raw.trim();
  // Excel stores numbers as scientific notation
  if (s.toLowerCase().contains('e')) {
    try {
      final val = double.tryParse(s);
      if (val != null && val >= 1e9 && val < 1e11) {
        return val.toInt().toString();
      }
    } catch (_) {}
  }
  return s.replaceAll(RegExp(r'\D'), '');
}

/// Normalizes US phone to E.164 (+1XXXXXXXXXX). Returns empty string if invalid.
/// Accepts all common formats including Excel scientific notation.
String normalizeToE164Us(String? raw) {
  final digits = _extractDigits(raw ?? '');
  if (digits.isEmpty) return '';
  if (digits.length == 10) return '+1$digits';
  if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
  return '';
}

/// Normalizes to E.164 when possible; otherwise returns trimmed input.
/// Use when you want to accept user input and prefer E.164 when valid.
String normalizePhoneInput(String? raw) {
  final normalized = normalizeToE164Us(raw);
  if (normalized.isNotEmpty) return normalized;
  return (raw ?? '').trim();
}

/// True if [storedDisplayPhone] matches [query] for list/search UIs.
///
/// Stored values are usually E.164 (+1…) while users often type Excel/CSV-style
/// numbers with spaces, parentheses, or dashes. [name.contains] alone misses those.
bool phoneMatchesSearchQuery(String? storedDisplayPhone, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return true;
  final ph = (storedDisplayPhone ?? '').trim();
  if (ph.isEmpty) return false;
  if (ph.toLowerCase().contains(raw.toLowerCase())) return true;
  final qDigits = _extractDigits(raw);
  if (qDigits.length < 3) return false;
  final pDigits = _extractDigits(ph);
  if (pDigits.isEmpty) return false;
  if (qDigits.length == 10) {
    var p10 = pDigits;
    if (p10.length == 11 && p10.startsWith('1')) {
      p10 = p10.substring(1);
    } else if (p10.length > 10) {
      p10 = p10.substring(p10.length - 10);
    }
    if (p10 == qDigits) return true;
  }
  return pDigits.contains(qDigits) || qDigits.contains(pDigits);
}
