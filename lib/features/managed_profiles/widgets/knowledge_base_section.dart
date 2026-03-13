import 'package:flutter/material.dart';

import '../../../theme/neyvo_theme.dart';
import '../../../tenant/tenant_brand.dart';
import '../../../ui/components/glass/neyvo_glass_panel.dart';
import '../../../widgets/neyvo_empty_state.dart';
import '../managed_profile_api_service.dart';

class KnowledgeBaseSection extends StatefulWidget {
  const KnowledgeBaseSection({
    super.key,
    required this.profileId,
  });

  final String profileId;

  @override
  State<KnowledgeBaseSection> createState() => _KnowledgeBaseSectionState();
}

class _KnowledgeBaseSectionState extends State<KnowledgeBaseSection> {
  bool _loading = false;
  bool _saving = false;
  bool _deleting = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ManagedProfileApiService.listKnowledgeItems(widget.profileId);
      final raw = (res['items'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openAddDialog() async {
    final questionCtrl = TextEditingController();
    final answerCtrl = TextEditingController();
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
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
                  onPressed: _saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: _saving
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
                          setState(() => _saving = true);
                          try {
                            await ManagedProfileApiService.addKnowledgeItem(
                              widget.profileId,
                              question: question,
                              answer: answer,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            await _loadItems();
                            if (!mounted || !context.mounted) return;
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            if (messenger != null) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Saved to knowledge base.')),
                              );
                            }
                          } catch (e) {
                            if (mounted && ctx.mounted) {
                              setLocalState(() {
                                localError = 'Failed to save knowledge. Please try again.';
                              });
                              if (context.mounted) {
                                final messenger = ScaffoldMessenger.maybeOf(context);
                                if (messenger != null) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Failed to save knowledge: $e')),
                                  );
                                }
                              }
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  style: FilledButton.styleFrom(
                    backgroundColor: TenantBrand.primary(context),
                    foregroundColor: NeyvoColors.white,
                  ),
                  label: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ],
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
                  onPressed: _saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: _saving
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
                          setState(() => _saving = true);
                          try {
                            await ManagedProfileApiService.addKnowledgeItem(
                              widget.profileId,
                              question: question,
                              answer: answer,
                            );
                            // Remove the old item so we don't show duplicates.
                            if (itemId.isNotEmpty) {
                              await ManagedProfileApiService.deleteKnowledgeItem(widget.profileId, itemId);
                            }
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            await _loadItems();
                            if (!mounted || !context.mounted) return;
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            if (messenger != null) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Knowledge updated.')),
                              );
                            }
                          } catch (e) {
                            if (mounted && ctx.mounted) {
                              setLocalState(() {
                                localError = 'Failed to update knowledge. Please try again.';
                              });
                              if (context.mounted) {
                                final messenger = ScaffoldMessenger.maybeOf(context);
                                if (messenger != null) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Update failed: $e')),
                                  );
                                }
                              }
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  style: FilledButton.styleFrom(
                    backgroundColor: TenantBrand.primary(context),
                    foregroundColor: NeyvoColors.white,
                  ),
                  label: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    if (_deleting) return;
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

    setState(() => _deleting = true);
    try {
      await ManagedProfileApiService.deleteKnowledgeItem(widget.profileId, itemId);
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => (e['id'] ?? '').toString() != itemId).toList();
      });
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Knowledge item deleted.')),
        );
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((item) {
      final question = (item['question'] ?? '').toString().toLowerCase();
      final answer = (item['answer'] ?? '').toString().toLowerCase();
      return question.contains(q) || answer.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

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
                    Text('Agent Knowledge (Vector RAG)', style: NeyvoTextStyles.heading),
                    const SizedBox(height: 6),
                    Text(
                      'Add specific policies and facts here to prevent AI hallucinations.',
                      style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _openAddDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: TenantBrand.primary(context),
                  foregroundColor: NeyvoColors.white,
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Add Knowledge'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: const InputDecoration(
              hintText: 'Search saved Q&A by keyword',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _loading ? null : _loadItems,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (!_loading && _items.isEmpty)
            SizedBox(
              width: double.infinity,
              child: buildNeyvoEmptyState(
                context: context,
                title: 'No custom knowledge added yet',
                subtitle: 'Add your first policy or FAQ to help the agent answer accurately.',
                buttonLabel: 'Add Knowledge',
                onAction: _openAddDialog,
                icon: Icons.psychology_alt_outlined,
              ),
            )
          else if (!_loading && filtered.isEmpty)
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
                          onPressed: _saving ? null : () => _openEditDialog(item),
                          icon: const Icon(Icons.edit_outlined),
                          color: NeyvoColors.textSecondary,
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: _deleting ? null : () => _deleteItem(item),
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
