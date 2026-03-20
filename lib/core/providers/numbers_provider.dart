import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/managed_profiles/managed_profile_api_service.dart';
import '../../neyvo_pulse_api.dart';
import 'account_provider.dart';
import 'api_provider.dart';

part 'numbers_provider.g.dart';

class NumbersData {
  const NumbersData({
    required this.account,
    required this.numbers,
    required this.profiles,
  });

  final Map<String, dynamic> account;
  final List<Map<String, dynamic>> numbers;
  final List<Map<String, dynamic>> profiles;
}

@riverpod
class NumbersNotifier extends _$NumbersNotifier {
  @override
  Future<NumbersData> build() async {
    ref.watch(speariaApiProvider);
    final results = await Future.wait([
      ref.read(accountInfoProvider.future),
      NeyvoPulseApi.listNumbers(),
      ManagedProfileApiService.listProfiles(),
    ]);
    final account = Map<String, dynamic>.from(results[0] as Map);
    final numbersRes = Map<String, dynamic>.from(results[1] as Map);
    final profilesRes = Map<String, dynamic>.from(results[2] as Map);
    final raw =
        (numbersRes['numbers'] as List?) ?? (numbersRes['items'] as List?) ?? const [];
    final numbers =
        raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final profiles = ((profilesRes['profiles'] as List?)?.cast<dynamic>() ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return NumbersData(account: account, numbers: numbers, profiles: profiles);
  }
}
