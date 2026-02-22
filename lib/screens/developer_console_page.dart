// lib/screens/developer_console_page.dart
// Developer Console – Revenue Control Center: Overview, Tier Configs, Organizations (with top-up),
// Subscription Override, Wallet Ops, Pricing, System Health (admin/developer only).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/spearia_api.dart';
import '../theme/spearia_theme.dart';

class DeveloperConsolePage extends StatefulWidget {
  const DeveloperConsolePage({super.key});

  @override
  State<DeveloperConsolePage> createState() => _DeveloperConsolePageState();
}

class _DeveloperConsolePageState extends State<DeveloperConsolePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _overview;
  List<dynamic>? _tierConfigs;
  Map<String, dynamic>? _numbersStats;
  List<dynamic>? _warmUpNumbers;
  Map<String, dynamic>? _dailyResetLog;
  Map<String, dynamic>? _systemHealth;
  List<dynamic>? _organizations;
  Map<String, dynamic>? _pricingConfig;
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  static const int _tabOverview = 0;
  static const int _tabOrgs = 1;
  static const int _tabSubOverride = 2;
  static const int _tabWalletOps = 3;
  static const int _tabTierConfigs = 4;
  static const int _tabPricing = 5;
  static const int _tabHealth = 6;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await SpeariaApi.getJsonMap('/api/admin/billing-overview', adminAuth: true);
      final configsRes = await SpeariaApi.getJsonMap('/api/admin/tier-configs', adminAuth: true);
      final configs = configsRes['tier_configs'] as List? ?? [];
      Map<String, dynamic>? numbersStats;
      List<dynamic>? warmUpNumbers;
      Map<String, dynamic>? dailyResetLog;
      try {
        numbersStats = await SpeariaApi.getJsonMap('/api/admin/numbers/stats', adminAuth: true);
        final warmRes = await SpeariaApi.getJsonMap('/api/admin/numbers/warm-up', adminAuth: true);
        warmUpNumbers = warmRes['numbers'] as List? ?? [];
        dailyResetLog = await SpeariaApi.getJsonMap('/api/admin/numbers/daily-reset', adminAuth: true);
      } catch (_) {}
      Map<String, dynamic>? systemHealth;
      try {
        systemHealth = await SpeariaApi.getJsonMap('/api/admin/system-health', adminAuth: true);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _overview = overview;
          _tierConfigs = configs;
          _numbersStats = numbersStats;
          _warmUpNumbers = warmUpNumbers;
          _dailyResetLog = dailyResetLog;
          _systemHealth = systemHealth;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() { if (_tabController.indexIsChanging) return; setState(() {}); });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrgs() async {
    try {
      final res = await SpeariaApi.getJsonMap('/api/admin/organizations', params: {'limit': 100}, adminAuth: true);
      if (mounted) setState(() => _organizations = res['organizations'] as List? ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _loadPricing() async {
    try {
      final res = await SpeariaApi.getJsonMap('/api/admin/pricing-config', adminAuth: true);
      if (mounted) setState(() => _pricingConfig = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _overview == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading…', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final orgs = (_overview?['total_organizations'] as num?)?.toInt() ?? 0;
    final callsToday = (_overview?['total_calls_today'] as num?)?.toInt() ?? 0;
    final revenueToday = (_overview?['total_revenue_today'] as num?)?.toDouble() ?? 0.0;
    final revenueMtd = (_overview?['total_revenue_mtd'] as num?)?.toDouble() ?? 0.0;
    final costToday = (_overview?['total_cost_today'] as num?)?.toDouble() ?? 0.0;
    final marginPct = (_overview?['platform_margin_pct'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: SpeariaAura.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Accounts'),
              Tab(text: 'Sub Override'),
              Tab(text: 'Wallet Ops'),
              Tab(text: 'Tier Configs'),
              Tab(text: 'Pricing'),
              Tab(text: 'Health'),
            ],
            onTap: (i) {
              if (i == _tabOrgs && _organizations == null) _loadOrgs();
              if (i == _tabPricing && _pricingConfig == null) _loadPricing();
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _tabController.index == _tabOverview ? _buildOverviewContent(orgs, callsToday, revenueToday, revenueMtd, costToday, marginPct)
                : _tabController.index == _tabOrgs ? _buildOrgsTab()
                : _tabController.index == _tabSubOverride ? _buildSubOverrideTab()
                : _tabController.index == _tabWalletOps ? _buildWalletOpsTab()
                : _tabController.index == _tabTierConfigs ? _buildTierConfigsTab()
                : _tabController.index == _tabPricing ? _buildPricingTab()
                : _tabController.index == _tabHealth ? _buildHealthTab()
                : _buildOverviewContent(orgs, callsToday, revenueToday, revenueMtd, costToday, marginPct),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewContent(int orgs, int callsToday, double revenueToday, double revenueMtd, double costToday, double marginPct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          Banner(
            message: 'Changes apply immediately to all new calls.',
            location: BannerLocation.topEnd,
            color: SpeariaAura.warning,
          ),
          const SizedBox(height: 16),
          Text('Revenue Control Center', style: SpeariaType.headlineMedium),
          const SizedBox(height: 8),
          Text('Platform overview', style: SpeariaType.titleLarge),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _stat('Organizations', '$orgs'),
                  _stat('Calls today', '$callsToday'),
                  _stat('Revenue today', '\$${revenueToday.toStringAsFixed(2)}'),
                  _stat('Revenue MTD', '\$${revenueMtd.toStringAsFixed(2)}'),
                  _stat('Cost today', '\$${costToday.toStringAsFixed(2)}'),
                  _stat('Platform margin %', '${marginPct.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Numbers (platform)', style: SpeariaType.titleLarge),
          const SizedBox(height: 8),
          if (_numbersStats != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _stat('Total numbers', '${_numbersStats!['total_numbers'] ?? 0}'),
                    _stat('In warm-up', '${_numbersStats!['numbers_in_warmup'] ?? 0}'),
                    _stat('Flagged', '${_numbersStats!['numbers_flagged'] ?? 0}'),
                    _stat('Total daily capacity', '${_numbersStats!['total_daily_capacity'] ?? 0}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('Warm-up management', style: SpeariaType.titleMedium),
          const SizedBox(height: 8),
          if (_warmUpNumbers != null && _warmUpNumbers!.isNotEmpty)
            ...(_warmUpNumbers as List).map<Widget>((n) {
              final numberId = n['number_id'] as String? ?? '';
              final phone = n['phone_number'] as String? ?? '';
              final org = n['org_id'] as String? ?? '';
              final week = n['warm_up_week'] as num? ?? 0;
              final daysInWeek = n['days_in_current_week'] as num? ?? 0;
              final nextDate = n['next_advance_date'] as String?;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: SpeariaAura.border)),
                child: ListTile(
                  title: Text(phone),
                  subtitle: Text('Org: $org · Week $week · days in week: $daysInWeek · next: $nextDate'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _advanceWarmUp(numberId),
                        child: const Text('Advance week'),
                      ),
                      TextButton(
                        onPressed: () => _resetWarmUp(numberId),
                        child: const Text('Reset warm-up'),
                      ),
                    ],
                  ),
                ),
              );
            })
          else if (_warmUpNumbers != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('No numbers in warm-up.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
            ),
          const SizedBox(height: 12),
          Text('Daily reset log', style: SpeariaType.titleMedium),
          const SizedBox(height: 8),
          if (_dailyResetLog != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last reset: ${_dailyResetLog!['count_reset'] ?? 0} numbers at ${_dailyResetLog!['last_run_at'] ?? '—'}', style: SpeariaType.bodyMedium),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _triggerDailyReset,
                      child: const Text('Trigger reset now'),
                    ),
                  ],
                ),
              ),
            ),
        ],
    );
  }

  Widget _buildOrgsTab() {
    final list = _organizations ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Banner(message: 'Top-up opens Stripe Checkout for the selected business.', location: BannerLocation.topEnd, color: SpeariaAura.warning),
        const SizedBox(height: 16),
        Text('Accounts', style: SpeariaType.headlineMedium),
        const SizedBox(height: 8),
        Text('All registered accounts. Account name and ID shown below.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: () { _loadOrgs(); }, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No accounts. Tap Refresh.', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted))))
        else
          ...list.map<Widget>((o) {
            final accountId = o['account_id'] as String? ?? o['org_id'] as String? ?? '';
            final name = o['name'] as String? ?? accountId;
            final tier = o['tier'] as String? ?? o['plan'] as String? ?? '—';
            final credits = o['wallet_credits'] as num? ?? 0;
            final status = o['status'] as String? ?? '—';
            if (accountId.isEmpty) return const SizedBox.shrink();
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: SpeariaAura.border)),
              child: ListTile(
                title: Text(name.isNotEmpty ? name : accountId),
                subtitle: Text('Account ID: $accountId · $tier · $credits credits · $status'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: () => _openOrgDetail(accountId), child: const Text('Detail')),
                    TextButton(onPressed: () => _adminTopUp(accountId), child: const Text('Top up')),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _openOrgDetail(String orgId) async {
    if (orgId.isEmpty) return;
    try {
      final data = await SpeariaApi.getJsonMap('/api/admin/organizations/$orgId', adminAuth: true);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Account: ${data['name'] ?? orgId}', style: SpeariaType.titleLarge),
                const SizedBox(height: 4),
                Text('Account ID: $orgId', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                const SizedBox(height: 8),
                _jsonBlock('Data', data),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  TextButton(onPressed: () => _showAddDeductCredits(orgId), child: const Text('Add/Deduct credits')),
                  TextButton(onPressed: () => _adminTopUp(orgId), child: const Text('Top up (Stripe)')),
                  TextButton(onPressed: () => _showSubOverride(orgId), child: const Text('Subscription override')),
                  TextButton(onPressed: () => _showOrgStatus(orgId), child: const Text('Status')),
                ]),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showAddDeductCredits(String orgId) async {
    final op = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Credits operation'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: const Text('Add'), onTap: () => Navigator.of(ctx).pop('add')),
        ListTile(title: const Text('Deduct'), onTap: () => Navigator.of(ctx).pop('deduct')),
      ]),
    ));
    if (op == null || !mounted) return;
    final reasonC = TextEditingController();
    final creditsC = TextEditingController();
    final submitted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Credits'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: creditsC, decoration: const InputDecoration(labelText: 'Credits'), keyboardType: TextInputType.number),
        TextField(controller: reasonC, decoration: const InputDecoration(labelText: 'Reason (required)'), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply')),
      ],
    ));
    if (submitted != true || !mounted) return;
    final credits = int.tryParse(creditsC.text) ?? 0;
    final reason = reasonC.text.trim();
    if (reason.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason required'))); return; }
    try {
      await SpeariaApi.postJsonMap('/api/admin/organizations/$orgId/credits', body: {'operation': op, 'credits': credits, 'reason': reason}, adminAuth: true);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Done'))); _loadOrgs(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _adminTopUp(String orgId) async {
    final packC = TextEditingController(text: 'starter');
    final submitted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Top up (Stripe Checkout)'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: packC, decoration: const InputDecoration(labelText: 'Pack (starter, growth, scale)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Get link')),
      ],
    ));
    if (submitted != true || !mounted) return;
    final pack = packC.text.trim();
    if (pack.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pack required'))); return; }
    try {
      final base = Uri.base.origin;
      final res = await SpeariaApi.postJsonMap('/api/admin/organizations/$orgId/create-checkout-session', body: {
        'pack': pack,
        'success_url': '$base/pulse/wallet?payment=success',
        'cancel_url': '$base/pulse/wallet',
      }, adminAuth: true);
      final url = res['url'] as String?;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opened Stripe Checkout')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No checkout URL (Stripe may not be configured)')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showSubOverride(String orgId) async {
    final tierC = TextEditingController();
    final reasonC = TextEditingController();
    final submitted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Subscription override'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: tierC, decoration: const InputDecoration(labelText: 'Tier')),
        TextField(controller: reasonC, decoration: const InputDecoration(labelText: 'Reason (min 20 chars)'), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply')),
      ],
    ));
    if (submitted != true || !mounted) return;
    final tier = tierC.text.trim();
    final reason = reasonC.text.trim();
    if (reason.length < 20) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason must be at least 20 characters'))); return; }
    try {
      await SpeariaApi.putJson('/api/admin/organizations/$orgId/subscription', body: {'tier': tier, 'reason': reason}, adminAuth: true);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Done'))); _loadOrgs(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showOrgStatus(String orgId) async {
    final status = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Status'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: const Text('active'), onTap: () => Navigator.of(ctx).pop('active')),
        ListTile(title: const Text('suspended'), onTap: () => Navigator.of(ctx).pop('suspended')),
      ]),
    ));
    if (status == null || !mounted) return;
    try {
      await SpeariaApi.putJson('/api/admin/organizations/$orgId/status', body: {'status': status}, adminAuth: true);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Done'))); _loadOrgs(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildSubOverrideTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Subscription override', style: SpeariaType.headlineMedium),
        const SizedBox(height: 8),
        Text('Select an organization from the Organizations tab, open Detail, then use "Subscription override".', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
      ],
    );
  }

  Widget _buildWalletOpsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Wallet operations', style: SpeariaType.headlineMedium),
        const SizedBox(height: 8),
        Text('Use Organizations → Detail → "Add/Deduct credits" to adjust wallet balance.', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
      ],
    );
  }

  Widget _buildTierConfigsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Banner(message: 'Changes apply immediately.', location: BannerLocation.topEnd, color: SpeariaAura.warning),
        const SizedBox(height: 16),
        Text('Voice tier configs', style: SpeariaType.titleLarge),
        const SizedBox(height: 8),
        ...(_tierConfigs ?? []).map<Widget>((tc) {
          final tier = tc['tier'] as String? ?? '';
          final price = tc['price_per_minute'] as num? ?? 0.0;
          final credits = tc['credits_per_minute'] as num? ?? 0;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: ExpansionTile(
              title: Text('$tier — \$$price/min, $credits credits/min', style: SpeariaType.titleMedium),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _jsonBlock('Voice', tc['vapi_voice_config']),
                      const SizedBox(height: 8),
                      _jsonBlock('Transcriber', tc['vapi_transcriber_config']),
                      const SizedBox(height: 8),
                      _jsonBlock('Model', tc['vapi_model_config']),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPricingTab() {
    final pc = _pricingConfig ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Banner(message: 'Changes apply immediately.', location: BannerLocation.topEnd, color: SpeariaAura.warning),
        const SizedBox(height: 16),
        Text('Pricing config', style: SpeariaType.headlineMedium),
        const SizedBox(height: 8),
        Text('Edit in JSON and Save. Backend expects the full pricing document.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () { _loadPricing(); }, child: const Text('Refresh')),
        const SizedBox(height: 12),
        _jsonBlock('pricing_config', pc),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _savePricingConfig, child: const Text('Save (PUT full document)')),
      ],
    );
  }

  Future<void> _savePricingConfig() async {
    if (_pricingConfig == null) return;
    try {
      await SpeariaApi.putJson('/api/admin/pricing-config', body: Map<String, dynamic>.from(_pricingConfig!), adminAuth: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildHealthTab() {
    if (_systemHealth == null) return Center(child: Text('Load overview first for health data.', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('System health', style: SpeariaType.titleLarge),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _stat('Orgs below 500 credits', '${_systemHealth!['orgs_below_500_credits'] ?? 0}'),
                    _stat('Billing errors today', '${_systemHealth!['billing_errors_today'] ?? 0}'),
                    _stat('Calls missing billing', '${_systemHealth!['calls_missing_billing_record'] ?? 0}'),
                    if (_systemHealth!['avg_assistant_request_ms_last_20'] != null)
                      _stat('Avg assistant-request ms', '${_systemHealth!['avg_assistant_request_ms_last_20']}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Environment (set/not set only)', style: SpeariaType.labelMedium.copyWith(color: SpeariaAura.textMuted)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: (_systemHealth!['env_vars'] as Map<String, dynamic>? ?? {}).entries.map((e) {
                    final set = (e.value as String?) == 'set';
                    return Chip(
                      label: Text('${e.key}: ${set ? "✓ Set" : "✗ Not set"}', style: SpeariaType.labelSmall),
                      backgroundColor: set ? SpeariaAura.success.withValues(alpha: 0.15) : SpeariaAura.error.withValues(alpha: 0.15),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: SpeariaType.titleMedium.copyWith(fontWeight: FontWeight.w600)),
        Text(label, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
      ],
    );
  }

  Widget _jsonBlock(String title, dynamic data) {
    final str = data is Map || data is List ? _prettyJson(data) : data.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SpeariaType.labelMedium),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: SpeariaAura.bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: SpeariaAura.border)),
          child: SelectableText(str, style: SpeariaType.bodySmall.copyWith(fontFamily: 'monospace')),
        ),
      ],
    );
  }

  String _prettyJson(dynamic d) {
    try {
      if (d is Map) return _mapToJson(d);
      if (d is List) return _listToJson(d);
      return d.toString();
    } catch (_) {
      return d.toString();
    }
  }

  String _mapToJson(Map m, [int indent = 0]) {
    final pad = '  ' * indent;
    final lines = <String>['{'];
    m.forEach((k, v) {
      if (v is Map) {
        lines.add('$pad  "$k": ${_mapToJson(v, indent + 1)},');
      } else if (v is List) {
        lines.add('$pad  "$k": ${_listToJson(v, indent + 1)},');
      } else {
        lines.add('$pad  "$k": ${v is String ? '"$v"' : v},');
      }
    });
    lines.add('$pad}');
    return lines.join('\n');
  }

  String _listToJson(List l, [int indent = 0]) {
    if (l.isEmpty) {
      return '[]';
    }
    final pad = '  ' * indent;
    final lines = <String>['['];
    for (final e in l) {
      if (e is Map) {
        lines.add('$pad  ${_mapToJson(e, indent + 1)},');
      } else if (e is List) {
        lines.add('$pad  ${_listToJson(e, indent + 1)},');
      } else {
        lines.add('$pad  $e,');
      }
    }
    lines.add('$pad]');
    return lines.join('\n');
  }

  Future<void> _advanceWarmUp(String numberId) async {
    try {
      await SpeariaApi.postJsonMap('/api/admin/numbers/warm-up/$numberId/advance', body: {}, adminAuth: true);
      if (mounted) _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _resetWarmUp(String numberId) async {
    try {
      await SpeariaApi.postJsonMap('/api/admin/numbers/warm-up/$numberId/reset', body: {}, adminAuth: true);
      if (mounted) _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _triggerDailyReset() async {
    try {
      await SpeariaApi.postJsonMap('/api/admin/numbers/daily-reset/trigger', body: {}, adminAuth: true);
      if (mounted) _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
