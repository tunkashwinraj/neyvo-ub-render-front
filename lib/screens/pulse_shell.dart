// lib/screens/pulse_shell.dart
// Neyvo Pulse – main shell with persistent sidebar (always visible).
// Listens to Firestore org doc for real-time wallet_credits updates.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pulse_route_names.dart';
import 'pulse_dashboard_page.dart';
import 'settings_page.dart';
import 'campaigns_page.dart';
import 'phone_numbers_page.dart';
import 'call_history_page.dart';
import 'analytics_page.dart';
import 'callbacks_page.dart';
import '../features/managed_profiles/managed_profiles_page.dart';
import '../features/managed_profiles/profile_detail_page.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../ui/screens/launch/launch_page.dart';
import '../ui/screens/calls/calls_page.dart';
import '../ui/screens/calls/test_call_page.dart';
import '../ui/screens/billing/billing_page.dart';
import '../ui/screens/integrations/integrations_page.dart';
import '../ui/screens/voice_studio/voice_studio_page.dart';
import '../ui/components/calls/incoming_call_overlay.dart';
import '../ui/screens/agency/agency_overview_page.dart';
import 'students_hub_page.dart';
import 'team_page.dart';

class PulseShell extends StatefulWidget {
  const PulseShell({
    super.key,
    this.initialRouteName,
    this.initialProfileId,
    this.initialCallsSection,
  });

  final String? initialRouteName;
  /// When set with initialRouteName == managedProfiles, open Voice Profiles and show this profile's detail (inside shell).
  final String? initialProfileId;
  final CallsSection? initialCallsSection;

  @override
  State<PulseShell> createState() => _PulseShellState();
}

class _PulseShellState extends State<PulseShell> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int? _walletCredits;
  final GlobalKey<NavigatorState> _managedProfilesNavKey = GlobalKey<NavigatorState>();
  int? _numbersCount; // kept for future analytics panels
  int? _callsTodayCapacity;
  int? _callsTodayUsed;
  double? _usageSpend;
  int _addonsCount = 0;
  String? _subscriptionStatus;
  String? _subscriptionTier;
  String? _orgStatus;
  String? _accountName;
  String? _accountIdDisplay;
  String _orgCollection = '';
  String? _orgDocId; // Firestore document ID for real-time listener (backend returns this; we only show short account_id in UI)
  bool _hasFirstCompletedCall = false;
  bool _voiceStudioEnabled = false;
  bool _agencyMode = false;
  Map<String, dynamic>? _incomingCall;
  StreamSubscription<DocumentSnapshot>? _walletSubscription;
  late final AnimationController _livePulseCtrl;
  late final Animation<double> _livePulse;

  /// Unified Voice OS navigation – no surfaces exposed to the user.
  List<_NavItem> get _navItems {
    // UB-only nav: Students hub, Call Logs, Campaigns as first-class.
    final items = <_NavItem>[
      const _NavItem('Home', Icons.home_outlined, PulseRouteNames.dashboard),
      const _NavItem('Operators', Icons.smart_toy_outlined, PulseRouteNames.agents),
      const _NavItem('Lines', Icons.phone_outlined, PulseRouteNames.phoneNumbers),
      const _NavItem('Students', Icons.school_outlined, PulseRouteNames.students),
      const _NavItem('Call Logs', Icons.call_outlined, PulseRouteNames.calls),
      const _NavItem('Campaigns', Icons.campaign_outlined, PulseRouteNames.campaigns),
      const _NavItem('Team', Icons.groups_outlined, PulseRouteNames.team),
      const _NavItem('Insights', Icons.auto_graph_outlined, PulseRouteNames.analytics),
      const _NavItem('Integrations', Icons.hub_outlined, PulseRouteNames.integrations),
      const _NavItem('Billing', Icons.account_balance_wallet_outlined, PulseRouteNames.billing),
      const _NavItem('Settings', Icons.settings_outlined, PulseRouteNames.settings),
    ];

    if (_selectedIndex >= items.length) {
      _selectedIndex = 0;
    }
    return items;
  }

  static const String _managedProfileDetailRoute = 'detail';

  Widget _buildManagedProfilesContent() {
    return Navigator(
      key: _managedProfilesNavKey,
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == _managedProfileDetailRoute) {
          final profileId = settings.arguments as String? ?? '';
          return MaterialPageRoute<void>(
            builder: (_) => ManagedProfileDetailPage(profileId: profileId, embedded: false),
          );
        }
        // '/' = list
        return MaterialPageRoute<void>(
          builder: (_) => ManagedProfilesPage(
            onOpenProfileDetail: (String profileId) {
              _managedProfilesNavKey.currentState?.pushNamed<void>(
                _managedProfileDetailRoute,
                arguments: profileId,
              );
            },
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) debugPrint('PulseShell initialized');
    _livePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _livePulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _livePulseCtrl, curve: Curves.easeInOut),
    );
    _resolveAccountThenLoad();
    final name = widget.initialRouteName;
    if (name != null && name.isNotEmpty) {
      final items = _navItems;
      final idx = items.indexWhere((n) => n.route == name);
      if (idx >= 0) _selectedIndex = idx;
    }
    // When deep-linked to a profile detail, push it after the nested Navigator is built.
    if (widget.initialProfileId != null && widget.initialProfileId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _managedProfilesNavKey.currentState?.pushNamed<void>(
          _managedProfileDetailRoute,
          arguments: widget.initialProfileId,
        );
      });
    }
  }

  /// Resolve logged-in account from API first, then load all data so every request uses the resolved account id.
  /// Use org_doc_id for Firestore listener (actual doc id); display only short account_id everywhere in UI.
  Future<void> _resolveAccountThenLoad() async {
    await _loadAccountInfo();
    if (!mounted) return;
    _loadWalletCredits();
    _loadNumbersSummary();
    _loadUsageSummary();
    await _loadFirstCallStatus();
    // Only start Firestore real-time listener when the user is signed in with Firebase Auth.
    // Otherwise Firestore rules typically deny access and we get permission-denied. Wallet
    // data still loads via _loadWalletCredits() (API) above.
    final docId = _orgDocId ?? NeyvoPulseApi.defaultAccountId;
    final user = FirebaseAuth.instance.currentUser;
    if (docId.isNotEmpty && _orgCollection.isNotEmpty && user != null) {
      _walletSubscription = FirebaseFirestore.instance
          .collection(_orgCollection)
          .doc(docId)
          .snapshots()
          .listen(
        (snap) {
          if (!mounted || !snap.exists) return;
          final data = snap.data();
          final credits = (data?['wallet_credits'] as num?)?.toInt();
          final status = (data?['status'] as String?)?.toLowerCase();
          final subStatus = (data?['subscription_status'] as String?)?.toLowerCase();
          final incoming = data?['incoming_call'];
          Map<String, dynamic>? incomingMap;
          if (incoming is Map) incomingMap = Map<String, dynamic>.from(incoming as Map);
          final incomingActive = _isIncomingActive(incomingMap, data);
          setState(() {
            if (credits != null) _walletCredits = credits;
            if (status != null) _orgStatus = status;
            if (subStatus != null) _subscriptionStatus = subStatus;
            _incomingCall = incomingActive ? incomingMap : null;
          });
        },
        onError: (error) {
          // On permission-denied, cancel so we don't keep logging; wallet stays from API.
          _walletSubscription?.cancel();
          _walletSubscription = null;
          debugPrint('Wallet subscription error: $error');
        },
      );
    }
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _livePulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWalletCredits() async {
    try {
      final w = await NeyvoPulseApi.getBillingWallet();
      if (mounted) {
        final credits = (w['credits'] as num?)?.toInt();
        final shield = w['addon_shield_numbers'] as List? ?? [];
        final hipaa = w['addon_hipaa'] == true;
        setState(() {
          _walletCredits = credits;
          _addonsCount = shield.length + (hipaa ? 1 : 0);
          _subscriptionStatus =
              (w['subscription_status'] as String?)?.toLowerCase();
          _subscriptionTier =
              (w['subscription_tier'] as String?)?.toLowerCase();
          _orgStatus = (w['status'] as String?)?.toLowerCase();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAccountInfo() async {
    try {
      final res = await NeyvoPulseApi.getAccountInfo();
      if (res['ok'] == true && res['account_id'] != null) {
        final accountId = res['account_id']?.toString() ?? '';
        NeyvoPulseApi.setDefaultAccountId(accountId);
      }
      final col = res['org_collection'] as String?;
      if (col != null && col.trim().isNotEmpty) _orgCollection = col.trim();
      final orgDocId = (res['org_doc_id'] ?? res['business_doc_id'])?.toString().trim();
      if (orgDocId != null && orgDocId.isNotEmpty) _orgDocId = orgDocId;
      if (mounted && res['ok'] == true) {
        setState(() {
          _accountIdDisplay = res['account_id']?.toString();
          _accountName = (res['account_name'] as String?)?.trim();
          if (_accountName != null && _accountName!.isEmpty) _accountName = null;
          _voiceStudioEnabled = (res['studio_enabled'] == true);
          _agencyMode = (res['agency_mode'] == true) || (res['is_agency'] == true);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUsageSummary() async {
    try {
      final now = DateTime.now();
      final from = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final to = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final u = await NeyvoPulseApi.getBillingUsage(from: from, to: to);
      if (mounted) setState(() => _usageSpend = (u['total_dollars_spent'] as num?)?.toDouble());
    } catch (_) {}
  }

  Future<void> _loadNumbersSummary() async {
    try {
      final res = await NeyvoPulseApi.listNumbers();
      if (mounted) {
        setState(() {
          _numbersCount = (res['total_numbers'] as num?)?.toInt();
          _callsTodayCapacity = (res['total_daily_capacity'] as num?)?.toInt();
          final numbers = res['numbers'] as List? ?? [];
          int used = 0;
          for (final n in numbers) {
            used += (n['calls_today'] as num?)?.toInt() ?? 0;
          }
          _callsTodayUsed = used;
        });
      }
    } catch (_) {}
  }

  /// Determine if this org has at least one completed call; used to decide when
  /// the system is considered "live" and whether Launch should remain visible.
  Future<void> _loadFirstCallStatus() async {
    try {
      final res = await NeyvoPulseApi.listCalls();
      final calls = (res['calls'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final hasCompleted = calls.any((c) {
        final status = (c['status'] as String?)?.toLowerCase();
        if (status == 'completed' || status == 'success') return true;
        final endedAt = c['ended_at'];
        return endedAt != null && status != 'failed';
      });
      if (mounted) {
        setState(() {
          _hasFirstCompletedCall = hasCompleted;
        });
      }
    } catch (_) {
      // Non-fatal; defaults to false until we can confirm a call.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) debugPrint('PulseShell building (index: $_selectedIndex)');

    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: Row(
        children: [
          // Sidebar — 220px, NeyvoColors per spec
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: NeyvoColors.sidebarBg,
              border: Border(right: BorderSide(color: NeyvoColors.borderSubtle, width: 1)),
            ),
            child: Column(
              children: [
                // Logo area — height 52px (match top bar)
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        'assets/ub_logo/ub_logo_horizontal_white.png',
                        fit: BoxFit.contain,
                        height: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: _navItems.length,
                    itemBuilder: (context, i) {
                      final item = _navItems[i];
                      final selected = _selectedIndex == i;
                      return _SidebarNavItem(
                        icon: item.icon,
                        label: item.label,
                        isActive: selected,
                        onTap: () {
                          setState(() => _selectedIndex = i);
                          if (item.label == 'Billing') _loadWalletCredits();
                          if (item.label == 'Numbers') _loadNumbersSummary();
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: NeyvoColors.borderSubtle),
                // Credits at bottom (label size, teal)
                if (_walletCredits != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      '${_walletCredits!.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} cr',
                      style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal, fontSize: 12),
                    ),
                  ),
                if (_accountName != null && _accountName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Text(
                      _accountName!,
                      style: NeyvoTextStyles.micro,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (_subscriptionTier != null && _subscriptionTier!.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: NeyvoColors.teal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: NeyvoColors.teal.withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _subscriptionTier == 'business'
                              ? 'Business'
                              : _subscriptionTier == 'pro'
                                  ? 'Pro'
                                  : 'Free',
                          style: NeyvoTextStyles.micro.copyWith(
                            color: NeyvoColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Account ID shown in Settings → Organization only (not raw org doc id in sidebar)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.logout, size: 18, color: NeyvoColors.textMuted),
                  title: Text('Sign out', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                  onTap: () async => await FirebaseAuth.instance.signOut(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_orgStatus == 'suspended')
                  Material(
                    color: NeyvoColors.error.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.block, color: NeyvoColors.error, size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Account suspended. Contact support.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error))),
                        ],
                      ),
                    ),
                  ),
                if (_subscriptionStatus == 'past_due')
                  Material(
                    color: NeyvoColors.warning.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.payment, color: NeyvoColors.warning, size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Subscription past due. Update payment to avoid service interruption.', style: NeyvoTextStyles.bodyPrimary)),
                          TextButton(
                            onPressed: () => _navigateToRoute(PulseRouteNames.billing),
                            child: const Text('Update billing'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_walletCredits != null && _walletCredits! < 500 && _walletCredits! >= 0)
                  Material(
                    color: (_walletCredits! < 200 ? NeyvoColors.error : NeyvoColors.warning).withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: _walletCredits! < 200 ? NeyvoColors.error : NeyvoColors.warning, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Low credits — $_walletCredits remaining. Top up to keep calling.',
                              style: NeyvoTextStyles.bodyPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _navigateToRoute(PulseRouteNames.billing),
                            child: const Text('Top up'),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Top bar: 52px, bgBase, borderSubtle. Title left; credits pill + avatar right
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: NeyvoColors.bgBase,
                    border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedIndex < _navItems.length ? _navItems[_selectedIndex].label : 'Home',
                          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
                        ),
                      ),
                      // Live status dot (animated)
                      AnimatedBuilder(
                        animation: _livePulse,
                        builder: (context, _) {
                          final live = _hasFirstCompletedCall;
                          final color = live ? NeyvoColors.success : NeyvoColors.warning;
                          return Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(live ? _livePulse.value : 0.45),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.35),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (_walletCredits != null)
                          Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final items = _navItems;
                              var idx = items.indexWhere((n) => n.route == PulseRouteNames.billing);
                              if (idx < 0) idx = items.indexWhere((n) => n.route == PulseRouteNames.settings);
                              if (idx >= 0) setState(() => _selectedIndex = idx);
                            },
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _walletCredits! < 500
                                    ? NeyvoColors.error.withOpacity(0.1)
                                    : NeyvoColors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: _walletCredits! < 500
                                      ? NeyvoColors.error.withOpacity(0.2)
                                      : NeyvoColors.teal.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                '${_walletCredits!.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} credits',
                                style: NeyvoTextStyles.label.copyWith(
                                  color: _walletCredits! < 500 ? NeyvoColors.error : NeyvoColors.teal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      PopupMenuButton<String>(
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        color: NeyvoColors.bgRaised,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: NeyvoColors.teal.withOpacity(0.15),
                                border: Border.all(color: NeyvoColors.teal.withOpacity(0.2)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (_accountName?.isNotEmpty == true ? _accountName!.substring(0, 1) : '?').toUpperCase(),
                                style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down, color: NeyvoColors.textSecondary),
                          ],
                        ),
                        itemBuilder: (context) => [
                          if (_accountName != null && _accountName!.isNotEmpty)
                            PopupMenuItem(
                              enabled: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_accountName!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary)),
                                  if (_accountIdDisplay != null && _accountIdDisplay!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Account ID: $_accountIdDisplay',
                                        style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const PopupMenuItem(value: 'switch_org', child: Row(children: [Icon(Icons.swap_horiz, size: 20), SizedBox(width: 12), Text('Switch org')])),
                          const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, size: 20), SizedBox(width: 12), Text('Settings')])),
                          const PopupMenuItem(value: 'signout', child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 12), Text('Sign out')])),
                        ],
                        onSelected: (value) {
                          if (value == 'switch_org') {
                            _showOrgSwitchDialog();
                          } else if (value == 'settings') {
                            final items = _navItems;
                            final idx = items.indexWhere((n) => n.label == 'Settings');
                            if (idx >= 0) setState(() => _selectedIndex = idx);
                          } else if (value == 'signout') {
                            FirebaseAuth.instance.signOut();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                              children: [
                                _buildCurrentPage(),
                                if (_incomingCall != null)
                                  IncomingCallOverlay(
                                    agentName: (_incomingCall?['agent_name'] ?? _incomingCall?['agent'] ?? '').toString(),
                                    fromNumber: (_incomingCall?['from'] ?? _incomingCall?['caller'] ?? '').toString(),
                                    onDismiss: () => setState(() => _incomingCall = null),
                                    onViewLive: () {
                                      setState(() => _incomingCall = null);
                                      _navigateToRoute(PulseRouteNames.voiceStudio);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on _PulseShellState {
  bool _isIncomingActive(Map<String, dynamic>? incoming, Map<String, dynamic>? data) {
    final activeFlag = data?['incoming_call_active'] == true;
    final active = incoming?['active'] == true || activeFlag;
    final state = (incoming?['state'] ?? incoming?['status'] ?? '').toString().toLowerCase();
    return active || state == 'ringing' || state == 'inbound' || state == 'answering';
  }

  void _navigateToRoute(String route) {
    final items = _navItems;
    final idx = items.indexWhere((n) => n.route == route);
    if (idx >= 0) setState(() => _selectedIndex = idx);
  }

  Future<void> _showOrgSwitchDialog() async {
    final controller = TextEditingController();
    bool working = false;
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) => AlertDialog(
            backgroundColor: NeyvoColors.bgBase,
            title: const Text('Switch org'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enter an Account ID to switch organizations.', style: NeyvoTextStyles.body),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Account ID',
                      hintText: 'e.g. 12345678',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: working ? null : () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: working
                    ? null
                    : () async {
                        final id = controller.text.trim();
                        if (id.isEmpty) {
                          setInner(() => err = 'Enter an account id.');
                          return;
                        }
                        setInner(() {
                          working = true;
                          err = null;
                        });
                        try {
                          await NeyvoPulseApi.linkUserToAccount(id);
                          NeyvoPulseApi.setDefaultAccountId(id);
                          if (!mounted) return;
                          await _resolveAccountThenLoad();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (e) {
                          setInner(() {
                            working = false;
                            err = e.toString();
                          });
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                child: working
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Switch'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  /// Map the currently selected nav route to the active page widget.
  Widget _buildCurrentPage() {
    final items = _navItems;
    if (_selectedIndex < 0 || _selectedIndex >= items.length) {
      return const PulseDashboardPage();
    }
    final route = items[_selectedIndex].route;
    switch (route) {
      case PulseRouteNames.dashboard:
        return const PulseDashboardPage();
      case PulseRouteNames.launch:
        // Launch wizard page (implemented as separate screen/route).
        return const LaunchPage();
      case PulseRouteNames.agents:
        return _buildManagedProfilesContent();
      case PulseRouteNames.phoneNumbers:
        return const PhoneNumbersPage();
      case PulseRouteNames.calls:
        // Calls shell – default to call history for now; sub-nav handled inside.
        return CallsPage(initialSection: widget.initialCallsSection ?? CallsSection.inbound);
      case PulseRouteNames.students:
        return const StudentsHubPage();
      case PulseRouteNames.campaigns:
        return const CampaignsPage();
      case PulseRouteNames.team:
        return const TeamPage();
      case PulseRouteNames.testCall:
        return const TestCallPage();
      case PulseRouteNames.analytics:
        return const AnalyticsPage();
      case PulseRouteNames.integrations:
        return const IntegrationsPage();
      case PulseRouteNames.billing:
        return const BillingPage();
      case PulseRouteNames.settings:
        return const PulseSettingsPage();
      case PulseRouteNames.agency:
        return const AgencyOverviewPage();
      case PulseRouteNames.voiceStudio:
        return const VoiceStudioPage();
      default:
        return const PulseDashboardPage();
    }
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

/// Sidebar nav item: 36px height, 16px icon, 10px gap. Active = teal + left border.
class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isActive ? NeyvoColors.sidebarSelected : (_hover ? NeyvoColors.sidebarHover : Colors.transparent),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: isActive ? NeyvoColors.teal : (_hover ? NeyvoColors.textSecondary : NeyvoColors.textMuted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: NeyvoTextStyles.bodyPrimary.copyWith(
                        fontSize: 14,
                        color: isActive ? NeyvoColors.teal : (_hover ? NeyvoColors.textSecondary : NeyvoColors.textMuted),
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Positioned(
                left: 0,
                top: 0,
                bottom: 2,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    color: NeyvoColors.teal,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

