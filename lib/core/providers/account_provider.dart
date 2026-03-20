import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/account_repository.dart';

part 'account_provider.g.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref);
});

@riverpod
class AccountInfo extends _$AccountInfo {
  @override
  Future<Map<String, dynamic>> build() async {
    ref.keepAlive();
    final repo = ref.watch(accountRepositoryProvider);
    return repo.getAccountInfo();
  }
}

