import 'package:flutter/material.dart';

import '../../neyvo_pulse_api.dart';
import '../../pulse_route_names.dart';
import '../../screens/voice_library_modal.dart';
import '../../theme/neyvo_theme.dart';
import '../../ui/components/ai_orb/neyvo_ai_orb.dart';
import '../../ui/components/glass/neyvo_glass_panel.dart';
import 'managed_profile_api_service.dart';

class ManagedProfileDetailPage extends StatefulWidget {
  const ManagedProfileDetailPage({
    super.key,
    required this.profileId,
    this.embedded = false,
  });

  final String profileId;
  final bool embedded;

  @override
  State<ManagedProfileDetailPage> createState() => _ManagedProfileDetailPageState();
}

class _ManagedProfileDetailPageState extends State<ManagedProfileDetailPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _attaching = false;

  Map<String, dynamic> _profile = const {};
  List<Map<String, dynamic>> _numbers = const [];
  Map<String, dynamic>? _wallet;

  late TabController _tabs;

  final _nameCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _voicemailCtrl = TextEditingController();
  final _aiSuggestMessageCtrl = TextEditingController();

  String _tone = 'warm_friendly';
  bool _interruptEnabled = true;
  bool _handoffEnabled = true;
  bool _aiSuggestLoading = false;
  Map<String, dynamic>? _aiSuggestResult;
  List<Map<String, String>> _promptVariables = [];
  bool _variablePreviewLoading = false;
  String? _variablePreviewSentence;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    _promptCtrl.dispose();
    _voicemailCtrl.dispose();
    _aiSuggestMessageCtrl.dispose();
    super.dispose();
  }

  bool get _isUbOperator =>
      (_profile['custom_system_prompt'] ?? '').toString().trim().isNotEmpty ||
      (_profile['department'] ?? '').toString().trim().isNotEmpty;

  String get _attachedNumberId {
    return (_profile['attached_phone_number_id'] ??
            _profile['attached_vapi_phone_number_id'] ??
            _profile['phone_number_id'] ??
            '')
        .toString()
        .trim();
  }

  bool get _isLive => _attachedNumberId.isNotEmpty;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ManagedProfileApiService.getProfile(widget.profileId),
        NeyvoPulseApi.listNumbers(),
        NeyvoPulseApi.getBillingWallet(),
      ]);
      final profile = Map<String, dynamic>.from(results[0] as Map);
      final numbersRes = results[1] as Map<String, dynamic>;
      final walletRes = results[2] as Map<String, dynamic>?;
      final raw = (numbersRes['numbers'] as List?) ?? const [];
      final numbers = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      _nameCtrl.text = (profile['profile_name'] ?? profile['name'] ?? '').toString();
      _goalCtrl.text = (profile['work_goals'] ?? profile['goal'] ?? '').toString();
      _promptCtrl.text = (profile['custom_system_prompt'] ?? profile['system_prompt'] ?? profile['prompt'] ?? '').toString();
      _voicemailCtrl.text = (profile['voicemail_message'] ?? '').toString();
      final pv = profile['prompt_variables'];
      _promptVariables = (pv is List)
          ? (pv.map((e) => Map<String, String>.from((e is Map ? e : {}).map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))).toList())
          : [];

      final convo = profile['conversation_profile'];
      if (convo is Map) {
        _tone = (convo['tone'] ?? _tone).toString();
      }
      final behavior = profile['behavior'];
      if (behavior is Map) {
        _interruptEnabled = (behavior['interrupt_enabled'] as bool?) ?? true;
      }
      final guardrails = profile['guardrails'];
      if (guardrails is Map) {
        _handoffEnabled = (guardrails['handoff_enabled'] as bool?) ?? true;
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _numbers = numbers;
        _wallet = walletRes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'profile_name': _nameCtrl.text.trim(),
        'goal': _goalCtrl.text.trim(),
        'conversation_profile': {'tone': _tone},
        'behavior': {'interrupt_enabled': _interruptEnabled},
        'guardrails': {'handoff_enabled': _handoffEnabled},
      };
      if (_isUbOperator) {
        body['custom_system_prompt'] = _promptCtrl.text.trim();
        body['work_goals'] = _goalCtrl.text.trim();
        body['voicemail_message'] = _voicemailCtrl.text.trim();
        body['prompt_variables'] = _promptVariables;
      }
      final updated = await ManagedProfileApiService.updateProfile(widget.profileId, body);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _attachToNumber() async {
    final available = _numbers;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No numbers yet. Add one in Numbers Hub.')),
      );
      return;
    }

    String selected = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeyvoColors.bgBase,
        title: const Text('Attach to number'),
        content: SizedBox(
          width: 440,
          child: DropdownButtonFormField<String>(
            value: selected.isEmpty ? null : selected,
            items: available.map((n) {
              final id = (n['phone_number_id'] ?? n['id'] ?? n['number_id'] ?? '').toString();
              final e164 = (n['phone_number_e164'] ?? n['phone_number'] ?? '').toString();
              return DropdownMenuItem(
                value: id,
                child: Text(e164.isEmpty ? id : e164, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (v) => selected = (v ?? '').trim(),
            decoration: const InputDecoration(labelText: 'Number'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
            child: const Text('Attach'),
          ),
        ],
      ),
    );

    if (selected.isEmpty) return;
    setState(() => _attaching = true);
    try {
      await ManagedProfileApiService.attachPhoneNumber(
        profileId: widget.profileId,
        phoneNumberId: selected,
        vapiPhoneNumberId: selected,
      );
      if (!mounted) return;
      setState(() => _attaching = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _attaching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _detach() async {
    setState(() => _attaching = true);
    try {
      await ManagedProfileApiService.detachPhoneNumber(widget.profileId);
      if (!mounted) return;
      setState(() => _attaching = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _attaching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  List<String> get _unlockedTiers {
    final w = _wallet;
    final tiers =
        (w?['unlocked_tiers'] as List<dynamic>?)?.map((e) => e.toString().toLowerCase()).toList();
    if (tiers != null && tiers.isNotEmpty) return tiers;
    final sub = (w?['subscription_tier'] ?? '').toString().toLowerCase();
    if (sub == 'free') return const ['neutral'];
    return const ['neutral', 'natural', 'ultra'];
  }

  String get _effectiveTier {
    final w = _wallet ?? const {};
    return (w['voice_tier'] ?? w['tier'] ?? 'ultra').toString().toLowerCase();
  }

  String _tierDisplay(String tier) {
    switch (tier.toLowerCase()) {
      case 'neutral':
        return 'Neutral Human';
      case 'natural':
        return 'Natural Human';
      case 'ultra':
        return 'Ultra Real Human';
      default:
        return tier;
    }
  }

  String get _currentVoiceProvider {
    final v = (_profile['voice_provider'] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
    // Fall back to plan default.
    return _effectiveTier == 'neutral' ? 'openai' : '11labs';
  }

  String get _currentVoiceId => (_profile['voice_id'] ?? '').toString().trim();

  Future<void> _openVoiceLibrary() async {
    final currentTier = _unlockedTiers.contains(_effectiveTier) ? _effectiveTier : _unlockedTiers.first;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeyvoColors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => VoiceLibraryModal(
        currentTier: currentTier,
        currentVoiceId: _currentVoiceId.isEmpty ? null : _currentVoiceId,
        currentProvider: _currentVoiceProvider,
        unlockedTiers: _unlockedTiers,
      ),
    );
    if (selected == null || !mounted) return;
    final provider = (selected['provider'] ?? '').toString().trim();
    final voiceId = (selected['voice_id'] ?? '').toString().trim();
    if (provider.isEmpty || voiceId.isEmpty) return;

    setState(() => _saving = true);
    try {
      final updated = await ManagedProfileApiService.updateProfile(widget.profileId, {
        'voice_provider': provider,
        'voice_id': voiceId,
      });
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _nameCtrl.text.trim().isEmpty ? 'Operator' : _nameCtrl.text.trim();

    final inner = _loading
        ? const Center(child: CircularProgressIndicator(color: NeyvoColors.teal))
        : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: NeyvoGlassPanel(
                      glowing: !_isLive,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_isLive ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: _isLive ? NeyvoColors.success : NeyvoColors.warning),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  style: NeyvoTextStyles.heading.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (_attaching)
                                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.teal)),
                              if (_isLive)
                                OutlinedButton(
                                  onPressed: _attaching ? null : _detach,
                                  child: const Text('Detach'),
                                )
                              else
                                FilledButton(
                                  onPressed: _attaching ? null : _attachToNumber,
                                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                                  child: const Text('Attach to number'),
                                ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _saving ? null : _save,
                                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                                child: _saving
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Save'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _metric('Status', _isLive ? 'Live' : 'Not attached'),
                              _metric('Numbers attached', _isLive ? '1' : '0'),
                              _metric('Last call', '—'),
                              _metric('Latency score', '—'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: NeyvoColors.bgBase,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      labelColor: NeyvoColors.teal,
                      unselectedLabelColor: NeyvoColors.textSecondary,
                      indicatorColor: NeyvoColors.teal,
                      tabs: const [
                        Tab(text: 'Personality'),
                        Tab(text: 'AI Studio'),
                        Tab(text: 'Voice'),
                        Tab(text: 'Additional settings'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _tabPersonality(),
                        _tabAiStudio(),
                        _tabVoice(),
                        _tabAdditionalSettings(),
                      ],
                    ),
                  ),
                ],
              );

    if (widget.embedded) return Container(color: NeyvoColors.bgVoid, child: inner);

    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      appBar: AppBar(
        backgroundColor: NeyvoColors.bgBase,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeyvoColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
      ),
      body: inner,
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Text('$label: $value', style: NeyvoTextStyles.micro),
    );
  }

  Widget _tabPersonality() {
    final department = (_profile['department'] ?? '').toString().trim();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
              const SizedBox(height: 6),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Neyvo Receptionist')),
              const SizedBox(height: 12),
              if (department.isNotEmpty) ...[
                Text('Department', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                const SizedBox(height: 6),
                Text(department, style: NeyvoTextStyles.bodyPrimary),
                const SizedBox(height: 12),
              ],
              Text('Tone', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _tone,
                items: const [
                  DropdownMenuItem(value: 'warm_friendly', child: Text('Warm & friendly')),
                  DropdownMenuItem(value: 'calm_professional', child: Text('Calm & professional')),
                  DropdownMenuItem(value: 'fast_direct', child: Text('Fast & direct')),
                ],
                onChanged: (v) => setState(() => _tone = (v ?? 'warm_friendly')),
              ),
              const SizedBox(height: 12),
              Text(_isUbOperator ? 'Work goals' : 'Goal', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _goalCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'What is this operator trying to accomplish?'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabAiStudio() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Studio', style: NeyvoTextStyles.heading),
              const SizedBox(height: 6),
              Text(
                'Update the operator’s behavior and voicemail using AI. You don’t need to edit the raw prompt.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isUbOperator) ...[
          _buildAiStudioCard(),
          const SizedBox(height: 16),
          _buildVariablesCard(),
        ] else
          NeyvoGlassPanel(
            child: Text(
              'AI Studio is available for UB operators that use a custom prompt.',
              style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildAiStudioCard() {
    final sub = (_wallet?['subscription_tier'] ?? '').toString().toLowerCase();
    final canUse = sub != 'free';
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Studio', style: NeyvoTextStyles.heading),
          const SizedBox(height: 6),
          Text(
            canUse
                ? 'Improve the operator\'s script with AI. Suggestions keep your placeholders and tone.'
                : 'AI Studio requires a Pro or Business plan.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aiSuggestMessageCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'E.g. Make the opening warmer, or add a line about deadlines.',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: (!canUse || _aiSuggestLoading) ? null : _runAiSuggestPrompt,
                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                child: _aiSuggestLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Get AI suggestion'),
              ),
              if (_aiSuggestResult != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _applyAiSuggestResult,
                  child: const Text('Apply'),
                ),
              ],
            ],
          ),
          if (_aiSuggestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeyvoColors.bgRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeyvoColors.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explanation', style: NeyvoTextStyles.label),
                  const SizedBox(height: 4),
                  Text(
                    (_aiSuggestResult!['explanation'] ?? '').toString(),
                    style: NeyvoTextStyles.body,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runAiSuggestPrompt() async {
    setState(() => _aiSuggestLoading = true);
    try {
      final res = await ManagedProfileApiService.aiSuggestPrompt(
        widget.profileId,
        message: _aiSuggestMessageCtrl.text.trim().isEmpty ? null : _aiSuggestMessageCtrl.text.trim(),
      );
      if (mounted) setState(() {
        _aiSuggestResult = Map<String, dynamic>.from(res);
        _aiSuggestLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _aiSuggestLoading = false;
        _aiSuggestResult = null;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _applyAiSuggestResult() {
    if (_aiSuggestResult == null) return;
    final prompt = (_aiSuggestResult!['custom_system_prompt'] ?? '').toString();
    final voicemail = (_aiSuggestResult!['voicemail_message'] ?? '').toString();
    if (prompt.isNotEmpty) _promptCtrl.text = prompt;
    if (voicemail.isNotEmpty) _voicemailCtrl.text = voicemail;
    setState(() => _aiSuggestResult = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applied. Save to update the operator.')));
  }

  static Map<String, String> _sampleValuesForVariables(List<Map<String, String>> variables) {
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

  Future<void> _loadVariablePreview() async {
    final template = _voicemailCtrl.text.trim().isNotEmpty
        ? _voicemailCtrl.text.trim()
        : _promptVariables.isEmpty
            ? ''
            : '{{${_promptVariables.first['key'] ?? ''}}} has a balance due.';
    if (template.isEmpty) return;
    setState(() {
      _variablePreviewLoading = true;
      _variablePreviewSentence = null;
    });
    try {
      final sampleValues = _sampleValuesForVariables(_promptVariables);
      final res = await ManagedProfileApiService.previewVariableSentence(
        template: template,
        variableValues: sampleValues,
      );
      if (mounted) {
        setState(() {
          _variablePreviewSentence = (res['sentence'] ?? '').toString();
          _variablePreviewLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _variablePreviewSentence = null;
          _variablePreviewLoading = false;
        });
      }
    }
  }

  Widget _buildVariablesCard() {
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prompt variables', style: NeyvoTextStyles.heading),
          const SizedBox(height: 6),
          Text(
            'Variables like {{studentName}} used in the prompt. When making outbound calls, pass values for these.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_promptVariables.isEmpty)
            Text('None', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _promptVariables.map((v) {
                final label = v['label'] ?? v['key'] ?? '';
                final key = v['key'] ?? '';
                return Chip(
                  label: Text(label.isNotEmpty ? '$label ($key)' : key),
                  onDeleted: () => setState(() {
                    _promptVariables.removeWhere((e) => (e['key'] ?? '') == key);
                    _variablePreviewSentence = null;
                  }),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addPromptVariable,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add variable'),
          ),
          if (_promptVariables.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Preview with sample values', style: NeyvoTextStyles.label),
            const SizedBox(height: 6),
            Text(
              'See how the script will sound with example data (e.g. name, balance).',
              style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
            ),
            const SizedBox(height: 8),
            if (_variablePreviewLoading)
              const SizedBox(height: 24, child: Center(child: CircularProgressIndicator()))
            else if (_variablePreviewSentence != null && _variablePreviewSentence!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NeyvoColors.bgRaised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeyvoColors.borderDefault),
                ),
                child: Text(
                  'Example: $_variablePreviewSentence',
                  style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary),
                ),
              )
            else
              OutlinedButton(
                onPressed: _loadVariablePreview,
                child: const Text('Show example'),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _addPromptVariable() async {
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add variable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(labelText: 'Key (e.g. studentName)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Label (e.g. Student name)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final key = keyCtrl.text.trim();
              if (key.isNotEmpty) {
                final label = labelCtrl.text.trim().isEmpty ? key : labelCtrl.text.trim();
                Navigator.of(ctx).pop();
                setState(() => _promptVariables.add({'key': key, 'label': label}));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _tabGuardrails() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guardrails', style: NeyvoTextStyles.heading),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _handoffEnabled,
                onChanged: (v) => setState(() => _handoffEnabled = v),
                title: Text('Allow human handoff', style: NeyvoTextStyles.bodyPrimary),
                subtitle: Text('Enable transferring callers to a human fallback.', style: NeyvoTextStyles.micro),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabVoice() {
    final sub = (_wallet?['subscription_tier'] ?? '').toString().toLowerCase();
    final tier = _effectiveTier;
    final provider = _currentVoiceProvider.toLowerCase();
    final voiceId = _currentVoiceId;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Voice', style: NeyvoTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                'Current tier: ${_tierDisplay(tier)}${sub.isNotEmpty ? ' · Plan: ${sub[0].toUpperCase()}${sub.substring(1)}' : ''}',
                style: NeyvoTextStyles.bodyPrimary,
              ),
              const SizedBox(height: 6),
              Text(
                voiceId.isEmpty ? 'Using your plan default voice.' : 'Selected voice: $provider · $voiceId',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saving ? null : _openVoiceLibrary,
                  child: const Text('Choose voice (listen to sample)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabAdditionalSettings() {
    final allowed = (_profile['allowed_actions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guardrails', style: NeyvoTextStyles.heading),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _handoffEnabled,
                onChanged: (v) => setState(() => _handoffEnabled = v),
                title: Text('Allow human handoff', style: NeyvoTextStyles.bodyPrimary),
                subtitle: Text('Enable transferring callers to a human fallback.', style: NeyvoTextStyles.micro),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _interruptEnabled,
                onChanged: (v) => setState(() => _interruptEnabled = v),
                title: Text('Interrupt enabled', style: NeyvoTextStyles.bodyPrimary),
                subtitle: Text('Allow callers to interrupt the operator mid-sentence.', style: NeyvoTextStyles.micro),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tool integrations', style: NeyvoTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                allowed.isEmpty ? 'No tools enabled.' : 'Enabled tools:',
                style: NeyvoTextStyles.body,
              ),
              const SizedBox(height: 8),
              if (allowed.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: allowed.map((t) => _metric('Tool', t)).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NeyvoGlassPanel(
          glowing: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const NeyvoAIOrb(state: NeyvoAIOrbState.listening, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Testing', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          'Place a real outbound call using the Dialer.',
                          style: NeyvoTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.dialer),
                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                  child: const Text('Open Dialer'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabBehavior() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Behavior', style: NeyvoTextStyles.heading),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _interruptEnabled,
                onChanged: (v) => setState(() => _interruptEnabled = v),
                title: Text('Interrupt enabled', style: NeyvoTextStyles.bodyPrimary),
                subtitle: Text('Allow callers to interrupt the operator mid-sentence.', style: NeyvoTextStyles.micro),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabTools() {
    final allowed = (_profile['allowed_actions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tool integrations', style: NeyvoTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                allowed.isEmpty ? 'No tools enabled.' : 'Enabled tools:',
                style: NeyvoTextStyles.body,
              ),
              const SizedBox(height: 8),
              if (allowed.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: allowed.map((t) => _metric('Tool', t)).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabTesting() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          glowing: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const NeyvoAIOrb(state: NeyvoAIOrbState.listening, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Testing', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          'Place a real outbound call using the Dialer.',
                          style: NeyvoTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.dialer),
                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                  child: const Text('Open Dialer'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

