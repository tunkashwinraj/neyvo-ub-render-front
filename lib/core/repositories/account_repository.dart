import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../neyvo_pulse_api.dart';
import '../providers/api_provider.dart';

class AccountRepository {
  AccountRepository(this.ref);

  final Ref ref;

  Future<Map<String, dynamic>> getAccountInfo() async {
    ref.watch(speariaApiProvider);
    return NeyvoPulseApi.getAccountInfo();
  }
}

