// lib/features/agents/create_agent_wizard.dart
// Role-first agent creation — simple 3-step flow.

import 'package:flutter/material.dart';

import '../../theme/neyvo_theme.dart';
import '../business_intelligence/bi_wizard_api_service.dart';
import '../managed_profiles/managed_profile_api_service.dart';
//cmd new
class CreateAgentWizard extends StatefulWidget {
  const CreateAgentWizard({super.key});

  @override
  State<CreateAgentWizard> createState() => _CreateAgentWizardState();
}

class _CreateAgentWizardState extends State<CreateAgentWizard> {
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _biStatus = 'missing';

  String _role = 'support';
  final Set<String> _selectedGoals = {};
  String _tone = 'warm_friendly';
  bool _advancedExpanded = false;
  final Map<String, bool> _actions = {
    'answer_questions': true,
    'create_callback': true,
    'create_lead': false,
    'create_booking': false,
    'check_availability': false,
    'reschedule_booking': false,
    'cancel_booking': false,
    'send_confirmation': false,
    'handoff': true,
  };

  static const List<Map<String, String>> _roles = [
    {'id': 'support', 'label': 'Reception / Support'},
    {'id': 'booking', 'label': 'Booking'},
    {'id': 'sales', 'label': 'Sales'},
    {'id': 'billing', 'label': 'Billing'},
    {'id': 'promo', 'label': 'Promo / Outreach'},
    {'id': 'custom', 'label': 'Custom'},
  ];

  static const Map<String, List<String>> _goalsByRole = {
    'support': ['Answer questions', 'Route callers', 'Take messages', 'Handle complaints'],
    'booking': ['Book appointments', 'Confirm/reschedule', 'Handle no-shows', 'Check availability'],
    'sales': ['Qualify leads', 'Capture contact details', 'Warm transfer', 'Follow up'],
    'billing': ['Answer billing questions', 'Process payments', 'Explain invoices', 'Set up payment plans'],
    'promo': ['Promote offers', 'Capture interest', 'Schedule callbacks', 'Qualify prospects'],
    'custom': ['Custom goal 1', 'Custom goal 2', 'Custom goal 3'],
  };

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await BiWizardApiService.getStatus();
      if (res['ok'] == true && res['status'] is String) {
        _biStatus = res['status'] as String;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _defaultGoalForRole(String role) {
    switch (role) {
      case 'sales': return 'Qualify leads and book consultations.';
      case 'booking': return 'Book, reschedule, and cancel appointments.';
      case 'billing': return 'Help with billing questions and payment options.';
      case 'promo': return 'Promote offers and capture interested leads.';
      case 'support':
      default: return 'Help callers with questions and route them correctly.';
    }
  }

  List<String> _defaultActionsForRole(String role) {
    switch (role) {
      case 'booking':
        return ['answer_questions', 'create_booking', 'check_availability', 'reschedule_booking', 'cancel_booking', 'create_callback', 'handoff'];
      case 'sales':
        return ['answer_questions', 'create_lead', 'create_callback', 'handoff'];
      case 'billing':
        return ['answer_questions', 'create_callback', 'handoff'];
      case 'promo':
        return ['answer_questions', 'create_lead', 'create_callback'];
      default:
        return ['answer_questions', 'create_callback', 'create_lead', 'handoff'];
    }
  }

  Future<void> _create() async {
    if (_biStatus != 'ready') {
      setState(() => _error = 'Set up your business profile first in Launch Wizard.');
      return;
    }
    final goal = _selectedGoals.isNotEmpty
        ? _selectedGoals.join('. ')
        : _defaultGoalForRole(_role);
    final defaultActions = _defaultActionsForRole(_role);
    final allowed = _advancedExpanded
        ? _actions.entries.where((e) => e.value).map((e) => e.key).toList()
        : defaultActions;
    if (allowed.isEmpty) {
      setState(() => _error = 'Select at least one allowed action.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await ManagedProfileApiService.createProfileFromBi(
        role: _role,
        goal: goal,
        allowedActions: allowed,
        tone: _tone,
        direction: 'inbound',
      );
      if (res['error'] != null) {
        setState(() => _error = res['error'].toString());
      } else {
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          width: 200,
          child: Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
        ),
      );
    }
    if (_biStatus != 'ready') {
      return AlertDialog(
        title: const Text('Create Operator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.info_outline, size: 48, color: NeyvoColors.warning),
            const SizedBox(height: 16),
            Text(
              'Set up your business profile first to create the right agents.',
              style: NeyvoTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
              child: const Text('Go to Launch Wizard'),
            ),
          ],
        ),
      );
    }
    return AlertDialog(
      backgroundColor: NeyvoColors.bgBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeyvoRadius.lg)),
      contentPadding: const EdgeInsets.all(24),
      title: Text(_step == 0 ? 'Choose role' : _step == 1 ? 'Choose goals' : 'Confirm & create'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NeyvoColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                ),
                const SizedBox(height: 16),
              ],
              if (_step == 0) _buildRoleStep(),
              if (_step == 1) _buildGoalsStep(),
              if (_step == 2) _buildConfirmStep(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 8),
                  if (_step < 2)
                    FilledButton(
                      onPressed: () => setState(() => _step++),
                      style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                      child: const Text('Continue'),
                    )
                  else
                    FilledButton(
                      onPressed: _saving ? null : _create,
                      style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Operator'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleStep() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _roles.map((r) {
        final id = r['id']!;
        final label = r['label']!;
        final selected = _role == id;
        return InkWell(
          onTap: () => setState(() => _role = id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? NeyvoColors.teal.withOpacity(0.15) : NeyvoColors.bgRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? NeyvoColors.teal : NeyvoColors.borderDefault,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _iconForRole(id),
                  size: 32,
                  color: selected ? NeyvoColors.teal : NeyvoColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: NeyvoTextStyles.label.copyWith(
                    color: selected ? NeyvoColors.teal : NeyvoColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForRole(String id) {
    switch (id) {
      case 'support': return Icons.support_agent;
      case 'booking': return Icons.calendar_today;
      case 'sales': return Icons.trending_up;
      case 'billing': return Icons.receipt_long;
      case 'promo': return Icons.campaign;
      default: return Icons.tune;
    }
  }

  Widget _buildGoalsStep() {
    final goals = _goalsByRole[_role] ?? _goalsByRole['custom']!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: goals.map((g) {
        final selected = _selectedGoals.contains(g);
        return FilterChip(
          label: Text(g),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) _selectedGoals.add(g);
              else _selectedGoals.remove(g);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildConfirmStep() {
    final goal = _selectedGoals.isNotEmpty
        ? _selectedGoals.join('. ')
        : _defaultGoalForRole(_role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _confirmRow('Role', _roles.firstWhere((r) => r['id'] == _role, orElse: () => {'label': _role})['label'] ?? _role),
        _confirmRow('Goal', goal),
        _confirmRow('Tone', _tone == 'warm_friendly' ? 'Warm & friendly' : _tone),
        const SizedBox(height: 16),
        ExpansionTile(
          title: Text('Advanced', style: NeyvoTextStyles.label),
          initiallyExpanded: _advancedExpanded,
          onExpansionChanged: (v) => setState(() => _advancedExpanded = v),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _actions.keys.map((key) {
                final label = key.replaceAll('_', ' ');
                final selected = _actions[key] == true;
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (v) => setState(() => _actions[key] = v),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: NeyvoTextStyles.label)),
          Expanded(child: Text(value, style: NeyvoTextStyles.body)),
        ],
      ),
    );
  }
}
