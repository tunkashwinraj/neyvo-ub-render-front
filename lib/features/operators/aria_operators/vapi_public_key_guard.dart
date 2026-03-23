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
