import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/managed_profiles/managed_profile_api_service.dart';
import 'api_provider.dart';

part 'agents_provider.g.dart';

class AgentProfile {
  const AgentProfile({
    required this.profileId,
    required this.profileName,
    required this.createdAt,
    required this.rawVapi,
    required this.schemaVersion,
    required this.raw,
  });

  final String profileId;
  final String profileName;
  final String? createdAt;
  final bool rawVapi;
  final int? schemaVersion;
  final Map<String, dynamic> raw;

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      profileId: (json['profile_id'] ?? json['id'] ?? '').toString(),
      profileName: (json['profile_name'] ?? 'Unnamed').toString(),
      createdAt: json['created_at']?.toString(),
      rawVapi: json['raw_vapi'] == true,
      schemaVersion: (json['schema_version'] as num?)?.toInt(),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

@Riverpod(keepAlive: true)
class AgentsNotifier extends _$AgentsNotifier {
  @override
  Future<List<AgentProfile>> build() async {
    ref.watch(speariaApiProvider);
    final res = await ManagedProfileApiService.listProfiles();
    final list = (res['profiles'] as List?)?.cast<dynamic>() ?? const [];
    return list
        .map((e) => AgentProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.profileId.isNotEmpty)
        .toList();
  }

  Future<String> createRawProfile({
    required String profileName,
    required String systemPrompt,
    required String voicemailMessage,
  }) async {
    ref.read(speariaApiProvider);
    final res = await ManagedProfileApiService.createRawProfile(
      profileName: profileName,
      systemPrompt: systemPrompt,
      voicemailMessage: voicemailMessage,
    );
    ref.invalidateSelf();
    return (res['profile_id'] ?? '').toString();
  }

  Future<void> archiveProfile(String profileId) async {
    ref.read(speariaApiProvider);
    await ManagedProfileApiService.archiveProfile(profileId);
    ref.invalidateSelf();
  }

  Future<String> duplicateProfile(String profileId) async {
    ref.read(speariaApiProvider);
    final res = await ManagedProfileApiService.duplicateProfile(profileId);
    ref.invalidateSelf();
    return (res['profile_id'] ?? '').toString();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
