// lib/features/operators/universal_operator_wizard/universal_operator_wizard_screen.dart
// Universal 5-step operator creation wizard (v3). Persists draft to shared_preferences.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../neyvo_pulse_api.dart';
import '../../managed_profiles/managed_profile_api_service.dart';
import '../../managed_profiles/profile_detail_page.dart';
import '../../../theme/neyvo_theme.dart';
import '../../../utils/voice_preview_player.dart';
import 'universal_wizard_state.dart';

const String _draftKey = 'universal_operator_wizard_draft';
const int _totalSteps = 6;

/// Refining questions template (goal-based). Shown after user enters primary objective.
List<RefiningQuestion> buildRefiningQuestionsForGoal(String goal) {
  return [
    const RefiningQuestion(id: 'q1', text: 'Should the operator offer to schedule a callback?', type: 'mcq', options: ['Yes, always', 'Only if the caller asks', 'No']),
    const RefiningQuestion(id: 'q2', text: 'Should the operator transfer to a live person when needed?', type: 'mcq', options: ['Yes', 'No', 'Only for specific topics']),
    const RefiningQuestion(id: 'q3', text: 'What level of detail should the operator give?', type: 'mcq', options: ['Brief and to the point', 'Detailed when asked', 'Proactive and thorough']),
    const RefiningQuestion(id: 'q4', text: 'Should the operator collect any information from the caller?', type: 'checkbox', options: ['Name', 'Phone', 'Student ID', 'Email', 'None']),
    const RefiningQuestion(id: 'q5_extra', text: 'Anything else you want this operator to do or avoid?', type: 'text', options: []),
  ];
}

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
  List<Map<String, dynamic>> _voicesForTier = [];
  bool _voicesLoaded = false;
  String? _voicesError;
  String? _playingVoiceId;
  /// When non-null, a draft was found; show "Restore or start fresh?" dialog before applying.
  String? _pendingDraftJson;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState ?? const UniversalWizardState();
    _loadDraft();
    _loadTools();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    if (_voicesLoaded) return;
    setState(() { _voicesError = null; });
    try {
      final res = await NeyvoPulseApi.getVoices(tier: 'all');
      final list = _extractVoicesFromResponse(res);
      if (mounted) {
        setState(() {
          _voicesForTier = list;
          _voicesLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _voicesError = e.toString(); _voicesLoaded = true; });
    }
  }

  List<Map<String, dynamic>> _extractVoicesFromResponse(dynamic res) {
    final List<Map<String, dynamic>> out = [];
    void addFromList(List<dynamic> raw) {
      for (final v in raw) {
        if (v is Map) out.add(Map<String, dynamic>.from(v));
      }
    }
    if (res is List) {
      addFromList(res);
    } else if (res is Map) {
      if (res['voices'] is List) {
        addFromList(res['voices'] as List);
      } else {
        for (final key in ['neutral', 'natural', 'ultra']) {
          if (res[key] is List) addFromList(res[key] as List);
        }
      }
    }
    return out;
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

  Future<void> _onNext() async {
    if (_step == 2 && _state.step3.primaryObjective.trim().isNotEmpty) {
      setState(() { _loading = true; _error = null; });
      List<RefiningQuestion> questions;
      bool usedFallback = false;
      try {
        final res = await ManagedProfileApiService.aiGoalQuestions(_state.step3.primaryObjective.trim());
        if (res['error'] != null) {
          questions = buildRefiningQuestionsForGoal(_state.step3.primaryObjective);
          usedFallback = true;
        } else {
          final raw = res['questions'];
          if (raw is List && raw.isNotEmpty) {
            questions = raw.map((e) => RefiningQuestion.fromJson(e is Map ? Map<String, dynamic>.from(e) : null)).where((q) => q.id.isNotEmpty && q.text.isNotEmpty).toList();
            if (questions.length < 4) {
              questions = buildRefiningQuestionsForGoal(_state.step3.primaryObjective);
              usedFallback = true;
            }
          } else {
            questions = buildRefiningQuestionsForGoal(_state.step3.primaryObjective);
            usedFallback = true;
          }
        }
      } catch (_) {
        questions = buildRefiningQuestionsForGoal(_state.step3.primaryObjective);
        usedFallback = true;
      }
      if (!mounted) return;
      setState(() {
        _state = UniversalWizardState(
          step1: _state.step1,
          step2: _state.step2,
          step3: _state.step3.copyWith(refiningQuestions: questions),
          step4: _state.step4,
          step5: _state.step5,
        );
        _step++;
        _loading = false;
      });
      _persistDraft();
      if (mounted && usedFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: const Text('Using default questions.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      setState(() => _step++);
      _persistDraft();
    }
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _state.step1.operatorDisplayName.trim().isNotEmpty;
      case 1:
        return true;
      case 2:
        return _state.step3.primaryObjective.trim().isNotEmpty;
      case 3:
      case 4:
      case 5:
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
      final firstMessage = res['first_message']?.toString();
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
              generatedFirstMessage: firstMessage,
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
          setState(() { _error = 'Generate a prompt first (Review step) or complete previous steps and tap Regenerate.'; _saving = false; });
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
        'first_message': _state.step5.generatedFirstMessage ?? '',
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
      'Identity',
      'Voice',
      'Goal',
      'Refine',
      'Tools',
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
              child: _loading && _step == 2
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text('Generating questions from your goal…', style: NeyvoTextStyles.body),
                          ],
                        ),
                      ),
                    )
                  : _loading && _step == 5
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
                    onPressed: (_canProceed() && !_saving && !_loading) ? _onNext : null,
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
        return _buildStep1Identity();
      case 1:
        return _buildStep2Voice();
      case 2:
        return _buildStep3Goal();
      case 3:
        return _buildStepRefining();
      case 4:
        return _buildStep4Tools();
      case 5:
        return _buildStep5Review();
      default:
        return const SizedBox();
    }
  }

  /// Step 0 — Identity: Operator name first, callback, compliance. Industry default Education. Departments as icons.
  Widget _buildStep1Identity() {
    final s1 = _state.step1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Operator name', style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: s1.operatorDisplayName,
          decoration: const InputDecoration(hintText: 'e.g. Front Desk, Support Operator', border: OutlineInputBorder()),
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
        Text('Department', style: NeyvoTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kDepartmentIcons.map((d) {
            final id = d['id'] ?? '';
            final label = d['label'] ?? id;
            final selected = s1.department == id;
            return FilterChip(
              selected: selected,
              label: Text(label),
              avatar: Icon(selected ? Icons.check_circle : Icons.business, size: 18, color: selected ? NeyvoColors.white : NeyvoColors.textSecondary),
              onSelected: (_) => _updateState(UniversalWizardState(
                step1: s1.copyWith(department: id, departmentOther: null),
                step2: _state.step2, step3: _state.step3, step4: _state.step4, step5: _state.step5,
              )),
            );
          }).toList(),
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

  /// Step 1 — Voice tone + voice picker (tier handles technical config).
  Widget _buildStep2Voice() {
    final s2 = _state.step2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Voice tone', style: NeyvoTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kVoiceToneIds.map((toneId) {
            final selected = s2.voiceTone == toneId;
            return FilterChip(
              selected: selected,
              label: Text(kVoiceToneLabels[toneId] ?? toneId),
              onSelected: (_) => _updateState(UniversalWizardState(step1: _state.step1, step2: s2.copyWith(voiceTone: toneId), step3: _state.step3, step4: _state.step4, step5: _state.step5)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text('Choose a voice', style: NeyvoTextStyles.label),
        const SizedBox(height: 4),
        if (_voicesError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_voicesError!, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error)),
          )
        else if (!_voicesLoaded)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_voicesForTier.isEmpty)
          Text('No voices available. Your plan will use the default voice.', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _voicesForTier.length,
              itemBuilder: (context, index) {
                final v = _voicesForTier[index];
                final vid = (v['voice_id'] ?? '').toString();
                final name = (v['name'] ?? v['voice_name'] ?? vid).toString();
                final provider = (v['provider'] ?? '11labs').toString();
                final isSelected = s2.voiceId == vid;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? NeyvoColors.tealGlow : NeyvoColors.bgRaised,
                  child: ListTile(
                    leading: Icon(isSelected ? Icons.check_circle : Icons.record_voice_over_outlined, color: isSelected ? NeyvoColors.teal : null),
                    title: Text(name, style: NeyvoTextStyles.body),
                    subtitle: Text(provider, style: NeyvoTextStyles.micro),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_playingVoiceId == vid ? Icons.stop : Icons.volume_up),
                          onPressed: () => _playVoicePreview(v),
                        ),
                        TextButton(
                          onPressed: () => _updateState(UniversalWizardState(
                            step1: _state.step1,
                            step2: s2.copyWith(voiceId: vid, voiceProvider: provider),
                            step3: _state.step3, step4: _state.step4, step5: _state.step5,
                          )),
                          child: Text(isSelected ? 'Selected' : 'Select'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _playVoicePreview(Map<String, dynamic> voice) async {
    final voiceId = (voice['voice_id'] ?? '').toString();
    final provider = (voice['provider'] ?? '11labs').toString();
    if (voiceId.isEmpty) return;
    setState(() => _playingVoiceId = voiceId);
    try {
      final res = await NeyvoPulseApi.postVoicePreview(voiceId: voiceId, provider: provider);
      await playVoicePreview(res);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview unavailable for this voice.')),
        );
      }
    }
    if (mounted) setState(() => _playingVoiceId = null);
  }

  /// Step 2 — Goal only (what should this operator accomplish).
  Widget _buildStep3Goal() {
    final s3 = _state.step3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What should this operator accomplish on each call?', style: NeyvoTextStyles.label),
        const SizedBox(height: 6),
        Text(
          'Describe the main purpose in 1–3 sentences. Include: what the operator should do (e.g. remind, guide, answer, collect), for whom, and any key actions (offer callback, transfer, send confirmation). Use short phrases separated by semicolons or line breaks.',
          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: s3.primaryObjective,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'e.g. Remind students to accept federal loans; guide them through the portal; offer a callback if they\'re busy. Or: Answer questions about appointments; collect name and reason for call; offer to transfer to the front desk.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (v) => _updateState(UniversalWizardState(step1: _state.step1, step2: _state.step2, step3: s3.copyWith(primaryObjective: v), step4: _state.step4, step5: _state.step5)),
        ),
      ],
    );
  }

  /// Step 3 — Refining questions (4–5 based on goal): MCQ/checkbox + text.
  Widget _buildStepRefining() {
    final s3 = _state.step3;
    final questions = s3.refiningQuestions.isEmpty ? buildRefiningQuestionsForGoal(s3.primaryObjective) : s3.refiningQuestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A few questions to refine your operator', style: NeyvoTextStyles.heading),
        const SizedBox(height: 12),
        ...questions.map((q) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.text, style: NeyvoTextStyles.label),
                const SizedBox(height: 6),
                if (q.type == 'text')
                  TextFormField(
                    initialValue: (s3.refiningAnswers[q.id] ?? '').toString(),
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Optional', border: OutlineInputBorder()),
                    onChanged: (v) {
                      final ans = Map<String, dynamic>.from(s3.refiningAnswers);
                      ans[q.id] = v;
                      _updateState(UniversalWizardState(step1: _state.step1, step2: _state.step2, step3: s3.copyWith(refiningAnswers: ans), step4: _state.step4, step5: _state.step5));
                    },
                  )
                else if (q.type == 'mcq')
                  Wrap(
                    spacing: 8,
                    children: q.options.map((opt) {
                      final selected = (s3.refiningAnswers[q.id] ?? '').toString() == opt;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(opt),
                        onSelected: (_) {
                          final ans = Map<String, dynamic>.from(s3.refiningAnswers);
                          ans[q.id] = opt;
                          _updateState(UniversalWizardState(step1: _state.step1, step2: _state.step2, step3: s3.copyWith(refiningAnswers: ans), step4: _state.step4, step5: _state.step5));
                        },
                      );
                    }).toList(),
                  )
                else if (q.type == 'checkbox')
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: q.options.map((opt) {
                      final list = (s3.refiningAnswers[q.id] is List ? (s3.refiningAnswers[q.id] as List).cast<String>() : <String>[]);
                      final selected = list.contains(opt);
                      return FilterChip(
                        selected: selected,
                        label: Text(opt),
                        onSelected: (_) {
                          final ans = Map<String, dynamic>.from(s3.refiningAnswers);
                          final list = (s3.refiningAnswers[q.id] is List ? (s3.refiningAnswers[q.id] as List).cast<String>() : <String>[]).toList();
                          if (selected) {
                            list.remove(opt);
                          } else {
                            list.add(opt);
                          }
                          ans[q.id] = list;
                          _updateState(UniversalWizardState(step1: _state.step1, step2: _state.step2, step3: s3.copyWith(refiningAnswers: ans), step4: _state.step4, step5: _state.step5));
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep4Tools() {
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

  Widget _buildStep5Review() {
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
          if ((s5.generatedFirstMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Opening line (assistant speaks first)', style: NeyvoTextStyles.label),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeyvoColors.bgRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeyvoColors.borderDefault),
              ),
              child: SelectableText(s5.generatedFirstMessage!, style: NeyvoTextStyles.body.copyWith(fontSize: 12)),
            ),
          ],
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
      'first_message': _state.step5.generatedFirstMessage ?? '',
      'enabled_tool_keys': _state.step4.enabledToolKeys,
    };
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(payload);
  }
}
