// Stub: Vapi JS bridge exists only on Flutter web (dart.library.html).

Future<void> ariaVapiWaitForBridgeReady({Duration timeout = const Duration(seconds: 45)}) async {
  throw UnsupportedError('ARIA Vapi bridge is only available on Flutter web.');
}

Future<void> ariaVapiBridgeStart({
  required String publicKey,
  required String assistantId,
  required String sessionId,
  required String accountId,
  required String operatorId,
  required void Function(String type, Map<String, dynamic>? detail) onEvent,
}) async {
  throw UnsupportedError('ARIA Vapi bridge is only available on Flutter web.');
}

void ariaVapiBridgeStop() {}

void ariaVapiBridgeSetMuted(bool muted) {}
