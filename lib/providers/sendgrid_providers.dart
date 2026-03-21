import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/email_models.dart';
import '../neyvo_pulse_api.dart';
import '../services/email_templates_api.dart';
import '../services/sendgrid_api.dart';

/// SendGrid connection status for the current Pulse account (uses [NeyvoPulseApi.defaultAccountId] via API client).
final sendgridConfigProvider = FutureProvider.autoDispose<SendgridConfig>((ref) async {
  if (NeyvoPulseApi.defaultAccountId.isEmpty) {
    throw StateError('No account selected');
  }
  return SendgridApi.getConfig();
});

/// Operator-scoped email templates.
final emailTemplatesForOperatorProvider =
    FutureProvider.autoDispose.family<List<EmailTemplate>, String>((ref, operatorId) async {
  if (NeyvoPulseApi.defaultAccountId.isEmpty) {
    throw StateError('No account selected');
  }
  return EmailTemplatesApi.listTemplates(operatorId: operatorId);
});

/// Disconnect SendGrid and refresh config.
final sendgridDisconnectProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await SendgridApi.disconnect();
    ref.invalidate(sendgridConfigProvider);
  };
});

/// Mutation helper: invalidate template list after create/update/delete.
final emailTemplatesRefreshProvider = Provider.family<void Function(), String>((ref, operatorId) {
  return () => ref.invalidate(emailTemplatesForOperatorProvider(operatorId));
});
