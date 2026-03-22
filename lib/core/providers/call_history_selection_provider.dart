import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'call_history_selection_provider.g.dart';

/// Selected call for in-shell call history ↔ detail (Pulse sidebar stays visible).
@riverpod
class CallHistorySelection extends _$CallHistorySelection {
  @override
  Map<String, dynamic>? build() => null;

  void select(Map<String, dynamic> call) {
    state = Map<String, dynamic>.from(call);
  }

  void clear() => state = null;

  /// Clears selection when the given call id was deleted from history.
  void clearIfMatches(String callId) {
    final cur = state;
    if (cur == null || callId.isEmpty) return;
    final curId = (cur['id'] ?? cur['call_id'] ?? cur['vapi_call_id'] ?? '').toString().trim();
    if (curId == callId) state = null;
  }
}
