// File: agent_creation_wizard.dart
// Purpose: Neyvo unified – 6-step Agent Creation Wizard (surface, direction, industry, use case, name, confirm).
// Surface: comms
// Connected to: GET /api/templates, POST /api/agents

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/spearia_api.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

class AgentCreationWizard extends StatefulWidget {
  const AgentCreationWizard({super.key});

  @override
  State<AgentCreationWizard> createState() => _AgentCreationWizardState();
}

class _AgentCreationWizardState extends State<AgentCreationWizard> {
  int _step = 0;
  static const int _totalSteps = 6;
  String _surface = 'comms';
  String _direction = 'inbound';
  String? _industry;
  String? _templateId;
  String _agentName = '';
  List<dynamic> _templates = [];
  bool _loadingTemplates = false;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _billing;
  List<Map<String, dynamic>> _voiceProfiles = [];
  String? _selectedVoiceId;
  String? _selectedVoiceProvider;
  bool _loadingVoices = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadBilling();
    _loadVoices();
  }

  Future<void> _loadBilling() async {
    try {
      final w = await NeyvoPulseApi.getBillingWallet();
      if (mounted) setState(() => _billing = w);
    } catch (_) {}
  }

  Future<void> _loadVoices() async {
    setState(() => _loadingVoices = true);
    try {
      final res = await NeyvoPulseApi.listVoiceProfilesLibrary();
      final list = (res['profiles'] as List?)?.cast<dynamic>() ?? [];
      if (mounted) {
        setState(() {
          _voiceProfiles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loadingVoices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVoices = false);
    }
  }

  /// Templates from API. Always include a "Custom" option so user is never stuck.
  static final Map<String, dynamic> _customTemplate = {
    'id': 'custom',
    'display_name': 'Custom agent',
    'description': 'Set up your agent manually — full control over all settings.',
  };

  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final res = await NeyvoPulseApi.listTemplates(industry: _industry, direction: _direction);
      List<dynamic> list = [];
      if (res['templates'] != null && res['templates'] is List) {
        list = List<dynamic>.from(res['templates'] as List);
      }
      if (list.isEmpty && kDebugMode) {
        // ignore: avoid_print
        print('Neyvo templates empty for industry=$_industry direction=$_direction. '
            'Run POST ${SpeariaApi.baseUrl}/api/admin/seed-templates to seed templates.');
      }
      setState(() { _templates = list; _loadingTemplates = false; });
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Neyvo listTemplates error: $e');
      }
      setState(() { _templates = []; _loadingTemplates = false; });
    }
  }

  List<dynamic> get _displayTemplates {
    if (_templates.isEmpty) return [_customTemplate];
    return List<dynamic>.from(_templates)..add(_customTemplate);
  }

  String get _selectedTemplateDisplayName {
    if (_templateId == null) return '—';
    if (_templateId == 'custom') return 'Custom agent';
    final t = _templates.cast<Map<String, dynamic>>().where((e) => e['id'] == _templateId).toList();
    if (t.isNotEmpty) return t.first['display_name'] as String? ?? _templateId!;
    return _templateId!;
  }

  Future<void> _createAgent() async {
    final name = _agentName.trim();
    if (name.isEmpty || _templateId == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      final res = await NeyvoPulseApi.createAgent(
        name: name,
        templateId: _templateId,
        direction: _direction,
        industry: _industry,
        voiceProvider: _selectedVoiceProvider,
        voiceId: _selectedVoiceId,
      );
      if (res['ok'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: NeyvoColors.success, width: 4)),
              ),
              child: const Text('✓ Agent created — AI is ready to handle calls', style: TextStyle(color: NeyvoColors.textPrimary, fontSize: 14)),
            ),
            backgroundColor: NeyvoColors.bgRaised,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        final msg = res['error'] as String? ?? res['message'] as String? ?? res['detail']?.toString() ?? 'Failed to create agent';
        setState(() { _error = msg; _saving = false; });
      }
    } catch (e) {
      final String msg = e is ApiException ? e.message : e.toString();
      setState(() { _error = msg; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NeyvoColors.bgOverlay,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Create operator', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
                  const Spacer(),
                  IconButton(icon: Icon(Icons.close, color: NeyvoColors.textSecondary), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _totalSteps,
                  minHeight: 3,
                  backgroundColor: NeyvoColors.borderSubtle,
                  valueColor: const AlwaysStoppedAnimation<Color>(NeyvoColors.teal),
                ),
              ),
              const SizedBox(height: NeyvoSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_step == 0) _buildStepSurface(),
                      if (_step == 1) _buildStepDirection(),
                      if (_step == 2) _buildStepIndustry(),
                      if (_step == 3) _buildStepUseCase(),
                      if (_step == 4) _buildStepName(),
                      if (_step == 5) _buildStepConfirm(),
                    ],
                  ),
                ),
              ),
              if (_error != null) Text(_error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error)),
              const SizedBox(height: NeyvoSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
                  if (_step < _totalSteps - 1)
                    FilledButton(onPressed: () => setState(() => _step++), style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal), child: const Text('Next'))
                  else
                    FilledButton(
                      onPressed: (_saving || _agentName.trim().isEmpty || _templateId == null) ? null : _createAgent,
                      style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
                      child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepSurface() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Which surface is this operator for?', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.sm),
        ...['comms', 'studio'].map((s) => RadioListTile<String>(
          title: Text(s == 'comms' ? 'Handle calls (Comms)' : 'Create voice content (Studio)', style: NeyvoType.bodyLarge.copyWith(color: NeyvoTheme.textPrimary)),
          value: s,
          groupValue: _surface,
          onChanged: (v) => setState(() => _surface = v!),
        )),
      ],
    );
  }

  Widget _buildStepDirection() {
    final options = [
      ('inbound', '← Inbound', 'Receive calls from customers and contacts', Icons.call_received),
      ('outbound', '→ Outbound', 'Make calls for campaigns and outreach', Icons.call_made),
      ('hybrid', '⇄ Hybrid', 'Handle both inbound and outbound calls', Icons.swap_calls),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What will this operator do?', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 16),
        ...options.map((t) {
          final (value, label, subtitle, icon) = t;
          final selected = _direction == value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: selected ? NeyvoColors.teal.withValues(alpha: 0.05) : NeyvoColors.bgRaised,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () { setState(() { _direction = value; _templateId = null; }); _loadTemplates(); },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? NeyvoColors.borderStrong : NeyvoColors.borderDefault,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: NeyvoColors.teal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 20, color: selected ? NeyvoColors.teal : NeyvoColors.textSecondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w600)),
                            Text(subtitle, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? NeyvoColors.teal : NeyvoColors.textMuted),
                          color: selected ? NeyvoColors.teal : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  static const List<MapEntry<String, IconData>> _industryTiles = [
    MapEntry('healthcare', Icons.medical_services_outlined),
    MapEntry('education', Icons.school_outlined),
    MapEntry('automotive', Icons.directions_car_outlined),
    MapEntry('real_estate', Icons.apartment_outlined),
    MapEntry('finance', Icons.bar_chart_outlined),
    MapEntry('retail', Icons.shopping_bag_outlined),
    MapEntry('sales', Icons.track_changes_outlined),
    MapEntry('recruitment', Icons.person_add_outlined),
    MapEntry('logistics', Icons.local_shipping_outlined),
    MapEntry('hospitality', Icons.restaurant_outlined),
    MapEntry('insurance', Icons.shield_outlined),
    MapEntry('government', Icons.balance_outlined),
    MapEntry('home_services', Icons.build_outlined),
    MapEntry('telecom', Icons.signal_cellular_alt_outlined),
    MapEntry('custom', Icons.settings_outlined),
  ];

  Widget _buildStepIndustry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What\'s your industry?', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const itemWidth = 100.0;
            const itemHeight = 90.0;
            const gap = 8.0;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: _industryTiles.map((e) {
                final key = e.key;
                final label = key == 'custom' ? 'Custom' : key.replaceAll('_', ' ');
                final selected = _industry == key;
                return SizedBox(
                  width: itemWidth,
                  height: itemHeight,
                  child: Material(
                    color: selected ? NeyvoColors.tealGlow.withValues(alpha: 0.5) : NeyvoColors.bgRaised,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () { setState(() { _industry = key; _templateId = null; }); _loadTemplates(); },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? NeyvoColors.borderStrong : NeyvoColors.borderDefault,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(e.value, size: 24, color: selected ? NeyvoColors.teal : NeyvoColors.textSecondary),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              style: NeyvoTextStyles.label.copyWith(
                                fontSize: 11,
                                color: selected ? NeyvoColors.textPrimary : NeyvoColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStepUseCase() {
    if (_loadingTemplates) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose your setup', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.xs),
        Text(
          'Pre-configured templates for ${_industry ?? 'your industry'}',
          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.md),
        ..._displayTemplates.take(16).map((t) {
          final id = t['id'] as String?;
          final displayName = t['display_name'] as String? ?? id ?? 'Custom';
          final desc = t['description'] as String?;
          return Padding(
            padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
            child: Material(
              color: _templateId == id ? NeyvoTheme.bgHover : NeyvoTheme.bgCard,
              borderRadius: BorderRadius.circular(NeyvoRadius.md),
              child: InkWell(
                onTap: () => setState(() => _templateId = id),
                borderRadius: BorderRadius.circular(NeyvoRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: NeyvoSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: NeyvoType.bodyLarge.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w600)),
                            if (desc != null && desc.isNotEmpty)
                              Text(desc, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Icon(_templateId == id ? Icons.radio_button_checked : Icons.radio_button_off, color: _templateId == id ? NeyvoTheme.teal : NeyvoTheme.textSecondary, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String get _accountTierDisplay {
    final tier = (_billing?['voice_tier'] as String?)?.toLowerCase() ?? 'neutral';
    final cpm = _billing?['credits_per_minute'] ?? 25;
    switch (tier) {
      case 'natural': return 'Natural Human';
      case 'ultra': return 'Ultra Real Human';
      default: return 'Neutral Human';
    }
  }

  int get _accountCreditsPerMin {
    final v = _billing?['credits_per_minute'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 25;
  }

  Widget _buildStepName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Name your agent', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: 'e.g., Patient Support Line',
            hintStyle: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
            filled: true,
            fillColor: NeyvoColors.bgBase,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: NeyvoTextStyles.bodyPrimary.copyWith(fontSize: 14),
          onChanged: (v) => setState(() => _agentName = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Voice: $_accountTierDisplay ($_accountCreditsPerMin credits/min)',
              style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted),
            ),
            const SizedBox(width: 8),
            if (_loadingVoices)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Uses your account default from Settings → Billing → Voice Tier. You can optionally pick a specific voice below.',
          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
        ),
        const SizedBox(height: 12),
        if (_voiceProfiles.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a voice (optional)', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedVoiceId,
                decoration: const InputDecoration(
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Use account default'),
                items: _voiceProfiles.map((p) {
                  final id = p['voice_id']?.toString() ?? '';
                  final name = p['display_name']?.toString() ?? id;
                  final tier = (p['tier']?.toString() ?? 'neutral').toLowerCase();
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text('$name (${tier[0].toUpperCase()}${tier.substring(1)})'),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedVoiceId = v;
                    if (v == null || v.isEmpty) {
                      _selectedVoiceProvider = null;
                    } else {
                      final match = _voiceProfiles.firstWhere(
                        (p) => (p['voice_id']?.toString() ?? '') == v,
                        orElse: () => <String, dynamic>{},
                      );
                      _selectedVoiceProvider = match['provider']?.toString();
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              if (_selectedVoiceId != null && _selectedVoiceId!.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final provider = _selectedVoiceProvider ?? 'openai';
                      final res = await NeyvoPulseApi.postVoicePreview(
                        voiceId: _selectedVoiceId!,
                        provider: provider,
                        text: 'Hi! This is your Neyvo voice sample.',
                      );
                      final url = res['audio_url'] as String?;
                      if (url != null && url.isNotEmpty) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Preview generated.')),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Preview failed: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Preview voice'),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeyvoColors.bgBase,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: NeyvoColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _badge(_industry ?? 'any'),
                  _badge(_direction, teal: true),
                ],
              ),
              const SizedBox(height: 8),
              Text('Will create: $_selectedTemplateDisplayName', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
              const SizedBox(height: 4),
              Text('Voice: $_accountTierDisplay ($_accountCreditsPerMin credits/min)', style: NeyvoTextStyles.micro),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, {bool teal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: teal ? NeyvoColors.teal.withValues(alpha: 0.2) : NeyvoColors.borderSubtle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: NeyvoTextStyles.label.copyWith(color: teal ? NeyvoColors.teal : NeyvoColors.textSecondary, fontSize: 11)),
    );
  }

  Widget _buildStepConfirm() {
    final name = _agentName.trim().isEmpty ? '(name required)' : _agentName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(NeyvoSpacing.lg),
          decoration: BoxDecoration(
            color: NeyvoTheme.bgHover,
            borderRadius: BorderRadius.circular(NeyvoRadius.md),
            border: Border.all(color: NeyvoTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: NeyvoSpacing.sm),
              Wrap(
                spacing: NeyvoSpacing.sm,
                runSpacing: NeyvoSpacing.xs,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeyvoTheme.border.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_industry ?? 'any', style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textSecondary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeyvoTheme.teal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_direction, style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.teal)),
                  ),
                ],
              ),
              const SizedBox(height: NeyvoSpacing.md),
              Text('Template: $_selectedTemplateDisplayName', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
              const SizedBox(height: NeyvoSpacing.xs),
              Text('Voice: $_accountTierDisplay ($_accountCreditsPerMin credits/min)', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
