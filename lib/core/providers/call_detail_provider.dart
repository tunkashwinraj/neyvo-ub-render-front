import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'call_detail_provider.g.dart';

class CallDetailUiState {
  const CallDetailUiState({
    this.initialized = false,
    this.merged = const {},
    this.loading = false,
    this.error,
  });

  final bool initialized;
  final Map<String, dynamic> merged;
  final bool loading;
  final String? error;

  CallDetailUiState copyWith({
    bool? initialized,
    Map<String, dynamic>? merged,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return CallDetailUiState(
      initialized: initialized ?? this.initialized,
      merged: merged ?? this.merged,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Same id the list row / Firestore doc uses for [NeyvoPulseApi.getCallById].
String resolveVapiCallIdForApi(Map<String, dynamic> c) {
  final v = _safeStr(c['vapi_call_id']);
  if (v.isNotEmpty) return v;
  final v2 = _safeStr(c['vapiCallId']);
  if (v2.isNotEmpty) return v2;
  final id = _safeStr(c['id']);
  if (id.isNotEmpty) return id;
  final cid = _safeStr(c['call_id']);
  if (cid.isNotEmpty) return cid;
  return '';
}

/// Stable family key when API id is missing (multiple anonymous rows stay distinct).
String callDetailProviderKey(Map<String, dynamic> c) {
  final id = resolveVapiCallIdForApi(c);
  if (id.isNotEmpty) return id;
  final sid = _safeStr(c['call_sid']);
  if (sid.isNotEmpty) return 'sid:$sid';
  return 'anon:${identityHashCode(c)}';
}

String _safeStr(dynamic v) => (v ?? '').toString().trim();

@riverpod
class CallDetailUiCtrl extends _$CallDetailUiCtrl {
  @override
  CallDetailUiState build(String key) {
    return const CallDetailUiState();
  }

  void ensureInitialized(Map<String, dynamic> call) {
    if (state.initialized) return;
    state = CallDetailUiState(
      initialized: true,
      merged: Map<String, dynamic>.from(call),
      loading: true,
      error: null,
    );
    Future<void>.microtask(loadRich);
  }

  Future<void> loadRich() async {
    if (!state.initialized) return;
    final merged = state.merged;
    final vapiId = resolveVapiCallIdForApi(merged);
    if (vapiId.isEmpty) {
      state = state.copyWith(loading: false);
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await NeyvoPulseApi.getCallById(vapiId);
      final ok = res['ok'] == true;
      final call = res['call'];
      if (ok && call is Map) {
        final rich = Map<String, dynamic>.from(call);
        state = state.copyWith(
          merged: {...merged, ...rich},
          loading: false,
        );
        return;
      }
      state = state.copyWith(
        loading: false,
        error: (res['error'] ?? 'Failed to load call details').toString(),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
