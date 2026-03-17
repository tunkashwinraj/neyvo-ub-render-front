import '../api/spearia_api.dart';
import '../theme/neyvo_theme.dart';
import 'tenant_config.dart';

/// API helper to load tenant configuration from the backend.
class TenantApi {
  /// Fallback UB theme when tenant endpoint is unavailable (used by main.dart
  /// on timeout/error and by fetchConfig catch).
  static TenantConfig get ubFallback => TenantConfig(
        tenantId: 'ub',
        schoolName: 'Neyvo',
        primaryColor: NeyvoColors.ubPurple,
        secondaryColor: NeyvoColors.ubLightBlue,
        accentColor: NeyvoColors.ubLightBlueSoft,
      );

  static Future<TenantConfig> fetchConfig() async {
    try {
      final res = await SpeariaApi.getJsonMap('/api/tenant/config');
      return TenantConfig.fromJson(res);
    } catch (_) {
      return ubFallback;
    }
  }
}

