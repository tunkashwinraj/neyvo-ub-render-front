// lib/screens/business_setup_page.dart
// Business Intelligence Setup — model your business once for all voice agents.

import 'package:flutter/material.dart';

import '../theme/neyvo_theme.dart';
import '../features/business_intelligence/bi_wizard_api_service.dart';

class BusinessSetupPage extends StatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  State<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends State<BusinessSetupPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _status = 'missing'; // missing | partial | ready
  final _businessNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _subcategoryCtrl = TextEditingController();
  List<Map<String, dynamic>> _serviceSuggestions = [];
  final Set<int> _selectedServices = {};
  List<Map<String, dynamic>> _simulations = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
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
      final biRes = await BiWizardApiService.load();
      if (biRes['ok'] == true && biRes['bi'] != null) {
        final bi = Map<String, dynamic>.from(biRes['bi'] as Map);
        final core = Map<String, dynamic>.from(bi['core'] as Map? ?? {});
        final knowledge = Map<String, dynamic>.from(bi['knowledge'] as Map? ?? {});
        final contact = Map<String, dynamic>.from(knowledge['contact'] as Map? ?? {});
        _businessNameCtrl.text = (core['name'] ?? '').toString();
        _categoryCtrl.text = (core['category'] ?? '').toString();
        _subcategoryCtrl.text = (core['subcategory'] ?? '').toString();
        _phoneCtrl.text = (contact['main_phone'] ?? contact['mainPhone'] ?? '').toString();
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
          Text('Business Setup', style: NeyvoType.headlineLarge),
          const SizedBox(height: NeyvoSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Model your business once for all voice agents.',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                ),
              ),
              _buildStatusChip(),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: NeyvoSpacing.sm),
            Text(_error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error)),
          ],
          const SizedBox(height: NeyvoSpacing.xl),
          NeyvoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Identity', style: NeyvoTextStyles.heading),
                const SizedBox(height: NeyvoSpacing.sm),
                _field(label: 'Business name', controller: _businessNameCtrl, hint: 'Downtown Dental'),
                const SizedBox(height: NeyvoSpacing.sm),
                _field(label: 'Main phone', controller: _phoneCtrl, hint: '+1 555 123 4567'),
              ],
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          NeyvoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category', style: NeyvoTextStyles.heading),
                const SizedBox(height: NeyvoSpacing.sm),
                _field(label: 'Industry category', controller: _categoryCtrl, hint: 'Healthcare, Beauty, Legal…'),
                const SizedBox(height: NeyvoSpacing.sm),
                _field(label: 'Subcategory', controller: _subcategoryCtrl, hint: 'Dental clinic, Hair salon…'),
                const SizedBox(height: NeyvoSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _getSuggestions,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Get AI suggestions'),
                    style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                  ),
                ),
              ],
            ),
          ),
          if (_serviceSuggestions.isNotEmpty) ...[
            const SizedBox(height: NeyvoSpacing.lg),
            NeyvoCard(
              glowing: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suggested services', style: NeyvoTextStyles.heading),
                  const SizedBox(height: NeyvoSpacing.sm),
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
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: NeyvoSpacing.lg),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _simulate,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Simulate calls'),
              ),
              const SizedBox(width: NeyvoSpacing.sm),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save'),
                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
              ),
            ],
          ),
          if (_simulations.isNotEmpty) ...[
            const SizedBox(height: NeyvoSpacing.lg),
            Text('Simulation preview', style: NeyvoTextStyles.heading),
            const SizedBox(height: NeyvoSpacing.sm),
            ..._simulations.map((s) {
              final scenario = (s['scenario'] ?? '').toString();
              final userReq = (s['userRequest'] ?? '').toString();
              final risk = (s['riskLevel'] ?? '').toString();
              final missing = (s['missingData'] as List? ?? []).join(', ');
              final warn = (s['complianceWarning'] as List? ?? []).join(', ');
              return Padding(
                padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                child: NeyvoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scenario.isEmpty ? 'Scenario' : scenario,
                        style: NeyvoTextStyles.heading.copyWith(color: NeyvoTheme.textPrimary),
                      ),
                      const SizedBox(height: NeyvoSpacing.xs),
                      Text(userReq, style: NeyvoType.bodySmall),
                      const SizedBox(height: NeyvoSpacing.xs),
                      Text('Risk: $risk', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.warning)),
                      if (missing.isNotEmpty)
                        Text('Missing: $missing', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                      if (warn.isNotEmpty)
                        Text('Compliance: $warn', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
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
