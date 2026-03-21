import '../api/neyvo_api.dart' show ApiException, NeyvoApi;
import '../api/spearia_api.dart';
import '../models/sms_models.dart';
import '../neyvo_pulse_api.dart';

class SmsApi {
  SmsApi._();

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

  static Future<SmsConfig> getConfig() async {
    try {
      final m = await NeyvoApi.getJsonMap(
        '/api/sms/config',
        params: _idParams(),
      );
      return SmsConfig.fromJson(m);
    } on ApiException catch (e) {
      // Fallback for environments that still expose Twilio integration only.
      if (e.statusCode == 404) {
        final m = await NeyvoApi.getJsonMap(
          '/api/integrations/twilio',
          params: _idParams(),
        );
        final from = m['default_number']?.toString();
        return SmsConfig(
          configured: (from != null && from.isNotEmpty),
          fromMasked: from,
        );
      }
      if (e.statusCode == 400) {
        return const SmsConfig(configured: false);
      }
      rethrow;
    }
  }

  static Future<List<SmsTemplate>> listTemplates({required String operatorId}) async {
    final m = await NeyvoApi.getJsonMap(
      '/api/sms/templates',
      params: {
        ..._idParams(),
        'operator_id': operatorId,
      },
    );
    final raw = m['templates'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SmsTemplate.fromJson)
        .toList();
  }

  static Future<SmsTemplate> getTemplate({
    required String operatorId,
    required String templateId,
  }) async {
    final m = await NeyvoApi.getJsonMap(
      '/api/sms/templates/$templateId',
      params: {
        ..._idParams(),
        'operator_id': operatorId,
      },
    );
    final t = m['template'];
    if (t is Map<String, dynamic>) return SmsTemplate.fromJson(t);
    throw ApiException('Missing template in response');
  }

  static Future<SmsTemplate> createTemplate({
    required String operatorId,
    required String name,
    required String body,
  }) async {
    final m = await NeyvoApi.postJsonMap(
      '/api/sms/templates',
      body: {
        ..._idBody(),
        'operator_id': operatorId,
        'name': name,
        'body': body,
      },
    );
    final t = m['template'];
    if (t is Map<String, dynamic>) return SmsTemplate.fromJson(t);
    throw ApiException('Missing template in response');
  }

  static Future<SmsTemplate> updateTemplate({
    required String operatorId,
    required String templateId,
    String? name,
    String? body,
  }) async {
    final b = <String, dynamic>{
      'operator_id': operatorId,
      'name': ?name,
      'body': ?body,
    };
    final m = await SpeariaApi.putJson(
      '/api/sms/templates/$templateId',
      body: b,
    );
    if (m is Map<String, dynamic>) {
      final t = m['template'];
      if (t is Map<String, dynamic>) return SmsTemplate.fromJson(t);
    }
    throw ApiException('Unexpected update response');
  }

  static Future<void> deleteTemplate({
    required String operatorId,
    required String templateId,
  }) async {
    await NeyvoApi.deleteJson(
      '/api/sms/templates/$templateId',
      params: {
        ..._idParams(),
        'operator_id': operatorId,
      },
    );
  }
}
