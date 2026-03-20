import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';
import 'api_provider.dart';

part 'calls_provider.g.dart';

class CallsData {
  const CallsData({required this.calls});
  final List<Map<String, dynamic>> calls;
}

@riverpod
class CallsNotifier extends _$CallsNotifier {
  @override
  Future<CallsData> build() async {
    ref.watch(speariaApiProvider);
    final res = await NeyvoPulseApi.listCalls(limit: 50);
    final calls = (res['calls'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return CallsData(calls: calls);
  }
}
