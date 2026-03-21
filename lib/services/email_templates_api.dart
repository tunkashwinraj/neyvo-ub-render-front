import '../api/neyvo_api.dart';
import '../models/email_models.dart';

class EmailTemplatesApi {
  EmailTemplatesApi._();

  static Future<List<EmailTemplate>> listTemplates({required String operatorId}) async {
    final m = await NeyvoApi.getJsonMap(
      '/api/email/templates',
      params: {'operator_id': operatorId},
    );
    final raw = m['templates'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(EmailTemplate.fromJson)
        .toList();
  }

  static Future<EmailTemplate> getTemplate({
    required String operatorId,
    required String templateId,
  }) async {
    final m = await NeyvoApi.getJsonMap(
      '/api/email/templates/$templateId',
      params: {'operator_id': operatorId},
    );
    final t = m['template'];
    if (t is Map<String, dynamic>) return EmailTemplate.fromJson(t);
    throw ApiException('Missing template in response');
  }

  static Future<EmailTemplate> createTemplate({
    required String operatorId,
    required String name,
    required String subject,
    required String body,
    String? htmlBody,
  }) async {
    final m = await NeyvoApi.postJsonMap(
      '/api/email/templates',
      body: {
        'operator_id': operatorId,
        'name': name,
        'subject': subject,
        'body': body,
        if (htmlBody != null && htmlBody.trim().isNotEmpty) 'html_body': htmlBody.trim(),
      },
    );
    final t = m['template'];
    if (t is Map<String, dynamic>) return EmailTemplate.fromJson(t);
    throw ApiException('Missing template in response');
  }

  static Future<EmailTemplate> updateTemplate({
    required String operatorId,
    required String templateId,
    String? name,
    String? subject,
    String? body,
    String? htmlBody,
  }) async {
    final b = <String, dynamic>{
      'operator_id': operatorId,
      if (name != null) 'name': name,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (htmlBody != null) 'html_body': htmlBody,
    };
    final m = await SpeariaApi.putJson(
      '/api/email/templates/$templateId',
      body: b,
    );
    if (m is Map<String, dynamic>) {
      final t = m['template'];
      if (t is Map<String, dynamic>) return EmailTemplate.fromJson(t);
    }
    throw ApiException('Unexpected update response');
  }

  static Future<void> deleteTemplate({
    required String operatorId,
    required String templateId,
  }) async {
    await NeyvoApi.deleteJson(
      '/api/email/templates/$templateId',
      params: {'operator_id': operatorId},
    );
  }
}
