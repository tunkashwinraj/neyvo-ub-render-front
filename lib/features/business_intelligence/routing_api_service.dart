// lib/features/business_intelligence/routing_api_service.dart
// API client for Phone Number Routing. Uses /api/routing/*.

import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';

class RoutingApiService {
  static Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? params}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      p['account_id'] = p['account_id'] ?? NeyvoPulseApi.defaultAccountId;
    }
    return SpeariaApi.getJsonMap(path, params: p);
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      body['account_id'] = body['account_id'] ?? NeyvoPulseApi.defaultAccountId;
    }
    final v = await SpeariaApi.patchJson(path, body: body);
    return Map<String, dynamic>.from(v as Map);
  }

  /// GET /api/routing/config - routing config for org
  static Future<Map<String, dynamic>> getConfig() async =>
      _get('/api/routing/config');

  /// PATCH /api/routing/config - update routing config
  static Future<Map<String, dynamic>> updateConfig(Map<String, dynamic> config) async =>
      _patch('/api/routing/config', config);
}
