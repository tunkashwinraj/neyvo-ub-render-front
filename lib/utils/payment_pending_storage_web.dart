// Web: store/read payment pending in sessionStorage for success message.
import 'dart:convert';
import 'dart:html' as html;

const String _key = 'neyvo_payment_pending';

void setPaymentPending({String? pack, double? amountDollars}) {
  final map = <String, dynamic>{};
  if (pack != null) map['pack'] = pack;
  if (amountDollars != null) map['amountDollars'] = amountDollars;
  html.window.sessionStorage[_key] = jsonEncode(map);
}

Map<String, dynamic>? getPaymentPending() {
  final raw = html.window.sessionStorage[_key];
  if (raw == null || raw.isEmpty) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
}

void removePaymentPending() {
  html.window.sessionStorage.remove(_key);
}
