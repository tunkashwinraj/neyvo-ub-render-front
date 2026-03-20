import 'tenant_config.dart';

/// API helper to load tenant configuration from the backend.
/// This app is Goodwin University only; fallback is always Goodwin theme.
class TenantApi {
  static Future<TenantConfig> fetchConfig() async {
    // Tenant endpoint is deprecated. Runtime branding is organization-scoped.
    return TenantConfig.defaultGoodwin;
  }
}

