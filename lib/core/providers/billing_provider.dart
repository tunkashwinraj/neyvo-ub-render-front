import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';
import 'api_provider.dart';

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
      NeyvoPulseApi.getBillingWallet(),
      NeyvoPulseApi.getBillingUsage(from: fromStr, to: toStr),
      NeyvoPulseApi.getSubscription(),
      NeyvoPulseApi.listNumbers(),
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
