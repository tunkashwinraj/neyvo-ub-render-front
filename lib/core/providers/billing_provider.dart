import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';
import 'api_provider.dart';
import '../models/billing_model.dart';

part 'billing_provider.g.dart';

class BillingData {
  const BillingData({
    required this.wallet,
    required this.usage,
    required this.subscription,
    required this.numbers,
  });

  final Map<String, dynamic> wallet;
  final Map<String, dynamic> usage;
  final Map<String, dynamic> subscription;
  final Map<String, dynamic> numbers;
}

@riverpod
class BillingNotifier extends _$BillingNotifier {
  @override
  Future<BillingData> build() async {
    ref.watch(speariaApiProvider);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final toStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final results = await Future.wait([
      NeyvoPulseApi.getBillingWallet(shellScoped: true),
      NeyvoPulseApi.getBillingUsage(from: fromStr, to: toStr, shellScoped: true),
      NeyvoPulseApi.getSubscription(shellScoped: true),
      NeyvoPulseApi.listNumbers(shellScoped: true),
    ]);
    return BillingData(
      wallet: Map<String, dynamic>.from(results[0] as Map),
      usage: Map<String, dynamic>.from(results[1] as Map),
      subscription: Map<String, dynamic>.from(results[2] as Map),
      numbers: Map<String, dynamic>.from(results[3] as Map),
    );
  }

  Future<void> setVoiceTier(String tier) async {
    ref.read(speariaApiProvider);
    await NeyvoPulseApi.setBillingTier(tier);
    ref.invalidateSelf();
  }
}

@riverpod
Future<BillingSummaryModel> billingSummary(BillingSummaryRef ref) async {
  final api = ref.watch(speariaApiProvider);
  final response = await api.dio.get('/api/billing/summary');
  return BillingSummaryModel.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
Future<List<CallUsagePoint>> callUsageChart(CallUsageChartRef ref) async {
  final api = ref.watch(speariaApiProvider);
  final response = await api.dio.get('/api/billing/usage');
  return (response.data as List)
      .map((e) => CallUsagePoint.fromJson(e as Map<String, dynamic>))
      .toList();
}

@riverpod
Future<String> stripeCheckoutUrl(StripeCheckoutUrlRef ref) async {
  final api = ref.watch(speariaApiProvider);
  final response = await api.dio.get('/api/billing/upgrade');
  return response.data['checkout_url'] as String;
}
