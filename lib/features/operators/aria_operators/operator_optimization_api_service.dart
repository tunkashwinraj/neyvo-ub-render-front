// API client for /api/optimization/* (FastAPI).

import '../../../api/neyvo_api.dart';
import '../../../neyvo_pulse_api.dart';

class OperatorOptimizationApiService {
  static Map<String, dynamic> _params() {
    final p = <String, dynamic>{};
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      p['account_id'] = NeyvoPulseApi.defaultAccountId;
    }
    return p;
  }

  static Future<Map<String, dynamic>> getStatus(String operatorId) async {
    return NeyvoApi.getJsonMap(
      '/api/optimization/$operatorId/status',
      params: _params(),
    );
  }

  static Future<Map<String, dynamic>> listIterations(String operatorId, {int limit = 20}) async {
    return NeyvoApi.getJsonMap(
      '/api/optimization/$operatorId/iterations',
      params: {..._params(), 'limit': limit.toString()},
    );
  }

  static Future<Map<String, dynamic>> getIteration(String operatorId, String iterationId) async {
    return NeyvoApi.getJsonMap(
      '/api/optimization/$operatorId/iterations/$iterationId',
      params: _params(),
    );
  }

  static Future<Map<String, dynamic>> listFlaggedCalls(String operatorId) async {
    return NeyvoApi.getJsonMap(
      '/api/optimization/$operatorId/calls/flagged',
      params: _params(),
    );
  }

  static Future<Map<String, dynamic>> updateSettings(
    String operatorId, {
    double? threshold,
    bool? optimizationEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (threshold != null) body['threshold'] = threshold;
    if (optimizationEnabled != null) body['optimization_enabled'] = optimizationEnabled;
    return NeyvoApi.postJsonMap(
      '/api/optimization/$operatorId/settings',
      body: body,
      params: _params(),
    );
  }

  static Future<Map<String, dynamic>> getPerformance(String operatorId) async {
    return NeyvoApi.getJsonMap(
      '/api/optimization/$operatorId/performance',
      params: _params(),
    );
  }
}
