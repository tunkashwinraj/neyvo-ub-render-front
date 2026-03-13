// #region agent log
// Debug session logging: sends NDJSON to ingest endpoint for analysis.
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

const _sessionId = 'd2cfd5';
const _endpoint = 'http://127.0.0.1:7272/ingest/7a600e15-272a-4fa7-b08b-296a92dc7e88';

void debugSessionLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
  final payload = <String, dynamic>{
    'sessionId': _sessionId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'hypothesisId': hypothesisId,
  };
  if (kIsWeb) {
    http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json', 'X-Debug-Session-Id': _sessionId},
      body: jsonEncode(payload),
    ).catchError((_) {});
  }
}
// #endregion
