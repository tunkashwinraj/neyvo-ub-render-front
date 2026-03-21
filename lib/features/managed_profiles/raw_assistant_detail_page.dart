import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/neyvo_theme.dart';
import 'raw_assistant_detail_provider.dart';

class RawAssistantDetailPage extends ConsumerStatefulWidget {
  const RawAssistantDetailPage({
    super.key,
    required this.profileId,
    this.embedded = false,
  });

  final String profileId;
  final bool embedded;

  @override
  ConsumerState<RawAssistantDetailPage> createState() => _RawAssistantDetailPageState();
}

class _RawAssistantDetailPageState extends ConsumerState<RawAssistantDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _syncSignature;

  final _nameCtrl = TextEditingController();
  final _systemPromptCtrl = TextEditingController();
  final _voicemailCtrl = TextEditingController();
  final _jsonImportCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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

  void _syncControllersFromState(RawAssistantDetailUiState ui) {
    if (ui.loading) return;
    final profile = ui.profile;
    final rawCfg = ui.rawConfig;
    final sig = '${profile['updated_at'] ?? profile['id'] ?? ''}|${rawCfg.hashCode}';
    if (_syncSignature == sig) return;
    _syncSignature = sig;
    final name = (profile['profile_name'] ?? profile['name'] ?? '').toString();
    _nameCtrl.text = name;
    final model = (rawCfg['model'] as Map?) ?? const {};
    final messages = (model['messages'] as List?) ?? const [];
    if (messages.isNotEmpty &&
        messages.first is Map &&
        (messages.first['role'] ?? '').toString().toLowerCase() == 'system') {
      _systemPromptCtrl.text = (messages.first['content'] ?? '').toString();
    } else {
      _systemPromptCtrl.text = (profile['custom_system_prompt'] ?? '').toString();
    }
    _voicemailCtrl.text = (rawCfg['voicemailMessage'] ?? profile['voicemail_message'] ?? '').toString();
  }

  Future<void> _save() async {
    final ui = ref.read(rawAssistantDetailCtrlProvider(widget.profileId));
    if (ui.saving) return;
    try {
      await ref.read(rawAssistantDetailCtrlProvider(widget.profileId).notifier).save(
            name: _nameCtrl.text,
            systemPrompt: _systemPromptCtrl.text,
            voicemail: _voicemailCtrl.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assistant saved and synced to Vapi.')),
      );
    } catch (e) {
      if (!mounted) return;
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
    final ui = ref.read(rawAssistantDetailCtrlProvider(widget.profileId));
    if (ui.saving) return;
    try {
      await ref.read(rawAssistantDetailCtrlProvider(widget.profileId).notifier).importJson(raw);
      if (!mounted) return;
      _jsonImportCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imported JSON and replaced assistant in Vapi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON or failed to import: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(rawAssistantDetailCtrlProvider(widget.profileId));
    _syncControllersFromState(ui);
    final profile = ui.profile;
    final rawConfig = ui.rawConfig;
    final primary = Theme.of(context).colorScheme.primary;

    final inner = ui.loading
        ? Center(child: CircularProgressIndicator(color: primary))
        : ui.error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(ui.error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.read(rawAssistantDetailCtrlProvider(widget.profileId).notifier).load(),
                      child: const Text('Retry'),
                    ),
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
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _nameCtrl,
                            builder: (context, value, _) {
                              final title = value.text.trim().isEmpty ? 'Raw assistant' : value.text.trim();
                              return Text(
                                title,
                                style: NeyvoTextStyles.heading.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: ui.saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: NeyvoColors.white,
                          ),
                          child: ui.saving
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
                        _detailChip('VAPI Assistant ID', (profile['vapi_assistant_id'] ?? '—').toString()),
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
                        _tabVoice(rawConfig),
                        _tabSettings(profile, ui.saving),
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
        title: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _nameCtrl,
          builder: (context, value, _) {
            final title = value.text.trim().isEmpty ? 'Raw assistant' : value.text.trim();
            return Text(title, style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary));
          },
        ),
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
          onChanged: (_) {},
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
    final cfg = Map<String, dynamic>.from(ref.read(rawAssistantDetailCtrlProvider(widget.profileId)).rawConfig);
    cfg['voice'] = Map<String, dynamic>.from(_defaultVoiceConfig);
    ref.read(rawAssistantDetailCtrlProvider(widget.profileId).notifier).replaceRawConfig(cfg);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice reset to default. Tap Save to apply.')),
    );
  }

  Widget _tabVoice(Map<String, dynamic> rawConfig) {
    final voice = (rawConfig['voice'] as Map?) ?? const {};
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
                  ref
                      .read(rawAssistantDetailCtrlProvider(widget.profileId).notifier)
                      .setVoiceChunkEnabled(v ?? true);
                },
              ),
            ],
          ),
        ),
        _voiceField('Min characters per chunk', minChars, (v) {
          final val = int.tryParse(v);
          ref.read(rawAssistantDetailCtrlProvider(widget.profileId).notifier).setVoiceMinCharacters(val);
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

  Widget _tabSettings(Map<String, dynamic> profile, bool saving) {
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
            onPressed: saving ? null : _importJson,
            child: saving
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
          'Assistant ID: ${(profile['vapi_assistant_id'] ?? '').toString()}',
          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
        ),
      ],
    );
  }

  void _updateVoiceField(String key, dynamic value) {
    ref.read(rawAssistantDetailCtrlProvider(widget.profileId).notifier).updateVoiceField(key, value);
  }
}

