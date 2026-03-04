// UB Model Overview – "receipt" screen after initialization. Shows stats, departments, recommended operators; Continue → Dashboard.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../screens/pulse_shell.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/backgrounds/neyvo_neural_background.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class UbModelOverviewPage extends StatefulWidget {
  const UbModelOverviewPage({super.key});

  @override
  State<UbModelOverviewPage> createState() => _UbModelOverviewPageState();
}

class _UbModelOverviewPageState extends State<UbModelOverviewPage> {
  bool _loading = true;
  String? _error;
  String _status = 'missing';
  Map<String, dynamic>? _summary;
  List<dynamic> _departments = [];
  List<dynamic> _faqTopics = [];
  Timer? _pollTimer;
  String _websiteUrl = 'bridgeport.edu';

  static const List<String> _recommendedOperators = [
    'Admissions Operator',
    'Student Financial Services Operator',
    'Registrar Operator',
    'Housing Operator',
    'IT Help Desk Operator',
    'General Front Desk Operator',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NeyvoPulseApi.getUbStatus();
      if (!mounted) return;
      final ok = res['ok'] == true;
      if (!ok) {
        setState(() {
          _loading = false;
          _error = res['error']?.toString() ?? 'Failed to load status';
        });
        return;
      }
      final status = (res['status'] as String?)?.toLowerCase() ?? 'missing';
      setState(() {
        _status = status;
        _summary = res['summary'] is Map ? Map<String, dynamic>.from(res['summary'] as Map) : null;
        _departments = res['departments'] is List ? List<dynamic>.from(res['departments'] as List) : [];
        _faqTopics = res['faqTopics'] is List ? List<dynamic>.from(res['faqTopics'] as List) : [];
        _loading = false;
        _error = res['error']?.toString();
      });
      if (status == 'building' && mounted) _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _load();
      if (!mounted || (_status != 'building' && _status != 'missing')) {
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> _completeAndGoToDashboard() async {
    try {
      await NeyvoPulseApi.updateAccountInfo({
        'onboarding_completed': true,
        'active_surface': 'comms',
        'surfaces_enabled': ['comms'],
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('neyvo_pulse_onboarding_completed', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PulseShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _rerunAnalysis() async {
    setState(() => _loading = true);
    try {
      await NeyvoPulseApi.initializeUb(website: 'https://www.bridgeport.edu');
      if (!mounted) return;
      _websiteUrl = 'bridgeport.edu';
      await _load();
      if (_status == 'building') _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: Stack(
        children: [
          const Positioned.fill(child: NeyvoNeuralBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _loading && _status == 'building'
                      ? _buildBuildingState()
                      : _status == 'ready'
                          ? _buildReadyState()
                          : _status == 'error'
                              ? _buildErrorState()
                              : _buildBuildingState(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const NeyvoAIOrb(state: NeyvoAIOrbState.processing, size: 120),
        const SizedBox(height: 24),
        Text(
          'Building your University Model…',
          style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We are analyzing $_websiteUrl. This may take a minute.',
          style: NeyvoTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.teal),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'UB Voice OS',
            style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          NeyvoGlassPanel(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: NeyvoColors.error, size: 28),
                    const SizedBox(width: 12),
                    Text('Analysis encountered an issue', style: NeyvoTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_error ?? 'Unknown error', style: NeyvoTextStyles.body),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _rerunAnalysis,
                      style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                      child: const Text('Re-run analysis'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyState() {
    final summary = _summary ?? {};
    final deptCount = summary['departmentsCount'] is int ? summary['departmentsCount'] as int : _departments.length;
    final faqCount = summary['faqCount'] is int ? summary['faqCount'] as int : _faqTopics.length;
    final contactsFound = summary['contactsFound'] is int ? summary['contactsFound'] as int : 0;
    final hoursFound = (summary['hoursFound'] as String?) ?? 'No';

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Text(
          'UB Voice OS initialized',
          style: NeyvoTextStyles.title.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: NeyvoColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'We analyzed $_websiteUrl and built your University Model.',
          style: NeyvoTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _statCard('Departments detected', '$deptCount')),
            const SizedBox(width: 12),
            Expanded(child: _statCard('FAQs extracted', '$faqCount')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Contacts found', '$contactsFound')),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Hours found', hoursFound)),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Department preview',
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ...(_departments.take(10).map((d) {
          final m = d is Map ? Map<String, dynamic>.from(d as Map) : <String, dynamic>{};
          final name = m['name']?.toString() ?? 'Department';
          final handles = m['handles']?.toString() ?? '';
          final phone = m['phone']?.toString();
          final email = m['email']?.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeyvoGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                  if (handles.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(handles, style: NeyvoTextStyles.body),
                  ],
                  if (phone != null && phone.isNotEmpty || email != null && email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (phone != null && phone.isNotEmpty) phone, if (email != null && email.isNotEmpty) email]
                          .join(' • '),
                      style: NeyvoTextStyles.micro,
                    ),
                  ],
                ],
              ),
            ),
          );
        })),
        const SizedBox(height: 24),
        Text(
          'Recommended Operators',
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'We recommend starting with: ${_recommendedOperators.take(4).join(', ')}…',
          style: NeyvoTextStyles.body,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _completeAndGoToDashboard,
          style: FilledButton.styleFrom(
            backgroundColor: NeyvoColors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Continue → Dashboard'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _rerunAnalysis,
          child: const Text('Re-run analysis'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
        ],
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return NeyvoGlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.teal)),
          const SizedBox(height: 4),
          Text(label, style: NeyvoTextStyles.micro),
        ],
      ),
    );
  }
}
