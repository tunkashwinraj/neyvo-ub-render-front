import '../api/neyvo_api.dart';
import '../models/email_models.dart';
import '../neyvo_pulse_api.dart';

class SendgridApi {
  SendgridApi._();

  static Map<String, dynamic> _idParams() {
    final id = NeyvoPulseApi.defaultAccountId.trim();
    if (id.isEmpty) return const {};
    // Send both keys for compatibility across FastAPI/legacy endpoints.
    return {'account_id': id, 'business_id': id};
  }

  static Map<String, dynamic> _idBody() {
    final id = NeyvoPulseApi.defaultAccountId.trim();
    if (id.isEmpty) return const {};
    return {'account_id': id, 'business_id': id};
  }

  static Future<SendgridConfig> getConfig() async {
    try {
      final m = await NeyvoApi.getJsonMap(
        '/api/integrations/sendgrid',
        params: _idParams(),
      );
      return SendgridConfig.fromJson(m);
    } on ApiException {
      // Keep Integrations page usable on partial/older deployments.
      return const SendgridConfig(enabled: false, connected: false);
    }
  }

  static Future<void> disconnect() async {
    await NeyvoApi.postJsonMap(
      '/api/integrations/sendgrid/disconnect',
      body: {..._idBody()},
    );
  }

  static Future<void> verifySingleSender({
    required String fromEmail,
    required String fromName,
  }) async {
    await NeyvoApi.postJsonMap(
      '/api/integrations/sendgrid/sender/verify',
      body: {
        ..._idBody(),
        'from_email': fromEmail.trim(),
        'from_name': fromName.trim(),
      },
    );
  }

  static Future<SendgridSenderStatus> getSenderStatus() async {
    final m = await NeyvoApi.getJsonMap(
      '/api/integrations/sendgrid/sender/status',
      params: _idParams(),
    );
    return SendgridSenderStatus.fromJson(m);
  }
}
