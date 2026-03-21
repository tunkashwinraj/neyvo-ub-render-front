import '../api/neyvo_api.dart';
import '../models/email_models.dart';
import '../neyvo_pulse_api.dart';

class SendgridApi {
  SendgridApi._();

  static Map<String, dynamic> _idParams() {
    final id = NeyvoPulseApi.defaultAccountId.trim();
    if (id.isEmpty) return const {};
    // Send both keys for compatibility across FastAPI/legacy endpoints.
    return {
      'account_id': id,
      'business_id': id,
    };
  }

  static Map<String, dynamic> _idBody() {
    final id = NeyvoPulseApi.defaultAccountId.trim();
    if (id.isEmpty) return const {};
    return {
      'account_id': id,
      'business_id': id,
    };
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

  /// Returns (valid, errorMessage). [errorMessage] set when invalid or request failed.
  static Future<({bool valid, String? errorMessage})> validateApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      return (valid: false, errorMessage: 'Enter an API key');
    }
    try {
      final m = await NeyvoApi.postJsonMap(
        '/api/integrations/sendgrid/validate',
        body: {
          ..._idBody(),
          'api_key': trimmed,
        },
      );
      final ok = m['ok'] == true;
      return (valid: ok, errorMessage: ok ? null : (m['error']?.toString() ?? 'Invalid key'));
    } on ApiException catch (e) {
      final payload = e.payload;
      if (payload is Map) {
        final err = payload['error']?.toString();
        if (err != null && err.isNotEmpty) {
          return (valid: false, errorMessage: err);
        }
      }
      return (valid: false, errorMessage: e.message);
    }
  }

  static Future<void> connect({required String apiKey, required String fromEmail}) async {
    await NeyvoApi.postJsonMap(
      '/api/integrations/sendgrid/connect',
      body: {
        ..._idBody(),
        'api_key': apiKey.trim(),
        'from_email': fromEmail.trim(),
      },
    );
  }

  static Future<void> disconnect() async {
    await NeyvoApi.postJsonMap(
      '/api/integrations/sendgrid/disconnect',
      body: {
        ..._idBody(),
      },
    );
  }
}
