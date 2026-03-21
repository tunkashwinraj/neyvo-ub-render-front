import '../api/neyvo_api.dart' show ApiException, NeyvoApi;
import '../api/spearia_api.dart';
import '../models/sms_models.dart';

class SmsApi {
  SmsApi._();

  static Future<SmsConfig> getConfig() async {
    final m = await NeyvoApi.getJsonMap('/api/sms/config');
    return SmsConfig.fromJson(m);
  }

  static Future<List<SmsTemplate>> listTemplates({required String operatorId}) async {
    final m = await NeyvoApi.getJsonMap(
      '/api/sms/templates',
      params: {'operator_id': operatorId},
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
      params: {'operator_id': operatorId},
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
      params: {'operator_id': operatorId},
    );
  }
}
