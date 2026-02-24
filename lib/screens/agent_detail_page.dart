// lib/screens/agent_detail_page.dart
// Agent detail: all configurations — basics, scripts & prompts, voice, compliance.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import 'voice_library_modal.dart';

class AgentDetailPage extends StatefulWidget {
  const AgentDetailPage({super.key, required this.agentId});

  final String agentId;

  @override
  State<AgentDetailPage> createState() => _AgentDetailPageState();
}

class _AgentDetailPageState extends State<AgentDetailPage> {
  Map<String, dynamic>? _agent;
  Map<String, dynamic>? _billing;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
  final TextEditingController _openingMessageController = TextEditingController();
  double? _stabilityOverride;
  double? _similarityBoostOverride;

  @override
  void dispose() {
    _nameController.dispose();
    _systemPromptController.dispose();
    _openingMessageController.dispose();
    super.dispose();
  }

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
      final results = await Future.wait([
        NeyvoPulseApi.getAgent(widget.agentId),
        NeyvoPulseApi.getBillingWallet(),
      ]);
      final agentRes = results[0] as Map<String, dynamic>?;
      if (agentRes != null && (agentRes['ok'] != false)) {
        final agentData = agentRes['agent'] as Map<String, dynamic>? ?? agentRes;
        _nameController.text = (agentData['name'] as String?) ?? '';
        _systemPromptController.text = (agentData['system_prompt'] as String?) ?? '';
        _openingMessageController.text = (agentData['opening_message'] as String?) ?? '';
        _stabilityOverride = null;
        _similarityBoostOverride = null;
        if (mounted) {
          setState(() {
            _agent = agentData;
            _billing = results[1] as Map<String, dynamic>?;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = agentRes?['error'] as String? ?? 'Failed to load agent';
            _loading = false;
          });
        }
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

  bool get _useAccountDefault {
    final override = _agent?['voice_tier_override'] as String?;
    final legacy = _agent?['voice_tier'] as String?;
    return (override == null || override.toString().trim().isEmpty) &&
        (legacy == null || legacy.toString().trim().isEmpty);
  }

  String get _effectiveTier {
    if (!_useAccountDefault) {
      final override = _agent?['voice_tier_override'] as String?;
      final legacy = _agent?['voice_tier'] as String?;
      return (override ?? legacy ?? 'neutral').toString().toLowerCase();
    }
    return (_billing?['voice_tier'] as String?)?.toLowerCase() ?? 'neutral';
  }

  String _tierDisplay(String tier) {
    switch (tier) {
      case 'neutral': return 'Neutral Human';
      case 'natural': return 'Natural Human';
      case 'ultra': return 'Ultra Real Human';
      default: return tier;
    }
  }

  String? get _voiceProfileName =>
      _agent?['voice_profile_name'] as String? ?? _agent?['voice_id'] as String?;

  bool get _is11labsVoice {
    final p = (_agent?['voice_provider'] as String?)?.toLowerCase() ?? '';
    if (p == '11labs' || p == 'elevenlabs') return true;
    return _effectiveTier == 'natural' || _effectiveTier == 'ultra';
  }

  double get _voiceStability {
    if (_stabilityOverride != null) return _stabilityOverride!.clamp(0.0, 1.0);
    final v = _agent?['voice_stability'];
    if (v == null) return 0.5;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.5;
  }

  double get _voiceSimilarityBoost {
    if (_similarityBoostOverride != null) return _similarityBoostOverride!.clamp(0.0, 1.0);
    final v = _agent?['voice_similarity_boost'];
    if (v == null) return 0.75;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.75;
  }

  List<String> get _unlockedTiers =>
      List<String>.from(_billing?['unlocked_tiers'] as List? ?? ['neutral']);

  bool get _allowPerAgentVoiceTier =>
      _billing?['allow_per_agent_voice_tier'] == true;

  Future<void> _setUseAccountDefault(bool useDefault) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (useDefault) {
        await NeyvoPulseApi.updateAgent(widget.agentId, {
          'voice_tier_override': null,
          'voice_profile_id': null,
          'voice_provider': null,
          'voice_id': null,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice settings updated')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setTierOverride(String tier) async {
    if (_saving || !_unlockedTiers.contains(tier)) return;
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.updateAgent(widget.agentId, {
        'voice_tier_override': tier,
        'voice_profile_id': null,
        'voice_provider': null,
        'voice_id': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice tier set to ${_tierDisplay(tier)}')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveBasicsAndScripts() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        'system_prompt': _systemPromptController.text.trim().isEmpty ? null : _systemPromptController.text.trim(),
        'opening_message': _openingMessageController.text.trim().isEmpty ? null : _openingMessageController.text.trim(),
      };
      payload.removeWhere((_, v) => v == null);
      await NeyvoPulseApi.updateAgent(widget.agentId, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent updated')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setStatus(String status) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.updateAgent(widget.agentId, {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setComplianceFlag(String key, bool value) async {
    if (_saving) return;
    final current = Map<String, dynamic>.from(
      (_agent?['compliance_flags'] as Map?) ?? {},
    );
    current[key] = value;
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.updateAgent(widget.agentId, {'compliance_flags': current});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compliance updated')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionCard(String title, String? subtitle, Widget child) {
    return Card(
      color: NeyvoTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _saveVoiceTuning(double stability, double similarityBoost) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.updateAgent(widget.agentId, {
        'voice_stability': stability,
        'voice_similarity_boost': similarityBoost,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice tuning updated')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildStabilitySlider() {
    final value = _voiceStability.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stability: ${value.toStringAsFixed(2)}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 20,
          activeColor: NeyvoTheme.teal,
          onChanged: _saving ? null : (v) => setState(() => _stabilityOverride = v),
          onChangeEnd: _saving ? null : (v) => _saveVoiceTuning(v, _voiceSimilarityBoost),
        ),
      ],
    );
  }

  Widget _buildSimilarityBoostSlider() {
    final value = _voiceSimilarityBoost.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Similarity boost: ${value.toStringAsFixed(2)}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 20,
          activeColor: NeyvoTheme.teal,
          onChanged: _saving ? null : (v) => setState(() => _similarityBoostOverride = v),
          onChangeEnd: _saving ? null : (v) => _saveVoiceTuning(_voiceStability, v),
        ),
      ],
    );
  }

  Future<void> _openVoiceLibrary() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeyvoTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => VoiceLibraryModal(
        currentTier: _effectiveTier,
        currentVoiceId: _agent?['voice_id'] as String?,
        currentProvider: _agent?['voice_provider'] as String?,
        unlockedTiers: _unlockedTiers,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.updateAgent(widget.agentId, {
        'voice_tier_override': selected['tier'] as String?,
        'voice_profile_id': selected['id'] as String?,
        'voice_provider': selected['provider'] as String?,
        'voice_id': selected['voice_id'] as String?,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice updated')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _agent == null) {
      return const Scaffold(
        backgroundColor: NeyvoTheme.bgPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: NeyvoTheme.bgPrimary,
        appBar: AppBar(
          backgroundColor: NeyvoTheme.bgSurface,
          title: const Text('Agent'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final name = _agent?['name'] as String? ?? 'Unnamed';
    final status = (_agent?['status'] as String?)?.toLowerCase() ?? 'active';
    final direction = _agent?['direction'] as String?;
    final industry = _agent?['industry'] as String?;
    final useCase = _agent?['use_case'] as String?;
    final templateId = _agent?['template_id'] as String?;
    final phoneNumber = _agent?['phone_number'] as String?;
    final complianceFlags = _agent?['compliance_flags'] as Map? ?? {};
    final hipaa = complianceFlags['hipaa'] == true;

    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: NeyvoTheme.bgSurface,
        title: Text(name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        children: [
          _sectionCard(
            'Basics',
            'Name, status, and metadata for this agent.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: status == 'active' ? NeyvoTheme.success : NeyvoTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Agent name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Status', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'active', label: Text('Active'), icon: Icon(Icons.check_circle_outline)),
                    ButtonSegment(value: 'paused', label: Text('Paused'), icon: Icon(Icons.pause_circle_outline)),
                  ],
                  selected: {'active', 'paused'}.contains(status) ? {status} : {'active'},
                  onSelectionChanged: (Set<String> s) {
                    final v = s.isNotEmpty ? s.first : null;
                    if (v != null && v != status) _setStatus(v);
                  },
                ),
                if (direction != null || industry != null || useCase != null || templateId != null || phoneNumber != null) ...[
                  const SizedBox(height: 16),
                  Text('Details', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary)),
                  if (direction != null) _detailRow('Direction', direction),
                  if (industry != null) _detailRow('Industry', industry),
                  if (useCase != null) _detailRow('Use case', useCase),
                  if (templateId != null) _detailRow('Template', templateId),
                  if (phoneNumber != null) _detailRow('Phone', phoneNumber),
                ],
              ],
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _sectionCard(
            'Scripts & prompts',
            'System prompt and opening message. You can use variables like {{business_name}}.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _systemPromptController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'System prompt',
                    hintText: 'Instructions for how the agent should behave...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _openingMessageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Opening message',
                    hintText: 'First thing the agent says when a call starts...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveBasicsAndScripts,
                    child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save name & scripts'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _sectionCard(
            'Voice',
            _allowPerAgentVoiceTier
                ? 'Use account default or set a custom voice for this agent.'
                : 'This agent uses your account default voice. Change it in Settings → Billing → Voice Tier.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<bool>(
                  title: const Text('Use account default'),
                  subtitle: Text(
                    '${_tierDisplay((_billing?['voice_tier'] as String?)?.toLowerCase() ?? 'neutral')} (from Settings → Billing)',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                  ),
                  value: true,
                  groupValue: _useAccountDefault,
                  onChanged: _saving ? null : (v) => _setUseAccountDefault(true),
                  activeColor: NeyvoTheme.teal,
                ),
                if (_allowPerAgentVoiceTier) ...[
                  RadioListTile<bool>(
                    title: const Text('Custom override'),
                    subtitle: const Text('Choose a tier and voice for this agent only'),
                    value: false,
                    groupValue: _useAccountDefault,
                    onChanged: _saving ? null : (v) => _setUseAccountDefault(false),
                    activeColor: NeyvoTheme.teal,
                  ),
                  if (!_useAccountDefault) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: ['neutral', 'natural', 'ultra']
                          .where((t) => _unlockedTiers.contains(t))
                          .map<Widget>((tier) {
                        final selected = _effectiveTier == tier;
                        return ChoiceChip(
                          label: Text(_tierDisplay(tier)),
                          selected: selected,
                          onSelected: _saving ? null : (_) => _setTierOverride(tier),
                          selectedColor: NeyvoTheme.teal.withOpacity(0.3),
                        );
                      }).toList(),
                    ),
                    if (_unlockedTiers.length < 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Upgrade in Settings → Billing to unlock Natural and Ultra.',
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary),
                        ),
                      ),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Different voice tier per agent is available on Business plan. Enable it in Settings → Billing → Voice Tier.',
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Voice personality', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                const SizedBox(height: 8),
                Card(
                  color: NeyvoTheme.bgSurface,
                  child: ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined, color: NeyvoTheme.teal),
                    title: Text(
                      _voiceProfileName ?? _tierDisplay(_effectiveTier),
                      style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                    ),
                    subtitle: Text(
                      _tierDisplay(_effectiveTier),
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _saving ? null : _openVoiceLibrary,
                      child: const Text('Change Voice'),
                    ),
                  ),
                ),
                if (_is11labsVoice) ...[
                  const SizedBox(height: 24),
                  Text('Voice tuning (11labs)', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                  const SizedBox(height: 8),
                  _buildStabilitySlider(),
                  const SizedBox(height: 12),
                  _buildSimilarityBoostSlider(),
                ],
              ],
            ),
          ),
          if (_agent?['model_display'] != null || _agent?['transcriber_display'] != null) ...[
            const SizedBox(height: NeyvoSpacing.lg),
            _sectionCard(
              'AI / Model',
              'Model and transcriber from your voice tier (read-only).',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_agent?['model_display'] != null)
                    _detailRow('Model', _agent!['model_display'] as String),
                  if (_agent?['transcriber_display'] != null)
                    _detailRow('Transcriber', _agent!['transcriber_display'] as String),
                ],
              ),
            ),
          ],
          const SizedBox(height: NeyvoSpacing.lg),
          _sectionCard(
            'Configuration',
            'Compliance and behavior flags.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('HIPAA compliance'),
                  subtitle: Text(
                    'Enable when handling protected health information.',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                  ),
                  value: hipaa,
                  onChanged: _saving ? null : (v) => _setComplianceFlag('hipaa', v),
                  activeColor: NeyvoTheme.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary))),
          Expanded(child: Text(value, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary))),
        ],
      ),
    );
  }
}
