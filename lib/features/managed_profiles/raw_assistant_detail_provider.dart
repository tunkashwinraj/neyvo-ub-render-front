import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'managed_profile_api_service.dart';

part 'raw_assistant_detail_provider.g.dart';

class RawAssistantDetailUiState {
  const RawAssistantDetailUiState({
    this.loading = true,
    this.saving = false,
    this.error,
    this.profile = const {},
    this.rawConfig = const {},
  });

  final bool loading;
  final bool saving;
  final String? error;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> rawConfig;

  RawAssistantDetailUiState copyWith({
    bool? loading,
    bool? saving,
    String? error,
    Map<String, dynamic>? profile,
    Map<String, dynamic>? rawConfig,
    bool clearError = false,
  }) {
    return RawAssistantDetailUiState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      profile: profile ?? this.profile,
      rawConfig: rawConfig ?? this.rawConfig,
    );
  }
}

@riverpod
class RawAssistantDetailCtrl extends _$RawAssistantDetailCtrl {
  @override
  RawAssistantDetailUiState build(String profileId) {
    Future<void>.microtask(load);
    return const RawAssistantDetailUiState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ManagedProfileApiService.getProfile(profileId);
      final profile = Map<String, dynamic>.from(res);
      final rawCfg = Map<String, dynamic>.from(
        (profile['raw_vapi_config'] as Map?) ?? const <String, dynamic>{},
      );
      state = state.copyWith(
        loading: false,
        profile: profile,
        rawConfig: rawCfg,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> save({
    required String name,
    required String systemPrompt,
    required String voicemail,
  }) async {
    if (state.saving) return;
    state = state.copyWith(saving: true);
    try {
      final cfg = jsonDecode(jsonEncode(state.rawConfig)) as Map<String, dynamic>;
      cfg['name'] = name.trim().isEmpty ? (cfg['name'] ?? 'Operator') : name.trim();
      cfg['voicemailMessage'] = voicemail.trim();
      final model = (cfg['model'] as Map?) ?? <String, dynamic>{};
      final messages = (model['messages'] as List?)?.toList() ?? <dynamic>[];
      if (messages.isEmpty ||
          messages.first is! Map ||
          ((messages.first as Map)['role'] ?? '').toString().toLowerCase() != 'system') {
        messages.insert(0, {'role': 'system', 'content': systemPrompt.trim()});
      } else {
        (messages.first as Map)['content'] = systemPrompt.trim();
      }
      model['messages'] = messages;
      cfg['model'] = model;

      final updated = await ManagedProfileApiService.updateProfile(profileId, {
        'profile_name': name.trim(),
        'raw_vapi_import': cfg,
      });
      state = state.copyWith(
        profile: updated,
        rawConfig: Map<String, dynamic>.from(updated['raw_vapi_config'] as Map? ?? cfg),
        saving: false,
      );
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> importJson(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.saving) return;
    state = state.copyWith(saving: true);
    try {
      final parsed = jsonDecode(text);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('JSON must be an object');
      }
      final updated = await ManagedProfileApiService.updateProfile(profileId, {
        'raw_vapi_import': parsed,
      });
      state = state.copyWith(
        profile: updated,
        rawConfig: Map<String, dynamic>.from(updated['raw_vapi_config'] as Map? ?? parsed),
        saving: false,
      );
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      rethrow;
    }
  }

  void replaceRawConfig(Map<String, dynamic> rawConfig) {
    state = state.copyWith(rawConfig: rawConfig);
  }

  void updateVoiceField(String key, dynamic value) {
    final cfg = Map<String, dynamic>.from(state.rawConfig);
    final voiceCfg = Map<String, dynamic>.from((cfg['voice'] as Map?) ?? const {});
    voiceCfg[key] = value;
    cfg['voice'] = voiceCfg;
    state = state.copyWith(rawConfig: cfg);
  }

  void setVoiceChunkEnabled(bool enabled) {
    final cfg = Map<String, dynamic>.from(state.rawConfig);
    final voiceCfg = Map<String, dynamic>.from((cfg['voice'] as Map?) ?? const {});
    final cp = Map<String, dynamic>.from((voiceCfg['chunkPlan'] as Map?) ?? const {});
    cp['enabled'] = enabled;
    voiceCfg['chunkPlan'] = cp;
    cfg['voice'] = voiceCfg;
    state = state.copyWith(rawConfig: cfg);
  }

  void setVoiceMinCharacters(int? minCharacters) {
    if (minCharacters == null) return;
    final cfg = Map<String, dynamic>.from(state.rawConfig);
    final voiceCfg = Map<String, dynamic>.from((cfg['voice'] as Map?) ?? const {});
    final cp = Map<String, dynamic>.from((voiceCfg['chunkPlan'] as Map?) ?? const {});
    cp['minCharacters'] = minCharacters;
    voiceCfg['chunkPlan'] = cp;
    cfg['voice'] = voiceCfg;
    state = state.copyWith(rawConfig: cfg);
  }
}
