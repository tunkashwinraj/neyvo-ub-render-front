import 'package:flutter/material.dart';

import '../theme/neyvo_theme.dart';
import 'tenant_scope.dart';

/// Tenant-aware brand helpers.
///
/// Many legacy screens use `NeyvoColors.*` which are UB-branded constants.
/// Use this helper when you need the current tenant's colors without
/// changing global constants (so UB remains unchanged).
class TenantBrand {
  static Color primary(BuildContext context) {
    final t = TenantScope.of(context)?.config;
    return t?.primaryColor ?? NeyvoColors.ubPurple;
  }

  static Color secondary(BuildContext context) {
    final t = TenantScope.of(context)?.config;
    return t?.secondaryColor ?? NeyvoColors.ubLightBlue;
  }

  static Color accent(BuildContext context) {
    final t = TenantScope.of(context)?.config;
    return t?.accentColor ?? (t?.secondaryColor ?? NeyvoColors.ubLightBlue);
  }

  static bool isGoodwin(BuildContext context) =>
      (TenantScope.of(context)?.config.tenantId ?? '').toLowerCase() == 'goodwin';
}

