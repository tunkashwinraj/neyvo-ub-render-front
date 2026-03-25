// Flutter web: calls window.neyvoAria from web/neyvo_vapi_bridge.js (see index.html).
//
// dart:js_util is provided by the web compiler (ddc/dart2js); the VM analyzer may
// not resolve it — web build still succeeds.
// ignore_for_file: uri_does_not_exist, deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'dart:js' as js;
import 'dart:js_util' as js_util;

// #region agent log
void _agentDebugLog(String location, String message, Map<String, Object?> data, String hypothesisId) {
  try {
    final body = jsonEncode({
      'sessionId': 'e71456',
      'location': location,
      'message': message,
      'data': {...data, 'hypothesisId': hypothesisId},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'hypothesisId': hypothesisId,
      'runId': data['runId'] ?? 'pre-fix',
    });
    unawaited(
      html.HttpRequest.request(
        'http://127.0.0.1:7489/ingest/925cfa1d-bc90-457f-bdcb-898a7040d985',
        method: 'POST',
        requestHeaders: {
          'Content-Type': 'application/json',
          'X-Debug-Session-Id': 'e71456',
        },
        sendData: body,
      ).then((_) {}, onError: (_) {}),
    );
  } catch (_) {}
}
// #endregion

Map<String, dynamic>? _parseBridgePayload(String eventType, dynamic detail) {
  if (detail == null) return null;
  if (detail is String) {
    final s = detail.trim();
    if (s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      if (eventType == 'error') {
        return {'message': s};
      }
    }
    return null;
  }
  // Stale cached neyvo_vapi_bridge.js may still pass raw objects; best-effort only.
  try {
    final out = <String, dynamic>{};
    for (final key in const ['message', 'who', 'text']) {
      try {
        final v = js_util.getProperty(detail, key);
        if (v != null) {
          out[key] = v.toString();
        }
      } catch (_) {}
    }
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

/// Resolves `window.neyvoAria` as a [js.JsObject].
/// Do not use [js_util.callMethod] on this value — use [js.JsObject.callMethod] only.
js.JsObject _neyvoAriaApi() {
  final v = js.context['neyvoAria'];
  if (v == null) {
    throw StateError('neyvoAria is not defined on window.');
  }
  return v as js.JsObject;
}

Future<void> ariaVapiWaitForBridgeReady({Duration timeout = const Duration(seconds: 45)}) async {
  final until = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(until)) {
    final ready = js.context['neyvoAriaReady'];
    final api = js.context['neyvoAria'];
    if (ready == true && api != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError(
    'Vapi bridge did not load (neyvoAria). Add web/neyvo_vapi_bridge.js to index.html and allow cdn.jsdelivr.net / esm.sh.',
  );
}

Future<void> ariaVapiBridgeStart({
  required String publicKey,
  required String assistantId,
  required String sessionId,
  required String accountId,
  required String operatorId,
  required void Function(String type, Map<String, dynamic>? detail) onEvent,
}) async {
  await ariaVapiWaitForBridgeReady();
  final api = _neyvoAriaApi();
  final meta = js_util.jsify(<String, dynamic>{
    'session_id': sessionId,
    'account_id': accountId,
    'operator_id': operatorId,
  });
  final cb = js_util.allowInterop((dynamic type, dynamic detail) {
    final eventType = type?.toString() ?? '';
    // JS bridge sends JSON strings (see web/neyvo_vapi_bridge.js `emitToFlutter`).
    final m = _parseBridgePayload(eventType, detail);
    onEvent(eventType, m);
    // #region agent log
    if (eventType == 'transcript' || eventType == 'error') {
      _agentDebugLog(
        'aria_vapi_bridge_web.dart:cb',
        'bridge event',
        {
          'eventType': eventType,
          'detailIsString': detail is String,
          'payloadChars': detail is String ? detail.length : -1,
          'mapNull': m == null,
          'hasText': m?.containsKey('text') ?? false,
          'hasWho': m?.containsKey('who') ?? false,
          'hasMessage': m?.containsKey('message') ?? false,
        },
        'H-json',
      );
    }
    // #endregion
  });
  final dynamic result = api.callMethod('start', [
    publicKey,
    assistantId,
    meta,
    cb,
  ]);
  // Do not await the JS Promise from [start] in Dart (interop can break under DDC).
  // Completion and errors come through [onEvent].
  // #region agent log
  _agentDebugLog(
    'aria_vapi_bridge_web.dart:start',
    'after callMethod start',
    {
      'resultIsNull': result == null,
      'resultIsJsObject': result is js.JsObject,
      'hasThenProp': result is js.JsObject ? result.hasProperty('then') : false,
      'skipPromiseToFuture': true,
    },
    'H1',
  );
  // #endregion
}

void ariaVapiBridgeStop() {
  try {
    _neyvoAriaApi().callMethod('stop', []);
  } catch (_) {
    /* Bridge may be torn down mid-call; avoid cascading errors. */
  }
}

void ariaVapiBridgeSetMuted(bool muted) {
  try {
    _neyvoAriaApi().callMethod('setMuted', [muted]);
  } catch (_) {}
}
