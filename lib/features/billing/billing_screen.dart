import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/billing_provider.dart';
import '../../theme/neyvo_theme.dart';
import 'widgets/calls_line_chart.dart';
import 'widgets/calls_usage_bar.dart';
import 'widgets/credit_balance_card.dart';
import 'widgets/shimmer_card.dart';

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(billingSummaryProvider);
    final chartData = ref.watch(callUsageChartProvider);
    final urlAsync = ref.watch(stripeCheckoutUrlProvider);

    final creditCard = summary.when(
      data: (data) => CreditBalanceCard(
        balance: data.creditBalance,
        planName: data.planName,
      ),
      loading: () => const ShimmerCard(),
      error: (e, st) => _ErrorCard(message: e.toString()),
    );

    final usageBar = summary.when(
      data: (data) => CallsUsageBar(used: data.callsThisMonth, limit: data.callsLimit),
      loading: () => const ShimmerCard(),
      error: (e, st) => _ErrorCard(message: e.toString()),
    );

    final callsChart = chartData.when(
      data: (points) => CallsLineChart(points: points),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Chart error: $e'),
    );

    final upgradeButton = urlAsync.when(
      data: (url) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open upgrade page')),
                );
              }
            },
            child: const Text('Upgrade Plan'),
          ),
        );
      },
      loading: () => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, st) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            },
            child: const Text('Upgrade Plan'),
          ),
        );
      },
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        creditCard,
        const SizedBox(height: 16),
        usageBar,
        const SizedBox(height: 16),
        callsChart,
        const SizedBox(height: 16),
        upgradeButton,
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        border: Border.all(color: NeyvoColors.error.withOpacity(0.45)),
      ),
      child: Text(
        message,
        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error),
      ),
    );
  }
}

