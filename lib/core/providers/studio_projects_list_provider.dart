import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'studio_projects_list_provider.g.dart';

@riverpod
class StudioProjectsList extends _$StudioProjectsList {
  @override
  Future<List<dynamic>> build() async {
    final res = await NeyvoPulseApi.listStudioProjects();
    if (res['ok'] == true && res['projects'] != null) {
      return List<dynamic>.from(res['projects'] as List);
    }
    throw Exception(res['error'] as String? ?? 'Failed to load');
  }
}
