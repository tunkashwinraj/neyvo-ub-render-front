import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tenant/tenant_api.dart';
import '../../tenant/tenant_config.dart';
import '../providers/api_provider.dart';

class TenantRepository {
  TenantRepository(this.ref);

  final Ref ref;

  Future<TenantConfig> getTenantConfig() async {
    ref.watch(speariaApiProvider);
    return TenantApi.fetchConfig();
  }
}

