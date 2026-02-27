// lib/features/managed_profiles/managed_profile_api_service.dart
// API client for Managed Profiles only. Uses /api/managed-profiles/*.

import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';

class ManagedProfileApiService {
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

  static Future<void> _delete(String path, {Map<String, dynamic>? body}) async {
    final params = Map<String, dynamic>.from(body ?? {});
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      params['account_id'] = params['account_id'] ?? NeyvoPulseApi.defaultAccountId;
    }
    await SpeariaApi.deleteJson(path, params: params);
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      body['account_id'] = body['account_id'] ?? NeyvoPulseApi.defaultAccountId;
    }
    final v = await SpeariaApi.patchJson(path, body: body);
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<Map<String, dynamic>> getIndustries() async =>
      _get('/api/managed-profiles/industries');

  static Future<Map<String, dynamic>> createProfile(Map<String, dynamic> body) async =>
      _post('/api/managed-profiles', body);

  static Future<Map<String, dynamic>> listProfiles() async =>
      _get('/api/managed-profiles');

  static Future<Map<String, dynamic>> getProfile(String profileId) async =>
      _get('/api/managed-profiles/$profileId');

  static Future<Map<String, dynamic>> updateProfile(String profileId, Map<String, dynamic> body) async =>
      _patch('/api/managed-profiles/$profileId', body);

  static Future<Map<String, dynamic>> aiSuggest(String profileId, String message) async =>
      _post('/api/managed-profiles/$profileId/ai-suggest', {'message': message});

  static Future<Map<String, dynamic>> getProfileCalls(String profileId, {int limit = 20, String? cursor}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    return _get('/api/managed-profiles/$profileId/calls', params: params);
  }

  static Future<Map<String, dynamic>> getProfilePerformance(String profileId) async =>
      _get('/api/managed-profiles/$profileId/performance');

  static Future<void> archiveProfile(String profileId) async {
    await _delete('/api/managed-profiles/$profileId');
  }

  static Future<void> attachPhoneNumber({
    required String profileId,
    required String phoneNumberId,
    required String vapiPhoneNumberId,
  }) async {
    await _post('/api/managed-profiles/$profileId/attach-number', {
      'phone_number_id': phoneNumberId,
      'vapi_phone_number_id': vapiPhoneNumberId,
    });
  }

  static Future<void> detachPhoneNumber(String profileId) async {
    await _post('/api/managed-profiles/$profileId/detach-number', {});
  }

  static Future<Map<String, dynamic>> makeOutboundCall({
    required String profileId,
    required String customerPhone,
    Map<String, dynamic> overrides = const {},
  }) async {
    return _post('/api/managed-profiles/$profileId/call', {
      'customer_phone': customerPhone,
      'overrides': overrides,
    });
  }

  static Future<Map<String, dynamic>> getWebCallToken(String profileId) async {
    return _get('/api/managed-profiles/$profileId/web-call-token');
  }
}
