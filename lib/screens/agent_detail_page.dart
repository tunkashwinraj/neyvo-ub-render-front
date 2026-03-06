// lib/screens/agent_detail_page.dart
// Agent detail: all configurations — basics, scripts & prompts, voice, compliance.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../neyvo_pulse_api.dart';
import '../utils/voice_preview_player.dart';
import '../theme/neyvo_theme.dart';

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

  // Inline voice catalog state (shared with managed profiles).
  bool _voiceCatalogLoading = false;
  String? _voiceCatalogError;
  List<Map<String, dynamic>> _voicesForTier = const [];
  String? _playingVoiceId;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _toneController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
  final TextEditingController _openingMessageController = TextEditingController();
  final TextEditingController _voicemailMessageController = TextEditingController();
  final TextEditingController _endCallPhrasesController = TextEditingController();
  final TextEditingController _advancedConfigController = TextEditingController();
  double? _stabilityOverride;
  double? _similarityBoostOverride;

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _toneController.dispose();
    _systemPromptController.dispose();
    _openingMessageController.dispose();
    _voicemailMessageController.dispose();
    _endCallPhrasesController.dispose();
    _advancedConfigController.dispose();
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
        final customFields = agentData['custom_fields'] as Map<String, dynamic>?;
        _goalController.text = (customFields?['goal'] ?? agentData['goal'])?.toString() ?? '';
        _toneController.text = (customFields?['tone'] ?? agentData['tone'])?.toString() ?? '';
        _systemPromptController.text = (agentData['system_prompt'] as String?) ?? '';
        _openingMessageController.text = (agentData['opening_message'] as String?) ?? '';
        _voicemailMessageController.text = (agentData['voicemail_message'] as String?) ?? '';
        final endPhrases = agentData['end_call_phrases'] as List?;
        _endCallPhrasesController.text = endPhrases != null
            ? (endPhrases.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join('\n'))
            : '';
        _stabilityOverride = null;
        _similarityBoostOverride = null;
        _advancedConfigController.text = _formatAdvancedConfig(agentData);
        if (mounted) {
          setState(() {
            _agent = agentData;
            _billing = results[1] as Map<String, dynamic>?;
            _loading = false;
          });
        }
        // After wallet is available, load curated voices for the effective tier.
        await _loadVoiceCatalogForTier();
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

  /// Format agent's full-parity fields as readable JSON for the advanced text area.
  String _formatAdvancedConfig(Map<String, dynamic> agent) {
    final map = <String, dynamic>{};
    for (final key in [
      'voice_config',
      'model_config',
      'transcriber_config',
      'analysis_plan',
      'message_plan',
      'start_speaking_plan',
      'stop_speaking_plan',
    ]) {
      final v = agent[key];
      if (v != null && (v is Map || v is List)) map[key] = v;
    }
    if (map.isEmpty) return '';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(map);
    } catch (_) {
      return map.toString();
    }
  }

  Future<void> _saveCallBehavior() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final voicemail = _voicemailMessageController.text.trim();
      final phrasesText = _endCallPhrasesController.text.trim();
      final endCallPhrases = phrasesText.isEmpty
          ? <String>[]
          : phrasesText.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final payload = <String, dynamic>{
        'voicemail_message': voicemail.isEmpty ? null : voicemail,
        'end_call_phrases': endCallPhrases.isEmpty ? null : endCallPhrases,
      };
      payload.removeWhere((_, v) => v == null);
      await NeyvoPulseApi.updateAgent(widget.agentId, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call behavior saved')),
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

  Future<void> _saveAdvancedConfig() async {
    final raw = _advancedConfigController.text.trim();
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter JSON or leave empty to skip.')),
        );
      }
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>?;
      if (decoded == null || decoded.isEmpty) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      await NeyvoPulseApi.updateAgent(widget.agentId, decoded);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Advanced config saved')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid JSON or failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
      return (override ?? legacy ?? 'ultra').toString().toLowerCase();
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

  String get _currentVoiceId => (_agent?['voice_id'] ?? '').toString().trim();

  String? get _currentVoiceName {
    final id = _currentVoiceId;
    if (id.isEmpty) return null;
    for (final v in _voicesForTier) {
      final vid = (v['voice_id'] ?? '').toString();
      if (vid == id) {
        final name = (v['name'] ?? '').toString();
        return name.isNotEmpty ? name : vid;
      }
    }
    return null;
  }

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
      List<String>.from(_billing?['unlocked_tiers'] as List? ?? ['neutral', 'natural', 'ultra']);

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

  Future<void> _loadVoiceCatalogForTier() async {
    if (!mounted || _billing == null) return;
    final tier = _effectiveTier;
    setState(() {
      _voiceCatalogLoading = true;
      _voiceCatalogError = null;
    });
    try {
      // Always fetch full catalog (tier=all) so we show all ElevenLabs + OpenAI voices.
      final res = await NeyvoPulseApi.getVoices(tier: 'all');
      List<Map<String, dynamic>> list = _extractVoicesFromResponse(res, preferredTier: tier);

      if (!mounted) return;
      setState(() {
        _voicesForTier = list;
        _voiceCatalogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voiceCatalogError = e.toString();
        _voiceCatalogLoading = false;
        _voicesForTier = const [];
      });
    }
  }

  List<Map<String, dynamic>> _extractVoicesFromResponse(dynamic res, {String? preferredTier}) {
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
        final neutral = res['neutral'];
        final natural = res['natural'];
        final ultra = res['ultra'];

        if (preferredTier != null) {
          final t = preferredTier.toLowerCase();
          if (t == 'neutral' && neutral is List) addFromList(neutral);
          if (t == 'natural' && natural is List) addFromList(natural);
          if (t == 'ultra' && ultra is List) addFromList(ultra);
        }

        if (neutral is List) addFromList(neutral);
        if (natural is List) addFromList(natural);
        if (ultra is List) addFromList(ultra);
      }
    }

    return out;
  }

  Future<void> _saveName() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      await NeyvoPulseApi.updateAgent(widget.agentId, {'name': name.isEmpty ? null : name});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name saved')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save name: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Save personality (name, status, goal, tone). Syncs to VAPI.
  Future<void> _savePersonality() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final goal = _goalController.text.trim();
      final tone = _toneController.text.trim();
      final status = (_agent?['status'] as String?)?.toLowerCase();
      final effectiveStatus = status == 'paused' ? 'paused' : 'active';
      final existingCustom = Map<String, dynamic>.from(_agent?['custom_fields'] as Map? ?? {});
      existingCustom['goal'] = goal.isEmpty ? null : goal;
      existingCustom['tone'] = tone.isEmpty ? null : tone;
      existingCustom.removeWhere((_, v) => v == null);
      final payload = <String, dynamic>{
        'name': name.isEmpty ? null : name,
        'status': effectiveStatus,
        if (existingCustom.isNotEmpty) 'custom_fields': existingCustom,
      };
      payload.removeWhere((_, v) => v == null);
      await NeyvoPulseApi.updateAgent(widget.agentId, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personality saved and synced to operator')),
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

  Future<void> _saveSystemPrompt() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final value = _systemPromptController.text.trim();
      await NeyvoPulseApi.updateAgent(widget.agentId, {'system_prompt': value.isEmpty ? null : value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System prompt saved')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save system prompt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOpeningMessage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final value = _openingMessageController.text.trim();
      await NeyvoPulseApi.updateAgent(widget.agentId, {'opening_message': value.isEmpty ? null : value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening message saved')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save opening message: $e')),
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

  Future<void> _setBackgroundSound(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.updateAgent(widget.agentId, {
        'background_sound': enabled ? 'office' : 'off',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(enabled ? 'Background voice on' : 'Background voice off')),
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

  Future<void> _playVoiceSample(Map<String, dynamic> voice) async {
    final voiceId = (voice['voice_id'] ?? '').toString();
    final provider = (voice['provider'] ?? '').toString();
    if (voiceId.isEmpty || provider.isEmpty) return;
    setState(() => _playingVoiceId = voiceId);
    try {
      final res = await NeyvoPulseApi.postVoicePreview(
        voiceId: voiceId,
        provider: provider,
        text: (voice['sample_text'] ?? '').toString().trim().isEmpty
            ? null
            : (voice['sample_text'] ?? '').toString(),
      );
      if (!mounted) return;
      await playVoicePreview(res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playing sample…')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview unavailable for this voice. Try another.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _playingVoiceId = null);
      }
    }
  }

  Future<void> _selectVoice(Map<String, dynamic> voice) async {
    final voiceId = (voice['voice_id'] ?? '').toString();
    final provider = (voice['provider'] ?? '').toString();
    if (voiceId.isEmpty || provider.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final tier = (voice['tier'] ?? _effectiveTier).toString();
      await NeyvoPulseApi.updateAgent(widget.agentId, {
        'voice_tier_override': tier,
        'voice_profile_id': voice['id'],
        'voice_provider': provider,
        'voice_id': voiceId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice updated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
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
          title: const Text('Operator'),
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
            'Personality',
            'Operator name, goal, tone, and status. Save to sync to your voice operator.',
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
                          labelText: 'Operator name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _goalController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Goal',
                    hintText: 'What should this operator achieve (e.g. book appointments, answer FAQs)?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _toneController,
                  decoration: const InputDecoration(
                    labelText: 'Tone',
                    hintText: 'e.g. professional, friendly, warm',
                    border: OutlineInputBorder(),
                  ),
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: _saving ? null : _savePersonality,
                      style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _sectionCard(
            'Scripts & prompts',
            'System prompt and opening message (first message). Use variables like {{business_name}}. Save each field separately.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _systemPromptController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'System prompt',
                    hintText: 'Instructions for how the operator should behave...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.tonal(
                      onPressed: _saving ? null : _enhanceSystemPrompt,
                      child: const Text('Enhance script with AI'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _saveSystemPrompt,
                      child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save system prompt'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _openingMessageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Opening message (first message)',
                    hintText: 'First thing the operator says when a call starts...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveOpeningMessage,
                    child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save opening message'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _sectionCard(
            'Call behavior',
            'Voicemail message and end-call phrases (synced to Vapi).',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _voicemailMessageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Voicemail message',
                    hintText: 'Message when call goes to voicemail...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _endCallPhrasesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'End-call phrases',
                    hintText: 'One phrase per line (e.g. "Goodbye", "Talk to you later")',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _saving ? null : _saveCallBehavior,
                    child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save call behavior'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _sectionCard(
            'Voice',
            _allowPerAgentVoiceTier
                ? 'Use account default or set a custom voice for this operator.'
                : 'This agent uses your account default voice. Change it in Settings → Billing → Voice Tier.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<bool>(
                  title: const Text('Use account default'),
                  subtitle: Text(
                    '${_tierDisplay((_billing?['voice_tier'] as String?)?.toLowerCase() ?? 'ultra')} (from Settings → Billing)',
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
                    subtitle: const Text('Choose a tier and voice for this operator only'),
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
                const SizedBox(height: 12),
                Text(
                  'Currently using: ${_currentVoiceId.isEmpty ? 'Default (Sarah) for ${_tierDisplay(_effectiveTier)}' : (_currentVoiceName ?? _voiceProfileName ?? 'Custom voice')}',
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 24),
                Text('Voice personality', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                const SizedBox(height: 8),
                Card(
                  color: NeyvoTheme.bgSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current tier: ${_tierDisplay(_effectiveTier)}',
                          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentVoiceId.isEmpty
                              ? 'Using your default voice for this tier.'
                              : 'Selected voice: ${_currentVoiceName ?? _voiceProfileName ?? 'Custom voice'}',
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        if (_voiceCatalogLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoTheme.teal),
                            ),
                          )
                        else if (_voiceCatalogError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 2),
                            child: Text(
                              'Voice catalog is unavailable right now. Please try again later.',
                              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                            ),
                          )
                        else if (_voicesForTier.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 2),
                            child: Text(
                              'No curated voices available right now. Please try another tier or try again later.',
                              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                            ),
                          )
                        else ...[
                          Text(
                            'Choose a voice for this operator. You can listen to a short sample before selecting.',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _voicesForTier.length,
                            itemBuilder: (context, index) {
                              final v = _voicesForTier[index];
                              final vid = (v['voice_id'] ?? '').toString();
                              final name = (v['name'] ?? '').toString().isNotEmpty
                                  ? (v['name'] ?? '').toString()
                                  : vid;
                              final vtier = (v['tier'] ?? _effectiveTier).toString();
                              final isSelected = _currentVoiceId.isNotEmpty && _currentVoiceId == vid;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? NeyvoTheme.bgCard
                                      : NeyvoTheme.bgSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? NeyvoTheme.teal : NeyvoTheme.borderSubtle,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    isSelected ? Icons.check_circle : Icons.record_voice_over_outlined,
                                    color: isSelected ? NeyvoTheme.teal : NeyvoTheme.textSecondary,
                                  ),
                                  title: Text(
                                    name,
                                    style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                                  ),
                                  subtitle: Text(
                                    _tierDisplay(vtier),
                                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                                  ),
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      IconButton(
                                        icon: _playingVoiceId == vid
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.play_circle_outline),
                                        tooltip: 'Play sample',
                                        onPressed: () => _playVoiceSample(v),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: _saving ? null : () => _selectVoice(v),
                                        child: Text(isSelected ? 'Selected' : 'Select'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
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
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Background voice'),
                  subtitle: Text(
                    'Play ambient sound during calls. Turn off if you hear unwanted background audio.',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                  ),
                  value: (_agent?['background_sound'] ?? 'off').toString().toLowerCase() != 'off',
                  onChanged: _saving ? null : (v) => _setBackgroundSound(v),
                  activeColor: NeyvoTheme.teal,
                ),
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
          const SizedBox(height: NeyvoSpacing.lg),
          ExpansionTile(
            title: Text('Advanced (Vapi parity)', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            subtitle: Text(
              'voice_config, model_config, transcriber_config, analysis_plan, message_plan, start_speaking_plan, stop_speaking_plan',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
            collapsedBackgroundColor: NeyvoTheme.bgCard,
            backgroundColor: NeyvoTheme.bgCard,
            children: [
              Padding(
                padding: const EdgeInsets.all(NeyvoSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit as JSON. Keys: voice_config, model_config, transcriber_config, analysis_plan, message_plan, start_speaking_plan, stop_speaking_plan. Use snake_case.',
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _advancedConfigController,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        hintText: '{}',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _saving ? null : _saveAdvancedConfig,
                        child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save advanced config'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Future<void> _enhanceSystemPrompt() async {
    final raw = _systemPromptController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a script or prompt first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final variables = <String, dynamic>{
        'studentName': '{{studentName}}',
        'schoolName': '{{schoolName}}',
        'balance': '{{balance}}',
        'dueDate': '{{dueDate}}',
        'lateFee': '{{lateFee}}',
        'callbackTime': '{{callbackTime}}',
        'callbackNumber': '{{callbackNumber}}',
      };
      final res = await NeyvoPulseApi.enhanceScript(
        script: raw,
        context: _agent?['use_case']?.toString() ?? '',
        agentType: 'outbound_campaign',
        tone: 'professional',
        complianceMode: 'recording_disclosure',
        variables: variables,
      );
      if (!mounted) return;
      if (res['ok'] != true || res['result'] == null) {
        final err = (res['error'] ?? 'Failed to enhance script').toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      final result = Map<String, dynamic>.from(res['result'] as Map);
      final enhanced = (result['enhancedSystemPrompt'] ?? '').toString();
      final score = (result['humanNessScore'] as num?)?.toInt();
      final summary = (result['changeSummary'] ?? '').toString();
      if (enhanced.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enhancer returned empty prompt.')),
        );
        return;
      }
      // Show a simple confirmation dialog with summary and score.
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Enhanced script ready'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (score != null)
                    Text('Human-ness score: $score/100', style: NeyvoType.bodyMedium),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(summary, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                  ],
                  const SizedBox(height: 12),
                  Text('Preview:', style: NeyvoType.bodyMedium),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NeyvoTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeyvoTheme.borderSubtle),
                    ),
                    child: SingleChildScrollView(
                      child: Text(enhanced, style: NeyvoType.bodySmall),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  _systemPromptController.text = enhanced;
                  Navigator.of(ctx).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
