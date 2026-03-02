import 'package:flutter/material.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../pulse_route_names.dart';
import '../features/business_intelligence/bi_wizard_api_service.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import 'business_setup_page.dart';

class SetupCenterPage extends StatefulWidget {
  const SetupCenterPage({super.key, this.onSwitchToTab});

  /// When set (e.g. by PulseShell), switches shell tab by index instead of pushing a route.
  final void Function(int index)? onSwitchToTab;

  @override
  State<SetupCenterPage> createState() => _SetupCenterPageState();
}

class _SetupCenterPageState extends State<SetupCenterPage> {
  bool _loading = true;
  String? _error;

  String _businessStatus = 'missing'; // missing | partial | ready
  int _agentsCount = 0;
  int _numbersCount = 0;

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
      // Business / BI status
      String biStatus = 'missing';
      try {
        final bi = await BiWizardApiService.getStatus();
        if (bi['ok'] == true && bi['status'] is String) {
          biStatus = (bi['status'] as String).toLowerCase();
        }
      } catch (_) {}

      // Agents (managed profiles / voice profiles)
      int agentsCount = 0;
      try {
        final res = await ManagedProfileApiService.listProfiles();
        final list = (res['profiles'] as List?) ?? const [];
        agentsCount = list.length;
      } catch (_) {}

      // Numbers
      int numbersCount = 0;
      try {
        final res = await NeyvoPulseApi.listNumbers();
        final list = (res['numbers'] as List?) ?? const [];
        numbersCount = list.length;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _loading = false;
        _businessStatus = biStatus;
        _agentsCount = agentsCount;
        _numbersCount = numbersCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool get _isBusinessReady => _businessStatus == 'ready';
  bool get _hasAgents => _agentsCount > 0;
  bool get _hasNumbers => _numbersCount > 0;

  String _nextActionLabel() {
    if (!_isBusinessReady) return 'Next: Set up your business profile';
    if (!_hasAgents) return 'Next: Create your first agent';
    if (!_hasNumbers) return 'Next: Connect a phone number';
    return 'You’re live. Test a call.';
  }

  VoidCallback _nextActionOnPressed(BuildContext context) {
    if (!_isBusinessReady) {
      return () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: const Text('Business Setup'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            body: const BusinessSetupPage(),
          ),
        ),
      );
    }
    if (!_hasAgents) {
      return () => _navigateToShellTab(context, PulseRouteNames.agents);
    }
    if (!_hasNumbers) {
      return () => _navigateToShellTab(context, PulseRouteNames.phoneNumbers);
    }
    return () => _navigateToShellTab(context, PulseRouteNames.callHistory);
  }

  void _navigateToShellTab(BuildContext context, String routeName) {
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: NeyvoColors.teal),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Setup Center', style: NeyvoTextStyles.title),
                  const SizedBox(height: 4),
                  Text(
                    'One place to get from zero to live: Business → Agents → Numbers → Calls.',
                    style: NeyvoTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NeyvoColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: NeyvoColors.error.withOpacity(0.4)),
                      ),
                      child: Text(
                        _error!,
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildNextActionBanner(context),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      int cols = 2;
                      if (w < 720) cols = 1;
                      final spacing = 16.0;
                      final cardW = cols == 1 ? w : (w - spacing) / 2;
                      final tiles = [
                        _buildBusinessTile(context),
                        _buildAgentsTile(context),
                        _buildNumbersTile(context),
                        _buildGoLiveTile(context),
                      ];
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: tiles.map((t) => SizedBox(width: cardW, child: t)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextActionBanner(BuildContext context) {
    final label = _nextActionLabel();
    final onPressed = _nextActionOnPressed(context);
    return NeyvoCard(
      glowing: _isBusinessReady && _hasAgents && _hasNumbers,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            _isBusinessReady && _hasAgents && _hasNumbers ? Icons.check_circle_outline : Icons.flag_outlined,
            color: NeyvoColors.teal,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: NeyvoTextStyles.bodyPrimary,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
            child: Text(
              _isBusinessReady && _hasAgents && _hasNumbers ? 'Test call' : 'Continue',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTile(BuildContext context) {
    String statusLabel;
    Color statusColor;
    if (_businessStatus == 'ready') {
      statusLabel = 'Ready';
      statusColor = NeyvoColors.success;
    } else if (_businessStatus == 'partial') {
      statusLabel = 'Partial';
      statusColor = NeyvoColors.warning;
    } else {
      statusLabel = 'Not set up';
      statusColor = NeyvoColors.textMuted;
    }
    final subtitle = switch (_businessStatus) {
      'ready' => 'Business profile is ready. Edit if anything changes.',
      'partial' => 'Some details are missing. Finish setup to unlock better agents.',
      _ => 'Tell Neyvo what your business does so agents behave correctly.',
    };
    final cta = _businessStatus == 'ready'
        ? 'Edit'
        : _businessStatus == 'partial'
            ? 'Finish setup'
            : 'Start setup';
    return NeyvoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.domain_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 8),
              Text('Business Profile', style: NeyvoTextStyles.heading),
              const Spacer(),
              _statusPill(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: NeyvoTextStyles.body),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Business Setup'),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                    body: const BusinessSetupPage(),
                  ),
                ),
              ),
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsTile(BuildContext context) {
    final statusLabel = _agentsCount == 0 ? 'Missing' : _agentsCount == 1 ? '1 agent' : '$_agentsCount agents';
    final statusColor = _agentsCount == 0 ? NeyvoColors.textMuted : NeyvoColors.success;
    final subtitle = _agentsCount == 0
        ? 'Create your first agent in under 2 minutes.'
        : 'You can add more agents for different roles (Sales, Support, Booking).';
    final cta = _agentsCount == 0 ? 'Create first agent' : 'Add agent';
    return NeyvoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 8),
              Text('Agents', style: NeyvoTextStyles.heading),
              const Spacer(),
              _statusPill(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: NeyvoTextStyles.body),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                if (widget.onSwitchToTab != null) {
                  widget.onSwitchToTab!(2);
                } else {
                  Navigator.of(context).pushNamed(PulseRouteNames.agents);
                }
              },
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumbersTile(BuildContext context) {
    final statusLabel = _numbersCount == 0 ? 'Missing' : '$_numbersCount connected';
    final statusColor = _numbersCount == 0 ? NeyvoColors.textMuted : NeyvoColors.success;
    final subtitle = _numbersCount == 0
        ? 'Connect a phone number so people can call your agents.'
        : 'You can add more numbers for different lines or campaigns.';
    final cta = _numbersCount == 0 ? 'Connect number' : 'Manage numbers';
    return NeyvoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_in_talk_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 8),
              Text('Numbers', style: NeyvoTextStyles.heading),
              const Spacer(),
              _statusPill(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: NeyvoTextStyles.body),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                if (widget.onSwitchToTab != null) {
                  widget.onSwitchToTab!(3);
                } else {
                  Navigator.of(context).pushNamed(PulseRouteNames.phoneNumbers);
                }
              },
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoLiveTile(BuildContext context) {
    final ready = _isBusinessReady && _hasAgents && _hasNumbers;
    final statusLabel = ready ? 'Ready' : 'Not ready';
    final statusColor = ready ? NeyvoColors.success : NeyvoColors.textMuted;
    final subtitle = ready
        ? 'You’re ready to test live calls. Try an inbound or outbound test now.'
        : 'Finish the steps above to test your full call flow.';
    return NeyvoCard(
      glowing: ready,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_made_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 8),
              Text('Go Live & Test', style: NeyvoTextStyles.heading),
              const Spacer(),
              _statusPill(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: NeyvoTextStyles.body),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: ready ? () => Navigator.of(context).pushNamed(PulseRouteNames.callHistory) : null,
                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                child: const Text('Test inbound'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: ready ? () => Navigator.of(context).pushNamed(PulseRouteNames.outbound) : null,
                child: const Text('Test outbound'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(label, style: NeyvoTextStyles.micro.copyWith(color: color)),
        ],
      ),
    );
  }
}

