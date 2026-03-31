import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'template_scripts_provider.g.dart';

class TemplateScriptsUiState {
  const TemplateScriptsUiState({
    this.templates = const [],
    this.loading = true,
    this.error,
    this.showEditor = false,
    this.editingId,
  });

  final List<Map<String, dynamic>> templates;
  final bool loading;
  final String? error;
  final bool showEditor;
  final String? editingId;

  TemplateScriptsUiState copyWith({
    List<Map<String, dynamic>>? templates,
    bool? loading,
    String? error,
    bool? showEditor,
    String? editingId,
    bool clearError = false,
    bool clearEditingId = false,
  }) {
    return TemplateScriptsUiState(
      templates: templates ?? this.templates,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      showEditor: showEditor ?? this.showEditor,
      editingId: clearEditingId ? null : (editingId ?? this.editingId),
    );
  }
}

@riverpod
class TemplateScriptsCtrl extends _$TemplateScriptsCtrl {
  @override
  TemplateScriptsUiState build() => const TemplateScriptsUiState();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await NeyvoPulseApi.listCallTemplates();
      final list = res['templates'] as List? ?? [];
      state = state.copyWith(
        templates: list.cast<Map<String, dynamic>>(),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void openEditor({Map<String, dynamic>? template}) {
    state = state.copyWith(
      showEditor: true,
      editingId: template?['id']?.toString(),
      clearEditingId: template == null,
    );
  }

  void closeEditor() {
    state = state.copyWith(showEditor: false, clearEditingId: true);
  }

  void setEditorTarget({String? editingId}) {
    state = state.copyWith(editingId: editingId, clearEditingId: editingId == null);
  }

  Future<void> deleteTemplate(String id) async {
    await NeyvoPulseApi.deleteCallTemplate(id);
    await load();
  }
}
