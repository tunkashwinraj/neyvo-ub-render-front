import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'member_detail_provider.g.dart';

class MemberDetailUiState {
  const MemberDetailUiState({
    this.initialized = false,
    this.member = const {},
    this.deleting = false,
  });

  final bool initialized;
  final Map<String, dynamic> member;
  final bool deleting;

  MemberDetailUiState copyWith({
    bool? initialized,
    Map<String, dynamic>? member,
    bool? deleting,
  }) {
    return MemberDetailUiState(
      initialized: initialized ?? this.initialized,
      member: member ?? this.member,
      deleting: deleting ?? this.deleting,
    );
  }
}

String memberDetailKey(Map<String, dynamic> member) {
  final userId = (member['user_id'] ?? '').toString().trim();
  if (userId.isNotEmpty) return 'uid:$userId';
  final id = (member['id'] ?? '').toString().trim();
  if (id.isNotEmpty) return 'id:$id';
  final email = (member['email'] ?? '').toString().trim();
  if (email.isNotEmpty) return 'email:$email';
  return 'anon:${identityHashCode(member)}';
}

@riverpod
class MemberDetailCtrl extends _$MemberDetailCtrl {
  @override
  MemberDetailUiState build(String key) {
    return const MemberDetailUiState();
  }

  void ensureInitialized(Map<String, dynamic> member) {
    if (state.initialized) return;
    state = state.copyWith(
      initialized: true,
      member: Map<String, dynamic>.from(member),
    );
  }

  Future<void> removeMember() async {
    final member = state.member;
    final userId = (member['user_id'] ?? member['id'] ?? '').toString();
    if (userId.isEmpty || state.deleting) return;
    state = state.copyWith(deleting: true);
    try {
      await NeyvoPulseApi.deleteMember(userId);
      state = state.copyWith(deleting: false);
    } catch (_) {
      state = state.copyWith(deleting: false);
      rethrow;
    }
  }
}
