import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/settings_model.dart';
import '../../neyvo_pulse_api.dart';
import 'api_provider.dart';

part 'settings_provider.g.dart';

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<SettingsModel> build() async {
    ref.watch(speariaApiProvider);
    final res = await NeyvoPulseApi.getSettings();
    return SettingsModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> updateSettings(Map<String, dynamic> payload) async {
    ref.read(speariaApiProvider);
    await NeyvoPulseApi.patchSettings(payload);
    ref.invalidateSelf();
  }

  Future<bool> sendTestEmail() async {
    ref.read(speariaApiProvider);
    return NeyvoPulseApi.sendTestEmail();
  }
}
