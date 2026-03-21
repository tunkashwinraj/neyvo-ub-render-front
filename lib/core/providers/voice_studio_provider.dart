import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';
import '../../utils/voice_preview_player.dart';

part 'voice_studio_provider.g.dart';

class VoiceStudioUiState {
  const VoiceStudioUiState({
    this.loading = true,
    this.error,
    this.neutralVoices = const [],
    this.naturalVoices = const [],
    this.ultraVoices = const [],
    this.filterTier = 'all',
    this.searchTerm = '',
    this.playingVoiceId,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> neutralVoices;
  final List<Map<String, dynamic>> naturalVoices;
  final List<Map<String, dynamic>> ultraVoices;
  final String filterTier;
  final String searchTerm;
  final String? playingVoiceId;

  VoiceStudioUiState copyWith({
    bool? loading,
    String? error,
    List<Map<String, dynamic>>? neutralVoices,
    List<Map<String, dynamic>>? naturalVoices,
    List<Map<String, dynamic>>? ultraVoices,
    String? filterTier,
    String? searchTerm,
    String? playingVoiceId,
    bool clearError = false,
    bool clearPlaying = false,
  }) {
    return VoiceStudioUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      neutralVoices: neutralVoices ?? this.neutralVoices,
      naturalVoices: naturalVoices ?? this.naturalVoices,
      ultraVoices: ultraVoices ?? this.ultraVoices,
      filterTier: filterTier ?? this.filterTier,
      searchTerm: searchTerm ?? this.searchTerm,
      playingVoiceId: clearPlaying ? null : (playingVoiceId ?? this.playingVoiceId),
    );
  }

  List<Map<String, dynamic>> get filteredVoices {
    List<Map<String, dynamic>> base;
    switch (filterTier) {
      case 'neutral':
        base = neutralVoices;
        break;
      case 'natural':
        base = naturalVoices;
        break;
      case 'ultra':
        base = ultraVoices;
        break;
      default:
        base = [...neutralVoices, ...naturalVoices, ...ultraVoices];
    }
    final term = searchTerm.trim().toLowerCase();
    if (term.isEmpty) return base;
    return base.where((v) {
      final name = (v['name'] ?? '').toString().toLowerCase();
      final id = (v['voice_id'] ?? '').toString().toLowerCase();
      final desc = (v['description'] ?? '').toString().toLowerCase();
      return name.contains(term) || id.contains(term) || desc.contains(term);
    }).toList();
  }
}

List<Map<String, dynamic>> _extractList(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }
  return const [];
}

@riverpod
class VoiceStudioCtrl extends _$VoiceStudioCtrl {
  @override
  VoiceStudioUiState build() => const VoiceStudioUiState();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await NeyvoPulseApi.getVoices(tier: 'all');
      List<Map<String, dynamic>> neutral = const [];
      List<Map<String, dynamic>> natural = const [];
      List<Map<String, dynamic>> ultra = const [];

      if (res is Map) {
        neutral = _extractList(res['neutral']);
        natural = _extractList(res['natural']);
        ultra = _extractList(res['ultra']);
      } else if (res is List) {
        final all = _extractList(res);
        neutral = all.where((v) => (v['tier'] ?? '').toString().toLowerCase() == 'neutral').toList();
        natural = all.where((v) => (v['tier'] ?? '').toString().toLowerCase() == 'natural').toList();
        ultra = all.where((v) => (v['tier'] ?? '').toString().toLowerCase() == 'ultra').toList();
      }

      state = state.copyWith(
        loading: false,
        neutralVoices: neutral,
        naturalVoices: natural,
        ultraVoices: ultra,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setSearchTerm(String v) {
    state = state.copyWith(searchTerm: v);
  }

  void setFilterTier(String v) {
    state = state.copyWith(filterTier: v);
  }

  Future<void> playSample(Map<String, dynamic> voice) async {
    final voiceId = (voice['voice_id'] ?? '').toString();
    final provider = (voice['provider'] ?? '').toString();
    if (voiceId.isEmpty || provider.isEmpty) return;
    state = state.copyWith(playingVoiceId: voiceId);
    try {
      final res = await NeyvoPulseApi.postVoicePreview(
        voiceId: voiceId,
        provider: provider,
        text: (voice['sample_text'] ?? '').toString().trim().isEmpty
            ? null
            : (voice['sample_text'] ?? '').toString(),
      );
      await playVoicePreview(res);
    } finally {
      state = state.copyWith(clearPlaying: true);
    }
  }
}
