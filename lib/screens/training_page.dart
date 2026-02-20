// lib/screens/training_page.dart
// Phase C: Assistant training – FAQ + policy for school knowledge.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../theme/spearia_theme.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  List<dynamic> _faq = [];
  Map<String, dynamic> _policy = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final faqRes = await NeyvoPulseApi.listKnowledgeFaq();
      final policyRes = await NeyvoPulseApi.getKnowledgePolicy();
      if (mounted) {
        setState(() {
          _faq = faqRes['faq'] as List? ?? [];
          _policy = policyRes['policy'] as Map<String, dynamic>? ?? {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePolicy(Map<String, String> values) async {
    try {
      await NeyvoPulseApi.updateKnowledgePolicy(
        paymentPolicy: values['payment_policy']?.isEmpty == true ? null : values['payment_policy'],
        lateFeePolicy: values['late_fee_policy']?.isEmpty == true ? null : values['late_fee_policy'],
        contactInfo: values['contact_info']?.isEmpty == true ? null : values['contact_info'],
        defaultDueDays: values['default_due_days']?.isEmpty == true ? null : values['default_due_days'],
        notes: values['notes']?.isEmpty == true ? null : values['notes'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Policy saved')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addFaq(String question, String answer) async {
    try {
      await NeyvoPulseApi.addKnowledgeFaq(question: question, answer: answer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FAQ added')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _updateFaq(String id, String question, String answer) async {
    try {
      await NeyvoPulseApi.updateKnowledgeFaq(id, question: question, answer: answer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FAQ updated')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteFaq(String id) async {
    try {
      await NeyvoPulseApi.deleteKnowledgeFaq(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FAQ removed')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assistant Training')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error), textAlign: TextAlign.center),
                const SizedBox(height: SpeariaSpacing.lg),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant Training'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(SpeariaSpacing.lg),
          children: [
            Text(
              'Train your assistant with school-specific knowledge. This is injected into every outbound call.',
              style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
            ),
            const SizedBox(height: SpeariaSpacing.xl),
            _PolicySection(policy: _policy, onSave: _savePolicy),
            const SizedBox(height: SpeariaSpacing.xl),
            _FaqSection(faq: _faq, onAdd: _addFaq, onUpdate: _updateFaq, onDelete: _deleteFaq),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatefulWidget {
  final Map<String, dynamic> policy;
  final Future<void> Function(Map<String, String>) onSave;

  const _PolicySection({required this.policy, required this.onSave});

  @override
  State<_PolicySection> createState() => _PolicySectionState();
}

class _PolicySectionState extends State<_PolicySection> {
  late TextEditingController _paymentPolicy;
  late TextEditingController _lateFeePolicy;
  late TextEditingController _contactInfo;
  late TextEditingController _defaultDueDays;
  late TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _paymentPolicy = TextEditingController(text: widget.policy['payment_policy']?.toString() ?? '');
    _lateFeePolicy = TextEditingController(text: widget.policy['late_fee_policy']?.toString() ?? '');
    _contactInfo = TextEditingController(text: widget.policy['contact_info']?.toString() ?? '');
    _defaultDueDays = TextEditingController(text: widget.policy['default_due_days']?.toString() ?? '');
    _notes = TextEditingController(text: widget.policy['notes']?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _PolicySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy != widget.policy) {
      _paymentPolicy.text = widget.policy['payment_policy']?.toString() ?? '';
      _lateFeePolicy.text = widget.policy['late_fee_policy']?.toString() ?? '';
      _contactInfo.text = widget.policy['contact_info']?.toString() ?? '';
      _defaultDueDays.text = widget.policy['default_due_days']?.toString() ?? '';
      _notes.text = widget.policy['notes']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _paymentPolicy.dispose();
    _lateFeePolicy.dispose();
    _contactInfo.dispose();
    _defaultDueDays.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('School policy', style: SpeariaType.titleLarge),
            const SizedBox(height: 4),
            Text('Used by the assistant to answer policy questions.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
            const SizedBox(height: SpeariaSpacing.md),
            TextField(
              controller: _paymentPolicy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Payment policy',
                hintText: 'e.g. Payments due within 30 days; payment plans available.',
              ),
            ),
            const SizedBox(height: SpeariaSpacing.md),
            TextField(
              controller: _lateFeePolicy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Late fee policy',
                hintText: r'e.g. $75 late fee after due date.',
              ),
            ),
            const SizedBox(height: SpeariaSpacing.md),
            TextField(
              controller: _contactInfo,
              decoration: const InputDecoration(
                labelText: 'Contact info',
                hintText: 'e.g. Billing office: 555-0100',
              ),
            ),
            const SizedBox(height: SpeariaSpacing.md),
            TextField(
              controller: _defaultDueDays,
              decoration: const InputDecoration(
                labelText: 'Default due days',
                hintText: 'e.g. 30',
              ),
            ),
            const SizedBox(height: SpeariaSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: SpeariaSpacing.lg),
            FilledButton.icon(
              onPressed: () => widget.onSave({
                'payment_policy': _paymentPolicy.text,
                'late_fee_policy': _lateFeePolicy.text,
                'contact_info': _contactInfo.text,
                'default_due_days': _defaultDueDays.text,
                'notes': _notes.text,
              }),
              icon: const Icon(Icons.save, size: 20),
              label: const Text('Save policy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  final List<dynamic> faq;
  final Future<void> Function(String question, String answer) onAdd;
  final Future<void> Function(String id, String question, String answer) onUpdate;
  final Future<void> Function(String id) onDelete;

  const _FaqSection({
    required this.faq,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FAQ', style: SpeariaType.titleLarge),
                    const SizedBox(height: 4),
                    Text('Questions and answers the assistant can use.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _showAddFaqDialog(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add FAQ'),
                ),
              ],
            ),
            const SizedBox(height: SpeariaSpacing.md),
            if (faq.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SpeariaSpacing.lg),
                child: Text('No FAQ entries yet. Add questions and answers for the assistant.', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
              )
            else
              ...faq.map((e) {
                final id = e['id']?.toString() ?? '';
                final q = e['question']?.toString() ?? '';
                final a = e['answer']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
                  child: ListTile(
                    title: Text(q, style: SpeariaType.titleMedium),
                    subtitle: Text(a, style: SpeariaType.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showEditFaqDialog(context, id, q, a),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20, color: SpeariaAura.error),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove FAQ?'),
                                content: const Text('This question and answer will be removed from the assistant knowledge.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                                ],
                              ),
                            );
                            if (confirm == true) await onDelete(id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showAddFaqDialog(BuildContext context) {
    final qC = TextEditingController();
    final aC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add FAQ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qC, decoration: const InputDecoration(labelText: 'Question'), maxLines: 2),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: aC, decoration: const InputDecoration(labelText: 'Answer'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (qC.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await onAdd(qC.text.trim(), aC.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditFaqDialog(BuildContext context, String id, String question, String answer) {
    final qC = TextEditingController(text: question);
    final aC = TextEditingController(text: answer);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit FAQ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qC, decoration: const InputDecoration(labelText: 'Question'), maxLines: 2),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: aC, decoration: const InputDecoration(labelText: 'Answer'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (qC.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await onUpdate(id, qC.text.trim(), aC.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
