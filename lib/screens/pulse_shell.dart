// lib/screens/pulse_shell.dart
// Neyvo Pulse – main shell with persistent sidebar (always visible).
// Listens to Firestore org doc for real-time wallet_credits updates.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pulse_route_names.dart';
import 'pulse_dashboard_page.dart';
import 'settings_page.dart';
import 'campaigns_page.dart';
import 'phone_numbers_page.dart';
import 'call_history_page.dart';
import 'analytics_page.dart';
import 'executive_dashboard_page.dart';
import 'callbacks_page.dart';
import '../features/managed_profiles/managed_profiles_page.dart';
import '../features/managed_profiles/raw_assistant_detail_page.dart';
import '../features/managed_profiles/profile_detail_page.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../api/spearia_api.dart';
import '../neyvo_pulse_api.dart';
import '../debug_session_log.dart';
import '../theme/neyvo_theme.dart';
import '../tenant/tenant_scope.dart';
import '../tenant/tenant_brand.dart';
import '../utils/update_url_stub.dart' if (dart.library.html) '../utils/update_url_web.dart' as url_helper;
import '../ui/screens/launch/launch_page.dart';
import '../ui/screens/calls/calls_page.dart';
import '../ui/screens/calls/test_call_page.dart';
import '../ui/screens/billing/billing_page.dart';
import '../ui/screens/billing/wallet_page.dart';
import '../ui/screens/billing/voice_tier_page.dart';
import '../ui/screens/billing/plan_selector_page.dart';
import '../ui/screens/integrations/integrations_page.dart';
import '../ui/screens/voice_studio/voice_studio_page.dart';
import '../ui/components/calls/incoming_call_overlay.dart';
import '../ui/screens/agency/agency_overview_page.dart';
import 'students_hub_page.dart';
import 'team_page.dart';
import 'training_page.dart';
import 'audit_log_page.dart';
import 'health_check_page.dart';

/// Allows navigating to a pulse tab without pushing a new PulseShell (avoids full re-init and slow load).
/// When [navigatePulse] is used, the app pops to the root shell and switches its tab instead of pushing a second shell.
class PulseShellController {
  PulseShellController._();

  static _PulseShellState? _root;

  /// Navigate to a pulse tab by switching the root shell's tab. Pops to root first so only one shell stays on the stack.
  static void navigatePulse(BuildContext context, String routeName) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((route) => route.isFirst);
    String tabRoute = routeName;
    if (tabRoute == PulseRouteNames.dialer || tabRoute == PulseRouteNames.outbound) tabRoute = PulseRouteNames.calls;
    _root?.navigateToTab(tabRoute);
  }
}

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
  /// When true, content is driven by _selectedIndex only (user tapped a sidebar tab). When false and initialRoute was wallet, we show Wallet page while Billing is selected.
  bool _userHasChangedTab = false;
  int? _walletCredits;
  final GlobalKey<NavigatorState> _managedProfilesNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<ManagedProfilesPageState> _managedProfilesListKey = GlobalKey<ManagedProfilesPageState>();
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
  /// Listens to wallet/{account_id} for real-time wallet_credits (backend writes here after Stripe).
  StreamSubscription<DocumentSnapshot>? _walletCreditsSubscription;
  late final AnimationController _livePulseCtrl;
  late final Animation<double> _livePulse;
  String? _myRole;
  List<String>? _myPermissions;

  /// Permission key per nav item; used to filter sidebar for staff. Admin sees all.
  static const List<_NavItem> _allNavItems = [
    _NavItem('Home', Icons.home_outlined, PulseRouteNames.dashboard, 'dashboard'),
    _NavItem('Operators', Icons.smart_toy_outlined, PulseRouteNames.agents, 'operators'),
    _NavItem('Lines', Icons.phone_outlined, PulseRouteNames.phoneNumbers, 'operators'),
    _NavItem('Students', Icons.school_outlined, PulseRouteNames.students, 'students'),
    _NavItem('Call Logs', Icons.call_outlined, PulseRouteNames.calls, 'call_logs'),
    _NavItem('Campaigns', Icons.campaign_outlined, PulseRouteNames.campaigns, 'campaigns'),
    _NavItem('Team', Icons.groups_outlined, PulseRouteNames.team, 'team'),
    _NavItem('Audit Log', Icons.history_outlined, PulseRouteNames.auditLog, 'audit_log'),
    _NavItem('Insights', Icons.auto_graph_outlined, PulseRouteNames.analytics, 'insights'),
    _NavItem('Executive Dashboard', Icons.dashboard_outlined, PulseRouteNames.executiveDashboard, 'insights'),
    _NavItem('Training', Icons.quiz_outlined, PulseRouteNames.training, 'settings'), // temporary: FAQ + policy
    _NavItem('Health', Icons.monitor_heart_outlined, PulseRouteNames.health, 'settings'),
    _NavItem('Billing', Icons.account_balance_wallet_outlined, PulseRouteNames.billing, 'billing'),
    _NavItem('Settings', Icons.settings_outlined, PulseRouteNames.settings, 'settings'),
  ];

  /// Unified Voice OS navigation. For admin: all items. For staff: only items whose permission is in _myPermissions.
  /// Audit Log is admin-only (hidden from non-admin).
  /// If staff has no permissions (empty list), show all tabs except Audit Log so the user is not locked out.
  List<_NavItem> get _navItems {
    final role = _myRole?.toLowerCase();
    final perms = _myPermissions;
    final isAdmin = role == 'admin';
    List<_NavItem> items;
    if (isAdmin || perms == null) {
      items = List<_NavItem>.from(_allNavItems);
      if (!isAdmin) items.removeWhere((n) => n.permissionKey == 'audit_log');
    } else {
      final filtered = _allNavItems.where((n) => n.permissionKey != 'audit_log' && perms.contains(n.permissionKey)).toList();
      items = filtered.isEmpty ? _allNavItems.where((n) => n.permissionKey != 'audit_log').toList() : filtered;
    }
    if (_selectedIndex >= items.length) _selectedIndex = 0;
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
            builder: (_) => _ProfileDetailRouter(profileId: profileId),
          );
        }
        // '/' = list
        return MaterialPageRoute<void>(
          builder: (_) => ManagedProfilesPage(
            key: _managedProfilesListKey,
            onOpenProfileDetail: (String profileId) async {
              final result = await _managedProfilesNavKey.currentState?.pushNamed<dynamic>(
                _managedProfileDetailRoute,
                arguments: profileId,
              );
              if (result == true && mounted) {
                _managedProfilesListKey.currentState?.refresh();
              }
            },
          ),
        );
      },
    );
  }
  @override
  void initState() {
    super.initState();
    if (PulseShellController._root == null) PulseShellController._root = this;
    // #region agent log
    debugSessionLog('pulse_shell.dart:initState', 'PulseShell initState', {'initialRouteName': widget.initialRouteName}, 'A');
    // #endregion
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
      int idx = items.indexWhere((n) => n.route == name);
      // Wallet is not in sidebar; it lives under Billing. Direct /pulse/wallet (e.g. View transactions) shows Wallet page with Billing tab selected in sidebar.
      if (idx < 0 && name == PulseRouteNames.wallet) {
        idx = items.indexWhere((n) => n.route == PulseRouteNames.billing);
      }
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
    // #region agent log
    final resolveStart = DateTime.now().millisecondsSinceEpoch;
    debugSessionLog('pulse_shell.dart:_resolveAccountThenLoad', 'resolveAccountThenLoad start', {'initialRoute': widget.initialRouteName}, 'B');
    // #endregion
    await _loadAccountInfo();
    if (!mounted) return;
    await _loadMyRoleAndPermissions();
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
          // Real-time org updates require Firestore read access to the org doc; wallet data still comes from API.
          debugPrint('Real-time wallet updates unavailable (using API data).');
        },
      );
    }
    // Real-time credits: backend uses unified path businesses/{id}/wallet/summary (billing writes there).
    final accountId = NeyvoPulseApi.defaultAccountId.trim().isNotEmpty ? NeyvoPulseApi.defaultAccountId : _accountIdDisplay?.trim();
    if ((accountId ?? '').isNotEmpty && user != null) {
      _walletCreditsSubscription = FirebaseFirestore.instance
          .collection('businesses')
          .doc(accountId)
          .collection('wallet')
          .doc('summary')
          .snapshots()
          .listen(
        (snap) {
          if (!mounted) return;
          final data = snap.data();
          final credits = (data?['wallet_credits'] as num?)?.toInt();
          if (credits != null) setState(() => _walletCredits = credits);
        },
        onError: (error) {
          _walletCreditsSubscription?.cancel();
          _walletCreditsSubscription = null;
          debugPrint('Real-time wallet credits listener unavailable (using API data).');
        },
      );
    }
    // #region agent log
    final resolveEnd = DateTime.now().millisecondsSinceEpoch;
    debugSessionLog('pulse_shell.dart:_resolveAccountThenLoad', 'resolveAccountThenLoad end', {'durationMs': resolveEnd - resolveStart, 'initialRoute': widget.initialRouteName}, 'B');
    // #endregion
  }

  @override
  void dispose() {
    if (PulseShellController._root == this) PulseShellController._root = null;
    _walletSubscription?.cancel();
    _walletCreditsSubscription?.cancel();
    _livePulseCtrl.dispose();
    super.dispose();
  }

  /// Switch this shell's selected tab to [routeName]. Used by [PulseShellController.navigatePulse] to avoid pushing a new shell.
  void navigateToTab(String routeName) {
    _navigateToRoute(routeName);
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

  Future<void> _loadMyRoleAndPermissions() async {
    try {
      final res = await NeyvoPulseApi.getMyRole();
      if (!mounted) return;
      if (res['ok'] == true) {
        final role = res['role']?.toString();
        final perms = res['permissions'];
        setState(() {
          _myRole = role;
          _myPermissions = perms is List ? (perms as List).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList() : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    SpeariaApi.setSessionToken(null);
    SpeariaApi.setUserId(null);
    NeyvoPulseApi.setDefaultAccountId(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('neyvo_pulse_onboarding_completed');
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
    // #region agent log
    debugSessionLog('pulse_shell.dart:build', 'PulseShell build', {'selectedIndex': _selectedIndex, 'initialRouteName': widget.initialRouteName}, 'A');
    // #endregion
    if (kIsWeb) debugPrint('PulseShell building (index: $_selectedIndex)');

    final tenant = TenantScope.of(context)?.config;
    final isGoodwin = tenant?.tenantId == 'goodwin';
    final Color sidebarBgColor = isGoodwin && tenant?.primaryColor != null
        ? tenant!.primaryColor!
        : NeyvoColors.sidebarBg;
    final Color sidebarAccentColor = isGoodwin && tenant?.secondaryColor != null
        ? tenant!.secondaryColor!
        : NeyvoColors.ubLightBlue;
    final Color sidebarSelectedColor = isGoodwin
        ? sidebarBgColor.withOpacity(0.85)
        : NeyvoColors.sidebarSelected;
    final Color sidebarHoverColor = isGoodwin
        ? sidebarBgColor.withOpacity(0.5)
        : NeyvoColors.sidebarHover;

    final brandPrimary = TenantBrand.primary(context);
    final brandSecondary = TenantBrand.secondary(context);

    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: Row(
              children: [
              // Sidebar — 220px, NeyvoColors per spec
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: sidebarBgColor,
              border: const Border(right: BorderSide(color: NeyvoColors.borderSubtle, width: 1)),
            ),
            child: Column(
              children: [
                // Logo area — tenant horizontal logo (white preferred), UB fallback
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sidebarBgColor,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Builder(
                      builder: (context) {
                        
                        final scope = TenantScope.of(context);
                        final tenant = scope?.config;
                        final tenantId = (tenant?.tenantId ?? '').toLowerCase();
                        final isGoodwin = tenantId == 'goodwin';
                        final isUb = tenantId == 'ub' || tenant == null;
                        if (isGoodwin) {
                          return Image.asset(
                            'assets/goodwin_logo/goodwin_horiz_white.png',
                            fit: BoxFit.contain,
                            height: 46,
                          );
                        }
                        if (isUb) {
                          return SvgPicture.asset(
                            'assets/ub_logo/ub_logo_horizontal_white.svg',
                            fit: BoxFit.contain,
                            height: 46,
                            colorFilter: const ColorFilter.mode(
                              NeyvoColors.white,
                              BlendMode.srcIn,
                            ),
                          );
                        }
                        final logoUrl = tenant?.logoHorizontalWhiteUrl ?? tenant?.logoHorizontalColorUrl;
                        if (logoUrl != null && logoUrl.isNotEmpty) {
                          final lower = logoUrl.toLowerCase();
                          if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
                            return Image.network(
                              logoUrl,
                              fit: BoxFit.contain,
                              height: 46,
                              errorBuilder: (context, _, __) {
                                final t = TenantScope.of(context)?.config;
                                final isUb = t == null || t.tenantId == 'ub';
                                if (isUb) {
                                  return SvgPicture.asset(
                                    'assets/ub_logo/ub_logo_horizontal_white.svg',
                                    fit: BoxFit.contain,
                                    height: 46,
                                    colorFilter: const ColorFilter.mode(
                                      NeyvoColors.white,
                                      BlendMode.srcIn,
                                    ),
                                  );
                                }
                                return Text(
                                  (t?.schoolName ?? 'Neyvo').trim().isEmpty ? 'Neyvo' : (t?.schoolName ?? 'Neyvo'),
                                  style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            );
                          } else {
                            return SvgPicture.network(
                              logoUrl,
                              fit: BoxFit.contain,
                              height: 46,
                              placeholderBuilder: (_) => const SizedBox(height: 46),
                            );
                          }
                        }
                        return SvgPicture.asset(
                          'assets/ub_logo/ub_logo_horizontal_white.svg',
                          fit: BoxFit.contain,
                          height: 46,
                          colorFilter: const ColorFilter.mode(
                            NeyvoColors.white,
                            BlendMode.srcIn,
                          ),
                        );
                      },
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
                        selectedBgColor: sidebarSelectedColor,
                        hoverBgColor: sidebarHoverColor,
                        accentColor: sidebarAccentColor,
                        onTap: () {
                          setState(() {
                            _selectedIndex = i;
                            _userHasChangedTab = true;
                          });
                          if (kIsWeb) url_helper.updateBrowserUrl(item.route);
                          if (item.label == 'Billing') _loadWalletCredits();
                          if (item.label == 'Lines') _loadNumbersSummary();
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: NeyvoColors.borderSubtle),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Account ID: ${_accountIdDisplay ?? '—'}',
                        style: NeyvoTextStyles.micro.copyWith(
                          color: NeyvoColors.white.withOpacity(0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FirebaseAuth.instance.currentUser?.email ?? '—',
                        style: NeyvoTextStyles.micro.copyWith(
                          color: NeyvoColors.white.withOpacity(0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.logout,
                    size: 18,
                    color: NeyvoColors.white.withOpacity(0.8),
                  ),
                  title: Text(
                    'Sign out',
                    style: NeyvoTextStyles.label.copyWith(
                      color: NeyvoColors.white.withOpacity(0.9),
                    ),
                  ),
                  onTap: () async => await _signOut(),
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
                // Low-credits banner disabled: min credits = 0 (only show if credits < 0, which never happens)
                if (_walletCredits != null && _walletCredits! < 0)
                  Material(
                    color: NeyvoColors.warning.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: NeyvoColors.warning, size: 22),
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
                // Top bar: 52px, bgBase, borderSubtle. Credits pill + avatar right (section title is on each page)
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: NeyvoColors.bgBase,
                    border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle)),
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
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
                              if (idx >= 0) {
                                setState(() { _selectedIndex = idx; _userHasChangedTab = true; });
                                if (kIsWeb) url_helper.updateBrowserUrl(items[idx].route);
                              }
                            },
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _walletCredits! < 0
                                    ? NeyvoColors.error.withOpacity(0.1)
                                    : brandPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: _walletCredits! < 0
                                      ? NeyvoColors.error.withOpacity(0.2)
                                      : brandPrimary.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                '${_walletCredits!.toString().replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]},')} credits',
                                style: NeyvoTextStyles.label.copyWith(
                                  color: _walletCredits! < 0 ? NeyvoColors.error : brandPrimary,
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
                                color: brandPrimary.withOpacity(0.15),
                                border: Border.all(color: brandPrimary.withOpacity(0.2)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                ((FirebaseAuth.instance.currentUser?.email ?? '').isNotEmpty
                                    ? (FirebaseAuth.instance.currentUser!.email!.substring(0, 1))
                                    : '?').toUpperCase(),
                                style: NeyvoTextStyles.label.copyWith(color: brandPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down, color: NeyvoColors.textSecondary),
                          ],
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account ID: ${_accountIdDisplay ?? '—'}',
                                  style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    FirebaseAuth.instance.currentUser?.email ?? '—',
                                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, size: 20), SizedBox(width: 12), Text('Settings')])),
                          const PopupMenuItem(value: 'signout', child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 12), Text('Sign out')])),
                        ],
                        onSelected: (value) {
                          if (value == 'settings') {
                            final items = _navItems;
                            final idx = items.indexWhere((n) => n.label == 'Settings');
                            if (idx >= 0) {
                              setState(() { _selectedIndex = idx; _userHasChangedTab = true; });
                              if (kIsWeb) url_helper.updateBrowserUrl(items[idx].route);
                            }
                          } else if (value == 'signout') {
                            _signOut();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                              children: [
                                ClipRect(child: _buildCurrentPage()),
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
    if (idx >= 0) {
      setState(() { _selectedIndex = idx; _userHasChangedTab = true; });
      if (kIsWeb) url_helper.updateBrowserUrl(route);
    }
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
                style: FilledButton.styleFrom(backgroundColor: TenantBrand.secondary(ctx)),
                child: working
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white))
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
    // When opened via "View plans" / "View voice tiers" from Billing, show that page (not in sidebar).
    // When opened at /pulse/wallet we show Wallet page and Billing is selected; once user taps another tab, content follows _selectedIndex so other tabs work.
    final initialRoute = widget.initialRouteName;
    if (initialRoute == PulseRouteNames.voiceTier) return const VoiceTierPage();
    if (initialRoute == PulseRouteNames.subscriptionPlan) return const PlanSelectorPage();

    final items = _navItems;
    final route = _selectedIndex >= 0 && _selectedIndex < items.length ? items[_selectedIndex].route : null;
    final showingWalletBecauseInitial = initialRoute == PulseRouteNames.wallet && !_userHasChangedTab && route == PulseRouteNames.billing;
    if (showingWalletBecauseInitial) return const WalletPage();

    if (_selectedIndex < 0 || _selectedIndex >= items.length || route == null) {
      return const PulseDashboardPage();
    }
    switch (route) {
      case PulseRouteNames.dashboard:
        return const ExecutiveDashboardPage();
      case PulseRouteNames.launch:
        // Launch wizard page (implemented as separate screen/route).
        return const LaunchPage();
      case PulseRouteNames.agents:
        return _buildManagedProfilesContent();
      case PulseRouteNames.phoneNumbers:
        return const PhoneNumbersPage();
      case PulseRouteNames.calls:
        // Calls shell – default to call history for now; sub-nav handled inside.
        return CallsPage(initialSection: widget.initialCallsSection ?? CallsSection.calls);
      case PulseRouteNames.students:
        return const StudentsHubPage();
      case PulseRouteNames.campaigns:
        return const CampaignsPage();
      case PulseRouteNames.team:
        return const TeamPage();
      case PulseRouteNames.auditLog:
        return const AuditLogPage();
      case PulseRouteNames.testCall:
        return const TestCallPage();
      case PulseRouteNames.analytics:
        return const AnalyticsPage();
      case PulseRouteNames.executiveDashboard:
        return const ExecutiveDashboardPage();
      case PulseRouteNames.health:
        return const HealthCheckPage();
      case PulseRouteNames.integrations:
        return const IntegrationsPage();
      case PulseRouteNames.billing:
        return const BillingPage();
      case PulseRouteNames.wallet:
        return const WalletPage();
      case PulseRouteNames.voiceTier:
        return const VoiceTierPage();
      case PulseRouteNames.subscriptionPlan:
        return const PlanSelectorPage();
      case PulseRouteNames.settings:
        return const PulseSettingsPage();
      case PulseRouteNames.training:
        return const TrainingPage();
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
  final String permissionKey;
  const _NavItem(this.label, this.icon, this.route, this.permissionKey);
}

/// Sidebar nav item: 36px height, 16px icon, 10px gap. Active = teal + left border.
class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color selectedBgColor;
  final Color hoverBgColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.selectedBgColor,
    required this.hoverBgColor,
    required this.accentColor,
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
    final baseColor = NeyvoColors.white.withOpacity(0.7);
    final hoverColor = NeyvoColors.white.withOpacity(0.9);
    final activeTextColor = NeyvoColors.white;
    final activeIconColor = widget.accentColor;

    final Color iconColor;
    final Color textColor;

    if (isActive) {
      iconColor = activeIconColor;
      textColor = activeTextColor;
    } else if (_hover) {
      iconColor = hoverColor;
      textColor = hoverColor;
    } else {
      iconColor = baseColor;
      textColor = baseColor;
    }

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
                color: isActive ? widget.selectedBgColor : (_hover ? widget.hoverBgColor : Colors.transparent),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: iconColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: NeyvoTextStyles.bodyPrimary.copyWith(
                        fontSize: 14,
                        color: textColor,
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
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: const BorderRadius.only(
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

/// Decide whether to show the wizard-based or raw Vapi detail page for a profile.
class _ProfileDetailRouter extends StatelessWidget {
  const _ProfileDetailRouter({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ManagedProfileApiService.getProfile(profileId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text(
                'Failed to load operator.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error),
              ),
            ),
          );
        }
        final data = snapshot.data!;
        final isRaw = data['raw_vapi'] == true || data['schema_version'] == 3;
        if (isRaw) {
          return RawAssistantDetailPage(profileId: profileId, embedded: false);
        }
        return ManagedProfileDetailPage(profileId: profileId, embedded: false);
      },
    );
  }
}


