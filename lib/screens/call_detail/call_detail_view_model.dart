// lib/screens/call_detail/call_detail_view_model.dart
// Pure helpers for lean Firestore + optional Vapi merge maps (snake_case + camelCase).

/// First non-empty string among keys on [m].
String cdStr(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

int? cdInt(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    if (v is int) return v;
    if (v is double) return v.round();
    final p = int.tryParse(v.toString());
    if (p != null) return p;
  }
  return null;
}

double? cdDouble(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final p = double.tryParse(v.toString());
    if (p != null) return p;
  }
  return null;
}

bool cdBool(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is bool) return v;
    final s = v?.toString().toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
  }
  return false;
}

Map<String, dynamic>? cdMap(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// Primary display id for app bar / copy.
String cdPrimaryCallId(Map<String, dynamic> m) {
  return cdStr(m, [
    'vapi_call_id',
    'call_id',
    'call_sid',
    'id',
  ]);
}

String cdFromNumber(Map<String, dynamic> m) {
  return cdStr(m, ['from', 'customer_phone', 'student_phone']);
}

String cdToNumber(Map<String, dynamic> m) {
  return cdStr(m, ['to']);
}

String cdContactName(Map<String, dynamic> m) {
  return cdStr(m, ['customer_name', 'student_name']);
}

String cdTranscript(Map<String, dynamic> m) {
  return cdStr(m, ['transcript', 'transcription']);
}

String cdSummary(Map<String, dynamic> m) {
  return cdStr(m, ['summary', 'analysis_summary', 'ai_summary']);
}

String cdSentiment(Map<String, dynamic> m) {
  return cdStr(m, ['sentiment', 'customer_sentiment', 'ai_sentiment']);
}

String cdRecordingUrl(Map<String, dynamic> m) {
  return cdStr(m, ['recording_url', 'recordingUrl']);
}

String cdStereoUrl(Map<String, dynamic> m) {
  return cdStr(m, ['stereo_recording_url', 'stereoRecordingUrl']);
}

String cdStatus(Map<String, dynamic> m) {
  return cdStr(m, ['status']);
}

String cdIntentLine(Map<String, dynamic> m) {
  return cdStr(m, ['intent', 'service_requested', 'outcome', 'outcome_type']);
}

/// Structured analysis / booking — may be nested.
Map<String, dynamic>? cdStructuredAnalysis(Map<String, dynamic> m) {
  return cdMap(m, 'analysis_structured_data');
}

Map<String, dynamic>? cdConfigSnapshot(Map<String, dynamic> m) {
  return cdMap(m, 'config_snapshot');
}

bool cdHasBilling(Map<String, dynamic> m) {
  return cdInt(m, ['credits_charged']) != null ||
      cdDouble(m, ['charged_amount_usd']) != null ||
      cdBool(m, ['billing_failed']);
}

bool cdHasCostBlock(Map<String, dynamic> m) {
  if (cdDouble(m, ['cost_usd', 'cost']) != null) return true;
  if (cdInt(m, ['duration_seconds', 'duration']) != null) return true;
  final cb = cdMap(m, 'cost_breakdown');
  return cb != null && cb.isNotEmpty;
}

bool cdHasPerformance(Map<String, dynamic> m) {
  if (m['average_latency_ms'] != null || m['averageLatency'] != null) return true;
  if (m['max_latency_ms'] != null || m['maxLatency'] != null) return true;
  if (m['interruptions_count'] != null || m['interruptionsCount'] != null) return true;
  if (m['messages_count'] != null || m['messagesCount'] != null) return true;
  final fs = cdStr(m, ['function_summary']);
  if (fs.isNotEmpty) return true;
  final tc = m['tool_calls'] ?? m['toolCalls'];
  return tc is List && tc.isNotEmpty;
}

bool cdHasTurnByTurn(Map<String, dynamic> m) {
  final msg = m['messages'];
  final hist = m['history'];
  if (msg is List && msg.isNotEmpty) return true;
  if (hist is List && hist.isNotEmpty) return true;
  return false;
}

/// Truncate for chip display.
String cdTruncate(String s, [int max = 120]) {
  final t = s.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

/// Format structured map entries for chips (skip huge values).
List<MapEntry<String, String>> cdStructuredEntries(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) return [];
  final out = <MapEntry<String, String>>[];
  var i = 0;
  for (final e in raw.entries) {
    if (i++ >= 24) break;
    final v = e.value;
    String vs;
    if (v == null) {
      vs = '';
    } else if (v is Map || v is List) {
      vs = cdTruncate(v.toString(), 80);
    } else {
      vs = cdTruncate(v.toString(), 160);
    }
    out.add(MapEntry(e.key.toString(), vs));
  }
  return out;
}

/// Keys to show in kDebugMode "Technical snapshot" (not full merged map).
const kDebugCallFieldAllowlist = <String>[
  'vapi_call_id',
  'call_id',
  'call_sid',
  'id',
  'account_id',
  'business_id',
  'status',
  'vapi_status',
  'type',
  'direction',
  'duration_seconds',
  'duration',
  'cost_usd',
  'cost',
  'credits_charged',
  'charged_amount_usd',
  'billing_failed',
  'recording_url',
  'ended_reason',
  'campaign_id',
  'student_id',
  'assistant_id',
  'phone_number_id',
  'profile_id',
  'booking_id',
  'booking_created',
  'messages_count',
  'transcript',
  'summary',
];

String cdDebugAllowlistedDump(Map<String, dynamic> m) {
  final buf = StringBuffer();
  for (final k in kDebugCallFieldAllowlist) {
    if (!m.containsKey(k)) continue;
    final v = m[k];
    var line = v?.toString() ?? '';
    if (k == 'transcript' && line.length > 500) {
      line = '${line.substring(0, 500)}… [truncated]';
    }
    buf.writeln('$k: $line');
  }
  return buf.toString().trimRight();
}
