import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../tenant/tenant_config.dart' as tenant;
import '../repositories/tenant_repository.dart';

part 'tenant_provider.g.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository(ref);
});

@riverpod
class TenantConfig extends _$TenantConfig {
  @override
  Future<tenant.TenantConfig> build() async {
    ref.keepAlive();
    final repo = ref.watch(tenantRepositoryProvider);
    return repo.getTenantConfig();
  }
}

