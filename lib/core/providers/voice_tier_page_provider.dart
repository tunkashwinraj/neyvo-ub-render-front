import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'voice_tier_page_provider.g.dart';

class VoiceTierUiState {
  const VoiceTierUiState({
    this.loading = true,
    this.error,
    this.wallet,
    this.updatingTier,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? wallet;
  final String? updatingTier;

  VoiceTierUiState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? wallet,
    String? updatingTier,
    bool clearError = false,
    bool clearUpdating = false,
  }) {
    return VoiceTierUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      wallet: wallet ?? this.wallet,
      updatingTier: clearUpdating ? null : (updatingTier ?? this.updatingTier),
    );
  }
}

@riverpod
class VoiceTierPageCtrl extends _$VoiceTierPageCtrl {
  @override
  VoiceTierUiState build() => const VoiceTierUiState();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final w = await NeyvoPulseApi.getBillingWallet(shellScoped: true);
      state = state.copyWith(loading: false, wallet: w);
    } catch (e) {
      if (isPulseRequestCancelled(e)) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> selectTier(String tier) async {
    if (state.updatingTier != null) return;
    state = state.copyWith(updatingTier: tier);
    try {
      await NeyvoPulseApi.setBillingTier(tier);
      await load();
    } finally {
      state = state.copyWith(clearUpdating: true);
    }
  }
}
