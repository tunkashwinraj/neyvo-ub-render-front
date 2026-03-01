// lib/features/business_intelligence/bi_wizard_api_service.dart
// API client for Business Intelligence wizard. Uses /api/wizard/*.

import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';

class BiWizardApiService {
  static Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? params}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      p['account_id'] = p['account_id'] ?? NeyvoPulseApi.defaultAccountId;
    }
    return SpeariaApi.getJsonMap(path, params: p);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      body['account_id'] = body['account_id'] ?? NeyvoPulseApi.defaultAccountId;
    }
    return SpeariaApi.postJsonMap(path, body: body);
  }

  /// GET /api/wizard/status - BI setup status (missing | partial | ready)
  static Future<Map<String, dynamic>> getStatus() async =>
      _get('/api/wizard/status');

  /// GET /api/wizard/load - load current BI data
  static Future<Map<String, dynamic>> load() async =>
      _get('/api/wizard/load');

  /// POST /api/wizard/suggestions - get AI service suggestions by category
  static Future<Map<String, dynamic>> getSuggestions({
    required String category,
    required String subcategory,
  }) async =>
      _post('/api/wizard/suggestions', {
        'category': category,
        'subcategory': subcategory,
      });

  /// POST /api/wizard/validate - validate BI payload
  static Future<Map<String, dynamic>> validate(Map<String, dynamic> payload) async =>
      _post('/api/wizard/validate', payload);

  /// POST /api/wizard/simulate - simulate calls with BI payload
  static Future<Map<String, dynamic>> simulate(Map<String, dynamic> payload) async =>
      _post('/api/wizard/simulate', payload);

  /// POST /api/wizard/save - save BI setup
  static Future<Map<String, dynamic>> save(Map<String, dynamic> payload) async =>
      _post('/api/wizard/save', payload);
}
