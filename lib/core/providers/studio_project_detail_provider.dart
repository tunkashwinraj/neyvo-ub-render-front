import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'studio_project_detail_provider.g.dart';

@riverpod
class StudioProjectDetail extends _$StudioProjectDetail {
  @override
  Future<Map<String, dynamic>> build(String projectId) async {
    if (projectId.isEmpty) {
      throw Exception('No project id');
    }
    final res = await NeyvoPulseApi.getStudioProject(projectId);
    if (res['ok'] == true && res['project'] != null) {
      return Map<String, dynamic>.from(res['project'] as Map);
    }
    throw Exception(res['error'] as String? ?? 'Not found');
  }
}
