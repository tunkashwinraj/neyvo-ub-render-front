// Single place to set the Neyvo backend base URL (staging, production, or local).
// Change [kNeyvoBackendUrl] to switch environments.
//
// Optional CI/local override without editing this file:
//   flutter run --dart-define=API_BASE_URL=https://...

/// Default backend URL (no trailing slash). Edit this value to point the app at
/// staging, production, or another host.
const String kNeyvoBackendUrl = 'https://neyvo-ub-render-back.onrender.com';

String _normalizeBaseUrl(String u) => u.trim().replaceAll(RegExp(r'/+$'), '');

/// Primary Neyvo API base URL (NeyvoApi, integration fallbacks).
///
/// Uses `--dart-define=API_BASE_URL=...` when set at build time; otherwise [kNeyvoBackendUrl].
String resolveNeyvoApiBaseUrl() {
  return _normalizeBaseUrl(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: kNeyvoBackendUrl,
    ),
  );
}
