import 'dart:convert';

import 'package:flutter/material.dart';

import '../../neyvo_pulse_api.dart';
import '../../pulse_route_names.dart';
import '../../screens/pulse_shell.dart';
import '../../tenant/tenant_brand.dart';
import '../../theme/neyvo_theme.dart';
import 'managed_profile_api_service.dart';

class RawAssistantDetailPage extends StatefulWidget {
  const RawAssistantDetailPage({
    super.key,
    required this.profileId,
    this.embedded = false,
  });

  final String profileId;
  final bool embedded;

  @override
  State<RawAssistantDetailPage> createState() => _RawAssistantDetailPageState();
}

class _RawAssistantDetailPageState extends State<RawAssistantDetailPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  bool _saving = false;

  Map<String, dynamic> _profile = const {};
  Map<String, dynamic> _rawConfig = const {};

  late TabController _tabs;

  final _nameCtrl = TextEditingController();
  final _systemPromptCtrl = TextEditingController();
  final _voicemailCtrl = TextEditingController();
  final _jsonImportCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _systemPromptCtrl.dispose();
    _voicemailCtrl.dispose();
    _jsonImportCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ManagedProfileApiService.getProfile(widget.profileId);
      final profile = Map<String, dynamic>.from(res);
      final rawCfg = Map<String, dynamic>.from(
        (profile['raw_vapi_config'] as Map?) ?? const <String, dynamic>{},
      );

      // Populate basic fields.
      final name = (profile['profile_name'] ?? profile['name'] ?? '').toString();
      _nameCtrl.text = name;
      final model = (rawCfg['model'] as Map?) ?? const {};
      final messages = (model['messages'] as List?) ?? const [];
      if (messages.isNotEmpty && messages.first is Map && (messages.first['role'] ?? '').toString().toLowerCase() == 'system') {
        _systemPromptCtrl.text = (messages.first['content'] ?? '').toString();
      } else {
        _systemPromptCtrl.text = (profile['custom_system_prompt'] ?? '').toString();
      }
      _voicemailCtrl.text = (rawCfg['voicemailMessage'] ?? profile['voicemail_message'] ?? '').toString();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _rawConfig = rawCfg;
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Start from current raw config and apply edits.
      final cfg = jsonDecode(jsonEncode(_rawConfig)) as Map<String, dynamic>;
      cfg['name'] = _nameCtrl.text.trim().isEmpty ? (cfg['name'] ?? 'Operator') : _nameCtrl.text.trim();
      cfg['voicemailMessage'] = _voicemailCtrl.text.trim();
      final model = (cfg['model'] as Map?) ?? <String, dynamic>{};
      final messages = (model['messages'] as List?)?.toList() ?? <dynamic>[];
      if (messages.isEmpty || messages.first is! Map || ((messages.first as Map)['role'] ?? '').toString().toLowerCase() != 'system') {
        messages.insert(0, {'role': 'system', 'content': _systemPromptCtrl.text.trim()});
      } else {
        (messages.first as Map)['content'] = _systemPromptCtrl.text.trim();
      }
      model['messages'] = messages;
      cfg['model'] = model;

      final updated = await ManagedProfileApiService.updateProfile(widget.profileId, {
        'profile_name': _nameCtrl.text.trim(),
        'raw_vapi_import': cfg,
      });
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _rawConfig = Map<String, dynamic>.from(updated['raw_vapi_config'] as Map? ?? cfg);
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assistant saved and synced to Vapi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _importJson() async {
    final raw = _jsonImportCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a full assistant JSON before importing.')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('JSON must be an object');
      }
      final updated = await ManagedProfileApiService.updateProfile(widget.profileId, {
        'raw_vapi_import': parsed,
      });
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _rawConfig = Map<String, dynamic>.from(updated['raw_vapi_config'] as Map? ?? parsed);
        _saving = false;
      });
      _jsonImportCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imported JSON and replaced assistant in Vapi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON or failed to import: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _nameCtrl.text.trim().isEmpty ? 'Raw assistant' : _nameCtrl.text.trim();
    final primary = TenantBrand.primary(context);

    final inner = _loading
        ? Center(child: CircularProgressIndicator(color: primary))
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
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: NeyvoTextStyles.heading.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: NeyvoColors.white,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _detailChip('Operator ID', widget.profileId),
                        _detailChip('VAPI Assistant ID', (_profile['vapi_assistant_id'] ?? '—').toString()),
                      ],
                    ),
                  ),
                  Container(
                    color: NeyvoColors.bgBase,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      labelColor: primary,
                      unselectedLabelColor: NeyvoColors.textSecondary,
                      indicatorColor: primary,
                      tabs: const [
                        Tab(text: 'Personality'),
                        Tab(text: 'Voice'),
                        Tab(text: 'Settings'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _tabPersonality(),
                        _tabVoice(),
                        _tabSettings(),
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

  Widget _detailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Text(
        '$label: $value',
        style: NeyvoTextStyles.micro.copyWith(
          color: NeyvoColors.textSecondary,
          fontFamily: value == widget.profileId || value.length > 20 ? 'monospace' : null,
        ),
      ),
    );
  }

  Widget _tabPersonality() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Name', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(hintText: 'e.g. Maria (SNAP E&T)'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('System prompt', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: _systemPromptCtrl,
          maxLines: 18,
          decoration: const InputDecoration(
            hintText: 'Full voice script and behavior instructions for this assistant.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        Text('Voicemail message', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: _voicemailCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What the assistant should say when leaving a voicemail.',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  static final Map<String, dynamic> _defaultVoiceConfig = {
    'provider': '11labs',
    'model': 'eleven_turbo_v2_5',
    'voiceId': 'GDzHdQOi6jjf8zaXhCYD',
    'speed': 0.87,
    'style': 0.22,
    'stability': 0.58,
    'similarityBoost': 0.8,
    'chunkPlan': {'enabled': true, 'minCharacters': 30},
  };

  void _resetVoiceToDefault() {
    setState(() {
      final cfg = Map<String, dynamic>.from(_rawConfig);
      cfg['voice'] = Map<String, dynamic>.from(_defaultVoiceConfig);
      _rawConfig = cfg;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice reset to default. Tap Save to apply.')),
    );
  }

  Widget _tabVoice() {
    final voice = (_rawConfig['voice'] as Map?) ?? const {};
    final provider = (voice['provider'] ?? '').toString();
    final voiceId = (voice['voiceId'] ?? '').toString();
    final model = (voice['model'] ?? '').toString();
    final speed = (voice['speed'] ?? '').toString();
    final stability = (voice['stability'] ?? '').toString();
    final style = (voice['style'] ?? '').toString();
    final similarity = (voice['similarityBoost'] ?? '').toString();
    final chunkPlan = (voice['chunkPlan'] as Map?) ?? const {};
    final chunkEnabled = (chunkPlan['enabled'] ?? true) == true;
    final minChars = (chunkPlan['minCharacters'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Voice configuration',
              style: NeyvoTextStyles.heading.copyWith(fontSize: 16),
            ),
            TextButton.icon(
              onPressed: _resetVoiceToDefault,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Reset to default'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'These settings are synced to VAPI. Tap Save to apply.',
          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _voiceField('Provider', provider, (v) => _updateVoiceField('provider', v.trim())),
        _voiceField('Voice ID', voiceId, (v) => _updateVoiceField('voiceId', v.trim())),
        _voiceField('Model', model, (v) => _updateVoiceField('model', v.trim())),
        _voiceField('Speed', speed, (v) => _updateVoiceField('speed', double.tryParse(v) ?? v)),
        _voiceField('Stability', stability, (v) => _updateVoiceField('stability', double.tryParse(v) ?? v)),
        _voiceField('Style', style, (v) => _updateVoiceField('style', double.tryParse(v) ?? v)),
        _voiceField('Similarity boost', similarity, (v) => _updateVoiceField('similarityBoost', double.tryParse(v) ?? v)),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 180,
                child: Text('Chunk plan enabled', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: chunkEnabled,
                onChanged: (v) {
                  setState(() {
                    final cfg = Map<String, dynamic>.from(_rawConfig);
                    final voiceCfg = Map<String, dynamic>.from((cfg['voice'] as Map?) ?? const {});
                    final cp = Map<String, dynamic>.from((voiceCfg['chunkPlan'] as Map?) ?? const {});
                    cp['enabled'] = v ?? true;
                    voiceCfg['chunkPlan'] = cp;
                    cfg['voice'] = voiceCfg;
                    _rawConfig = cfg;
                  });
                },
              ),
            ],
          ),
        ),
        _voiceField('Min characters per chunk', minChars, (v) {
          final val = int.tryParse(v);
          setState(() {
            final cfg = Map<String, dynamic>.from(_rawConfig);
            final voiceCfg = Map<String, dynamic>.from((cfg['voice'] as Map?) ?? const {});
            final cp = Map<String, dynamic>.from((voiceCfg['chunkPlan'] as Map?) ?? const {});
            if (val != null) cp['minCharacters'] = val;
            voiceCfg['chunkPlan'] = cp;
            cfg['voice'] = voiceCfg;
            _rawConfig = cfg;
          });
        }),
      ],
    );
  }

  Widget _voiceField(String label, String initialValue, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: initialValue,
              onChanged: (v) => onChanged(v),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabSettings() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Import from JSON',
          style: NeyvoTextStyles.heading,
        ),
        const SizedBox(height: 8),
        Text(
          'Paste a full Vapi assistant JSON export here. When you import, this assistant will be replaced with that JSON in Vapi (no billing or voice tier overrides).',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _jsonImportCtrl,
          maxLines: 14,
          decoration: const InputDecoration(
            hintText: '{"name": "...", "model": {...}, "voice": {...}, ...}',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          style: NeyvoTextStyles.bodyPrimary.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: _saving ? null : _importJson,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Import and replace assistant'),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Assistant metadata',
          style: NeyvoTextStyles.heading,
        ),
        const SizedBox(height: 8),
        Text(
          'Assistant ID: ${(_profile['vapi_assistant_id'] ?? '').toString()}',
          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
        ),
      ],
    );
  }

  void _updateVoiceField(String key, dynamic value) {
    setState(() {
      final cfg = Map<String, dynamic>.from(_rawConfig);
      final voiceCfg = Map<String, dynamic>.from((cfg['voice'] as Map?) ?? const {});
      voiceCfg[key] = value;
      cfg['voice'] = voiceCfg;
      _rawConfig = cfg;
    });
  }
}

