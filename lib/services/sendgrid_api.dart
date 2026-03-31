import '../api/neyvo_api.dart';
import '../config/backend_urls.dart';
import '../models/email_models.dart';
import '../neyvo_pulse_api.dart';

class SendgridApi {
  SendgridApi._();
  static String get _integrationBaseUrl => resolveNeyvoApiBaseUrl();

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
    try {
      await NeyvoApi.postJsonMap(
        '/api/integrations/sendgrid/sender/verify',
        body: {
          ..._idBody(),
          'from_email': fromEmail.trim(),
          'from_name': fromName.trim(),
        },
      );
    } on ApiException catch (e) {
      // Staging/older deployments may not expose sender verification routes yet.
      // Do not block email setup if connect + send endpoints are available.
      if (e.statusCode == 404 || e.statusCode == 405) {
        try {
          await NeyvoApi.postJsonMap(
            '$_integrationBaseUrl/api/integrations/sendgrid/sender/verify',
            body: {
              ..._idBody(),
              'from_email': fromEmail.trim(),
              'from_name': fromName.trim(),
            },
          );
        } on ApiException {
          // Keep this non-blocking for tenants that use platform-managed sender.
        }
        return;
      }
      rethrow;
    }
  }

  static Future<SendgridSenderStatus> getSenderStatus() async {
    try {
      final m = await NeyvoApi.getJsonMap(
        '/api/integrations/sendgrid/sender/status',
        params: _idParams(),
      );
      return SendgridSenderStatus.fromJson(m);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        try {
          final m = await NeyvoApi.getJsonMap(
            '$_integrationBaseUrl/api/integrations/sendgrid/sender/status',
            params: _idParams(),
          );
          return SendgridSenderStatus.fromJson(m);
        } on ApiException {
          return const SendgridSenderStatus(
            ok: true,
            verified: false,
            refreshed: false,
          );
        }
      }
      rethrow;
    }
  }
}


