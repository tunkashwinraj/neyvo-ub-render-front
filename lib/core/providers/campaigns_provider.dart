import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';
import 'api_provider.dart';

part 'campaigns_provider.g.dart';

class CampaignSummary {
  const CampaignSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.raw,
  });

  final String id;
  final String name;
  final String status;
  final Map<String, dynamic> raw;

  factory CampaignSummary.fromJson(Map<String, dynamic> json) {
    return CampaignSummary(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Untitled').toString(),
      status: (json['status'] ?? '').toString(),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

@riverpod
class CampaignsNotifier extends _$CampaignsNotifier {
  @override
  Future<List<CampaignSummary>> build() async {
    ref.watch(speariaApiProvider);
    final res = await NeyvoPulseApi.listCampaigns();
    final list = (res['campaigns'] as List? ?? const [])
        .map((e) => CampaignSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }
}
