// lib/features/agents/create_agent_wizard.dart
// UB Operator Wizard: department → work goals → AI suggest tools → confirm → AI craft prompt → overview → create.

import 'package:flutter/material.dart';

import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';
import '../../theme/neyvo_theme.dart';
import '../../pulse_route_names.dart';
import '../managed_profiles/managed_profile_api_service.dart';

class CreateAgentWizard extends StatefulWidget {
  const CreateAgentWizard({super.key, this.initialDepartmentId});

  final String? initialDepartmentId;

  @override
  State<CreateAgentWizard> createState() => _CreateAgentWizardState();
}

class _CreateAgentWizardState extends State<CreateAgentWizard> {
  static const int _totalSteps = 7;
  int _step = 0;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _departments = [];
  String _selectedDepartmentId = '';
  String _selectedDepartmentName = '';
  final _workGoalsCtrl = TextEditingController();
  List<String> _suggestedToolKeys = [];
  List<Map<String, String>> _suggestedVariables = [];
  final Set<String> _selectedToolKeys = {};
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
    if (widget.initialDepartmentId != null && widget.initialDepartmentId!.isNotEmpty) {
      _selectedDepartmentId = widget.initialDepartmentId!;
    }
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
          if (_selectedDepartmentId.isEmpty && list.isNotEmpty) {
            final first = list.first;
            _selectedDepartmentId = (first['id'] ?? '').toString();
            _selectedDepartmentName = (first['name'] ?? '').toString();
          } else if (_selectedDepartmentId.isNotEmpty) {
            for (final d in list) {
              if ((d['id'] ?? '').toString() == _selectedDepartmentId) {
                _selectedDepartmentName = (d['name'] ?? '').toString();
                break;
              }
            }
          }
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

  Future<void> _fetchSuggestedTools() async {
    if (_workGoalsCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter work goals first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ManagedProfileApiService.aiSuggestTools(
        department: _selectedDepartmentId.isNotEmpty ? _selectedDepartmentId : _selectedDepartmentName,
        workGoals: _workGoalsCtrl.text.trim(),
      );
      if (!mounted) return;
      final tools = (res['suggested_tool_keys'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final vars = (res['suggested_variables'] as List?)
          ?.map((e) => Map<String, String>.from({
                'key': (e is Map ? e['key'] : null)?.toString() ?? '',
                'label': (e is Map ? e['label'] : null)?.toString() ?? '',
              }))
          .toList() ?? [];
      setState(() {
        _suggestedToolKeys = tools;
        _suggestedVariables = vars;
        _selectedToolKeys.clear();
        _selectedToolKeys.addAll(tools);
        _promptVariables = List.from(vars);
        _loading = false;
      });
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
    if (_step != 5 || _promptVariables.isEmpty || _voicemailMessage.isEmpty ||
        _overviewExampleSentence != null || _overviewExampleLoading) return;
    setState(() => _overviewExampleLoading = true);
    try {
      final res = await ManagedProfileApiService.previewVariableSentence(
        template: _voicemailMessage,
        variableValues: _overviewSampleValues(_promptVariables),
      );
      if (mounted && _step == 5) {
        setState(() {
          _overviewExampleSentence = (res['sentence'] ?? '').toString();
          _overviewExampleLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _overviewExampleLoading = false);
    }
  }

  String? get _selectedDepartmentPhone {
    for (final d in _departments) {
      if ((d['id'] ?? '').toString() == _selectedDepartmentId) {
        final p = d['phone'];
        return p != null && p.toString().trim().isNotEmpty ? p.toString().trim() : null;
      }
    }
    return null;
  }

  Future<void> _fetchCraftedPrompt() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ManagedProfileApiService.aiCraftPrompt(
        department: _selectedDepartmentId.isNotEmpty ? _selectedDepartmentId : _selectedDepartmentName,
        workGoals: _workGoalsCtrl.text.trim(),
        selectedToolKeys: _selectedToolKeys.toList(),
        promptVariables: _promptVariables,
        departmentPhone: _selectedDepartmentPhone,
      );
      if (!mounted) return;
      setState(() {
        _systemPrompt = (res['system_prompt'] ?? '').toString();
        _voicemailMessage = (res['voicemail_message'] ?? '').toString();
        _operatorSummary = (res['operator_summary'] ?? '').toString();
        _loading = false;
        if (_profileNameCtrl.text.trim().isEmpty) {
          _profileNameCtrl.text = '$_selectedDepartmentName Operator';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final profileName = _profileNameCtrl.text.trim();
    if (profileName.isEmpty) {
      setState(() => _error = 'Enter an operator name.');
      return;
    }
    if (_systemPrompt.isEmpty) {
      setState(() => _error = 'System prompt is missing. Go back and generate it.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await ManagedProfileApiService.createProfile({
        'schema_version': 2,
        'profile_name': profileName,
        'department': _selectedDepartmentId.isNotEmpty ? _selectedDepartmentId : _selectedDepartmentName,
        'work_goals': _workGoalsCtrl.text.trim(),
        'custom_system_prompt': _systemPrompt,
        'voicemail_message': _voicemailMessage.isNotEmpty ? _voicemailMessage : null,
        'prompt_variables': _promptVariables,
        'operator_summary': _operatorSummary.isNotEmpty ? _operatorSummary : null,
        'enabled_tool_keys': _selectedToolKeys.toList(),
        'direction': 'outbound',
      });
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
        return 'Select department';
      case 1:
        return 'What should this operator do?';
      case 2:
        return 'Suggested tools & variables';
      case 3:
        return 'Confirm tools and variables';
      case 4:
        return 'Generate prompt';
      case 5:
        return 'Overview';
      case 6:
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
                if (_step == 0) _buildDepartmentStep(),
                if (_step == 1) _buildWorkGoalsStep(),
                if (_step == 2) _buildSuggestToolsStep(),
                if (_step == 3) _buildConfirmToolsStep(),
                if (_step == 4) _buildCraftPromptStep(),
                if (_step == 5) _buildOverviewStep(),
                if (_step == 6) _buildCreateStep(),
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
                  if (_step < _totalSteps - 1) ...[
                    if (_step == 1)
                      FilledButton(
                        onPressed: _workGoalsCtrl.text.trim().isEmpty ? null : () => setState(() {
                          _step++;
                          _overviewExampleSentence = null;
                        }),
                        style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                        child: const Text('Continue'),
                      )
                    else if (_step == 2)
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _step++;
                              _overviewExampleSentence = null;
                            }),
                            child: const Text('Continue without suggestions'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              await _fetchSuggestedTools();
                              if (mounted && _error == null) setState(() {
                                _step++;
                                _overviewExampleSentence = null;
                              });
                            },
                            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                            child: const Text('Get suggestions'),
                          ),
                        ],
                      )
                    else if (_step == 3)
                      FilledButton(
                        onPressed: () => setState(() {
                          _step++;
                          _overviewExampleSentence = null;
                        }),
                        style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                        child: const Text('Continue'),
                      )
                    else if (_step == 4)
                      FilledButton(
                        onPressed: () async {
                          await _fetchCraftedPrompt();
                          if (mounted && _error == null) {
                            setState(() {
                              _step++;
                              _overviewExampleSentence = null;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) => _loadOverviewExampleIfNeeded());
                          }
                        },
                        style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                        child: const Text('Generate prompt'),
                      )
                    else
                      FilledButton(
                        onPressed: () => setState(() {
                          _step++;
                          _overviewExampleSentence = null;
                        }),
                        style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                        child: const Text('Continue'),
                      ),
                  ] else
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

  Widget _buildDepartmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose the department this operator will represent.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (_departments.isEmpty)
          const Text('Loading departments…')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _departments.map((d) {
              final id = (d['id'] ?? '').toString();
              final name = (d['name'] ?? '').toString();
              final selected = _selectedDepartmentId == id;
              return InkWell(
                onTap: () => setState(() {
                  _selectedDepartmentId = id;
                  _selectedDepartmentName = name;
                }),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? NeyvoColors.teal.withOpacity(0.15) : NeyvoColors.bgRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? NeyvoColors.teal : NeyvoColors.borderDefault),
                  ),
                  child: Text(name, style: NeyvoTextStyles.label.copyWith(color: selected ? NeyvoColors.teal : null)),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildWorkGoalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Describe what this operator should do (e.g. remind students about federal loan acceptance, guide them through the portal, offer callback).',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: NeyvoColors.bgRaised.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: NeyvoColors.borderDefault.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tips', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal)),
              const SizedBox(height: 4),
              Text(
                'Include: what to remind or explain (e.g. federal loan acceptance, portal steps), how to guide (one step at a time), and what to offer (e.g. callback if busy).',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Example: "Remind students to accept or decline federal loans for this year; guide them through UB Portal → Self-Service → Financial Aid → View and Accept My Awards; offer to schedule a callback if they\'re busy."',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _workGoalsCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'E.g. Remind students to accept or decline federal loans, guide one step at a time in the portal, schedule callbacks if they\'re busy.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  bool _isVariableSelected(Map<String, String> v) {
    final key = v['key'] ?? '';
    return _promptVariables.any((e) => (e['key'] ?? '') == key);
  }

  void _toggleVariable(Map<String, String> v, bool selected) {
    final key = v['key'] ?? '';
    if (selected) {
      if (!_promptVariables.any((e) => (e['key'] ?? '') == key)) {
        _promptVariables.add(Map<String, String>.from(v));
      }
    } else {
      _promptVariables.removeWhere((e) => (e['key'] ?? '') == key);
    }
  }

  Widget _buildSuggestToolsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_suggestedToolKeys.isEmpty && _suggestedVariables.isEmpty)
          Text(
            'Click "Get suggestions" to load AI-recommended tools and variables based on your department and work goals, or "Continue without suggestions" to skip.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          )
        else ...[
          if (_suggestedToolKeys.isNotEmpty) ...[
            Text('Select the tools this operator can use:', style: NeyvoTextStyles.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _suggestedToolKeys.map((key) {
                final selected = _selectedToolKeys.contains(key);
                final label = key.replaceAll('@1.0', '').replaceAll('_', ' ');
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) _selectedToolKeys.add(key);
                    else _selectedToolKeys.remove(key);
                  }),
                );
              }).toList(),
            ),
          ],
          if (_suggestedVariables.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Select prompt variables (used in the script):', style: NeyvoTextStyles.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _suggestedVariables.map((v) {
                final label = v['label'] ?? v['key'] ?? '';
                final selected = _isVariableSelected(v);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (sel) => setState(() => _toggleVariable(v, sel)),
                );
              }).toList(),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildConfirmToolsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tools: ${_selectedToolKeys.join(", ")}', style: NeyvoTextStyles.body),
        const SizedBox(height: 8),
        Text('Variables: ${_promptVariables.map((v) => v['label'] ?? v['key']).join(", ")}', style: NeyvoTextStyles.body),
      ],
    );
  }

  Widget _buildCraftPromptStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDepartmentPhone != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Department number will be included in the script when available.',
              style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.teal),
            ),
          ),
        if (_operatorSummary.isNotEmpty) ...[
          Text('Summary:', style: NeyvoTextStyles.label),
          const SizedBox(height: 4),
          Text(_operatorSummary, style: NeyvoTextStyles.body),
          const SizedBox(height: 16),
        ],
        if (_systemPrompt.isNotEmpty) ...[
          Text('Generated prompt (preview):', style: NeyvoTextStyles.label),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeyvoColors.bgRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeyvoColors.borderDefault),
            ),
            child: Text(
              _systemPrompt.length > 400 ? '${_systemPrompt.substring(0, 400)}…' : _systemPrompt,
              style: NeyvoTextStyles.micro,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewStep() {
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
        _overviewRow('Department', _selectedDepartmentName),
        _overviewRow('Summary', _operatorSummary.isNotEmpty ? _operatorSummary : _workGoalsCtrl.text.trim()),
        _overviewRow('Tools', _selectedToolKeys.join(', ')),
        _overviewRow('Variables', _promptVariables.map((v) => v['label'] ?? v['key']).join(', ')),
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
