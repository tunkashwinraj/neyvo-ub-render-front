import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'training_knowledge_provider.g.dart';

class TrainingKnowledgeUiState {
  const TrainingKnowledgeUiState({
    this.loading = false,
    this.saving = false,
    this.deleting = false,
    this.searchQuery = '',
    this.items = const [],
  });

  final bool loading;
  final bool saving;
  final bool deleting;
  final String searchQuery;
  final List<Map<String, dynamic>> items;

  TrainingKnowledgeUiState copyWith({
    bool? loading,
    bool? saving,
    bool? deleting,
    String? searchQuery,
    List<Map<String, dynamic>>? items,
  }) {
    return TrainingKnowledgeUiState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      deleting: deleting ?? this.deleting,
      searchQuery: searchQuery ?? this.searchQuery,
      items: items ?? this.items,
    );
  }
}

@riverpod
class TrainingKnowledgeCtrl extends _$TrainingKnowledgeCtrl {
  @override
  TrainingKnowledgeUiState build() => const TrainingKnowledgeUiState();

  Future<void> loadItems() async {
    state = state.copyWith(loading: true);
    try {
      final res = await NeyvoPulseApi.listTrainingKnowledgeItems();
      final raw = (res['items'] as List?) ?? const [];
      state = state.copyWith(
        items: raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  void setSaving(bool v) {
    state = state.copyWith(saving: v);
  }

  void setDeleting(bool v) {
    state = state.copyWith(deleting: v);
  }

  Future<void> deleteItem(String itemId) async {
    state = state.copyWith(deleting: true);
    try {
      await NeyvoPulseApi.deleteTrainingKnowledgeItem(itemId);
      state = state.copyWith(
        deleting: false,
        items: state.items.where((e) => (e['id'] ?? '').toString() != itemId).toList(),
      );
    } catch (_) {
      state = state.copyWith(deleting: false);
      rethrow;
    }
  }

  Future<void> addItem({required String question, required String answer}) async {
    await NeyvoPulseApi.addTrainingKnowledgeItem(question: question, answer: answer);
    await loadItems();
  }

  /// Re-vectorizes by adding a new item then removing the old id (matches legacy UI).
  Future<void> replaceItem({required String oldItemId, required String question, required String answer}) async {
    await NeyvoPulseApi.addTrainingKnowledgeItem(question: question, answer: answer);
    if (oldItemId.isNotEmpty) {
      await NeyvoPulseApi.deleteTrainingKnowledgeItem(oldItemId);
    }
    await loadItems();
  }
}
