import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'plan_selector_page_provider.g.dart';

class PlanSelectorUiState {
  const PlanSelectorUiState({
    this.loading = true,
    this.error,
    this.subscription,
    this.updatingTo,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? subscription;
  final String? updatingTo;

  PlanSelectorUiState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? subscription,
    String? updatingTo,
    bool clearError = false,
    bool clearUpdating = false,
  }) {
    return PlanSelectorUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      subscription: subscription ?? this.subscription,
      updatingTo: clearUpdating ? null : (updatingTo ?? this.updatingTo),
    );
  }
}

@riverpod
class PlanSelectorPageCtrl extends _$PlanSelectorPageCtrl {
  @override
  PlanSelectorUiState build() => const PlanSelectorUiState();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final sub = await NeyvoPulseApi.getSubscription();
      state = state.copyWith(loading: false, subscription: sub);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Returns true if the plan was changed on the server.
  Future<bool> changePlan(String target) async {
    if (state.updatingTo != null) return false;
    state = state.copyWith(updatingTo: target);
    try {
      final current =
          (state.subscription?['tier'] ?? state.subscription?['subscription_tier'] ?? 'free').toString().toLowerCase();
      if (target == current) {
        state = state.copyWith(clearUpdating: true);
        return false;
      }
      if (target == 'free') {
        await NeyvoPulseApi.cancelSubscription();
      } else if (current == 'free') {
        await NeyvoPulseApi.subscribe(target);
      } else {
        await NeyvoPulseApi.upgradeSubscription(target);
      }
      await load();
      return true;
    } finally {
      state = state.copyWith(clearUpdating: true);
    }
  }
}
