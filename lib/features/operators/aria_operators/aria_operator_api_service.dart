// lib/features/operators/aria_operators/aria_operator_api_service.dart
// API client for ARIA Operators. Calls /api/operators/* endpoints.

import '../../../api/neyvo_api.dart';
import '../../../neyvo_pulse_api.dart';

class AriaOperatorApiService {
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
}

