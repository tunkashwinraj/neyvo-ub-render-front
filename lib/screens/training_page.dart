// lib/screens/training_page.dart
// Assistant training – org-wide Vector RAG knowledge (replaces legacy FAQ + policy UI).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/training_knowledge_provider.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../widgets/neyvo_empty_state.dart';

class TrainingPage extends ConsumerWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant Training'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: const TrainingKnowledgeSection(),
      ),
    );
  }
}

class TrainingKnowledgeSection extends ConsumerStatefulWidget {
  const TrainingKnowledgeSection({super.key});

  @override
  ConsumerState<TrainingKnowledgeSection> createState() => _TrainingKnowledgeSectionState();
}

class _TrainingKnowledgeSectionState extends ConsumerState<TrainingKnowledgeSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trainingKnowledgeCtrlProvider.notifier).loadItems();
    });
  }

  Future<void> _loadItems() => ref.read(trainingKnowledgeCtrlProvider.notifier).loadItems();

  Future<void> _openAddDialog() async {
    final questionCtrl = TextEditingController();
    final answerCtrl = TextEditingController();
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final saving = ref.watch(trainingKnowledgeCtrlProvider).saving;
            return StatefulBuilder(
              builder: (context, setLocalState) {
                return AlertDialog(
              backgroundColor: NeyvoColors.bgBase,
              title: const Text('Add Knowledge'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a policy, fact, or Q&A pair the agent can retrieve in real-time.',
                      style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: questionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Question/Topic',
                        hintText: 'e.g. What is the tuition payment extension policy?',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: answerCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Answer/Policy',
                        hintText: 'Enter a clear answer the caller should hear.',
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final question = questionCtrl.text.trim();
                          final answer = answerCtrl.text.trim();
                          if (question.isEmpty || answer.isEmpty) {
                            if (!ctx.mounted) return;
                            setLocalState(() {
                              localError = 'Please fill both Question/Topic and Answer/Policy.';
                            });
                            return;
                          }
                          ref.read(trainingKnowledgeCtrlProvider.notifier).setSaving(true);
                          try {
                            await ref.read(trainingKnowledgeCtrlProvider.notifier).addItem(
                                  question: question,
                                  answer: answer,
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            await ref.read(trainingKnowledgeCtrlProvider.notifier).loadItems();
                            if (!mounted || !context.mounted) return;
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            messenger?.showSnackBar(
                              const SnackBar(content: Text('Saved to training knowledge base.')),
                            );
                          } catch (e) {
                            if (mounted && ctx.mounted) {
                              setLocalState(() {
                                localError = 'Failed to save knowledge. Please try again.';
                              });
                              if (context.mounted) {
                                final messenger = ScaffoldMessenger.maybeOf(context);
                                messenger?.showSnackBar(
                                  SnackBar(content: Text('Failed to save knowledge: $e')),
                                );
                              }
                            }
                          } finally {
                            if (mounted) ref.read(trainingKnowledgeCtrlProvider.notifier).setSaving(false);
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  style: FilledButton.styleFrom(
                    backgroundColor: NeyvoColors.teal,
                    foregroundColor: NeyvoColors.white,
                  ),
                  label: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openEditDialog(Map<String, dynamic> item) async {
    final itemId = (item['id'] ?? '').toString();
    final questionCtrl = TextEditingController(text: (item['question'] ?? '').toString());
    final answerCtrl = TextEditingController(text: (item['answer'] ?? '').toString());
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final saving = ref.watch(trainingKnowledgeCtrlProvider).saving;
            return StatefulBuilder(
              builder: (context, setLocalState) {
                return AlertDialog(
              backgroundColor: NeyvoColors.bgBase,
              title: const Text('Edit Knowledge'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update the question or answer. The new version will be re-embedded for calls.',
                      style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: questionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Question/Topic',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: answerCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Answer/Policy',
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final question = questionCtrl.text.trim();
                          final answer = answerCtrl.text.trim();
                          if (question.isEmpty || answer.isEmpty) {
                            if (!ctx.mounted) return;
                            setLocalState(() {
                              localError = 'Please fill both Question/Topic and Answer/Policy.';
                            });
                            return;
                          }
                          ref.read(trainingKnowledgeCtrlProvider.notifier).setSaving(true);
                          try {
                            await ref.read(trainingKnowledgeCtrlProvider.notifier).replaceItem(
                                  oldItemId: itemId,
                                  question: question,
                                  answer: answer,
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (!mounted || !context.mounted) return;
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            messenger?.showSnackBar(
                              const SnackBar(content: Text('Knowledge updated.')),
                            );
                          } catch (e) {
                            if (mounted && ctx.mounted) {
                              setLocalState(() {
                                localError = 'Failed to update knowledge. Please try again.';
                              });
                              if (context.mounted) {
                                final messenger = ScaffoldMessenger.maybeOf(context);
                                messenger?.showSnackBar(
                                  SnackBar(content: Text('Update failed: $e')),
                                );
                              }
                            }
                          } finally {
                            if (mounted) ref.read(trainingKnowledgeCtrlProvider.notifier).setSaving(false);
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  style: FilledButton.styleFrom(
                    backgroundColor: NeyvoColors.teal,
                    foregroundColor: NeyvoColors.white,
                  ),
                  label: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final ui = ref.read(trainingKnowledgeCtrlProvider);
    if (ui.deleting) return;
    final itemId = (item['id'] ?? '').toString().trim();
    if (itemId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeyvoColors.bgBase,
        title: const Text('Delete knowledge item?'),
        content: Text(
          'This will remove the selected knowledge item from the list.',
          style: NeyvoTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: NeyvoColors.error,
              foregroundColor: NeyvoColors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(trainingKnowledgeCtrlProvider.notifier).deleteItem(itemId);
      if (!mounted) return;
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Knowledge item deleted.')),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _filteredItems(TrainingKnowledgeUiState ui) {
    final q = ui.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return ui.items;
    return ui.items.where((item) {
      final question = (item['question'] ?? '').toString().toLowerCase();
      final answer = (item['answer'] ?? '').toString().toLowerCase();
      return question.contains(q) || answer.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(trainingKnowledgeCtrlProvider);
    final filtered = _filteredItems(ui);

    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Training Knowledge (Vector RAG)', style: NeyvoTextStyles.heading),
                    const SizedBox(height: 6),
                    Text(
                      'Add org-wide policies and FAQs here. The agent will retrieve these in real time instead of guessing.',
                      style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: ui.saving ? null : _openAddDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: NeyvoColors.teal,
                  foregroundColor: NeyvoColors.white,
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Add Knowledge'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => ref.read(trainingKnowledgeCtrlProvider.notifier).setSearchQuery(v),
            decoration: const InputDecoration(
              hintText: 'Search saved Q&A by keyword',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: ui.loading ? null : _loadItems,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          if (ui.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (!ui.loading && ui.items.isEmpty)
            SizedBox(
              width: double.infinity,
              child: buildNeyvoEmptyState(
                context: context,
                title: 'No training knowledge added yet',
                subtitle: 'Add your first policy or FAQ to help the agent answer accurately.',
                buttonLabel: 'Add Knowledge',
                onAction: _openAddDialog,
                icon: Icons.psychology_alt_outlined,
              ),
            )
          else if (!ui.loading && filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No matches for your search.',
                  style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                ),
              ),
            )
          else
            Column(
              children: filtered.map((item) {
                final question = (item['question'] ?? '').toString();
                final answer = (item['answer'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: NeyvoColors.bgRaised.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: NeyvoColors.borderSubtle),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    title: Text(
                      question.isEmpty ? 'Untitled question' : question,
                      style: NeyvoTextStyles.bodyPrimary,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: NeyvoColors.success.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: NeyvoColors.success.withOpacity(0.45)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: NeyvoColors.success),
                                const SizedBox(width: 5),
                                Text(
                                  'Vectorized',
                                  style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.success),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: ui.saving ? null : () => _openEditDialog(item),
                          icon: const Icon(Icons.edit_outlined),
                          color: NeyvoColors.textSecondary,
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: ui.deleting ? null : () => _deleteItem(item),
                          icon: const Icon(Icons.delete_outline),
                          color: NeyvoColors.error,
                        ),
                      ],
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          answer.isEmpty ? 'No answer text.' : answer,
                          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

