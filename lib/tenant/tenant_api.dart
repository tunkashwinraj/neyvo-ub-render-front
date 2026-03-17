import '../api/spearia_api.dart';
import 'tenant_config.dart';

/// API helper to load tenant configuration from the backend.
/// This app is Goodwin University only; fallback is always Goodwin theme.
class TenantApi {
  static Future<TenantConfig> fetchConfig() async {
    try {
      final res = await SpeariaApi.getJsonMap('/api/tenant/config');
      return TenantConfig.fromJson(res);
    } catch (_) {
      return TenantConfig.defaultGoodwin;
    }
  }
}

