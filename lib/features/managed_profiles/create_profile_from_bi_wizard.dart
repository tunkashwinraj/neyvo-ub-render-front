// lib/features/managed_profiles/create_profile_from_bi_wizard.dart
// Role-based voice profile creation from Business Setup (use_bi=true).

import 'package:flutter/material.dart';
import '../../theme/neyvo_theme.dart';
import '../business_intelligence/bi_wizard_api_service.dart';
import 'managed_profile_api_service.dart';

class CreateProfileFromBiWizard extends StatefulWidget {
  const CreateProfileFromBiWizard({super.key});

  @override
  State<CreateProfileFromBiWizard> createState() => _CreateProfileFromBiWizardState();
}

class _CreateProfileFromBiWizardState extends State<CreateProfileFromBiWizard> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _biStatus = 'missing';
  String _role = 'support';
  String _direction = 'inbound';
  final _goalCtrl = TextEditingController();
  String _tone = 'warm_friendly';
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

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await BiWizardApiService.getStatus();
      if (res['ok'] == true && res['status'] is String) {
        _biStatus = res['status'] as String;
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

  Future<void> _save() async {
    if (_biStatus != 'ready') {
      setState(() {
        _error = 'Business Setup is not ready. Complete it first.';
      });
      return;
    }
    final allowed = _actions.entries.where((e) => e.value).map((e) => e.key).toList();
    if (allowed.isEmpty) {
      setState(() {
        _error = 'Select at least one allowed action.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final goal = _goalCtrl.text.trim().isEmpty
          ? _defaultGoalForRole(_role)
          : _goalCtrl.text.trim();
      final res = await ManagedProfileApiService.createProfileFromBi(
        role: _role,
        goal: goal,
        allowedActions: allowed,
        tone: _tone,
        direction: _direction,
      );
      if (res['error'] != null) {
        setState(() {
          _error = res['error'].toString();
        });
      } else {
        if (mounted) Navigator.of(context).pop(true);
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

  String _defaultGoalForRole(String role) {
    switch (role) {
      case 'sales':
        return 'Qualify leads and book consultations.';
      case 'booking':
        return 'Book, reschedule, and cancel appointments.';
      case 'billing':
        return 'Help with billing questions and payment options.';
      case 'promo':
        return 'Promote offers and capture interested leads.';
      case 'support':
      default:
        return 'Help callers with questions and route them correctly.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NeyvoColors.bgBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
      ),
      contentPadding: const EdgeInsets.all(NeyvoSpacing.lg),
      title: Row(
        children: [
          const Icon(Icons.smart_toy_outlined, color: NeyvoColors.teal),
          const SizedBox(width: NeyvoSpacing.sm),
          const Text('Create Voice Profile from Business Setup'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_biStatus != 'ready')
                    Padding(
                      padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                      child: Text(
                        _biStatus == 'missing'
                            ? 'Business Setup is not configured yet. Complete it first.'
                            : 'Business Setup is partially configured. Finish it for best results.',
                        style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.warning),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                      child: Text(_error!,
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error)),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Role', style: NeyvoTextStyles.label),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _role,
                    items: const [
                      DropdownMenuItem(value: 'support', child: Text('Support agent')),
                      DropdownMenuItem(value: 'sales', child: Text('Sales agent')),
                      DropdownMenuItem(value: 'booking', child: Text('Booking agent')),
                      DropdownMenuItem(value: 'billing', child: Text('Billing agent')),
                      DropdownMenuItem(value: 'promo', child: Text('Outbound promo agent')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _role = v);
                    },
                  ),
                  const SizedBox(height: NeyvoSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Goal', style: NeyvoTextStyles.label),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _goalCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: _defaultGoalForRole(_role),
                      filled: true,
                      fillColor: NeyvoColors.bgRaised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(NeyvoRadius.md),
                        borderSide: const BorderSide(color: NeyvoColors.borderDefault),
                      ),
                    ),
                  ),
                  const SizedBox(height: NeyvoSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Allowed actions', style: NeyvoTextStyles.label),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _actions.keys.map((key) {
                      final label = _labelForAction(key);
                      final selected = _actions[key] == true;
                      return FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            _actions[key] = v;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: NeyvoSpacing.md),
                  Row(
                    children: [
                      Text('Tone', style: NeyvoTextStyles.label),
                      const SizedBox(width: NeyvoSpacing.sm),
                      DropdownButton<String>(
                        value: _tone,
                        items: const [
                          DropdownMenuItem(
                              value: 'warm_friendly', child: Text('Warm & friendly')),
                          DropdownMenuItem(
                              value: 'professional_clear',
                              child: Text('Professional & clear')),
                          DropdownMenuItem(
                              value: 'calm_reassuring', child: Text('Calm & reassuring')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _tone = v);
                        },
                      ),
                      const Spacer(),
                      ToggleButtons(
                        isSelected: [
                          _direction == 'inbound',
                          _direction == 'outbound',
                          _direction == 'both',
                        ],
                        onPressed: (idx) {
                          setState(() {
                            _direction = idx == 0
                                ? 'inbound'
                                : idx == 1
                                    ? 'outbound'
                                    : 'both';
                          });
                        },
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Inbound'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Outbound'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Both'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _biStatus != 'ready' ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  String _labelForAction(String key) {
    switch (key) {
      case 'answer_questions':
        return 'Answer questions';
      case 'create_callback':
        return 'Create callback';
      case 'create_lead':
        return 'Create lead';
      case 'create_booking':
        return 'Create booking';
      case 'check_availability':
        return 'Check availability';
      case 'reschedule_booking':
        return 'Reschedule booking';
      case 'cancel_booking':
        return 'Cancel booking';
      case 'send_confirmation':
        return 'Send confirmation';
      case 'handoff':
        return 'Handoff to human';
      default:
        return key;
    }
  }
}
