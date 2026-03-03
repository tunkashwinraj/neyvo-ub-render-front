// lib/screens/business_setup_page.dart
// Business Intelligence Setup — model your business once for all voice agents.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/neyvo_theme.dart';
import '../features/business_intelligence/bi_wizard_api_service.dart';
import '../ui/components/ai_orb/neyvo_ai_orb.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';

class BusinessSetupPage extends StatefulWidget {
  const BusinessSetupPage({
    super.key,
    this.initialBi,
    this.initialSuggestions,
  });

  /// Optional BI object returned from /api/wizard/extract-model.
  final Map<String, dynamic>? initialBi;

  /// Optional service suggestions returned alongside BI extraction.
  final List<Map<String, dynamic>>? initialSuggestions;

  @override
  State<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends State<BusinessSetupPage> {
  int _step = 0; // 0: category, 1: confirm, 2: done
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _status = 'missing';
  bool _editExpanded = false;
  final _websiteUrlCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _subcategoryCtrl = TextEditingController();
  List<Map<String, dynamic>> _serviceSuggestions = [];
  final Set<int> _selectedServices = {};
  List<Map<String, dynamic>> _simulations = [];

  static const List<Map<String, String>> _categories = [
    {'id': 'healthcare', 'label': 'Healthcare'},
    {'id': 'beauty', 'label': 'Beauty'},
    {'id': 'legal', 'label': 'Legal'},
    {'id': 'restaurant', 'label': 'Restaurant'},
    {'id': 'retail', 'label': 'Retail'},
    {'id': 'services', 'label': 'Professional Services'},
    {'id': 'education', 'label': 'Education'},
    {'id': 'general', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _websiteUrlCtrl.dispose();
    _businessNameCtrl.dispose();
    _phoneCtrl.dispose();
    _categoryCtrl.dispose();
    _subcategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statusRes = await BiWizardApiService.getStatus();
      if (statusRes['ok'] == true && statusRes['status'] is String) {
        _status = statusRes['status'] as String;
      }
      Map<String, dynamic>? bi;
      if (widget.initialBi != null) {
        bi = Map<String, dynamic>.from(widget.initialBi!);
      } else {
        final biRes = await BiWizardApiService.load();
        if (biRes['ok'] == true && biRes['bi'] != null) {
          bi = Map<String, dynamic>.from(biRes['bi'] as Map);
        }
      }
      if (bi != null) {
        final core = Map<String, dynamic>.from(bi['core'] as Map? ?? {});
        final knowledge = Map<String, dynamic>.from(bi['knowledge'] as Map? ?? {});
        final contact = Map<String, dynamic>.from(knowledge['contact'] as Map? ?? {});
        _businessNameCtrl.text = (core['name'] ?? '').toString();
        _categoryCtrl.text = (core['category'] ?? '').toString();
        _subcategoryCtrl.text = (core['subcategory'] ?? '').toString();
        _phoneCtrl.text = (contact['main_phone'] ?? contact['mainPhone'] ?? '').toString();
      }
      // If we received initial suggestions from extract-model, seed them.
      if (widget.initialSuggestions != null &&
          widget.initialSuggestions!.isNotEmpty) {
        _serviceSuggestions = widget.initialSuggestions!
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _selectedServices
          ..clear()
          ..addAll(List<int>.generate(_serviceSuggestions.length, (i) => i));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _getSuggestions() async {
    setState(() {
      _error = null;
      _serviceSuggestions = [];
      _selectedServices.clear();
    });
    try {
      final res = await BiWizardApiService.getSuggestions(
        category: _categoryCtrl.text.trim().isEmpty ? 'general' : _categoryCtrl.text.trim(),
        subcategory: _subcategoryCtrl.text.trim().isEmpty ? 'general' : _subcategoryCtrl.text.trim(),
      );
      if (res['ok'] == true) {
        final list = (res['services'] as List? ?? []).cast<dynamic>();
        setState(() {
          _serviceSuggestions = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _simulate() async {
    setState(() {
      _error = null;
      _simulations = [];
    });
    try {
      final payload = _buildBiPayload();
      final res = await BiWizardApiService.simulate(payload);
      if (res['ok'] == true) {
        final sims = (res['simulations'] as List? ?? []).cast<dynamic>();
        setState(() {
          _simulations = sims.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> _buildBiPayload() {
    final services = <Map<String, dynamic>>[];
    for (final idx in _selectedServices) {
      if (idx < 0 || idx >= _serviceSuggestions.length) continue;
      final s = _serviceSuggestions[idx];
      final name = (s['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final priceRange = s['typicalPriceRange'];
      final price = priceRange is Map ? priceRange['min'] : null;
      final currency = priceRange is Map ? (priceRange['currency'] ?? 'USD') : 'USD';
      services.add({
        'name': name,
        'duration_min': s['typicalDurationMin'],
        'price': price,
        'currency': currency,
      });
    }
    return {
      'business_name': _businessNameCtrl.text.trim(),
      'phone_number': _phoneCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'subcategory': _subcategoryCtrl.text.trim(),
      'offerings': {
        'services': services,
      },
    };
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = _buildBiPayload();
      final res = await BiWizardApiService.save(payload);
      if (res['ok'] == true) {
        setState(() {
          _status = (res['status'] as String?) ?? _status;
          _error = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business setup saved'), behavior: SnackBarBehavior.floating),
          );
        }
      } else {
        setState(() {
          _error = (res['error'] ?? 'Failed to save business setup').toString();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    }
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: NeyvoGlassPanel(
                glowing: _status == 'ready',
                padding: const EdgeInsets.all(NeyvoSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const NeyvoAIOrb(
                          state: NeyvoAIOrbState.processing,
                          size: 64,
                        ),
                        const SizedBox(width: NeyvoSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Business Intelligence',
                                style: NeyvoTextStyles.heading.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Model your business once so every agent behaves correctly.',
                                style: NeyvoTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: NeyvoSpacing.md),
                        _buildStatusChip(),
                      ],
                    ),
                    const SizedBox(height: NeyvoSpacing.xl),
                    Row(
                      children: [
                        _stepDot(0, 'Category'),
                        _stepLine(),
                        _stepDot(1, 'Confirm'),
                        _stepLine(),
                        _stepDot(2, 'Save'),
                      ],
                    ),
                    const SizedBox(height: NeyvoSpacing.xl),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NeyvoColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                      ),
                      const SizedBox(height: NeyvoSpacing.lg),
                    ],
                    if (_step == 0) _buildStepCategory(),
                    if (_step == 1) _buildStepConfirm(),
                    if (_step == 2) _buildStepSave(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final active = _step == step;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? NeyvoColors.teal : NeyvoColors.bgRaised,
            border: Border.all(color: active ? NeyvoColors.teal : NeyvoColors.borderDefault),
          ),
          child: Center(child: Text('${step + 1}', style: NeyvoTextStyles.micro.copyWith(color: active ? Colors.white : NeyvoColors.textMuted))),
        ),
        const SizedBox(height: 4),
        Text(label, style: NeyvoTextStyles.micro.copyWith(color: active ? NeyvoColors.teal : NeyvoColors.textMuted)),
      ],
    );
  }

  Widget _stepLine() => Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 20), color: NeyvoColors.borderDefault));

  Widget _buildStepCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Where can we learn about your business?', style: NeyvoTextStyles.heading),
        const SizedBox(height: 8),
        Text('Enter your website URL or choose a category to get AI-suggested services.', style: NeyvoTextStyles.body),
        const SizedBox(height: 16),
        TextField(
          controller: _websiteUrlCtrl,
          decoration: const InputDecoration(
            labelText: 'Website URL (beta)',
            hintText: 'https://yourbusiness.com',
            helperText: 'If we can’t extract details yet, we’ll use category-based suggestions instead.',
            prefixIcon: Icon(Icons.language_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Or choose your industry', style: NeyvoTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((c) {
            final id = c['id']!;
            final label = c['label']!;
            final selected = _categoryCtrl.text == id;
            return FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _categoryCtrl.text = id;
                  _subcategoryCtrl.text = id;
                  _getSuggestions();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _field(label: 'Business name (optional)', controller: _businessNameCtrl, hint: 'e.g. Downtown Dental'),
        const SizedBox(height: 12),
        _field(label: 'Main phone (optional)', controller: _phoneCtrl, hint: '+1 555 123 4567'),
        const SizedBox(height: 24),
        if (_serviceSuggestions.isNotEmpty) ...[
          Text('Select services you offer', style: NeyvoTextStyles.heading),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_serviceSuggestions.length, (index) {
              final s = _serviceSuggestions[index];
              final name = (s['name'] ?? '').toString();
              final selected = _selectedServices.contains(index);
              return FilterChip(
                label: Text(name),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedServices.add(index);
                    } else {
                      _selectedServices.remove(index);
                    }
                  });
                },
              )
                  .animate()
                  .fadeIn(duration: 250.ms, delay: (index * 60).ms)
                  .slideY(begin: 0.1, curve: Curves.easeOut);
            }),
          ),
          const SizedBox(height: 24),
        ],
        FilledButton(
          onPressed: () {
            if (_categoryCtrl.text.isEmpty) {
              setState(() => _categoryCtrl.text = 'general');
              _getSuggestions();
            }
            setState(() => _step = 1);
          },
          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildStepConfirm() {
    final servicesStr = _selectedServices.map((i) => i < _serviceSuggestions.length ? (_serviceSuggestions[i]['name'] ?? '').toString() : '').where((s) => s.isNotEmpty).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Confirm your business profile', style: NeyvoTextStyles.heading),
        const SizedBox(height: 16),
        NeyvoCard(
          glowing: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_businessNameCtrl.text.trim().isNotEmpty)
                _previewRow('Name', _businessNameCtrl.text.trim()),
              _previewRow('Category', _categoryCtrl.text.isEmpty ? '—' : _categoryCtrl.text),
              if (_phoneCtrl.text.trim().isNotEmpty)
                _previewRow('Phone', _phoneCtrl.text.trim()),
              if (servicesStr.isNotEmpty)
                _previewRow('Services', servicesStr),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _editExpanded = !_editExpanded),
              child: Text(_editExpanded ? 'Hide details' : 'Edit details'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => setState(() => _step = 2),
              style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
              child: const Text('Looks good'),
            ),
          ],
        ),
        if (_editExpanded) ...[
          const SizedBox(height: 24),
          _field(label: 'Business name', controller: _businessNameCtrl, hint: 'Downtown Dental'),
          const SizedBox(height: 12),
          _field(label: 'Main phone', controller: _phoneCtrl, hint: '+1 555 123 4567'),
          const SizedBox(height: 12),
          _field(label: 'Subcategory', controller: _subcategoryCtrl, hint: 'Dental clinic, Hair salon…'),
        ],
      ],
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: NeyvoTextStyles.label)),
          Expanded(child: Text(value, style: NeyvoTextStyles.body)),
        ],
      ),
    );
  }

  Widget _buildStepSave() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Save & finish', style: NeyvoTextStyles.heading),
        const SizedBox(height: 8),
        Text('Save your business profile to enable AI agents.', style: NeyvoTextStyles.body),
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _simulate,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Preview & test'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _saveAndPop,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
              style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
            ),
          ],
        ),
        if (_simulations.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._simulations.take(2).map((s) {
            final scenario = (s['scenario'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeyvoCard(
                padding: const EdgeInsets.all(12),
                child: Text(scenario.isEmpty ? 'Preview' : scenario, style: NeyvoTextStyles.body),
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _saveAndPop() async {
    await _save();
    if (mounted && _error == null) Navigator.of(context).pop();
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: NeyvoColors.bgBase,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NeyvoRadius.md),
              borderSide: const BorderSide(color: NeyvoColors.borderDefault),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;
    if (_status == 'ready') {
      color = NeyvoColors.success;
      label = 'Ready';
    } else if (_status == 'partial') {
      color = NeyvoColors.warning;
      label = 'Partial';
    } else {
      color = NeyvoColors.textMuted;
      label = 'Not set up';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(label, style: NeyvoType.bodySmall.copyWith(color: color)),
        ],
      ),
    );
  }
}
