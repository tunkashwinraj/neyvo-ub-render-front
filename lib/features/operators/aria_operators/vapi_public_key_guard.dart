/// Detects documentation placeholders mistakenly stored as the Vapi public key.
bool isPlaceholderVapiPublicKey(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  if (v.isEmpty) return false;
  const bad = {
    'vapi_public_key',
    'public_key',
    'vapi_key',
    'next_public_vapi_key',
    'your_vapi_public_key',
    'changeme',
    'placeholder',
    'test',
    'api_key',
  };
  return bad.contains(v);
}

bool isLikelyMalformedVapiPublicKey(String? value) {
  final raw = (value ?? '');
  final v = raw.trim().replaceAll('"', '').replaceAll("'", '').trim();
  if (v.isEmpty) return true;
  if (v.contains('\n') || v.contains('\r') || v.contains(' ')) return true;
  // Private/secret keys must never be used in browser SDK.
  if (v.startsWith('sk_') || v.startsWith('vapi_sk_')) return true;
  final valid = RegExp(r'^[A-Za-z0-9._-]{20,200}$');
  return !valid.hasMatch(v);
}
