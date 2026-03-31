import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'callbacks_page_provider.g.dart';

class CallbacksPageUiState {
  const CallbacksPageUiState({
    this.loading = true,
    this.error,
    this.analytics,
    this.callbacks = const [],
    this.filter = 'all',
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? analytics;
  final List<Map<String, dynamic>> callbacks;
  final String filter;

  CallbacksPageUiState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? analytics,
    List<Map<String, dynamic>>? callbacks,
    String? filter,
    bool clearError = false,
  }) {
    return CallbacksPageUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      analytics: analytics ?? this.analytics,
      callbacks: callbacks ?? this.callbacks,
      filter: filter ?? this.filter,
    );
  }
}

@riverpod
class CallbacksPageCtrl extends _$CallbacksPageCtrl {
  @override
  CallbacksPageUiState build() => const CallbacksPageUiState();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final analyticsRes = await NeyvoPulseApi.getCallbacksAnalytics();
      final listRes = await NeyvoPulseApi.listCallbacks();
      Map<String, dynamic>? analytics;
      if (analyticsRes['ok'] == true) {
        analytics = analyticsRes['analytics'] as Map<String, dynamic>?;
      }
      List<Map<String, dynamic>> callbacks = state.callbacks;
      String? error;
      if (listRes['ok'] == true) {
        callbacks = (listRes['callbacks'] as List? ?? []).cast<Map<String, dynamic>>();
      } else if (listRes['error'] != null) {
        error = listRes['error']?.toString();
      }
      state = state.copyWith(loading: false, analytics: analytics, callbacks: callbacks, error: error);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setFilter(String value) {
    state = state.copyWith(filter: value);
  }

  List<Map<String, dynamic>> filteredCallbacks() {
    if (state.filter == 'overdue') {
      final now = DateTime.now().toUtc();
      return state.callbacks.where((c) {
        final raw = c['callback_at'];
        if (raw == null) return false;
        try {
          final dt = DateTime.parse(raw.toString()).toUtc();
          return dt.isBefore(now);
        } catch (_) {
          return false;
        }
      }).toList();
    }
    return state.callbacks;
  }
}
