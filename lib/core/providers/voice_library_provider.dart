import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'voice_library_provider.g.dart';

@riverpod
class VoiceLibraryList extends _$VoiceLibraryList {
  @override
  Future<List<dynamic>> build() async {
    final res = await NeyvoPulseApi.listVoiceProfilesLibrary();
    if (res['ok'] == true && res['profiles'] != null) {
      return List<dynamic>.from(res['profiles'] as List);
    }
    throw Exception(res['error'] as String? ?? 'Failed');
  }
}
