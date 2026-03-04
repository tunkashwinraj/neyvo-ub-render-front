import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/managed_profiles/managed_profile_api_service.dart';
import '../../../neyvo_pulse_api.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class DialerPage extends StatefulWidget {
  const DialerPage({super.key});

  @override
  State<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends State<DialerPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _capacity;
  List<Map<String, dynamic>> _agents = [];
  String? _selectedAgentId;
  List<Map<String, dynamic>> _numbers = [];
  String? _selectedNumberId;
  Map<String, dynamic>? _numberCapacity;

  final _contactPhone = TextEditingController();
  final _contactName = TextEditingController();
  final _structuredContext = TextEditingController();

  bool _starting = false;
  _DialerOverlayState? _overlay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contactPhone.dispose();
    _contactName.dispose();
    _structuredContext.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getOutboundCapacity(),
        ManagedProfileApiService.listProfiles(),
        NeyvoPulseApi.listNumbers(),
      ]);
      final cap = results[0] as Map<String, dynamic>;
      final prof = results[1] as Map<String, dynamic>;
      final nums = results[2] as Map<String, dynamic>;
      final list = (prof['profiles'] as List?)?.cast<dynamic>() ?? const [];
      final agents = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final first = agents.isNotEmpty ? (agents.first['profile_id']?.toString()) : null;
      final rawNums = (nums['numbers'] as List?)?.cast<dynamic>() ?? const [];
      final numbers = rawNums.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final firstNum = numbers.isNotEmpty ? (numbers.first['phone_number_id'] ?? numbers.first['id'])?.toString() : null;
      if (!mounted) return;
      setState(() {
        _capacity = cap;
        _agents = agents;
        _selectedAgentId = _selectedAgentId ?? first;
        _numbers = numbers;
        _selectedNumberId = _selectedNumberId ?? firstNum;
        _loading = false;
      });
      await _loadNumberCapacity();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadNumberCapacity() async {
    final id = (_selectedNumberId ?? '').trim();
    if (id.isEmpty) {
      if (mounted) setState(() => _numberCapacity = null);
      return;
    }
    try {
      final cap = await NeyvoPulseApi.getNumberCapacity(id);
      if (!mounted) return;
      setState(() => _numberCapacity = cap);
    } catch (_) {
      // Non-fatal; backend will enforce.
    }
  }

  Future<void> _startCall() async {
    final agentId = (_selectedAgentId ?? '').trim();
    final numberId = (_selectedNumberId ?? '').trim();
    final phone = _contactPhone.text.trim();
    if (agentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an agent.')));
      return;
    }
    if (numberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a number.')));
      return;
    }
    if (!RegExp(r'^\+[0-9]{8,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone in E.164 format (e.g. +12035551234).')));
      return;
    }

    // Guardrails (UI-side): wallet credits, capacity remaining.
    try {
      final wallet = await NeyvoPulseApi.getBillingWallet();
      final credits = (wallet['credits'] as num?)?.toInt() ??
          (wallet['wallet_credits'] as num?)?.toInt() ??
          0;
      if (credits <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient credits. Add credits to start a call.')),
        );
        return;
      }
    } catch (_) {
      // If wallet check fails, allow backend to enforce.
    }
    final remaining = (_capacity?['remaining_today'] as num?)?.toInt();
    if (remaining != null && remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No remaining outbound capacity today.')),
      );
      return;
    }
    try {
      final cap = await NeyvoPulseApi.getNumberCapacity(numberId);
      final nRemaining = (cap['remaining_today'] as num?)?.toInt();
      final warning = cap['warning'] == true;
      if (nRemaining != null && nRemaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected number reached its daily cap. Choose another number.')),
        );
        return;
      }
      if (warning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warm-up / carrier risk warning for this number. Consider using another number.')),
        );
      }
    } catch (_) {}

    setState(() {
      _starting = true;
      _overlay = _DialerOverlayState.connecting;
    });

    try {
      unawaited(_animateOverlay());
      final overrides = <String, dynamic>{};
      final name = _contactName.text.trim();
      if (name.isNotEmpty) overrides['clientName'] = name;
      final ctx = _structuredContext.text.trim();
      if (ctx.isNotEmpty) overrides['context'] = ctx;
      overrides['phone_number_id'] = numberId;

      await ManagedProfileApiService.makeOutboundCall(
        profileId: agentId,
        customerPhone: phone,
        overrides: overrides,
      );

      if (!mounted) return;
      setState(() {
        _starting = false;
        _overlay = _DialerOverlayState.speaking;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _overlay = _DialerOverlayState.success;
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _overlay = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _overlay = _DialerOverlayState.error;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _overlay = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
    }
  }

  Future<void> _animateOverlay() async {
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || _overlay != _DialerOverlayState.connecting) return;
    setState(() => _overlay = _DialerOverlayState.listening);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted || _overlay != _DialerOverlayState.listening) return;
    setState(() => _overlay = _DialerOverlayState.processing);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final remaining = (_capacity?['remaining_today'] as num?)?.toInt();
    final numbersCount = (_capacity?['numbers_count'] as num?)?.toInt();
    final safePerNumber = (_capacity?['safe_daily_per_number'] as num?)?.toInt();
    final perNumberRemaining = (_numberCapacity?['remaining_today'] as num?)?.toInt();
    final perNumberLimit = (_numberCapacity?['daily_limit'] as num?)?.toInt();
    final perNumberWarning = _numberCapacity?['warning'] == true;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dialer',
                    style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NeyvoGlassPanel(
              child: Row(
                children: [
                  const Icon(Icons.speed, color: NeyvoColors.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Remaining capacity today: ${remaining ?? '—'}'
                      '${numbersCount != null ? ' · Numbers: $numbersCount' : ''}'
                      '${safePerNumber != null ? ' · Safe/number: $safePerNumber' : ''}',
                      style: NeyvoTextStyles.bodyPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if ((_selectedNumberId ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              NeyvoGlassPanel(
                child: Row(
                  children: [
                    Icon(
                      perNumberWarning ? Icons.warning_amber_rounded : Icons.phone_outlined,
                      color: perNumberWarning ? NeyvoColors.warning : NeyvoColors.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selected number capacity: ${perNumberRemaining ?? '—'}'
                        '${perNumberLimit != null ? '/$perNumberLimit' : ''} remaining today',
                        style: NeyvoTextStyles.bodyPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NeyvoGlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Call setup', style: NeyvoTextStyles.heading),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedAgentId,
                          decoration: const InputDecoration(labelText: 'Select agent'),
                          items: _agents
                              .map((a) {
                                final id = (a['profile_id'] ?? '').toString();
                                final name = (a['profile_name'] ?? 'Operator').toString();
                                if (id.isEmpty) return null;
                                return DropdownMenuItem(value: id, child: Text(name));
                              })
                              .whereType<DropdownMenuItem<String>>()
                              .toList(),
                          onChanged: (v) => setState(() => _selectedAgentId = v),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedNumberId,
                          decoration: const InputDecoration(labelText: 'Select number'),
                          items: _numbers
                              .map((n) {
                                final id = (n['phone_number_id'] ?? n['id'] ?? '').toString();
                                final e164 = (n['phone_number_e164'] ?? n['phone_number'] ?? id).toString();
                                if (id.isEmpty) return null;
                                return DropdownMenuItem(value: id, child: Text(e164, overflow: TextOverflow.ellipsis));
                              })
                              .whereType<DropdownMenuItem<String>>()
                              .toList(),
                          onChanged: _starting
                              ? null
                              : (v) async {
                                  setState(() => _selectedNumberId = v);
                                  await _loadNumberCapacity();
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Select contact (phone)',
                            hintText: '+12035551234',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactName,
                          decoration: const InputDecoration(
                            labelText: 'Contact name (optional)',
                            hintText: 'Alex',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _structuredContext,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Optional structured context',
                            hintText: 'e.g. {"goal":"book appointment","notes":"prefers mornings"}',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _starting ? null : _startCall,
                            style: FilledButton.styleFrom(
                              backgroundColor: NeyvoColors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _starting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Start Call'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 320,
                  child: NeyvoGlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live', style: NeyvoTextStyles.heading),
                        const SizedBox(height: 12),
                        const Center(child: NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 140)),
                        const SizedBox(height: 12),
                        Text(
                          'Start a call to enter Live mode. Transcript will appear here when streaming is enabled.',
                          style: NeyvoTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_overlay != null) _DialerOverlay(state: _overlay!),
      ],
    );
  }
}

enum _DialerOverlayState { connecting, listening, processing, speaking, success, error }

class _DialerOverlay extends StatelessWidget {
  const _DialerOverlay({required this.state});

  final _DialerOverlayState state;

  @override
  Widget build(BuildContext context) {
    final (orbState, label) = switch (state) {
      _DialerOverlayState.connecting => (NeyvoAIOrbState.processing, 'Connecting call…'),
      _DialerOverlayState.listening => (NeyvoAIOrbState.listening, 'Listening…'),
      _DialerOverlayState.processing => (NeyvoAIOrbState.processing, 'Processing…'),
      _DialerOverlayState.speaking => (NeyvoAIOrbState.speaking, 'Speaking…'),
      _DialerOverlayState.success => (NeyvoAIOrbState.idle, 'Call started'),
      _DialerOverlayState.error => (NeyvoAIOrbState.error, 'Call failed'),
    };

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: NeyvoGlassPanel(
            glowing: state == _DialerOverlayState.success,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeyvoAIOrb(state: orbState, size: 160),
                  const SizedBox(height: 12),
                  Text(label, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'Neyvo is establishing audio and transcript streams.',
                    style: NeyvoTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

