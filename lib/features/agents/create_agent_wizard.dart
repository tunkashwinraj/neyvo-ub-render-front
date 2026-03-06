// lib/features/agents/create_agent_wizard.dart
// UB Operator Wizard: work goals → overview → create. Department fixed to Student Financial Services.

import 'package:flutter/material.dart';

import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';
import '../../theme/neyvo_theme.dart';
import '../../pulse_route_names.dart';
import '../managed_profiles/managed_profile_api_service.dart';

/// Default tools for UB operator when none selected (backend uses same default).
const List<String> _defaultToolKeys = [
  'get_business_info@1.0',
  'create_callback@1.0',
  'send_confirmation@1.0',
];

/// Friendly labels for Overview abilities (no raw tool keys shown).
const Map<String, String> _toolKeyToFriendlyLabel = {
  'get_business_info@1.0': 'Answer questions about the department',
  'create_callback@1.0': 'Schedule callbacks',
  'send_confirmation@1.0': 'Send confirmations',
};

class CreateAgentWizard extends StatefulWidget {
  const CreateAgentWizard({super.key, this.initialDepartmentId});

  final String? initialDepartmentId;

  @override
  State<CreateAgentWizard> createState() => _CreateAgentWizardState();
}

class _CreateAgentWizardState extends State<CreateAgentWizard> {
  static const int _totalSteps = 3;
  int _step = 0;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  static const String _fixedDepartmentId = 'student_financial_services';
  static const String _fixedDepartmentName = 'Student Financial Services';
  static const String _fixedDepartmentPhone = '203-576-4568';

  List<Map<String, dynamic>> _departments = [];
  final _workGoalsCtrl = TextEditingController();
  List<Map<String, String>> _promptVariables = [];
  String _systemPrompt = '';
  String _voicemailMessage = '';
  String _operatorSummary = '';
  final _profileNameCtrl = TextEditingController();
  String? _overviewExampleSentence;
  bool _overviewExampleLoading = false;

  @override
  void initState() {
    super.initState();
    _profileNameCtrl.text = 'Student Financial Services Operator';
    _loadDepartments();
  }

  @override
  void dispose() {
    _workGoalsCtrl.dispose();
    _profileNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ManagedProfileApiService.getUbDepartments(descriptions: true);
      final list = (res['departments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _departments = list;
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

  /// Call ai-craft-prompt with fixed department and default tools; store prompt/summary/voicemail for create.
  Future<void> _fetchCraftedPromptForOverview() async {
    if (_workGoalsCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter work goals first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ManagedProfileApiService.aiCraftPrompt(
        department: _fixedDepartmentId,
        workGoals: _workGoalsCtrl.text.trim(),
        selectedToolKeys: _defaultToolKeys,
        promptVariables: _promptVariables,
        departmentPhone: _fixedDepartmentPhone,
      );
      if (!mounted) return;
      setState(() {
        _systemPrompt = (res['system_prompt'] ?? '').toString();
        _voicemailMessage = (res['voicemail_message'] ?? '').toString();
        _operatorSummary = (res['operator_summary'] ?? '').toString();
        _loading = false;
        _step = 1;
        _overviewExampleSentence = null;
      });
      if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _loadOverviewExampleIfNeeded());
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  static Map<String, String> _overviewSampleValues(List<Map<String, String>> variables) {
    final out = <String, String>{};
    for (final v in variables) {
      final key = (v['key'] ?? '').trim();
      if (key.isEmpty) continue;
      final lower = key.toLowerCase();
      if (lower.contains('name') && !lower.contains('balance')) out[key] = 'Ashwin';
      else if (lower.contains('balance')) out[key] = '50';
      else if (lower.contains('fee') || lower.contains('late')) out[key] = '10';
      else if (lower.contains('deadline') || lower.contains('date')) out[key] = 'April 5th';
      else if (lower.contains('phone')) out[key] = '203-576-4000';
      else if (lower.contains('email')) out[key] = 'student@bridgeport.edu';
      else out[key] = 'Sample';
    }
    return out;
  }

  Future<void> _loadOverviewExampleIfNeeded() async {
    if (_step != 1 || _promptVariables.isEmpty || _voicemailMessage.isEmpty ||
        _overviewExampleSentence != null || _overviewExampleLoading) return;
    setState(() => _overviewExampleLoading = true);
    try {
      final res = await ManagedProfileApiService.previewVariableSentence(
        template: _voicemailMessage,
        variableValues: _overviewSampleValues(_promptVariables),
      );
      if (mounted && _step == 1) {
        setState(() {
          _overviewExampleSentence = (res['sentence'] ?? '').toString();
          _overviewExampleLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _overviewExampleLoading = false);
    }
  }

  /// Friendly ability labels for the default tools (Overview step).
  List<String> get _overviewAbilityLabels {
    return _defaultToolKeys
        .map((k) => _toolKeyToFriendlyLabel[k] ?? k.replaceAll('@1.0', '').replaceAll('_', ' '))
        .toList();
  }

  Future<void> _create() async {
    final profileName = _profileNameCtrl.text.trim();
    if (profileName.isEmpty) {
      setState(() => _error = 'Enter an operator name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'schema_version': 2,
      'profile_name': profileName,
      'department': _fixedDepartmentId,
      'work_goals': _workGoalsCtrl.text.trim(),
      'prompt_variables': _promptVariables,
      'operator_summary': _operatorSummary.isNotEmpty ? _operatorSummary : null,
      'enabled_tool_keys': _defaultToolKeys,
      'direction': 'outbound',
    };
    if (_systemPrompt.isNotEmpty) {
      payload['custom_system_prompt'] = _systemPrompt;
      if (_voicemailMessage.isNotEmpty) payload['voicemail_message'] = _voicemailMessage;
    }
    try {
      final res = await ManagedProfileApiService.createProfile(payload);
      if (!mounted) return;
      final err = res['error'];
      if (err != null) {
        setState(() => _error = err.toString());
        setState(() => _saving = false);
        return;
      }
      final profileId = res['profile_id']?.toString();
      if (mounted) {
        Navigator.of(context).pop(true);
        if (profileId != null && profileId.isNotEmpty) {
          Navigator.of(context, rootNavigator: true).pushNamed(
            PulseRouteNames.managedProfileDetail,
            arguments: profileId,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
        setState(() => _saving = false);
      }
    }
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'What should this operator do?';
      case 1:
        return 'Overview';
      case 2:
        return 'Create operator';
      default:
        return 'Create operator';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NeyvoColors.bgBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeyvoRadius.lg)),
      contentPadding: const EdgeInsets.all(24),
      title: Text('$_stepTitle (${_step + 1}/$_totalSteps)'),
      content: SizedBox(
        width: 520,
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
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
                )
              else ...[
                if (_step == 0) _buildWorkGoalsStep(),
                if (_step == 1) _buildOverviewStep(),
                if (_step == 2) _buildCreateStep(),
              ],
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
                  if (_step < _totalSteps - 1)
                    FilledButton(
                      onPressed: _step == 0
                          ? (_workGoalsCtrl.text.trim().isEmpty ? null : () => _fetchCraftedPromptForOverview())
                          : () => setState(() {
                                _step++;
                                _overviewExampleSentence = null;
                              }),
                      style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                      child: Text(_step == 0 ? 'Continue' : 'Continue'),
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

  Widget _buildWorkGoalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Department: $_fixedDepartmentName',
          style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal),
        ),
        const SizedBox(height: 12),
        Text(
          'Describe what this operator should do (e.g. remind students about federal loan acceptance, guide them through the portal, offer callback).',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeyvoColors.bgRaised.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: NeyvoColors.borderDefault.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Example (copy and edit if you like)', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal)),
              const SizedBox(height: 6),
              SelectableText(
                'Remind students to accept or decline federal student loans for this year; guide them through UB Portal → Self-Service → Financial Aid → View and Accept My Awards; offer to schedule a callback if they\'re busy. Provide department number 203-576-4568.',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _workGoalsCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Paste or type work goals…',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildOverviewStep() {
    final summary = _operatorSummary.isNotEmpty ? _operatorSummary : _workGoalsCtrl.text.trim();
    final abilities = _overviewAbilityLabels;
    final variablesStr = _promptVariables.isEmpty
        ? 'None'
        : _promptVariables.map((v) => v['label'] ?? v['key']).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _profileNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Operator name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _overviewRow('Department', _fixedDepartmentName),
        _overviewRow('Summary', summary.isEmpty ? '—' : summary),
        _overviewRow('Abilities', abilities.isEmpty ? '—' : abilities.join(', ')),
        _overviewRow('Variables', variablesStr),
        if (_promptVariables.isNotEmpty && _voicemailMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Example sentence', style: NeyvoTextStyles.label),
          const SizedBox(height: 4),
          if (_overviewExampleLoading)
            const SizedBox(height: 20, child: Center(child: CircularProgressIndicator()))
          else if (_overviewExampleSentence != null && _overviewExampleSentence!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeyvoColors.bgRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeyvoColors.borderDefault),
              ),
              child: Text(
                'Example: $_overviewExampleSentence',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary),
              ),
            ),
        ],
      ],
    );
  }

  Widget _overviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: NeyvoTextStyles.label)),
          Expanded(child: Text(value, style: NeyvoTextStyles.body)),
        ],
      ),
    );
  }

  Widget _buildCreateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Operator name: ${_profileNameCtrl.text.trim().isEmpty ? "(required)" : _profileNameCtrl.text.trim()}', style: NeyvoTextStyles.body),
        const SizedBox(height: 8),
        Text('Press "Create Operator" to create and open the operator detail page.', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary)),
      ],
    );
  }
}
