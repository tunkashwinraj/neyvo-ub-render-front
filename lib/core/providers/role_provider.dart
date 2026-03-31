import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/user_role.dart';
import 'account_provider.dart';

part 'role_provider.g.dart';

@riverpod
UserRole userRole(UserRoleRef ref) {
  final account = ref.watch(accountInfoProvider);
  return account.when(
    data: (data) {
      final roleRaw = (data['role'] ?? '').toString().trim().toLowerCase();
      switch (roleRaw) {
        case 'owner':
        case 'super_admin':
          return UserRole.owner;
        case 'admin':
          return UserRole.admin;
        case 'staff':
        case 'viewer':
        case 'member':
          return UserRole.member;
        default:
          return UserRole.unknown;
      }
    },
    loading: () => UserRole.unknown,
    error: (_, __) => UserRole.unknown,
  );
}
