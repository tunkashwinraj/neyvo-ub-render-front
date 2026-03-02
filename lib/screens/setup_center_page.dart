import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../pulse_route_names.dart';
import '../features/business_intelligence/bi_wizard_api_service.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../features/setup/setup_api_service.dart';
import 'business_setup_page.dart';
import 'phone_numbers_page.dart';

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
  Map<String, dynamic>? _setupStatus;
  Map<String, dynamic>? _goLive;
  Map<String, dynamic>? _nextStep;

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
      final res = await SetupStatusApiService.getStatus();
      final business = Map<String, dynamic>.from(res['business'] as Map? ?? {});
      final agents = Map<String, dynamic>.from(res['agents'] as Map? ?? {});
      final numbers = Map<String, dynamic>.from(res['numbers'] as Map? ?? {});
      final goLive = Map<String, dynamic>.from(res['goLive'] as Map? ?? {});
      final nextStep = Map<String, dynamic>.from(res['nextStep'] as Map? ?? {});

      if (!mounted) return;
      setState(() {
        _loading = false;
        _businessStatus = (business['status'] as String? ?? 'missing').toLowerCase();
        _agentsCount = (agents['count'] as num?)?.toInt() ?? 0;
        _numbersCount = (numbers['count'] as num?)?.toInt() ?? 0;
        _setupStatus = Map<String, dynamic>.from(res);
        _goLive = goLive;
        _nextStep = nextStep;
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
    final step = _nextStep;
    if (step != null && step['title'] is String && (step['title'] as String).trim().isNotEmpty) {
      return step['title'] as String;
    }
    if (!_isBusinessReady) return 'Next: Set up your business profile';
    if (!_hasAgents) return 'Next: Create your first agent';
    if (!_hasNumbers) return 'Next: Connect a phone number';
    return 'You’re live. Test a call.';
  }

  VoidCallback _nextActionOnPressed(BuildContext context) {
    final step = _nextStep;
    if (step != null && step['route'] is String && (step['route'] as String).trim().isNotEmpty) {
      final route = step['route'] as String;
      return () {
        // Map setup routes to shell tabs when possible.
        if (widget.onSwitchToTab != null) {
          switch (route) {
            case '/pulse/business-setup':
              Navigator.of(context).push(
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
              return;
            case '/pulse/agents':
              widget.onSwitchToTab!(2);
              return;
            case '/pulse/phone-numbers':
              widget.onSwitchToTab!(3);
              return;
            case '/pulse/call-history':
              widget.onSwitchToTab!(4);
              return;
          }
        }
        // Fallback to named routes.
        if (route == '/pulse/business-setup') {
          Navigator.of(context).push(
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
        } else if (route == '/pulse/agents') {
          Navigator.of(context).pushNamed(PulseRouteNames.agents);
        } else if (route == '/pulse/phone-numbers') {
          Navigator.of(context).pushNamed(PulseRouteNames.phoneNumbers);
        } else if (route == '/pulse/call-history') {
          Navigator.of(context).pushNamed(PulseRouteNames.callHistory);
        } else {
          // Default to existing behavior.
          if (!_isBusinessReady) {
            Navigator.of(context).push(
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
          } else if (!_hasAgents) {
            _navigateToShellTab(context, PulseRouteNames.agents);
          } else if (!_hasNumbers) {
            _navigateToShellTab(context, PulseRouteNames.phoneNumbers);
          } else {
            _navigateToShellTab(context, PulseRouteNames.callHistory);
          }
        }
      };
    }

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
    final cta = _numbersCount == 0 ? 'Get a number (1 min)' : 'Manage numbers';
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
                if (_numbersCount == 0) {
                  // Open the Buy Number flow directly so the user can get a number in one click.
                  showBuyNumberModal(context, onDone: () {
                    _load();
                  });
                } else {
                  if (widget.onSwitchToTab != null) {
                    widget.onSwitchToTab!(3);
                  } else {
                    Navigator.of(context).pushNamed(PulseRouteNames.phoneNumbers);
                  }
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
    final goLive = _goLive ?? const {};
    final inboundReady = goLive['inboundReady'] == true;
    final statusLabel = inboundReady ? 'Live' : 'Not live';
    final statusColor = inboundReady ? NeyvoColors.success : NeyvoColors.textMuted;
    final primaryNumber = (goLive['callToTest'] ?? '').toString();
    final numbers = _setupStatus?['numbers'] as Map<String, dynamic>? ?? const {};
    final routingModeRaw = (numbers['routingMode'] ?? 'unknown').toString();
    final routingModeLabel = switch (routingModeRaw) {
      'silent_intent' => 'Smart routing',
      'single' => 'Single agent',
      _ => 'Unknown',
    };
    final notes = (goLive['notes'] as List?)?.cast<String>() ?? const <String>[];

    final subtitle = inboundReady
        ? 'Inbound is live. You can call your number to test the full flow.'
        : (notes.isNotEmpty
            ? notes.first
            : 'Finish the steps above to test your full call flow.');

    return NeyvoCard(
      glowing: inboundReady,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_made_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 8),
              Text('Go Live', style: NeyvoTextStyles.heading),
              const Spacer(),
              _statusPill(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: NeyvoTextStyles.body),
          const SizedBox(height: 12),
          if (primaryNumber.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Call this number to test: $primaryNumber',
                    style: NeyvoTextStyles.body,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: primaryNumber)),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(Icons.alt_route, size: 16, color: NeyvoColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Routing mode: $routingModeLabel',
                style: NeyvoTextStyles.micro,
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

