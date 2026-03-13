import '../api/spearia_api.dart';
import '../theme/neyvo_theme.dart';
import 'tenant_config.dart';

/// API helper to load tenant configuration from the backend.
class TenantApi {
  static Future<TenantConfig> fetchConfig() async {
    try {
      final res = await SpeariaApi.getJsonMap('/api/tenant/config');
      return TenantConfig.fromJson(res);
    } catch (_) {
      // Fallback to UB theme so the app is always usable even if the
      // tenant endpoint is temporarily unavailable.
      return TenantConfig(
        tenantId: 'ub',
        schoolName: 'Neyvo',
        primaryColor: NeyvoColors.ubPurple,
        secondaryColor: NeyvoColors.ubLightBlue,
        accentColor: NeyvoColors.ubLightBlueSoft,
      );
    }
  }
}

