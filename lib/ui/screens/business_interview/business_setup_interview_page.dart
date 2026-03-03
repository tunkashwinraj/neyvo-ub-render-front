import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../features/business_intelligence/bi_wizard_api_service.dart';
import '../../../features/business_intelligence/business_model_completeness.dart';
import '../../../theme/neyvo_theme.dart';
import '../../../screens/business_setup_page.dart';
import '../../../neyvo_pulse_api.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import 'ai_log_event.dart';

class BusinessSetupInterviewPage extends StatefulWidget {
  const BusinessSetupInterviewPage({super.key});

  @override
  State<BusinessSetupInterviewPage> createState() =>
      _BusinessSetupInterviewPageState();
}

class _BusinessSetupInterviewPageState
    extends State<BusinessSetupInterviewPage> {
  bool _loading = true;
  String? _error;
  String _status = 'missing';

  String _description = '';
  String _website = '';

  Map<String, dynamic>? _extractResult;
  final List<AiLogEvent> _events = [];
  final ScrollController _logScroll = ScrollController();
  bool _consoleExpanded = true;

  Map<String, dynamic>? _lastBiSnapshot;
  BusinessModelCompleteness? _completeness;

  static const List<String> _recommendedRoles = [
    'Front Desk Agent',
    'Booking Agent',
    'Billing Agent',
    'Support Agent',
  ];
  final Set<String> _selectedAgentRoles = Set.from(_recommendedRoles);
  bool _creatingAgents = false;
  bool _agentsCreated = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _logScroll.dispose();
    super.dispose();
  }

  void addEvent(AiLogLevel level, String message, {bool ephemeral = false}) {
    final event = AiLogEvent(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_events.length}',
      level: level,
      message: message,
      at: DateTime.now(),
      isEphemeral: ephemeral,
    );
    if (!mounted) return;
    setState(() => _events.add(event));
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_logScroll.hasClients) return;
      _logScroll.animateTo(
        _logScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await BiWizardApiService.getStatus();
      if (res['ok'] == true && res['status'] is String) {
        _status = res['status'] as String;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _extractModel() async {
    setState(() {
      _error = null;
      _extractResult = null;
      _loading = true;
    });
    addEvent(AiLogLevel.info, 'Initializing Business Intelligence');
    addEvent(AiLogLevel.progress, 'Sending extraction request');
    await Future.delayed(const Duration(milliseconds: 200));
    addEvent(AiLogLevel.progress, 'Scanning website...');
    await Future.delayed(const Duration(milliseconds: 600));
    addEvent(AiLogLevel.progress, 'Extracting services...');
    await Future.delayed(const Duration(milliseconds: 600));
    addEvent(AiLogLevel.progress, 'Drafting policies...');
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      final res = await BiWizardApiService.extractModel(
        description: _description,
        website: _website,
      );
      if (!mounted) return;
      final biMap = res['bi'] as Map?;
      setState(() {
        _extractResult = res;
        _loading = false;
        if (biMap != null) {
          _lastBiSnapshot = Map<String, dynamic>.from(biMap);
          _completeness = evaluateBusinessModelCompleteness(_lastBiSnapshot!);
        }
      });
      addEvent(AiLogLevel.success, 'Extraction complete');
      final bi = res['bi'] as Map?;
      if (bi != null) {
        final core = bi['core'] as Map? ?? {};
        final cat = (core['category'] ?? '').toString();
        if (cat.isNotEmpty) addEvent(AiLogLevel.info, 'Extracted category: $cat');
        final suggestions = res['suggestions'] as Map?;
        final services = suggestions?['services'] as List? ?? [];
        addEvent(AiLogLevel.info, 'Detected ${services.length} services');
      }
      addEvent(AiLogLevel.info, 'Drafted policies');
      addEvent(AiLogLevel.success, 'Ready for review');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      addEvent(AiLogLevel.error, 'Extraction failed: $e');
    }
  }

  void _onBiSnapshot(Map<String, dynamic> payload) {
    if (!mounted) return;
    setState(() {
      _lastBiSnapshot = Map<String, dynamic>.from(payload);
      _completeness = evaluateBusinessModelCompleteness(_lastBiSnapshot!);
    });
  }

  Future<void> _createAgentsFromBusinessModel(
    Map<String, dynamic> businessModel,
    List<String> selectedRoles,
  ) async {
    if (selectedRoles.isEmpty) return;
    setState(() => _creatingAgents = true);
    final core = businessModel['core'] as Map<String, dynamic>? ?? businessModel;
    final name = (core['name'] ?? core['business_name'] ?? 'Business').toString();
    final category = (core['category'] ?? '').toString();
    final offerings = businessModel['offerings'] as Map? ?? businessModel['knowledge'] as Map? ?? {};
    final servicesList = offerings['services'] as List? ?? [];
    final servicesStr = servicesList
        .map((e) => (e is Map ? (e['name'] ?? '').toString() : ''))
        .where((s) => s.isNotEmpty)
        .take(10)
        .join(', ');
    for (final role in selectedRoles) {
      addEvent(AiLogLevel.progress, 'Generating prompt for $role…');
      addEvent(AiLogLevel.info, 'Applying business policies…');
      final prompt = _buildAgentPrompt(name: name, category: category, services: servicesStr, role: role);
      try {
        await NeyvoPulseApi.createAgent(
          name: role,
          systemPrompt: prompt,
          direction: 'inbound',
        );
        addEvent(AiLogLevel.success, 'Agent ready.');
      } catch (e) {
        addEvent(AiLogLevel.error, 'Failed to create $role: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _creatingAgents = false;
      _agentsCreated = true;
    });
  }

  String _buildAgentPrompt({
    required String name,
    required String category,
    required String services,
    required String role,
  }) {
    return 'You are the $role for $name.'
        ' Business category: $category.'
        ' Services offered: ${services.isEmpty ? "general" : services}.'
        ' Be professional, helpful, and concise.';
  }

  NeyvoAIOrbState get _orbState {
    if (_loading) return NeyvoAIOrbState.processing;
    if (_status == 'ready') return NeyvoAIOrbState.idle;
    if (_extractResult != null) return NeyvoAIOrbState.listening;
    return NeyvoAIOrbState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final extractBi = _extractResult != null && _extractResult!['bi'] is Map
        ? Map<String, dynamic>.from(_extractResult!['bi'] as Map)
        : null;
    List<Map<String, dynamic>>? extractServices;
    if (_extractResult != null &&
        _extractResult!['suggestions'] is Map &&
        (_extractResult!['suggestions'] as Map)['services'] is List) {
      final rawList =
          (_extractResult!['suggestions'] as Map)['services'] as List<dynamic>;
      extractServices = rawList
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: SafeArea(
        child: Row(
          children: [
            // Left: Orb + high-level status + extraction prompt.
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(NeyvoSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    const SizedBox(height: NeyvoSpacing.lg),
                    Center(
                      child: NeyvoAIOrb(
                        state: _orbState,
                        size: 160,
                      ),
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    Text(
                      'Business Modeling Interview',
                      style: NeyvoTextStyles.heading
                          .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell Neyvo what your business does. I will propose services, intents, and agent roles for you.',
                      style: NeyvoTextStyles.body,
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'One-line description',
                        hintText: 'e.g. A dental clinic focusing on family care',
                      ),
                      onChanged: (v) => _description = v,
                    ),
                    const SizedBox(height: NeyvoSpacing.md),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Website (optional)',
                        hintText: 'https://yourbusiness.com',
                      ),
                      onChanged: (v) => _website = v,
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    FilledButton(
                      onPressed: _loading ? null : _extractModel,
                      style: FilledButton.styleFrom(
                        backgroundColor: NeyvoColors.teal,
                      ),
                      child: Text(
                        _extractResult == null
                            ? 'Let Neyvo analyze'
                            : 'Re-run analysis',
                      ),
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    _buildStatusSummary(),
                    if (_completeness != null) ...[
                      const SizedBox(height: NeyvoSpacing.md),
                      Text(
                        'Business Model: ${_completeness!.percent}% complete',
                        style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textPrimary),
                      ),
                      if (_completeness!.missing.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Missing: ${_completeness!.missing.join(", ")}',
                          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.warning),
                        ),
                      ],
                    ],
                    if (extractServices != null && extractServices.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: NeyvoSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detected services',
                              style: NeyvoTextStyles.label,
                            ),
                            const SizedBox(height: NeyvoSpacing.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                  extractServices.length, (index) {
                                final s = extractServices![index];
                                final name =
                                    (s['name'] ?? '').toString().trim();
                                if (name.isEmpty) return const SizedBox();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(999),
                                    color: NeyvoColors.bgRaised
                                        .withOpacity(0.7),
                                    border: Border.all(
                                        color: NeyvoColors.borderSubtle),
                                  ),
                                  child: Text(
                                    name,
                                    style: NeyvoTextStyles.micro,
                                  ),
                                )
                                    .animate()
                                    .fadeIn(
                                        duration: 250.ms,
                                        delay: (index * 70).ms)
                                    .slideY(
                                        begin: 0.1,
                                        curve: Curves.easeOut);
                              }),
                            ),
                          ],
                        ),
                      ),
                    if (_extractResult != null && !_agentsCreated) ...[
                      const SizedBox(height: NeyvoSpacing.lg),
                      Text('Recommended AI Agents', style: NeyvoTextStyles.heading),
                      const SizedBox(height: NeyvoSpacing.sm),
                      ..._recommendedRoles.map((role) {
                        final selected = _selectedAgentRoles.contains(role);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (selected) _selectedAgentRoles.remove(role);
                                else _selectedAgentRoles.add(role);
                              });
                            },
                            borderRadius: BorderRadius.circular(NeyvoRadius.md),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(NeyvoRadius.md),
                                color: NeyvoColors.bgRaised.withOpacity(0.7),
                                border: Border.all(
                                  color: selected ? NeyvoColors.teal : NeyvoColors.borderSubtle,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 20,
                                    color: selected ? NeyvoColors.teal : NeyvoColors.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(role, style: NeyvoTextStyles.body),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: _creatingAgents
                                ? null
                                : () async {
                                    final bi = extractBi ?? _lastBiSnapshot ?? {};
                                    final payload = bi.isNotEmpty
                                        ? bi
                                        : {'core': {}, 'offerings': {'services': []}};
                                    await _createAgentsFromBusinessModel(
                                      payload,
                                      _selectedAgentRoles.toList(),
                                    );
                                  },
                            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                            child: _creatingAgents
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Create Selected Agents'),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: _creatingAgents ? null : () => setState(() => _agentsCreated = true),
                            child: const Text('Skip'),
                          ),
                        ],
                      ),
                    ],
                    if (_agentsCreated) ...[
                      const SizedBox(height: NeyvoSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NeyvoColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(NeyvoRadius.md),
                          border: Border.all(color: NeyvoColors.success.withOpacity(0.4)),
                        ),
                        child: Text(
                          'Your agents are ready. You can attach them to numbers and configure routing.',
                          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/pulse/agents'),
                            icon: const Icon(Icons.smart_toy_outlined, size: 18),
                            label: const Text('Go to Agents'),
                            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/pulse/phone-numbers'),
                            icon: const Icon(Icons.phone_outlined, size: 18),
                            label: const Text('Configure Numbers'),
                          ),
                        ],
                      ),
                    ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    Expanded(
                      child: NeyvoGlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _consoleExpanded = !_consoleExpanded),
                              child: Row(
                                children: [
                                  Icon(
                                    _consoleExpanded ? Icons.expand_more : Icons.chevron_right,
                                    color: NeyvoColors.textMuted,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'System Activity',
                                    style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_consoleExpanded)
                              Expanded(
                                child: ListView.builder(
                                  controller: _logScroll,
                                  itemCount: _events.length,
                                  itemBuilder: (context, index) {
                                    final e = _events[index];
                                    return _buildLogRow(e, index);
                                  },
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
            // Right: Floating console with structured editor (existing wizard).
            Expanded(
              flex: 7,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  NeyvoSpacing.xl,
                  NeyvoSpacing.xl,
                  NeyvoSpacing.xl,
                  NeyvoSpacing.xl,
                ),
                child: NeyvoGlassPanel(
                  glowing: _status != 'ready',
                  padding: const EdgeInsets.all(NeyvoSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.smart_toy_outlined,
                              color: NeyvoColors.teal),
                          const SizedBox(width: NeyvoSpacing.sm),
                          Text(
                            'Structured business profile',
                            style: NeyvoTextStyles.heading,
                          ),
                        ],
                      ),
                      const SizedBox(height: NeyvoSpacing.md),
                      Text(
                        'Review and refine the structured profile that powers every voice agent. Changes here affect all agents.',
                        style: NeyvoTextStyles.body,
                      ),
                      const SizedBox(height: NeyvoSpacing.lg),
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(NeyvoRadius.md),
                          child: BusinessSetupPage(
                            initialBi: extractBi,
                            initialSuggestions: extractServices,
                            onBiSnapshot: _onBiSnapshot,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSummary() {
    final statusLabel = switch (_status) {
      'ready' => 'Business model: Ready',
      'partial' => 'Business model: Partial',
      _ => 'Business model: Not set up',
    };
    final statusColor = switch (_status) {
      'ready' => NeyvoColors.success,
      'partial' => NeyvoColors.warning,
      _ => NeyvoColors.textMuted,
    };

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        const SizedBox(width: NeyvoSpacing.sm),
        Expanded(
          child: Text(
            statusLabel,
            style: NeyvoTextStyles.body.copyWith(color: statusColor),
          ),
        ),
      ],
    );
  }

  String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _buildLogRow(AiLogEvent e, int index) {
    final icon = switch (e.level) {
      AiLogLevel.info => Icons.info_outline,
      AiLogLevel.success => Icons.check_circle_outline,
      AiLogLevel.warn => Icons.warning_amber_outlined,
      AiLogLevel.error => Icons.error_outline,
      AiLogLevel.progress => Icons.hourglass_empty,
    };
    final color = switch (e.level) {
      AiLogLevel.info => NeyvoColors.info,
      AiLogLevel.success => NeyvoColors.success,
      AiLogLevel.warn => NeyvoColors.warning,
      AiLogLevel.error => NeyvoColors.error,
      AiLogLevel.progress => NeyvoColors.teal,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.message,
              style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relativeTime(e.at),
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms, delay: (index * 30).ms)
        .slideX(begin: 0.02, curve: Curves.easeOut);
  }
}

