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

  /// Preview profile (happy + fallback text) without creating. Body: partial ProfileSpec.
  static Future<Map<String, dynamic>> previewProfile(Map<String, dynamic> body) async =>
      _post('/api/managed-profiles/preview', body);

  /// IBA v2: Preview business understanding and enabled tools without creating.
  static Future<Map<String, dynamic>> previewProfileV2(Map<String, dynamic> body) async =>
      _post('/api/managed-profiles/preview_v2', body);

  static Future<Map<String, dynamic>> createProfile(Map<String, dynamic> body) async =>
      _post('/api/managed-profiles', body);

  /// Create profile from BI (use_bi=true). Requires org to have BI ready.
  /// Body: role, goal, allowed_actions, profile_name, conversation overrides.
  static Future<Map<String, dynamic>> createProfileFromBi({
    required String role,
    required String goal,
    required List<String> allowedActions,
    String? profileName,
    String? tone,
    String direction = 'inbound',
  }) =>
      _post('/api/managed-profiles', {
        'use_bi': true,
        'schema_version': 2,
        'role': role,
        'goal': goal,
        'allowed_actions': allowedActions,
        if (profileName != null) 'profile_name': profileName,
        if (tone != null) 'conversation_profile': {'tone': tone},
        'direction': direction,
      });

  static Future<Map<String, dynamic>> listProfiles() async =>
      _get('/api/managed-profiles');

  static Future<Map<String, dynamic>> getProfile(String profileId) async =>
      _get('/api/managed-profiles/$profileId');

  /// Fetch variable metadata (source, in_prompt, has_default) for Additional settings.
  static Future<Map<String, dynamic>> getVariableMetadata(String profileId) async =>
      _get('/api/managed-profiles/$profileId/variables-metadata');

  static Future<Map<String, dynamic>> updateProfile(String profileId, Map<String, dynamic> body) async =>
      _patch('/api/managed-profiles/$profileId', body);

  static Future<Map<String, dynamic>> listKnowledgeItems(String profileId) async =>
      _get('/api/managed-profiles/$profileId/knowledge/items');

  static Future<Map<String, dynamic>> addKnowledgeItem(
    String profileId, {
    required String question,
    required String answer,
  }) async =>
      _post('/api/managed-profiles/$profileId/knowledge/items', {
        'question': question,
        'answer': answer,
      });

  static Future<Map<String, dynamic>> aiSuggest(String profileId, String message) async =>
      _post('/api/managed-profiles/$profileId/ai-suggest', {'message': message});

  /// UB operator: AI suggest edits to custom prompt and voicemail.
  /// Pass [conversationHistory] for multi-turn context (list of {role, content}).
  static Future<Map<String, dynamic>> aiSuggestPrompt(
    String profileId, {
    String? message,
    List<Map<String, String>>? conversationHistory,
  }) async =>
      _post('/api/managed-profiles/$profileId/ai-suggest-prompt', {
        if (message != null && message.isNotEmpty) 'message': message,
        if (conversationHistory != null && conversationHistory.isNotEmpty)
          'conversation_history': conversationHistory,
      });

  /// Preview a sentence with variable values substituted (e.g. for display in wizard).
  static Future<Map<String, dynamic>> previewVariableSentence({
    required String template,
    required Map<String, String> variableValues,
  }) async =>
      _post('/api/managed-profiles/preview-variable-sentence', {
        'template': template,
        'variable_values': variableValues,
      });

  /// UB wizard: fetch department list (id, name, role_summary).
  static Future<Map<String, dynamic>> getUbDepartments({bool descriptions = true}) async {
    final params = <String, dynamic>{'descriptions': descriptions};
    return _get('/api/ub/departments', params: params);
  }

  /// UB wizard: AI suggest tools and variables from department + work_goals.
  static Future<Map<String, dynamic>> aiSuggestTools({
    required String department,
    required String workGoals,
    String universityName = 'University of Bridgeport',
  }) async =>
      _post('/api/managed-profiles/ai-suggest-tools', {
        'department': department,
        'work_goals': workGoals,
        'university_name': universityName,
      });

  /// UB wizard: AI craft system prompt, voicemail, and operator summary.
  static Future<Map<String, dynamic>> aiCraftPrompt({
    required String department,
    required String workGoals,
    String universityName = 'University of Bridgeport',
    List<String> selectedToolKeys = const [],
    List<Map<String, String>> promptVariables = const [],
    String? departmentPhone,
    String? usePrebuilt,
  }) async =>
      _post('/api/managed-profiles/ai-craft-prompt', {
        'department': department,
        'work_goals': workGoals,
        'university_name': universityName,
        'selected_tool_keys': selectedToolKeys,
        'prompt_variables': promptVariables,
        if (departmentPhone != null && departmentPhone.isNotEmpty) 'department_phone': departmentPhone,
        if (usePrebuilt != null && usePrebuilt.isNotEmpty) 'use_prebuilt': usePrebuilt,
      });

  /// Fetch a prebuilt prompt template (e.g. "sfs" for Student Financial Services).
  static Future<Map<String, dynamic>> getPromptTemplate(String templateId) async =>
      _get('/api/managed-profiles/prompt-templates/$templateId');

  static Future<Map<String, dynamic>> getProfileCalls(String profileId, {int limit = 20, String? cursor}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    return _get('/api/managed-profiles/$profileId/calls', params: params);
  }

  static Future<Map<String, dynamic>> getProfilePerformance(String profileId) async =>
      _get('/api/managed-profiles/$profileId/performance');

  /// Hardening: profile health metrics (goal completion, tool failure rate, handoff rate).
  static Future<Map<String, dynamic>> getProfileHealth(String profileId, {int windowDays = 7}) async =>
      _get('/api/managed-profiles/$profileId/health', params: {'window': windowDays});

  /// Hardening: recent tool runs for debug (args, result, fallback).
  static Future<Map<String, dynamic>> getProfileToolRuns(String profileId, {int limit = 50}) async =>
      _get('/api/managed-profiles/$profileId/tool_runs', params: {'limit': limit});

  /// Hardening: call insights (goal_completed, sentiment, primary_intent).
  static Future<Map<String, dynamic>> getProfileCallInsights(String profileId, {int limit = 50}) async =>
      _get('/api/managed-profiles/$profileId/call_insights', params: {'limit': limit});

  static Future<void> archiveProfile(String profileId) async {
    await _delete('/api/managed-profiles/$profileId');
  }

  /// Attach a phone number to this operator. If the number is in use by another operator,
  /// the server returns 409 with [in_use_by] (profile_id, profile_name). Pass [forceMove]
  /// true to move the number from that operator to this one.
  static Future<Map<String, dynamic>> attachPhoneNumber({
    required String profileId,
    required String phoneNumberId,
    required String vapiPhoneNumberId,
    bool forceMove = false,
  }) async {
    final body = {
      'phone_number_id': phoneNumberId,
      'vapi_phone_number_id': vapiPhoneNumberId,
      if (forceMove) 'force_move': true,
    };
    return _post('/api/managed-profiles/$profileId/attach-number', body);
  }

  static Future<void> detachPhoneNumber(String profileId) async {
    await _post('/api/managed-profiles/$profileId/detach-number', {});
  }

  static Future<Map<String, dynamic>> makeOutboundCall({
    required String profileId,
    required String customerPhone,
    String? studentId,
    Map<String, dynamic> overrides = const {},
  }) async {
    final body = <String, dynamic>{
      'customer_phone': customerPhone,
      'overrides': overrides,
    };
    if (studentId != null && studentId.trim().isNotEmpty) {
      body['student_id'] = studentId.trim();
    }
    return _post('/api/managed-profiles/$profileId/call', body);
  }

  static Future<Map<String, dynamic>> getWebCallToken(String profileId) async {
    return _get('/api/managed-profiles/$profileId/web-call-token');
  }
}
