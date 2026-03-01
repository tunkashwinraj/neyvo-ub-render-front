// lib/features/business_intelligence/bi_wizard_api_service.dart
// API client for Business Intelligence Wizard. Uses /api/wizard/*.

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

  /// POST /api/wizard/suggestions - AI suggestions for category/subcategory
  static Future<Map<String, dynamic>> getSuggestions({
    required String category,
    required String subcategory,
    Map<String, dynamic>? existingData,
  }) async =>
      _post('/api/wizard/suggestions', {
        'category': category,
        'subcategory': subcategory,
        if (existingData != null) 'existing_data': existingData,
      });

  /// POST /api/wizard/validate - validate BI object
  static Future<Map<String, dynamic>> validate(Map<String, dynamic> bi) async =>
      _post('/api/wizard/validate', bi);

  /// POST /api/wizard/simulate - simulate call scenarios
  static Future<Map<String, dynamic>> simulate(Map<String, dynamic> bi) async =>
      _post('/api/wizard/simulate', bi);

  /// POST /api/wizard/save - save BI to org
  static Future<Map<String, dynamic>> save(Map<String, dynamic> payload) async =>
      _post('/api/wizard/save', payload);

  /// GET /api/wizard/status - BI status (missing|partial|ready)
  static Future<Map<String, dynamic>> getStatus() async =>
      _get('/api/wizard/status');

  /// GET /api/wizard/load - load full BI for org
  static Future<Map<String, dynamic>> load() async =>
      _get('/api/wizard/load');
}
