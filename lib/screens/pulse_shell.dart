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
import 'wallet_page.dart';
import 'agents_list_page.dart';
import 'projects_list_page.dart';
import 'voice_library_page.dart';
import 'exports_page.dart';
import 'call_history_page.dart';
import 'analytics_page.dart';
import 'students_list_page.dart';
import 'template_scripts_page.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

class PulseShell extends StatefulWidget {
  const PulseShell({super.key, this.initialRouteName});

  final String? initialRouteName;

  @override
  State<PulseShell> createState() => _PulseShellState();
}

class _PulseShellState extends State<PulseShell> {
  int _selectedIndex = 0;
  int? _walletCredits;
  int? _numbersCount;
  int? _callsTodayCapacity;
  int? _callsTodayUsed;
  double? _usageSpend;
  int _addonsCount = 0;
  String? _subscriptionStatus;
  String? _orgStatus;
  String? _accountName;
  String? _accountIdDisplay;
  String _orgCollection = '';
  String? _orgDocId; // Firestore document ID for real-time listener (backend returns this; we only show short account_id in UI)
  List<String> _surfacesEnabled = [];
  String _activeSurface = 'comms';
  StreamSubscription<DocumentSnapshot>? _walletSubscription;

  // Comms nav — main workspace items. Exposed explicitly so users can jump directly.
  static List<_NavItem> get _navComms => [
    const _NavItem('Home', Icons.home_outlined, PulseRouteNames.dashboard),
    const _NavItem('Agents', Icons.smart_toy_outlined, PulseRouteNames.agents),
    const _NavItem('Contacts', Icons.people_outline, PulseRouteNames.students),
    const _NavItem('Calls', Icons.call_outlined, PulseRouteNames.callHistory),
    const _NavItem('Campaigns', Icons.campaign_outlined, PulseRouteNames.campaigns),
    const _NavItem('Templates', Icons.description_outlined, PulseRouteNames.templateScripts),
    const _NavItem('Analytics', Icons.analytics_outlined, PulseRouteNames.analytics),
    const _NavItem('Numbers', Icons.phone_outlined, PulseRouteNames.phoneNumbers),
    const _NavItem('Billing', Icons.account_balance_wallet_outlined, PulseRouteNames.wallet),
    const _NavItem('Settings', Icons.settings_outlined, PulseRouteNames.settings),
  ];

  // Studio nav — 7 items when org has studio surface
  static List<_NavItem> get _navStudio => [
    const _NavItem('Home', Icons.home_outlined, PulseRouteNames.dashboard),
    const _NavItem('Studio', Icons.folder_outlined, PulseRouteNames.projects),
    const _NavItem('Voice Library', Icons.record_voice_over_outlined, PulseRouteNames.voiceLibrary),
    const _NavItem('Exports', Icons.download_outlined, PulseRouteNames.exports),
    const _NavItem('Analytics', Icons.analytics_outlined, PulseRouteNames.analytics),
    const _NavItem('Wallet', Icons.account_balance_wallet_outlined, PulseRouteNames.wallet),
    const _NavItem('Settings', Icons.settings_outlined, PulseRouteNames.settings),
  ];

  List<_NavItem> get _currentNav => _activeSurface == 'studio' ? _navStudio : _navComms;

  List<Widget> get _pagesComms => [
    const PulseDashboardPage(),     // Home
    const AgentsListPage(),        // Agents
    const StudentsListPage(),      // Contacts
    const CallHistoryPage(),       // Calls
    const CampaignsPage(),         // Campaigns
    const TemplateScriptsPage(),   // Templates (scripts)
    const AnalyticsPage(),         // Analytics
    const PhoneNumbersPage(),      // Numbers
    const WalletPage(),            // Billing (Wallet summary)
    const PulseSettingsPage(),     // Settings
  ];

  List<Widget> get _pagesStudio => [
    const PulseDashboardPage(),
    const ProjectsListPage(),
    const VoiceLibraryPage(),
    const ExportsPage(),
    const AnalyticsPage(),
    const WalletPage(),
    const PulseSettingsPage(),
  ];

  List<Widget> get _currentPages => _activeSurface == 'studio' ? _pagesStudio : _pagesComms;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) debugPrint('PulseShell initialized');
    _resolveAccountThenLoad();
    final name = widget.initialRouteName;
    if (name != null && name.isNotEmpty) {
      final idx = _currentNav.indexWhere((n) => n.route == name);
      if (idx >= 0) _selectedIndex = idx;
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
    final docId = _orgDocId ?? NeyvoPulseApi.defaultAccountId;
    if (docId.isNotEmpty && _orgCollection.isNotEmpty) {
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
          setState(() {
            if (credits != null) _walletCredits = credits;
            if (status != null) _orgStatus = status;
            if (subStatus != null) _subscriptionStatus = subStatus;
          });
        },
        onError: (error) {
          // Gracefully handle Firestore permission errors so the UI doesn't crash.
          debugPrint('Wallet subscription error: $error');
        },
      );
    }
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
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
          _subscriptionStatus = (w['subscription_status'] as String?)?.toLowerCase();
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
        final raw = res['surfaces_enabled'];
        final surfaces = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
        final active = (res['active_surface'] as String?)?.trim().toLowerCase();
        setState(() {
          _accountIdDisplay = res['account_id']?.toString();
          _accountName = (res['account_name'] as String?)?.trim();
          if (_accountName != null && _accountName!.isEmpty) _accountName = null;
          _surfacesEnabled = surfaces;
          if (active == 'studio' || active == 'comms') _activeSurface = active!;
          final name = widget.initialRouteName;
          if (name != null && name.isNotEmpty) {
            const studioRoutes = [PulseRouteNames.projects, PulseRouteNames.voiceLibrary, PulseRouteNames.exports];
            if (studioRoutes.contains(name)) _activeSurface = 'studio';
            final nav = _activeSurface == 'studio' ? _navStudio : _navComms;
            final idx = nav.indexWhere((n) => n.route == name);
            if (idx >= 0) _selectedIndex = idx;
          }
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
                    child: Row(
                      children: [
                        Text(
                          'Neyvo',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: NeyvoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: NeyvoColors.teal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: NeyvoColors.teal.withOpacity(0.2)),
                          ),
                          child: Text(
                            'BETA',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: NeyvoColors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_surfacesEnabled.length > 1) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            style: ButtonStyle(
                              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) return NeyvoColors.sidebarSelected;
                                return Colors.transparent;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) return NeyvoColors.textPrimary;
                                return NeyvoColors.textSecondary;
                              }),
                              textStyle: WidgetStateProperty.all(
                                NeyvoTextStyles.label.copyWith(fontSize: 11),
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 'comms',
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Comms', softWrap: false),
                                ),
                                icon: Icon(Icons.phone_in_talk_outlined, size: 18),
                              ),
                              ButtonSegment(
                                value: 'studio',
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Studio', softWrap: false),
                                ),
                                icon: Icon(Icons.mic_outlined, size: 18),
                              ),
                            ],
                            selected: {_activeSurface},
                            onSelectionChanged: (Set<String> v) async {
                              final s = v.first;
                              if (s == _activeSurface) return;
                              try {
                                await NeyvoPulseApi.updateAccountInfo({'active_surface': s});
                                if (mounted) setState(() { _activeSurface = s; _selectedIndex = 0; });
                              } catch (_) {}
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: _currentNav.length,
                    itemBuilder: (context, i) {
                      final item = _currentNav[i];
                      final selected = _selectedIndex == i;
                      return _SidebarNavItem(
                        icon: item.icon,
                        label: item.label,
                        isActive: selected,
                        onTap: () {
                          setState(() => _selectedIndex = i);
                          if (item.label == 'Wallet') _loadWalletCredits();
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
                          TextButton(onPressed: () => setState(() { final idx = _currentNav.indexWhere((n) => n.label == 'Settings'); if (idx >= 0) _selectedIndex = idx; }), child: const Text('Update payment')),
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
                            onPressed: () => setState(() { final idx = _currentNav.indexWhere((n) => n.label == 'Wallet'); if (idx >= 0) _selectedIndex = idx; }),
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
                          _selectedIndex < _currentNav.length ? _currentNav[_selectedIndex].label : 'Home',
                          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
                        ),
                      ),
                      if (_walletCredits != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final idx = _currentNav.indexWhere((n) => n.route == PulseRouteNames.wallet);
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
                          const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, size: 20), SizedBox(width: 12), Text('Settings')])),
                          const PopupMenuItem(value: 'signout', child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 12), Text('Sign out')])),
                        ],
                        onSelected: (value) {
                          if (value == 'settings') {
                            final idx = _currentNav.indexWhere((n) => n.label == 'Settings');
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
                  child: _selectedIndex < _currentPages.length
                      ? _currentPages[_selectedIndex]
                      : const PulseDashboardPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

