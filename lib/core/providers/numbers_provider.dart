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

  Future<Map<String, dynamic>> syncNumbersFromVapi() async {
    ref.read(speariaApiProvider);
    final r = await NeyvoPulseApi.syncNumbersFromVapi();
    ref.invalidateSelf();
    return r;
  }

  Future<Map<String, dynamic>> importNumberToOrg({
    required String provider,
    required String numberE164,
    String? friendlyName,
    bool setAsPrimary = true,
    String? twilioAccountSid,
    String? twilioAuthToken,
    String? telnyxApiKey,
    String? vonageApiKey,
    String? vonageApiSecret,
  }) async {
    ref.read(speariaApiProvider);
    final r = await NeyvoPulseApi.importNumber(
      provider: provider,
      numberE164: numberE164,
      friendlyName: friendlyName,
      setAsPrimary: setAsPrimary,
      twilioAccountSid: twilioAccountSid,
      twilioAuthToken: twilioAuthToken,
      telnyxApiKey: telnyxApiKey,
      vonageApiKey: vonageApiKey,
      vonageApiSecret: vonageApiSecret,
    );
    ref.invalidateSelf();
    return r;
  }

  Future<Map<String, dynamic>> attachProfileToNumber({
    required String profileId,
    required String phoneNumberId,
    required String vapiPhoneNumberId,
    bool forceMove = false,
  }) async {
    ref.read(speariaApiProvider);
    await ManagedProfileApiService.attachPhoneNumber(
      profileId: profileId,
      phoneNumberId: phoneNumberId,
      vapiPhoneNumberId: vapiPhoneNumberId,
      forceMove: forceMove,
    );
    ref.invalidateSelf();
    return const {'ok': true};
  }

  Future<Map<String, dynamic>> searchNumbersForPurchase({
    String country = 'US',
    String type = 'local',
    int limit = 20,
    String? areaCode,
    bool? voiceEnabled,
    bool? smsEnabled,
    bool? mmsEnabled,
    bool includeSuggested = true,
  }) async {
    ref.read(speariaApiProvider);
    return NeyvoPulseApi.searchNumbers(
      country: country,
      type: type,
      limit: limit,
      areaCode: areaCode,
      voiceEnabled: voiceEnabled,
      smsEnabled: smsEnabled,
      mmsEnabled: mmsEnabled,
      includeSuggested: includeSuggested,
    );
  }

  Future<Map<String, dynamic>> purchaseNumberForOrg({
    required String phoneNumber,
    required String friendlyName,
  }) async {
    ref.read(speariaApiProvider);
    final r = await NeyvoPulseApi.purchaseNumber(
      phoneNumber: phoneNumber,
      friendlyName: friendlyName,
    );
    ref.invalidateSelf();
    return r;
  }
}

@riverpod
class NumbersSyncBusy extends _$NumbersSyncBusy {
  @override
  bool build() => false;

  void setBusy(bool v) => state = v;
}

@riverpod
class NumbersImportBusy extends _$NumbersImportBusy {
  @override
  bool build() => false;

  void setBusy(bool v) => state = v;
}

@riverpod
class NumbersAttachBusy extends _$NumbersAttachBusy {
  @override
  Map<String, bool> build() => {};

  void setForNumber(String numberId, bool v) {
    final next = Map<String, bool>.from(state);
    if (v) {
      next[numberId] = true;
    } else {
      next.remove(numberId);
    }
    state = next;
  }
}
