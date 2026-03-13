// #region agent log
// Debug session logging: only sends to ingest when running on localhost (dev).
// On production (e.g. https://ub.neyvo.ai) we skip to avoid CORS/loopback errors.
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'debug_session_log_stub.dart' if (dart.library.html) 'debug_session_log_web.dart' as _origin;

const _sessionId = '7f92f3';
const _endpoint = 'http://127.0.0.1:7693/ingest/4dbef325-696e-4a3f-ac76-bda8c8d2b735';

bool _isLocalOrigin(String? origin) {
  if (origin == null || origin.isEmpty) return false;
  final o = origin.toLowerCase();
  return o.contains('localhost') || o.contains('127.0.0.1');
}

void debugSessionLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
  if (!kIsWeb) return;
  if (!_isLocalOrigin(_origin.currentWebOrigin)) return;
  final payload = <String, dynamic>{
    'sessionId': _sessionId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'hypothesisId': hypothesisId,
  };
  http.post(
    Uri.parse(_endpoint),
    headers: {'Content-Type': 'application/json', 'X-Debug-Session-Id': _sessionId},
    body: jsonEncode(payload),
  ).catchError((_) {});
}
// #endregion
