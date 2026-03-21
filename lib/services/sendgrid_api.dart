import '../api/neyvo_api.dart';
import '../models/email_models.dart';

class SendgridApi {
  SendgridApi._();

  static Future<SendgridConfig> getConfig() async {
    final m = await NeyvoApi.getJsonMap('/api/integrations/sendgrid');
    return SendgridConfig.fromJson(m);
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
        body: {'api_key': trimmed},
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
        'api_key': apiKey.trim(),
        'from_email': fromEmail.trim(),
      },
    );
  }

  static Future<void> disconnect() async {
    await NeyvoApi.postJsonMap('/api/integrations/sendgrid/disconnect', body: {});
  }
}
