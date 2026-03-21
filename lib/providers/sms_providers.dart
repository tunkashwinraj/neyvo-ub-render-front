import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sms_models.dart';
import '../neyvo_pulse_api.dart';
import '../services/sms_api.dart';

/// Twilio SMS env status for the current Pulse account.
final smsConfigProvider = FutureProvider.autoDispose<SmsConfig>((ref) async {
  if (NeyvoPulseApi.defaultAccountId.isEmpty) {
    throw StateError('No account selected');
  }
  return SmsApi.getConfig();
});

/// Operator-scoped SMS templates.
final smsTemplatesForOperatorProvider =
    FutureProvider.autoDispose.family<List<SmsTemplate>, String>((ref, operatorId) async {
  if (NeyvoPulseApi.defaultAccountId.isEmpty) {
    throw StateError('No account selected');
  }
  return SmsApi.listTemplates(operatorId: operatorId);
});
