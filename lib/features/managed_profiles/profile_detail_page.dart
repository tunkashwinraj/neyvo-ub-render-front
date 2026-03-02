import 'package:flutter/material.dart';

import '../../neyvo_pulse_api.dart';
import '../../pulse_route_names.dart';
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

  late TabController _tabs;

  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();

  String _tone = 'warm_friendly';
  bool _interruptEnabled = true;
  bool _handoffEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _goalCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

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
      ]);
      final profile = Map<String, dynamic>.from(results[0] as Map);
      final numbersRes = results[1] as Map<String, dynamic>;
      final raw = (numbersRes['numbers'] as List?) ?? const [];
      final numbers = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      _nameCtrl.text = (profile['profile_name'] ?? profile['name'] ?? '').toString();
      _roleCtrl.text = (profile['role'] ?? '').toString();
      _goalCtrl.text = (profile['goal'] ?? '').toString();
      _promptCtrl.text = (profile['system_prompt'] ?? profile['prompt'] ?? '').toString();

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
        'role': _roleCtrl.text.trim(),
        'goal': _goalCtrl.text.trim(),
        'system_prompt': _promptCtrl.text,
        'conversation_profile': {'tone': _tone},
        'behavior': {'interrupt_enabled': _interruptEnabled},
        'guardrails': {'handoff_enabled': _handoffEnabled},
      };
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

  @override
  Widget build(BuildContext context) {
    final title = _nameCtrl.text.trim().isEmpty ? 'Agent' : _nameCtrl.text.trim();

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
                        Tab(text: 'Prompt editor'),
                        Tab(text: 'Guardrails'),
                        Tab(text: 'Voice'),
                        Tab(text: 'Behavior'),
                        Tab(text: 'Tool integrations'),
                        Tab(text: 'Testing'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _tabPersonality(),
                        _tabPrompt(),
                        _tabGuardrails(),
                        _tabVoice(),
                        _tabBehavior(),
                        _tabTools(),
                        _tabTesting(),
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
              Text('Role', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
              const SizedBox(height: 6),
              TextField(controller: _roleCtrl, decoration: const InputDecoration(hintText: 'e.g. support / booking / sales')),
              const SizedBox(height: 12),
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
              Text('Goal', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _goalCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'What is this agent trying to accomplish?'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabPrompt() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        NeyvoGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System prompt', style: NeyvoTextStyles.heading),
              const SizedBox(height: 8),
              TextField(
                controller: _promptCtrl,
                maxLines: 18,
                decoration: const InputDecoration(
                  hintText: 'Define the agent’s instructions, style, constraints, and tools.',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _promptCtrl.text = _promptCtrl.text.trim()),
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Clean up whitespace'),
                ),
              ),
            ],
          ),
        ),
      ],
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
                'Voice selection and tiers are managed in Billing and Voice Studio.',
                style: NeyvoTextStyles.body,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.billing),
                  child: const Text('Open Billing'),
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
                subtitle: Text('Allow callers to interrupt the agent mid-sentence.', style: NeyvoTextStyles.micro),
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

