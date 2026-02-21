// lib/screens/wallet_page.dart
// Wallet & Credits: balance, purchase packs, usage summary, transaction history.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
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
        NeyvoPulseApi.getBillingTransactions(limit: 30),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as Map<String, dynamic>?;
          _usage = results[1] as Map<String, dynamic>?;
          _transactions = results[2] as Map<String, dynamic>?;
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
              Text('Payment processing coming soon. Contact support to add credits.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
              const SizedBox(height: 24),
              _packCard('Starter', 49, 5000, null, 'starter'),
              const SizedBox(height: 12),
              _packCard('Growth', 149, 16500, '+10% bonus', 'growth'),
              const SizedBox(height: 12),
              _packCard('Scale', 399, 50000, '+25% bonus', 'scale'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _packCard(String name, int price, int credits, String? badge, String packKey) {
    final cpm = (_wallet?['credits_per_minute'] ?? 35) as int? ?? 35;
    final approxCalls = (credits / cpm).round();
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
                  Row(
                    children: [
                      Text(name, style: SpeariaType.titleMedium),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: SpeariaAura.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(badge, style: SpeariaType.labelSmall.copyWith(color: SpeariaAura.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('\$$price → $credits credits', style: SpeariaType.bodyMedium),
                  Text('≈ $approxCalls min at current tier', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  Chip(label: Text(tierDisplay), backgroundColor: SpeariaAura.primary.withOpacity(0.1)),
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
                    final isDebit = type == 'debit' || creditsVal < 0;
                    final date = t['created_at']?.toString() ?? '';
                    final desc = t['description']?.toString() ?? type;
                    final balanceAfter = (t['balance_after'] as num?)?.toInt();
                    return ListTile(
                      title: Text(desc, style: SpeariaType.bodyMedium),
                      subtitle: Text(date, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${creditsVal >= 0 ? '+' : ''}$creditsVal',
                            style: SpeariaType.bodyMedium.copyWith(color: isDebit ? SpeariaAura.error : SpeariaAura.success),
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
