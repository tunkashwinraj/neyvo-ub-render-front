// lib/features/operators/aria_operators/aria_operator_api_service.dart
// API client for ARIA Operators. Calls /api/operators/* endpoints.

import '../../../api/neyvo_api.dart';
import '../../../config/backend_urls.dart';
import '../../../models/email_models.dart';
import '../../../models/sms_models.dart';
import '../../../neyvo_pulse_api.dart';

class AriaOperatorApiService {
  static String get _integrationBaseUrl => resolveNeyvoApiBaseUrl();

  static Map<String, dynamic> _withAccountId(Map<String, dynamic> bodyOrParams) {
    final p = Map<String, dynamic>.from(bodyOrParams);
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      p['account_id'] = p['account_id'] ?? NeyvoPulseApi.defaultAccountId;
    }
    return p;
  }

  static Future<Map<String, dynamic>> initiateAriaCall() async {
    final body = _withAccountId(<String, dynamic>{});
    return NeyvoApi.postJsonMap('/api/operators/initiate-aria-call', body: body);
  }

  static Future<Map<String, dynamic>> startOrGetOperatorsList() async {
    final params = _withAccountId(<String, dynamic>{});
    return NeyvoApi.getJsonMap('/api/operators', params: params);
  }

  static Future<Map<String, dynamic>> getOperator(String operatorId) async {
    final params = _withAccountId(<String, dynamic>{});
    return NeyvoApi.getJsonMap('/api/operators/$operatorId', params: params);
  }

  static Future<Map<String, dynamic>> getOperatorStatus(String operatorId) async {
    final params = _withAccountId(<String, dynamic>{});
    return NeyvoApi.getJsonMap('/api/operators/$operatorId/status', params: params);
  }

  static Future<void> deleteOperator(String operatorId) async {
    final params = _withAccountId(<String, dynamic>{});
    await NeyvoApi.deleteJson('/api/operators/$operatorId', params: params);
  }

  static Future<Map<String, dynamic>> getMessagingDefaults(String operatorId) async {
    final params = _withAccountId(<String, dynamic>{});
    final path = '/api/operators/$operatorId/integrations/messaging-defaults';
    try {
      return NeyvoApi.getJsonMap(path, params: params);
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      final v = await SpeariaApi.getJson(
        '$_integrationBaseUrl$path',
        params: params,
      );
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      throw ApiException('Unexpected messaging-defaults response');
    }
  }

  static Future<Map<String, dynamic>> saveMessagingDefaults(
    String operatorId, {
    required Map<String, dynamic> email,
    required Map<String, dynamic> sms,
  }) async {
    return _saveMessagingDefaultsBody(
      operatorId,
      body: <String, dynamic>{'email': email, 'sms': sms},
    );
  }

  static Future<Map<String, dynamic>> saveEmailDefaults(
    String operatorId, {
    required Map<String, dynamic> email,
  }) async {
    return _saveMessagingDefaultsBody(
      operatorId,
      body: <String, dynamic>{'email': email},
    );
  }

  static Future<Map<String, dynamic>> saveSmsDefaults(
    String operatorId, {
    required Map<String, dynamic> sms,
  }) async {
    return _saveMessagingDefaultsBody(
      operatorId,
      body: <String, dynamic>{'sms': sms},
    );
  }

  static Future<Map<String, dynamic>> _saveMessagingDefaultsBody(
    String operatorId, {
    required Map<String, dynamic> body,
  }) async {
    final payload = _withAccountId(body);
    final path = '/api/operators/$operatorId/integrations/messaging-defaults';
    try {
      final v = await SpeariaApi.putJson(path, body: payload);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      throw ApiException('Unexpected messaging-defaults response');
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      final v = await SpeariaApi.putJson('$_integrationBaseUrl$path', body: payload);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      throw ApiException('Unexpected messaging-defaults response');
    }
  }

  static Future<SendgridConfig> getOperatorSendgridConfig(String operatorId) async {
    final params = _withAccountId(<String, dynamic>{});
    final path = '/api/operators/$operatorId/integrations/sendgrid';
    try {
      final v = await NeyvoApi.getJsonMap(path, params: params);
      return SendgridConfig.fromJson(v);
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      final v = await NeyvoApi.getJsonMap('$_integrationBaseUrl$path', params: params);
      return SendgridConfig.fromJson(v);
    }
  }

  static Future<Map<String, dynamic>> connectOperatorSendgrid(
    String operatorId, {
    required String apiKey,
    required String fromEmail,
  }) async {
    final body = _withAccountId({
      'api_key': apiKey.trim(),
      'from_email': fromEmail.trim(),
    });
    final path = '/api/operators/$operatorId/integrations/sendgrid/connect';
    try {
      return await NeyvoApi.postJsonMap(path, body: body);
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      return await NeyvoApi.postJsonMap('$_integrationBaseUrl$path', body: body);
    }
  }

  static Future<void> disconnectOperatorSendgrid(String operatorId) async {
    final body = _withAccountId(<String, dynamic>{});
    final path = '/api/operators/$operatorId/integrations/sendgrid/disconnect';
    try {
      await NeyvoApi.postJsonMap(path, body: body);
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      await NeyvoApi.postJsonMap('$_integrationBaseUrl$path', body: body);
    }
  }

  static Future<SendgridSenderStatus> getOperatorSendgridSenderStatus(String operatorId) async {
    final params = _withAccountId(<String, dynamic>{});
    final path = '/api/operators/$operatorId/integrations/sendgrid/sender/status';
    try {
      final v = await NeyvoApi.getJsonMap(path, params: params);
      return SendgridSenderStatus.fromJson(v);
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      final v = await NeyvoApi.getJsonMap('$_integrationBaseUrl$path', params: params);
      return SendgridSenderStatus.fromJson(v);
    }
  }

  static Future<Map<String, dynamic>> verifyOperatorSendgridSender(
    String operatorId, {
    required String fromEmail,
    required String fromName,
  }) async {
    final body = _withAccountId({
      'from_email': fromEmail.trim(),
      'from_name': fromName.trim(),
    });
    final path = '/api/operators/$operatorId/integrations/sendgrid/sender/verify';
    try {
      return await NeyvoApi.postJsonMap(path, body: body);
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      return await NeyvoApi.postJsonMap('$_integrationBaseUrl$path', body: body);
    }
  }

  static Future<SmsConfig> getOperatorTwilioConfig(String operatorId) async {
    final params = _withAccountId(<String, dynamic>{});
    final path = '/api/operators/$operatorId/integrations/twilio';
    try {
      final v = await NeyvoApi.getJsonMap(path, params: params);
      return SmsConfig.fromJson(v);
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      final v = await NeyvoApi.getJsonMap('$_integrationBaseUrl$path', params: params);
      return SmsConfig.fromJson(v);
    }
  }

  static Future<SmsConfig> saveOperatorTwilioConfig(
    String operatorId, {
    required String accountSid,
    required String authToken,
    required String fromNumber,
  }) async {
    final body = _withAccountId({
      'account_sid': accountSid.trim(),
      'auth_token': authToken.trim(),
      'from_number': fromNumber.trim(),
    });
    final path = '/api/operators/$operatorId/integrations/twilio';
    try {
      final v = await SpeariaApi.putJson(path, body: body);
      if (v is Map<String, dynamic>) return SmsConfig.fromJson(v);
      if (v is Map) return SmsConfig.fromJson(Map<String, dynamic>.from(v));
      throw ApiException('Unexpected operator twilio response');
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      final v = await SpeariaApi.putJson('$_integrationBaseUrl$path', body: body);
      if (v is Map<String, dynamic>) return SmsConfig.fromJson(v);
      if (v is Map) return SmsConfig.fromJson(Map<String, dynamic>.from(v));
      throw ApiException('Unexpected operator twilio response');
    }
  }
}

