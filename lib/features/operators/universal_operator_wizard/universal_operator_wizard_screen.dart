// lib/features/operators/universal_operator_wizard/universal_operator_wizard_screen.dart
// Universal 5-step operator creation wizard (v3). Persists draft to shared_preferences.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../managed_profiles/managed_profile_api_service.dart';
import '../../managed_profiles/profile_detail_page.dart';
import '../../../theme/neyvo_theme.dart';
import 'universal_wizard_state.dart';

const String _draftKey = 'universal_operator_wizard_draft';
const int _totalSteps = 5;

/// Suggested primary objective text by department (Step 3).
const Map<String, String> _departmentPrimaryObjectiveSuggestions = {
  'Education': 'Confirm the student\'s attendance and answer questions about next steps, deadlines, and resources.',
  'Admissions': 'Welcome the prospect, answer questions about programs and application steps, and offer to schedule a call or campus visit.',
  'Financial Aid': 'Explain aid status, next steps, and deadlines; offer to transfer to a specialist if needed.',
  'Registrar': 'Answer registration, transcripts, and enrollment verification questions; direct to forms or portal when needed.',
  'Healthcare': 'Confirm appointment or referral, collect brief intake information, and direct to the right department or voicemail.',
  'Other': 'Help the caller with their request, answer questions, and offer next steps or transfer as appropriate.',
};

class UniversalOperatorWizardScreen extends StatefulWidget {
  const UniversalOperatorWizardScreen({super.key, this.initialState});

  final UniversalWizardState? initialState;

  @override
  State<UniversalOperatorWizardScreen> createState() => _UniversalOperatorWizardScreenState();
}

class _UniversalOperatorWizardScreenState extends State<UniversalOperatorWizardScreen> {
  late UniversalWizardState _state;
  int _step = 0;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  List<Map<String, dynamic>> _tools = [];
  bool _toolsLoaded = false;
  /// When non-null, a draft was found; show "Restore or start fresh?" dialog before applying.
  String? _pendingDraftJson;
  final FlutterTts _tts = FlutterTts();
  bool _isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState ?? const UniversalWizardState();
    _loadDraft();
    _loadTools();
  }

  Future<void> _loadDraft() async {
    if (widget.initialState != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_draftKey);
      if (json != null && json.isNotEmpty && mounted) {
        setState(() => _pendingDraftJson = json);
        WidgetsBinding.instance.addPostFrameCallback((_) => _showRestoreDraftDialogIfNeeded());
      }
    } catch (_) {}
  }

  void _showRestoreDraftDialogIfNeeded() {
    if (!mounted || _pendingDraftJson == null) return;
    final json = _pendingDraftJson!;
    _pendingDraftJson = null;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved draft'),
        content: const Text(
          'You have an unsaved draft from a previous session. Restore it or start fresh?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Start fresh'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore draft'),
          ),
        ],
      ),
    ).then((restore) {
      if (!mounted) return;
      if (restore == true) {
        setState(() => _state = UniversalWizardState.fromJsonString(json));
        _persistDraft();
      } else {
        _clearDraft();
      }
    });
  }

  Future<void> _persistDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, _state.toJsonString());
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  void _updateState(UniversalWizardState newState) {
    setState(() {
      _state = newState;
      _error = null;
    });
    _persistDraft();
  }

  Future<void> _loadTools() async {
    if (_toolsLoaded) return;
    setState(() => _loading = true);
    try {
      final res = await ManagedProfileApiService.getTools();
      final list = (res['tools'] as List?)?.cast<dynamic>() ?? [];
      if (mounted) {
        setState(() {
          _tools = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _toolsLoaded = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _state.step1.businessName.trim().isNotEmpty &&
            _state.step1.operatorDisplayName.trim().isNotEmpty;
      case 1:
        return _state.step2.agentFirstName.trim().isNotEmpty;
      case 2:
        return _state.step3.primaryObjective.trim().isNotEmpty;
      case 3:
        return true;
      case 4:
        return true;
      default:
        return true;
    }
  }

  Future<void> _regeneratePrompt() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ManagedProfileApiService.aiCraftPromptV3(_state.toJson());
      if (!mounted) return;
      final systemPrompt = res['system_prompt']?.toString();
      final voicemailMessage = res['voicemail_message']?.toString();
      final operatorSummary = res['operator_summary']?.toString();
      if (systemPrompt != null) {
        setState(() {
          _state = UniversalWizardState(
            step1: _state.step1,
            step2: _state.step2,
            step3: _state.step3,
            step4: _state.step4,
            step5: WizardStep5Review(
              generatedSystemPrompt: systemPrompt,
              generatedVoicemailMessage: voicemailMessage,
              generatedSummary: operatorSummary,
              lastRegeneratedAt: DateTime.now().toIso8601String(),
            ),
          );
          _loading = false;
        });
        _persistDraft();
      } else {
        setState(() { _error = res['error']?.toString() ?? 'Failed to generate prompt'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    final profileName = _state.step1.operatorDisplayName.trim().isEmpty
        ? _state.step1.businessName.trim()
        : _state.step1.operatorDisplayName.trim();
    if (profileName.isEmpty) {
      setState(() { _error = 'Operator display name is required'; });
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final customPrompt = _state.step5.generatedSystemPrompt ?? '';
      final voicemail = _state.step5.generatedVoicemailMessage ?? '';
      final summary = _state.step5.generatedSummary ?? '';
      if (customPrompt.isEmpty) {
        await _regeneratePrompt();
        if (!mounted) return;
        final updated = _state;
        if (updated.step5.generatedSystemPrompt == null || updated.step5.generatedSystemPrompt!.isEmpty) {
          setState(() { _error = 'Generate a prompt first (Step 5) or fill Steps 1–4 and regenerate'; _saving = false; });
          return;
        }
      }
      final payload = <String, dynamic>{
        'wizardVersion': 'v3',
        'profile_name': profileName,
        'direction': 'outbound',
        'wizardMeta': _state.toJson(),
        'custom_system_prompt': _state.step5.generatedSystemPrompt ?? customPrompt,
        'voicemail_message': _state.step5.generatedVoicemailMessage ?? voicemail,
        'operator_summary': _state.step5.generatedSummary ?? summary,
        'enabled_tool_keys': _state.step4.enabledToolKeys,
      };
      final res = await ManagedProfileApiService.createProfile(payload);
      if (!mounted) return;
      final err = res['error'];
      if (err != null) {
        setState(() { _error = err.toString(); _saving = false; });
        return;
      }
      await _clearDraft();
      if (!mounted) return;
      final profileId = res['profile_id']?.toString();
      Navigator.of(context).pop(true);
      if (profileId != null && profileId.isNotEmpty) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => ManagedProfileDetailPage(profileId: profileId),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepTitles = [
      'Business & Department',
      'Persona & Voice',
      'Conversation Flow',
      'Tools & Integrations',
      'Review & Generate',
    ];
    return Scaffold(
      backgroundColor: NeyvoColors.bgBase,
      appBar: AppBar(
        title: Text('Create operator (universal) — ${stepTitles[_step]} (${_step + 1}/$_totalSteps)'),
        backgroundColor: NeyvoColors.bgRaised,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving || _loading ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: NeyvoColors.error.withOpacity(0.1),
              child: Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _loading && _step == 4
                  ? const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
                  : _buildStepContent(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: _saving || _loading ? null : () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 8),
                if (_step < _totalSteps - 1)
                  FilledButton(
                    onPressed: (_canProceed() && !_saving && !_loading) ? () => setState(() => _step++) : null,
                    style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                    child: const Text('Next'),
                  )
                else
                  FilledButton(
                    onPressed: (_saving || _loading) ? null : () => _save(),
                    style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                    child: Text(_saving ? 'Saving…' : 'Confirm & Save'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      default:
        return const SizedBox();
    }
  }

  static const List<String> _industryVerticals = [
    'Education', 'Healthcare', 'Admissions', 'Financial Aid', 'Registrar', 'Finance', 'Other',
  ];

  Widget _buildStep1() {
    final s1 = _state.step1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business name', style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: s1.businessName,
          decoration: const InputDecoration(hintText: 'e.g. Goodwin University', border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(step1: s1.copyWith(businessName: v), step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 16),
        Text('Industry / vertical', style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _industryVerticals.contains(s1.industryVertical) ? s1.industryVertical : 'Other',
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: _industryVerticals.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => _updateState(UniversalWizardState(
            step1: s1.copyWith(industryVertical: v ?? 'Education', industryOther: v == 'Other' ? s1.industryOther : null),
            step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5,
          )),
        ),
        if (s1.industryVertical == 'Other') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: s1.industryOther,
            decoration: const InputDecoration(labelText: 'Industry (free text)', border: OutlineInputBorder()),
            onChanged: (v) => _updateState(UniversalWizardState(step1: s1.copyWith(industryOther: v), step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5)),
          ),
        ],
        const SizedBox(height: 16),
        Text('Department', style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: departmentPresets.contains(s1.department) ? s1.department : 'Other',
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            ...departmentPresets.map((d) => DropdownMenuItem(value: d, child: Text(d))),
            const DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (v) => _updateState(UniversalWizardState(
            step1: s1.copyWith(department: v == 'Other' ? 'Other' : (v ?? 'Education'), departmentOther: v == 'Other' ? s1.departmentOther : null),
            step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5,
          )),
        ),
        if (s1.department == 'Other') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: s1.departmentOther,
            decoration: const InputDecoration(labelText: 'Department (free text)', border: OutlineInputBorder()),
            onChanged: (v) => _updateState(UniversalWizardState(step1: s1.copyWith(departmentOther: v), step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5)),
          ),
        ],
        const SizedBox(height: 16),
        Text('Operator display name', style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: s1.operatorDisplayName,
          decoration: const InputDecoration(hintText: 'e.g. SNAP Check-in', border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(step1: s1.copyWith(operatorDisplayName: v), step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 16),
        Text('Callback phone (optional)', style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: s1.mainPhone,
          decoration: const InputDecoration(hintText: 'e.g. 860-727-6936', border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(step1: s1.copyWith(mainPhone: v.isEmpty ? null : v), step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 16),
        Text('Compliance', style: NeyvoTextStyles.label),
        Row(
          children: [
            Checkbox(
              value: s1.complianceFlags['hipaa'] ?? false,
              onChanged: (v) {
                final flags = Map<String, bool>.from(s1.complianceFlags);
                flags['hipaa'] = v ?? false;
                _updateState(UniversalWizardState(step1: s1.copyWith(complianceFlags: flags), step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5));
              },
            ),
            const Text('HIPAA'),
            Checkbox(
              value: s1.complianceFlags['fdcpa'] ?? false,
              onChanged: (v) {
                final flags = Map<String, bool>.from(s1.complianceFlags);
                flags['fdcpa'] = v ?? false;
                _updateState(UniversalWizardState(step1: s1.copyWith(complianceFlags: flags), step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5));
              },
            ),
            const Text('FDCPA'),
            Checkbox(
              value: s1.complianceFlags['tcpa'] ?? false,
              onChanged: (v) {
                final flags = Map<String, bool>.from(s1.complianceFlags);
                flags['tcpa'] = v ?? false;
                _updateState(UniversalWizardState(step1: s1.copyWith(complianceFlags: flags), step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5));
              },
            ),
            const Text('TCPA'),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final s2 = _state.step2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: s2.agentFirstName,
          decoration: const InputDecoration(labelText: 'Agent first name', border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: s2.copyWith(agentFirstName: v), step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: s2.roleTitle,
          decoration: const InputDecoration(labelText: 'Role title', hintText: 'e.g. SNAP Department representative', border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: s2.copyWith(roleTitle: v), step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 12),
        Text('Personality (e.g. warm, energetic, empathetic)', style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: s2.personalityAdjectives.join(', '),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(
            step1: _state.step1,
            step2: s2.copyWith(personalityAdjectives: v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
            step3: _state.step3, step4: _state.step4, step5: _state.step5,
          )),
        ),
        const SizedBox(height: 16),
        Text('Voice provider', style: NeyvoTextStyles.label),
        DropdownButtonFormField<String>(
          initialValue: s2.voiceProvider,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: '11labs', child: Text('ElevenLabs')),
            DropdownMenuItem(value: 'playht', child: Text('PlayHT')),
            DropdownMenuItem(value: 'deepgram', child: Text('Deepgram')),
            DropdownMenuItem(value: 'azure', child: Text('Azure')),
          ],
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: s2.copyWith(voiceProvider: v ?? '11labs'), step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: s2.voiceId,
          decoration: const InputDecoration(labelText: 'Voice ID', border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: s2.copyWith(voiceId: v), step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 16),
        Text('Stability (lower = more expressive)', style: NeyvoTextStyles.label),
        Slider(
          value: s2.stability,
          min: 0,
          max: 1,
          divisions: 10,
          label: s2.stability.toStringAsFixed(1),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: s2.copyWith(stability: v), step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        Text('Similarity boost', style: NeyvoTextStyles.label),
        Slider(
          value: s2.similarityBoost,
          min: 0,
          max: 1,
          divisions: 10,
          label: s2.similarityBoost.toStringAsFixed(1),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: s2.copyWith(similarityBoost: v), step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        Text('Style (affects tone variation)', style: NeyvoTextStyles.label),
        Slider(
          value: s2.style,
          min: 0,
          max: 1,
          divisions: 10,
          label: s2.style.toStringAsFixed(1),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: s2.copyWith(style: v), step3: _state.step3, step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isPlayingPreview ? null : () => _playVoicePreview(),
          icon: _isPlayingPreview ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.volume_up),
          label: Text(_isPlayingPreview ? 'Playing…' : 'Preview voice (device TTS)'),
        ),
      ],
    );
  }

  static const String _voicePreviewSentence = 'Hello, this is a quick sample of how your operator might sound.';

  Future<void> _playVoicePreview() async {
    setState(() => _isPlayingPreview = true);
    try {
      await _tts.speak(_voicePreviewSentence);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (mounted) await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _isPlayingPreview = false);
  }

  Widget _buildStep3() {
    final s3 = _state.step3;
    final dept = _state.step1.department == 'Other' ? (_state.step1.departmentOther ?? 'Other') : _state.step1.department;
    final suggested = _departmentPrimaryObjectiveSuggestions[dept] ?? _departmentPrimaryObjectiveSuggestions['Other'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Primary call objective', style: NeyvoTextStyles.label),
        if (suggested != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('Suggested for $dept:', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => _updateState(UniversalWizardState(
                  step1: _state.step1, step2: _state.step2,
                  step3: s3.copyWith(primaryObjective: suggested),
                  step4: _state.step4, step5: _state.step5,
                )),
                child: const Text('Use this'),
              ),
            ],
          ),
          const SizedBox(height: 2),
        ],
        const SizedBox(height: 4),
        TextFormField(
          initialValue: s3.primaryObjective,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'What should this operator accomplish on each call?', border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: _state.step2, step3: s3.copyWith(primaryObjective: v), step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 12),
        Text('Fallback when unclear', style: NeyvoTextStyles.label),
        TextFormField(
          initialValue: s3.fallbackUnclearResponse,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: _state.step2, step3: s3.copyWith(fallbackUnclearResponse: v), step4: _state.step4, step5: _state.step5)),
        ),
        const SizedBox(height: 12),
        Text('Call closing', style: NeyvoTextStyles.label),
        DropdownButtonFormField<String>(
          initialValue: s3.callClosingBehavior,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'endCall', child: Text('End call')),
            DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
            DropdownMenuItem(value: 'voicemail', child: Text('Voicemail')),
          ],
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: _state.step2, step3: s3.copyWith(callClosingBehavior: v ?? 'endCall'), step4: _state.step4, step5: _state.step5)),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    final s4 = _state.step4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enabled tools', style: NeyvoTextStyles.label),
        if (_tools.isEmpty && !_loading)
          Text('No tools loaded. Save and continue to use defaults.', style: NeyvoTextStyles.micro)
        else
          ...(_tools.isEmpty ? [] : _tools.map((t) {
              final key = t['key']?.toString() ?? '';
              final checked = s4.enabledToolKeys.contains(key);
              return CheckboxListTile(
                title: Text(t['display_name']?.toString() ?? key),
                subtitle: Text(t['description']?.toString() ?? '', style: NeyvoTextStyles.micro),
                value: checked,
                onChanged: (v) {
                  final newKeys = List<String>.from(s4.enabledToolKeys);
                  if (v == true) {
                    if (!newKeys.contains(key)) newKeys.add(key);
                  } else {
                    newKeys.remove(key);
                  }
                  _updateState(UniversalWizardState(step1: _state.step1, step2: _state.step2, step3: _state.step3, step4: s4.copyWith(enabledToolKeys: newKeys), step5: _state.step5));
                },
              );
            })),
      ],
    );
  }

  Widget _buildStep5() {
    final s5 = _state.step5;
    final hasPrompt = (s5.generatedSystemPrompt ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _loading || _saving ? null : () => _regeneratePrompt(),
          icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
          label: Text(hasPrompt ? 'Regenerate prompt' : 'Generate prompt'),
        ),
        const SizedBox(height: 16),
        if (hasPrompt) ...[
          Text('System prompt preview', style: NeyvoTextStyles.label),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeyvoColors.bgRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeyvoColors.borderDefault),
            ),
            child: SelectableText(
              s5.generatedSystemPrompt!,
              style: NeyvoTextStyles.body.copyWith(fontSize: 12),
              maxLines: 15,
            ),
          ),
          const SizedBox(height: 12),
          Text('Voicemail message', style: NeyvoTextStyles.label),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeyvoColors.bgRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeyvoColors.borderDefault),
            ),
            child: SelectableText(s5.generatedVoicemailMessage ?? '', style: NeyvoTextStyles.body.copyWith(fontSize: 12)),
          ),
        ] else
          Text(
            'Click "Generate prompt" to create the system prompt and voicemail from your Steps 1–4, then review and save.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          ),
        const SizedBox(height: 16),
        ExpansionTile(
          title: Text('Full payload (for review)', style: NeyvoTextStyles.label),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SelectableText(
                _buildPayloadPreviewJson(),
                style: NeyvoTextStyles.micro.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _buildPayloadPreviewJson() {
    final profileName = _state.step1.operatorDisplayName.trim().isEmpty
        ? _state.step1.businessName.trim()
        : _state.step1.operatorDisplayName.trim();
    final payload = <String, dynamic>{
      'wizardVersion': 'v3',
      'profile_name': profileName,
      'direction': 'outbound',
      'wizardMeta': _state.toJson(),
      'custom_system_prompt': _state.step5.generatedSystemPrompt ?? '(will generate on save)',
      'voicemail_message': _state.step5.generatedVoicemailMessage ?? '',
      'operator_summary': _state.step5.generatedSummary ?? '',
      'enabled_tool_keys': _state.step4.enabledToolKeys,
    };
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(payload);
  }
}
