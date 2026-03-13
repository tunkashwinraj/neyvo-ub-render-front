import 'package:flutter/material.dart';

import '../../api/spearia_api.dart';
import '../../utils/voice_preview_player.dart';

import '../../neyvo_pulse_api.dart';
import '../../pulse_route_names.dart';
import '../../screens/pulse_shell.dart';
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
  bool _deleting = false;

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
  final List<_AiStudioMessage> _chatMessages = [];

  // Voice catalog state for inline picker in Voice tab.
  bool _voiceCatalogLoading = false;
  String? _voiceCatalogError;
  List<Map<String, dynamic>> _voicesForTier = const [];
  String? _playingVoiceId;

  List<Map<String, String>> _promptVariables = [];
  bool _variablePreviewLoading = false;
  String? _variablePreviewSentence;
  Map<String, String> _variableDefaults = {};
  List<Map<String, dynamic>> _variableMetadata = [];
  List<Map<String, dynamic>> _openVariables = [];
  bool _variableMetadataLoading = false;

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
      final numbersRes = Map<String, dynamic>.from(results[1] as Map);
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

      final vd = profile['variable_defaults'];
      final variableDefaults = (vd is Map)
          ? (vd.map((k, v) => MapEntry(k.toString(), (v ?? '').toString().trim())))
          : <String, String>{};

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _numbers = numbers;
        _wallet = walletRes;
        _variableDefaults = Map<String, String>.from(variableDefaults);
        _loading = false;
      });
      await _loadVariableMetadata();
      // After wallet is available, load curated voices for the effective tier.
      await _loadVoiceCatalogForTier();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadVariableMetadata() async {
    if (!mounted) return;
    setState(() => _variableMetadataLoading = true);
    try {
      final res = await ManagedProfileApiService.getVariableMetadata(widget.profileId);
      final vars = (res['variables'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final open = (res['open_variables'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      if (!mounted) return;
      setState(() {
        _variableMetadata = vars;
        _openVariables = open;
        _variableMetadataLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _variableMetadata = [];
        _openVariables = [];
        _variableMetadataLoading = false;
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
        final defaults = Map<String, String>.from(_variableDefaults);
        defaults.removeWhere((k, v) => v.isEmpty);
        body['variable_defaults'] = defaults;
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
      final goPurchase = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NeyvoColors.bgBase,
          title: const Text('No phone number'),
          content: Text(
            'You don\'t have a phone number yet. Tap "Purchase number" to go to the Phone Numbers page. After you add or purchase a number there, come back to this operator and tap "Attach to number" again to attach it.',
            style: NeyvoTextStyles.body,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
              child: const Text('Purchase number'),
            ),
          ],
        ),
      );
      if (goPurchase == true && mounted) {
        PulseShellController.navigatePulse(context, PulseRouteNames.phoneNumbers);
      }
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
              final attachedToId = (n['attached_profile_id'] ?? '').toString();
              final attachedToName = (n['attached_profile_name'] ?? '').toString();
              final inUseBy = attachedToId.isNotEmpty && attachedToId != widget.profileId
                  ? (attachedToName.isNotEmpty ? attachedToName : 'Another operator')
                  : null;
              final label = inUseBy != null
                  ? '${e164.isEmpty ? id : e164} — In use by: $inUseBy'
                  : (e164.isEmpty ? id : e164);
              return DropdownMenuItem(
                value: id,
                child: Text(label, overflow: TextOverflow.ellipsis),
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
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
            child: const Text('Attach'),
          ),
        ],
      ),
    );

    if (selected.isEmpty) return;
    setState(() => _attaching = true);
    try {
      await _attachNumberWithRetry(selected, forceMove: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _attaching = false);
      if (e.statusCode == 409 && e.payload is Map) {
        final payload = e.payload as Map<dynamic, dynamic>;
        final inUseBy = payload['in_use_by'];
        final profileName = inUseBy is Map
            ? ((inUseBy['profile_name'] ?? inUseBy['profile_id']) ?? 'Another operator').toString()
            : 'Another operator';
        final moveAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: NeyvoColors.bgBase,
            title: const Text('Number already in use'),
            content: Text(
              'This number is already in use by the operator "$profileName".\n\n'
              'Do you want to move it to this operator? (It will be detached from "$profileName".)',
              style: NeyvoTextStyles.body,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
                child: const Text('Move here'),
              ),
            ],
          ),
        );
        if (moveAnyway == true && mounted) {
          setState(() => _attaching = true);
          try {
            await _attachNumberWithRetry(selected, forceMove: true);
            if (mounted) {
              setState(() => _attaching = false);
              await _load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Number moved to this operator.')),
              );
            }
          } catch (e2) {
            if (mounted) {
              setState(() => _attaching = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e2.toString())));
            }
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _attaching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    setState(() => _attaching = false);
    await _load();
  }

  Future<void> _attachNumberWithRetry(String selected, {required bool forceMove}) async {
    await ManagedProfileApiService.attachPhoneNumber(
      profileId: widget.profileId,
      phoneNumberId: selected,
      vapiPhoneNumberId: selected,
      forceMove: forceMove,
    );
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

  Future<void> _loadVoiceCatalogForTier() async {
    // Requires wallet so we know which tier to request.
    if (_wallet == null) return;
    final tier = _effectiveTier;
    setState(() {
      _voiceCatalogLoading = true;
      _voiceCatalogError = null;
    });
    try {
      // Always fetch full catalog (tier=all) so we show all ElevenLabs + OpenAI voices.
      // The backend returns grouped { neutral, natural, ultra }; we flatten and prioritize current tier.
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

  /// Normalize /api/voices response into a flat list of voice profiles.
  /// Handles:
  /// - tier-specific: { voices: [...] }
  /// - all tiers: { neutral: [...], natural: [...], ultra: [...] }
  /// - raw list: [ {...}, {...} ]
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
        // Grouped by tier (tier == "all").
        final neutral = res['neutral'];
        final natural = res['natural'];
        final ultra = res['ultra'];

        // If a preferred tier is specified, prioritize that tier's list,
        // but still include others so users can browse alternatives.
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
                                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
                                  child: const Text('Attach to number'),
                                ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _saving ? null : _save,
                                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
                                child: _saving
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white))
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
                maxLines: 6,
                maxLength: 2500,
                decoration: const InputDecoration(
                  hintText: 'What is this operator trying to accomplish?',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 2),
              Text(
                '${_goalCtrl.text.length} / 2500',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabAiStudio() {
    if (!_isUbOperator) {
      return Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: NeyvoGlassPanel(
          child: Text(
            'AI Studio is available for UB operators that use a custom prompt.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(NeyvoSpacing.xl),
      child: _buildAiStudioCard(),
    );
  }

  Widget _buildAiStudioCard() {
    final sub = (_wallet?['subscription_tier'] ?? '').toString().toLowerCase();
    final canUse = sub != 'free';
    if (!canUse) {
      return NeyvoGlassPanel(
        child: Text(
          'AI Studio requires a Pro or Business plan.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
      );
    }
    return NeyvoGlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: NeyvoColors.bgRaised,
                            borderRadius: BorderRadius.circular(NeyvoRadius.lg),
                            border: Border.all(color: NeyvoColors.borderSubtle),
                          ),
                          child: _buildAiStudioChatList(),
                        ),
                      ),
                      const SizedBox(height: NeyvoSpacing.sm),
                      _buildAiStudioInputRow(),
                    ],
                  ),
                ),
                const SizedBox(width: NeyvoSpacing.lg),
                Expanded(
                  flex: 2,
                  child: _buildAiStudioSuggestionPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildAiStudioChatList() {
    if (_chatMessages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Describe how you want this operator to sound. For example: '
          '“Make the opening warmer and mention payment plans if there is a balance.”',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _chatMessages.length,
      itemBuilder: (context, index) {
        final msg = _chatMessages[index];
        final alignEnd = msg.isUser;
        final bgColor = msg.isUser ? NeyvoColors.teal.withOpacity(0.18) : NeyvoColors.bgOverlay;
        final borderColor = msg.isUser ? NeyvoColors.tealLight : NeyvoColors.borderDefault;
        return Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!msg.isUser)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const NeyvoAIOrb(state: NeyvoAIOrbState.listening, size: 18),
                      const SizedBox(width: 6),
                      Text('AI Studio', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary)),
                    ],
                  ),
                if (!msg.isUser) const SizedBox(height: 4),
                Text(
                  msg.text,
                  style: NeyvoTextStyles.bodyPrimary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiStudioSuggestionPanel() {
    final latestIndex = _chatMessages.lastIndexWhere((m) => m.hasSuggestion);
    if (latestIndex == -1) {
      return Container(
        decoration: BoxDecoration(
          color: NeyvoColors.bgRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NeyvoColors.borderSubtle),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggested script preview', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
            const SizedBox(height: 8),
            Text(
              'Suggestions will appear here with a before/after preview. Use the (i) button to view full prompt and voicemail when you have a suggestion.',
              style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final msg = _chatMessages[latestIndex];
    final hasChanges = msg.changes != null && msg.changes!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Suggested changes',
                  style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'View full system prompt and voicemail',
                onPressed: () => _showAiStudioFullContentDialog(msg),
                style: IconButton.styleFrom(
                  foregroundColor: NeyvoColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          Expanded(
            child: hasChanges
                ? ListView.builder(
                    itemCount: msg.changes!.length,
                    itemBuilder: (context, i) {
                      final c = msg.changes![i];
                      final summary = c['summary'] ?? '';
                      final before = c['before'] ?? '';
                      final after = c['after'] ?? '';
                      final type = c['type'] ?? '';
                      final typeLabel = type == 'voicemail' ? 'Voicemail' : 'System prompt';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: NeyvoSpacing.lg),
                        child: Container(
                          padding: const EdgeInsets.all(NeyvoSpacing.md),
                          decoration: BoxDecoration(
                            color: NeyvoColors.bgOverlay,
                            borderRadius: BorderRadius.circular(NeyvoRadius.md),
                            border: Border.all(color: NeyvoColors.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (summary.isNotEmpty)
                                Text(
                                  summary,
                                  style: NeyvoTextStyles.bodyPrimary.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (summary.isNotEmpty) const SizedBox(height: NeyvoSpacing.sm),
                              Text(
                                typeLabel,
                                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                              ),
                              if (before.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Before:', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
                                const SizedBox(height: 2),
                                Text(before, style: NeyvoTextStyles.bodyPrimary),
                              ],
                              if (after.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('After:', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
                                const SizedBox(height: 2),
                                Text(after, style: NeyvoTextStyles.bodyPrimary.copyWith(color: NeyvoColors.teal)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: NeyvoTextStyles.bodyPrimary,
                        ),
                        const SizedBox(height: NeyvoSpacing.md),
                        Text(
                          'View full prompt and voicemail using the (i) button above to review before applying.',
                          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          if (msg.applied)
            Text(
              'Applied and synced to operator.',
              style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
            )
          else if (msg.rejected)
            Text(
              'Suggestion rejected.',
              style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _rejectSuggestion(latestIndex),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: NeyvoSpacing.sm),
                FilledButton(
                  onPressed: _aiSuggestLoading ? null : () => _applySuggestion(latestIndex),
                  style: FilledButton.styleFrom(
                    backgroundColor: NeyvoColors.teal,
                    foregroundColor: NeyvoColors.white,
                  ),
                  child: const Text('Apply to operator'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showAiStudioFullContentDialog(_AiStudioMessage msg) {
    final prompt = msg.proposedPrompt ?? _promptCtrl.text;
    final voicemail = msg.proposedVoicemail ?? _voicemailCtrl.text;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: NeyvoColors.bgRaised,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(NeyvoSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      'Full system prompt and voicemail',
                      style: NeyvoTextStyles.heading,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: IconButton.styleFrom(foregroundColor: NeyvoColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: NeyvoColors.teal,
                        unselectedLabelColor: NeyvoColors.textSecondary,
                        indicatorColor: NeyvoColors.teal,
                        tabs: const [
                          Tab(text: 'System prompt'),
                          Tab(text: 'Voicemail'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(NeyvoSpacing.lg),
                              child: SelectableText(
                                prompt,
                                style: NeyvoTextStyles.bodyPrimary,
                              ),
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(NeyvoSpacing.lg),
                              child: SelectableText(
                                voicemail,
                                style: NeyvoTextStyles.bodyPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiStudioInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _aiSuggestMessageCtrl,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'E.g. Make the opening warmer, add a line about payment plans, or simplify the closing.',
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _aiSuggestLoading ? null : _sendAiStudioMessage,
          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
          child: _aiSuggestLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white))
              : const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _sendAiStudioMessage() async {
    final text = _aiSuggestMessageCtrl.text.trim();
    if (text.isEmpty || _aiSuggestLoading) return;
    setState(() {
      _aiSuggestLoading = true;
      _chatMessages.add(_AiStudioMessage.user(text));
    });
    // Build conversation history for multi-turn context (last 6 messages).
    final history = <Map<String, String>>[];
    for (final msg in _chatMessages) {
      if (msg.isUser) {
        history.add({'role': 'user', 'content': msg.text});
      } else {
        history.add({'role': 'assistant', 'content': msg.text});
      }
    }
    // Exclude the current user message we just added.
    if (history.isNotEmpty && history.last['role'] == 'user') {
      history.removeLast();
    }
    try {
      final res = await ManagedProfileApiService.aiSuggestPrompt(
        widget.profileId,
        message: text,
        conversationHistory: history.isNotEmpty ? history : null,
      );
      _aiSuggestMessageCtrl.clear();
      final ok = res['ok'] == true;
      if (!ok) {
        final err = (res['error'] ?? 'AI Studio suggestion failed').toString();
        if (mounted) {
          setState(() => _aiSuggestLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
        return;
      }
      final explanation = (res['explanation'] ?? '').toString().trim();
      final proposedPrompt = (res['custom_system_prompt'] ?? '').toString();
      final proposedVoicemail = (res['voicemail_message'] ?? '').toString();
      final rawChanges = res['changes'];
      List<Map<String, String>>? changes;
      if (rawChanges is List && rawChanges.isNotEmpty) {
        changes = [];
        for (final c in rawChanges) {
          if (c is! Map) continue;
          final type = (c['type'] ?? '').toString().trim();
          if (type != 'system_prompt' && type != 'voicemail') continue;
          changes.add({
            'type': type,
            'summary': (c['summary'] ?? '').toString(),
            'before': (c['before'] ?? '').toString(),
            'after': (c['after'] ?? '').toString(),
          });
        }
        if (changes!.isEmpty) changes = null;
      }
      final msgText = explanation.isEmpty
          ? 'I\'ve prepared an updated script and voicemail based on your request.'
          : explanation;
      if (mounted) {
        setState(() {
          _aiSuggestLoading = false;
          _chatMessages.add(
            _AiStudioMessage.assistant(
              msgText,
              proposedPrompt: proposedPrompt.isNotEmpty ? proposedPrompt : null,
              proposedVoicemail: proposedVoicemail.isNotEmpty ? proposedVoicemail : null,
              changes: changes,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiSuggestLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
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
      final updated = await ManagedProfileApiService.updateProfile(widget.profileId, {
        'voice_provider': provider,
        'voice_id': voiceId,
      });
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _applySuggestion(int index) async {
    if (index < 0 || index >= _chatMessages.length) return;
    final msg = _chatMessages[index];
    if (!msg.hasSuggestion || msg.proposedPrompt == null) return;
    setState(() => _aiSuggestLoading = true);
    try {
      final body = <String, dynamic>{
        'custom_system_prompt': msg.proposedPrompt,
        'voicemail_message': msg.proposedVoicemail ?? _voicemailCtrl.text.trim(),
      };
      final updated = await ManagedProfileApiService.updateProfile(widget.profileId, body);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _promptCtrl.text = (updated['custom_system_prompt'] ?? '').toString();
        _voicemailCtrl.text = (updated['voicemail_message'] ?? '').toString();
        _aiSuggestLoading = false;
        _chatMessages[index] = msg.copyWith(applied: true, rejected: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes applied and synced to this operator.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiSuggestLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _rejectSuggestion(int index) {
    if (index < 0 || index >= _chatMessages.length) return;
    final msg = _chatMessages[index];
    if (!msg.hasSuggestion) return;
    setState(() {
      _chatMessages[index] = msg.copyWith(applied: false, rejected: true);
    });
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
            'Use placeholders like {{studentName}} in your script to personalize each call. You can mix fixed text with variables—values are filled from student records, your profile, or overrides below. If a variable isn\'t auto-filled, it will appear in the "Open variables" section so you can add a default or pass it per call.',
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
          if (_openVariables.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeyvoColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeyvoColors.warning.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: NeyvoColors.warning),
                      const SizedBox(width: 8),
                      Text('Open variables', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'These variables appear in your script but aren\'t auto-filled. Add a default below or pass a value when making each call.',
                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _openVariables.map((v) {
                      final k = (v['key'] ?? '').toString();
                      return Chip(
                        label: Text('{{$k}}'),
                        backgroundColor: NeyvoColors.warning.withOpacity(0.2),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          if (_variableMetadataLoading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ] else if (_variableMetadata.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Variable sources & overrides', style: NeyvoTextStyles.label),
            const SizedBox(height: 6),
            Text(
              'Where each variable gets its value. Use an override to set a default for all calls; per-call overrides still take precedence.',
              style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ..._variableMetadata.map((v) {
              final key = (v['key'] ?? '').toString();
              final label = (v['label'] ?? key).toString();
              final sourceDesc = (v['source_description'] ?? '').toString();
              final inPrompt = v['in_prompt'] == true;
              final currentVal = _variableDefaults[key] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('{{$key}}', style: NeyvoTextStyles.bodyPrimary.copyWith(fontFamily: 'monospace')),
                        if (inPrompt) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: NeyvoColors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('In prompt', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.teal)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(sourceDesc, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: ValueKey('var_override_$key'),
                      initialValue: currentVal,
                      onChanged: (val) => setState(() => _variableDefaults[key] = val.trim()),
                      decoration: const InputDecoration(
                        labelText: 'Override value (optional)',
                        hintText: 'Hardcode for all calls',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              );
            }),
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
    final voiceId = _currentVoiceId;
    final currentName = _currentVoiceName;
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
                'Currently using: ${voiceId.isEmpty ? 'Default (Sarah) for ${_tierDisplay(tier)}' : (currentName ?? 'Custom voice')}',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary),
              ),
              const SizedBox(height: 12),
              if (_voiceCatalogLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.teal)),
                )
              else if (_voiceCatalogError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Text(
                    'Voice catalog is unavailable right now. Please try again later.',
                    style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                  ),
                )
              else if (_voicesForTier.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Text(
                    'No curated voices available for this tier yet.',
                    style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                  ),
                )
              else ...[
                Text(
                  'Choose a voice for this operator. You can listen to a short sample before selecting.',
                  style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                ),
                const SizedBox(height: 12),
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
                    final vtier = (v['tier'] ?? tier).toString();
                    final isSelected = voiceId.isNotEmpty && voiceId == vid;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? NeyvoColors.bgRaised.withOpacity(0.75) : NeyvoColors.bgRaised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? NeyvoColors.teal : NeyvoColors.borderSubtle,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.record_voice_over_outlined,
                          color: isSelected ? NeyvoColors.teal : NeyvoColors.textSecondary,
                        ),
                        title: Text(
                          name,
                          style: NeyvoTextStyles.bodyPrimary,
                        ),
                        subtitle: Text(
                          _tierDisplay(vtier),
                          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
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
      ],
    );
  }

  Widget _tabAdditionalSettings() {
    final allowed = (_profile['allowed_actions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildVariablesCard(),
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
                  onPressed: () => PulseShellController.navigatePulse(context, PulseRouteNames.dialer),
                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
                  child: const Text('Open Dialer'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildDangerZone(),
      ],
    );
  }

  Widget _buildDangerZone() {
    final status = (_profile['status'] ?? 'active').toString().toLowerCase();
    final isArchived = status == 'archived';

    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: NeyvoColors.error, size: 24),
              const SizedBox(width: 10),
              Text('Danger zone', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.error)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Permanently delete this operator. The number will be detached and the assistant removed from VAPI. This cannot be undone.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          ),
          if (!isArchived) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _deleting ? null : _confirmDeleteOperator,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NeyvoColors.error,
                  side: const BorderSide(color: NeyvoColors.error),
                ),
                child: _deleting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Delete operator'),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('This operator is archived and cannot be edited.', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteOperator() async {
    final profileName = (_profile['profile_name'] ?? _profile['name'] ?? 'Unnamed').toString().trim();
    final version = _profile['version'] as int? ?? 1;
    final confirmName = profileName.isEmpty ? 'Unnamed' : 'UB $profileName v$version';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteOperatorConfirmDialog(
        confirmName: confirmName,
        onCancel: () => Navigator.of(ctx).pop(false),
        onDelete: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ManagedProfileApiService.archiveProfile(widget.profileId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operator deleted.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
                  onPressed: () => PulseShellController.navigatePulse(context, PulseRouteNames.dialer),
                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
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

// Simple message model for AI Studio chat.
// Kept local to this file as it is purely UI state.
class _AiStudioMessage {
  final bool isUser;
  final String text;
  final String? proposedPrompt;
  final String? proposedVoicemail;
  final List<Map<String, String>>? changes;
  final bool applied;
  final bool rejected;

  const _AiStudioMessage({
    required this.isUser,
    required this.text,
    this.proposedPrompt,
    this.proposedVoicemail,
    this.changes,
    this.applied = false,
    this.rejected = false,
  });

  bool get hasSuggestion => !isUser && (proposedPrompt != null && proposedPrompt!.isNotEmpty);

  _AiStudioMessage copyWith({
    bool? applied,
    bool? rejected,
  }) {
    return _AiStudioMessage(
      isUser: isUser,
      text: text,
      proposedPrompt: proposedPrompt,
      proposedVoicemail: proposedVoicemail,
      changes: changes,
      applied: applied ?? this.applied,
      rejected: rejected ?? this.rejected,
    );
  }

  factory _AiStudioMessage.user(String text) {
    return _AiStudioMessage(isUser: true, text: text);
  }

  factory _AiStudioMessage.assistant(
    String text, {
    String? proposedPrompt,
    String? proposedVoicemail,
    List<Map<String, String>>? changes,
  }) {
    return _AiStudioMessage(
      isUser: false,
      text: text,
      proposedPrompt: proposedPrompt,
      proposedVoicemail: proposedVoicemail,
      changes: changes,
    );
  }
}

class _DeleteOperatorConfirmDialog extends StatefulWidget {
  const _DeleteOperatorConfirmDialog({
    required this.confirmName,
    required this.onCancel,
    required this.onDelete,
  });

  final String confirmName;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  State<_DeleteOperatorConfirmDialog> createState() => _DeleteOperatorConfirmDialogState();
}

class _DeleteOperatorConfirmDialogState extends State<_DeleteOperatorConfirmDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches => _controller.text.trim() == widget.confirmName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NeyvoColors.bgRaised,
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: NeyvoColors.error, size: 28),
          const SizedBox(width: 12),
          const Text('Delete Assistant'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete this assistant? This action cannot be undone. Please enter \'${widget.confirmName}\' to confirm deletion.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.confirmName,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: NeyvoColors.bgBase,
            ),
            style: NeyvoTextStyles.body,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _matches ? widget.onDelete : null,
          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.error),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

