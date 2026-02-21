// lib/screens/wallet_page.dart
// Wallet & Credits: balance (tier badge, bonus), purchase packs with bonused credits,
// transaction history by type (icons/colors), low-balance banner.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import 'pulse_shell.dart';
import '../theme/spearia_theme.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _usage;
  Map<String, dynamic>? _transactions;
  bool _loading = true;
  String? _error;
  bool _purchaseInProgress = false;
  int _txnOffset = 0;
  static const int _txnPageSize = 30;
  bool _loadingMore = false;

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
      final now = DateTime.now();
      final from = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final to = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final results = await Future.wait([
        NeyvoPulseApi.getBillingWallet(),
        NeyvoPulseApi.getBillingUsage(from: from, to: to),
        NeyvoPulseApi.getBillingTransactions(limit: _txnPageSize, offset: 0),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as Map<String, dynamic>?;
          _usage = results[1] as Map<String, dynamic>?;
          _transactions = results[2] as Map<String, dynamic>?;
          _txnOffset = 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _purchase(String pack) async {
    setState(() => _purchaseInProgress = true);
    try {
      await NeyvoPulseApi.purchaseCredits(pack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Credits added. Payment processing coming soon — contact support to add credits.')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _purchaseInProgress = false);
    }
  }

  void _showPurchaseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpeariaAura.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add credits', style: SpeariaType.headlineMedium),
              const SizedBox(height: 8),
              Text('Credits are applied with your plan bonus. Payment processing coming soon.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
              const SizedBox(height: 24),
              _packCard('Starter', 49, 5000, 'starter'),
              const SizedBox(height: 12),
              _packCard('Growth', 149, 16500, 'growth'),
              const SizedBox(height: 12),
              _packCard('Scale', 399, 50000, 'scale'),
            ],
          ),
        ),
      ),
    );
  }

  int _bonusedCredits(int baseCredits) {
    final pct = (_wallet?['credit_bonus_pct'] as num?)?.toDouble() ?? 0.0;
    return (baseCredits * (1 + pct)).floor();
  }

  Widget _packCard(String name, int price, int baseCredits, String packKey) {
    final bonusPct = (_wallet?['credit_bonus_pct'] as num?)?.toDouble() ?? 0.0;
    final totalCredits = _bonusedCredits(baseCredits);
    final bonusCredits = totalCredits - baseCredits;
    final cpm = (_wallet?['credits_per_minute'] as num?)?.toInt() ?? 35;
    final approxMin = totalCredits ~/ cpm;
    final bonusLabel = bonusPct > 0
        ? '${totalCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} credits — includes +${(bonusPct * 100).toInt()}% ${(_wallet?['subscription_tier'] ?? 'plan').toString().toUpperCase()} bonus'
        : null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: SpeariaType.titleMedium),
                  const SizedBox(height: 4),
                  Text('\$$price → ${totalCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} credits', style: SpeariaType.bodyMedium),
                  if (bonusLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(bonusLabel, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.primary)),
                    ),
                  const SizedBox(height: 4),
                  Text('~$approxMin min of Natural Human calls', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                ],
              ),
            ),
            FilledButton(
              onPressed: _purchaseInProgress ? null : () => _purchase(packKey),
              style: FilledButton.styleFrom(backgroundColor: SpeariaAura.primary),
              child: const Text('Purchase'),
            ),
          ],
        ),
      ),
    );
  }

  void _loadMoreTransactions() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final newOffset = _txnOffset + _txnPageSize;
    try {
      final res = await NeyvoPulseApi.getBillingTransactions(limit: _txnPageSize, offset: newOffset);
      final list = res['transactions'] as List? ?? [];
      if (mounted && _transactions != null) {
        final existing = _transactions!['transactions'] as List? ?? [];
        setState(() {
          _transactions = Map<String, dynamic>.from(_transactions!);
          _transactions!['transactions'] = [...existing, ...list];
          _txnOffset = newOffset;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  static (Color, IconData) _txnStyle(String type) {
    switch (type) {
      case 'purchase': return (SpeariaAura.success, Icons.account_balance_wallet_outlined);
      case 'debit': return (SpeariaAura.error, Icons.phone_outlined);
      case 'bonus': return (Color(0xFF7C3AED), Icons.star_outline);
      case 'addon_deduction': return (SpeariaAura.warning, Icons.toggle_on_outlined);
      case 'manual_adjustment': return (SpeariaAura.textMuted, Icons.admin_panel_settings_outlined);
      case 'refund': return (SpeariaAura.info, Icons.replay_outlined);
      default: return (SpeariaAura.textSecondary, Icons.receipt_long_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _wallet == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading wallet…', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
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

    final credits = (_wallet?['credits'] as num?)?.toInt() ?? 0;
    final dollars = (_wallet?['dollars'] as num?)?.toDouble() ?? 0.0;
    final tierDisplay = _wallet?['tier_display'] as String? ?? 'Natural Human';
    final subTier = (_wallet?['subscription_tier'] as String?)?.toLowerCase() ?? 'free';
    final bonusPct = (_wallet?['credit_bonus_pct'] as num?)?.toDouble() ?? 0.0;
    Color planColor = SpeariaAura.textMuted;
    if (subTier == 'pro') planColor = const Color(0xFF7C3AED);
    if (subTier == 'business') planColor = const Color(0xFFD97706);
    final lowBalance = credits < 500;
    final criticalBalance = credits < 200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lowBalance)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: criticalBalance ? SpeariaAura.error.withOpacity(0.12) : SpeariaAura.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: criticalBalance ? SpeariaAura.error : SpeariaAura.warning, width: 1),
              ),
              child: Row(
                children: [
                  Icon(criticalBalance ? Icons.warning_amber_rounded : Icons.info_outline, color: criticalBalance ? SpeariaAura.error : SpeariaAura.warning, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Low credits — $credits remaining (~${(credits / 35).round()} min). Top up now to keep calls running.',
                      style: SpeariaType.bodyMedium.copyWith(color: criticalBalance ? SpeariaAura.error : SpeariaAura.warning),
                    ),
                  ),
                  TextButton(onPressed: _showPurchaseModal, child: const Text('Top up')),
                ],
              ),
            ),
          // Balance card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balance', style: SpeariaType.labelLarge.copyWith(color: SpeariaAura.textMuted)),
                  const SizedBox(height: 8),
                  Text('${credits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} credits', style: SpeariaType.headlineMedium.copyWith(fontWeight: FontWeight.w700)),
                  Text('\$${dollars.toStringAsFixed(2)} available', style: SpeariaType.bodyLarge.copyWith(color: SpeariaAura.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(subTier == 'business' ? 'Business' : subTier == 'pro' ? 'Pro' : 'Free'),
                        backgroundColor: planColor.withOpacity(0.15),
                        labelStyle: SpeariaType.labelMedium.copyWith(color: planColor),
                      ),
                      if (bonusPct > 0)
                        Text('You get +${(bonusPct * 100).toInt()}% bonus on every top-up', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _showPurchaseModal,
                    icon: const Icon(Icons.add),
                    label: const Text('Add credits'),
                    style: FilledButton.styleFrom(backgroundColor: SpeariaAura.primary),
                  ),
                ],
              ),
            ),
          ),
          if (bonusPct == 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SpeariaAura.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpeariaAura.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('Get 10% more credits on every top-up with Pro.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textPrimary))),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.subscriptionPlan))),
                    child: const Text('Upgrade'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Usage this month
          Text('This month', style: SpeariaType.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statColumn('Calls', '${(_usage?['total_calls'] as num?)?.toInt() ?? 0}'),
                  _statColumn('Minutes', '${(_usage?['total_minutes'] as num?)?.toStringAsFixed(1) ?? '0'}'),
                  _statColumn('Credits used', '${(_usage?['total_credits_used'] as num?)?.toInt() ?? 0}'),
                  _statColumn('Spent', '\$${((_usage?['total_dollars_spent'] as num?) ?? 0).toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Transaction history
          Text('Transaction history', style: SpeariaType.titleMedium),
          const SizedBox(height: 8),
          Builder(
            builder: (ctx) {
              final list = _transactions?['transactions'] as List? ?? [];
              if (list.isEmpty) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
                  child: const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No transactions yet'))),
                );
              }
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = list[i] as Map<String, dynamic>;
                    final type = t['type'] as String? ?? '';
                    final creditsVal = (t['credits'] as num?)?.toInt() ?? 0;
                    final (color, icon) = _txnStyle(type);
                    final date = t['created_at']?.toString() ?? '';
                    final desc = t['description']?.toString() ?? type;
                    final balanceAfter = (t['balance_after'] as num?)?.toInt();
                    return ListTile(
                      leading: Icon(icon, color: color, size: 22),
                      title: Text(desc, style: SpeariaType.bodyMedium),
                      subtitle: Text(date, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${creditsVal >= 0 ? '+' : ''}$creditsVal',
                            style: SpeariaType.bodyMedium.copyWith(color: color),
                          ),
                          if (balanceAfter != null) Text('Balance: $balanceAfter', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Builder(
            builder: (ctx) {
              final list = _transactions?['transactions'] as List? ?? [];
              final hasMore = list.length >= _txnPageSize;
              if (!hasMore || list.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: _loadingMore
                      ? const SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton.icon(
                          onPressed: _loadMoreTransactions,
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Load more'),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: SpeariaType.titleMedium.copyWith(fontWeight: FontWeight.w600)),
        Text(label, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
      ],
    );
  }
}
