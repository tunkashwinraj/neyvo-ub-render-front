// lib/neyvo_pulse/neyvo_pulse_api.dart
// Neyvo Pulse – API client. All data is keyed by account_id.
// Account id is set dynamically from GET /api/pulse/account (no hardcoded values).

import '../api/api_response_cache.dart';
import '../api/neyvo_api.dart';

export '../core/pulse_request_cancelled.dart';

class NeyvoPulseApi {
  static String _defaultAccountId = '';

  // Simple in-memory session cache for core entities to avoid redundant calls
  // across pages during a single app session.
  static Map<String, dynamic>? _cachedAccountInfo;
  static DateTime? _cachedAccountInfoAt;
  static Map<String, dynamic>? _cachedBillingWallet;
  static DateTime? _cachedBillingWalletAt;
  static Map<String, dynamic>? _cachedNumbers;
  static DateTime? _cachedNumbersAt;
  static Map<String, dynamic>? _cachedMyRole;
  static DateTime? _cachedMyRoleAt;
  static Map<String, dynamic>? _cachedListAgents;
  static DateTime? _cachedListAgentsAt;
  static String? _cachedListAgentsKey;

  static const Duration _cacheTtl = Duration(seconds: 60);
  static const Duration _cacheTtlAccountRole = Duration(seconds: 120);
  static const Duration _cacheTtlAgents = Duration(seconds: 30);

  static String get defaultAccountId => _defaultAccountId;

  /// Clear account info cache (e.g. after 403 tenant mismatch so next load is fresh).
  static void clearAccountInfoCache() {
    _cachedAccountInfo = null;
    _cachedAccountInfoAt = null;
  }

  /// Set the account id from API (e.g. getAccountInfo). When empty, requests omit account_id and backend uses its default.
  static void setDefaultAccountId(String? id) {
    _defaultAccountId = (id == null || id.trim().isEmpty) ? '' : id.trim();
    // When switching accounts, clear cached per-account data.
    clearAccountInfoCache();
    _cachedBillingWallet = null;
    _cachedBillingWalletAt = null;
    _cachedNumbers = null;
    _cachedNumbersAt = null;
    _cachedMyRole = null;
    _cachedMyRoleAt = null;
    _cachedListAgents = null;
    _cachedListAgentsAt = null;
    _cachedListAgentsKey = null;
    ApiResponseCache.clear();
  }

  // High-level campaign error codes used by the frontend for tailored UX.
  // These are parsed from ApiException.payload['error'] when available.
  static const Set<String> _campaignErrorCodes = {
    'AUDIENCE_FIELD_ON_BASICS_ENDPOINT',
    'AUDIENCE_LOCKED',
    'NO_AUDIENCE_MODE',
    'NO_AUDIENCE',
    'INVALID_PHONES',
    'MISSING_ASSISTANT',
    'MISSING_PHONE_NUMBER',
    'INSUFFICIENT_CREDITS',
    'VALIDATION_FAILED',
    'SNAPSHOT_NOT_READY',
    'CAMPAIGN_RUNNING',
    'VAPI_RATE_LIMITED',
  };

  /// Extract a normalized campaign error code from an ApiException, or null if none.
  static String? campaignErrorCodeFrom(ApiException e) {
    final payload = e.payload;
    if (payload is Map && payload['error'] is String) {
      final code = (payload['error'] as String).toUpperCase();
      if (_campaignErrorCodes.contains(code)) return code;
    }
    // Backend may return lower_snake_case for some newer errors.
    if (payload is Map && payload['error'] is String) {
      final raw = (payload['error'] as String).toLowerCase().trim();
      if (raw == 'vapi_rate_limited') return 'VAPI_RATE_LIMITED';
    }
    // Some backend errors may only be surfaced via e.message.
    final m = e.message.toUpperCase();
    for (final code in _campaignErrorCodes) {
      if (m.contains(code)) return code;
    }
    return null;
  }

  /// Call when the user selects a different main Pulse sidebar tab. Cancels in-flight
  /// tab-scoped GETs so the previous screen does not keep loading ahead of the new tab.
  static void bumpTabRequestPriority() => SpeariaApi.bumpPulseTabCancelToken();

  static Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? params,
    Duration? timeout,
    bool shellScoped = false,
    Map<String, String>? extraHeaders,
  }) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (_defaultAccountId.isNotEmpty) p['account_id'] = p['account_id'] ?? _defaultAccountId;
    if (shellScoped) {
      return SpeariaApi.getJsonMap(path, params: p, timeout: timeout, headers: extraHeaders);
    }
    return SpeariaApi.getJsonMapTabScoped(path, params: p, timeout: timeout, extraHeaders: extraHeaders);
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    if (_defaultAccountId.isNotEmpty) body['account_id'] = body['account_id'] ?? _defaultAccountId;
    return SpeariaApi.postJsonMap(path, body: body, timeout: timeout);
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    if (_defaultAccountId.isNotEmpty) body['account_id'] = body['account_id'] ?? _defaultAccountId;
    final v = await SpeariaApi.patchJson(path, body: body);
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<Map<String, dynamic>> health({Duration? timeout}) async =>
      _get('/api/pulse/health', timeout: timeout, shellScoped: true);

  /// Inbound health check: validate Twilio webhook and Vapi endpoint wiring.
  /// GET /api/pulse/health/inbound
  static Future<Map<String, dynamic>> getInboundHealthCheck() async =>
      _get('/api/pulse/health/inbound');

  /// GET /api/pulse/account – account_id (short 6–8 digit, for display and API), account_name, onboarding_completed,
  /// surfaces_enabled, active_surface, wallet_credits. Optional: org_doc_id or business_doc_id (Firestore doc id for
  /// real-time listener), org_collection; primary_phone_e164, primary_phone_number_id (for Phone Numbers page).
  static Future<Map<String, dynamic>> getAccountInfo({Duration? timeout}) async {
    final now = DateTime.now();
    if (_cachedAccountInfo != null &&
        _cachedAccountInfoAt != null &&
        now.difference(_cachedAccountInfoAt!) < _cacheTtlAccountRole) {
      return _cachedAccountInfo!;
    }
    final res = await SpeariaApi.runWithRetry(
      () => _get('/api/pulse/account', timeout: timeout, shellScoped: true),
      maxAttempts: 3,
      delay: const Duration(seconds: 3),
    );
    _cachedAccountInfo = res;
    _cachedAccountInfoAt = now;
    return res;
  }

  /// PATCH /api/pulse/account – update onboarding_completed, active_surface, surfaces_enabled, name.
  /// Uses _patch so account_id is sent (same org as GET /account).
  static Future<Map<String, dynamic>> updateAccountInfo(Map<String, dynamic> body) async {
    return _patch('/api/pulse/account', body);
  }

  /// GET /api/pulse/activation – single source of truth for activation state.
  /// Returns: { ok, stage, checklist, counts, nextAction }
  static Future<Map<String, dynamic>> getActivationStatus() async =>
      _get('/api/pulse/activation');

  /// POST /api/ub/initialize – start UB Voice OS extraction from website. Body: { website }.
  /// Returns: { ok, status: "building"|"ready"|"error", error? }
  static Future<Map<String, dynamic>> initializeUb({required String website}) async {
    return _post('/api/ub/initialize', {'website': website.trim()});
  }

  /// GET /api/ub/status – UB model status. Returns: { ok, status, summary, departments, faqTopics, error? }
  static Future<Map<String, dynamic>> getUbStatus({Duration? timeout}) async =>
      _get('/api/ub/status', timeout: timeout);

  // Unified dashboard: agents (GET/POST /api/agents)
  static Future<Map<String, dynamic>> listAgents({
    String? direction,
    String? industry,
    String? status,
    Duration? timeout,
  }) async {
    final params = <String, dynamic>{};
    if (_defaultAccountId.isNotEmpty) params['account_id'] = _defaultAccountId;
    if (direction != null && direction.isNotEmpty) params['direction'] = direction;
    if (industry != null && industry.isNotEmpty) params['industry'] = industry;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final cacheKey =
        '${_defaultAccountId}|${direction ?? ''}|${industry ?? ''}|${status ?? ''}';
    final now = DateTime.now();
    if (_cachedListAgents != null &&
        _cachedListAgentsAt != null &&
        _cachedListAgentsKey == cacheKey &&
        now.difference(_cachedListAgentsAt!) < _cacheTtlAgents) {
      return _cachedListAgents!;
    }
    final res = await _get('/api/agents', params: params, timeout: timeout);
    _cachedListAgents = res;
    _cachedListAgentsAt = now;
    _cachedListAgentsKey = cacheKey;
    return res;
  }

  /// Create agent. Pass templateId only when using a seeded template (not for "Custom agent").
  /// When templateId is null, empty, or 'custom', template_id is omitted so the backend can create an agent without a template.
  static Future<Map<String, dynamic>> createAgent({
    required String name,
    String? templateId,
    String direction = 'inbound',
    String? industry,
    String? useCase,
    String? voiceTier,
    String? systemPrompt,
    String? openingMessage,
    String? voiceProvider,
    String? voiceId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'direction': direction,
      if (industry != null) 'industry': industry,
      if (useCase != null) 'use_case': useCase,
      if (voiceTier != null) 'voice_tier_override': voiceTier,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (openingMessage != null) 'opening_message': openingMessage,
      if (voiceProvider != null && voiceProvider.isNotEmpty) 'voice_provider': voiceProvider,
      if (voiceId != null && voiceId.isNotEmpty) 'voice_id': voiceId,
      if (_defaultAccountId.isNotEmpty) 'account_id': _defaultAccountId,
    };
    if (templateId != null && templateId.isNotEmpty) {
      body['template_id'] = templateId == 'custom' ? 'custom_blank' : templateId;
    }
    return SpeariaApi.postJsonMap('/api/agents', body: body);
  }

  static Future<Map<String, dynamic>> getAgent(String agentId) async =>
      _get('/api/agents/$agentId', params: _defaultAccountId.isNotEmpty ? {'account_id': _defaultAccountId} : null);

  /// GET /api/agents/{id}/knowledge — school_knowledge (education only).
  static Future<Map<String, dynamic>> getAgentKnowledge(String agentId) async =>
      _get('/api/agents/$agentId/knowledge');

  /// PATCH /api/agents/{id}/knowledge — update school_knowledge fields.
  static Future<Map<String, dynamic>> patchAgentKnowledge(String agentId, Map<String, dynamic> knowledge) async =>
      _patch('/api/agents/$agentId/knowledge', knowledge);

  /// GET /api/agents/{id}/knowledge/items — list vector knowledge backup rows.
  static Future<Map<String, dynamic>> getAgentKnowledgeItems(String agentId) async =>
      _get('/api/agents/$agentId/knowledge/items');

  /// POST /api/agents/{id}/knowledge/items — add one Q&A pair to vector knowledge.
  static Future<Map<String, dynamic>> addAgentKnowledgeItem({
    required String agentId,
    required String question,
    required String answer,
  }) async =>
      _post('/api/agents/$agentId/knowledge/items', {
        'question': question,
        'answer': answer,
      });

  static Future<Map<String, dynamic>> updateAgent(String agentId, Map<String, dynamic> body) async {
    if (_defaultAccountId.isNotEmpty) body['account_id'] = _defaultAccountId;
    final v = await SpeariaApi.patchJson('/api/agents/$agentId', body: body);
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<void> deleteAgent(String agentId) async =>
      SpeariaApi.deleteJson('/api/agents/$agentId', params: _defaultAccountId.isNotEmpty ? {'account_id': _defaultAccountId} : null);

  static Future<Map<String, dynamic>> testCallAgent(String agentId, {required String toNumber, String? studentName}) async =>
      SpeariaApi.postJsonMap('/api/agents/$agentId/test-call', body: {
        'to_number': toNumber,
        if (studentName != null) 'student_name': studentName,
        if (_defaultAccountId.isNotEmpty) 'account_id': _defaultAccountId,
      });

  // Templates (global)
  static Future<Map<String, dynamic>> listTemplates({String? industry, String? direction}) async {
    final params = <String, dynamic>{};
    if (industry != null && industry.isNotEmpty) params['industry'] = industry;
    if (direction != null && direction.isNotEmpty) params['direction'] = direction;
    return _get('/api/templates', params: params.isEmpty ? null : params);
  }

  static Future<Map<String, dynamic>> getTemplate(String templateId) async =>
      _get('/api/templates/$templateId');

  /// Admin: seed agent templates (run once if templates empty). POST /api/admin/seed-templates
  static Future<Map<String, dynamic>> seedTemplates() async =>
      SpeariaApi.postJsonMap('/api/admin/seed-templates', body: {});

  /// Admin: seed voice profiles library. POST /api/admin/seed-voice-profiles
  static Future<Map<String, dynamic>> seedVoiceProfiles() async =>
      SpeariaApi.postJsonMap('/api/admin/seed-voice-profiles', body: {});

  // Voice profiles library (Studio)
  static Future<Map<String, dynamic>> listVoiceProfilesLibrary() async =>
      _get('/api/voice-profiles/library');

  // Studio projects
  static Future<Map<String, dynamic>> listStudioProjects() async => _get('/api/studio/projects');

  static Future<Map<String, dynamic>> createStudioProject({
    required String name,
    String type = 'tts',
    String? voiceProfileId,
    String voiceTier = 'neutral',
  }) async =>
      _post('/api/studio/projects', {
        'name': name,
        'type': type,
        if (voiceProfileId != null) 'voice_profile_id': voiceProfileId,
        'voice_tier': voiceTier,
      });

  static Future<Map<String, dynamic>> getStudioProject(String projectId) async =>
      _get('/api/studio/projects/$projectId');

  static Future<Map<String, dynamic>> generateTts({
    required String projectId,
    required String text,
    String? scriptId,
    String? voiceTier,
  }) async =>
      _post('/api/studio/generate', {
        'project_id': projectId,
        'text': text,
        if (scriptId != null) 'script_id': scriptId,
        if (voiceTier != null) 'voice_tier': voiceTier,
      });

  // Analytics (unified dashboard)
  static Future<Map<String, dynamic>> getAnalyticsOverview({
    String? from,
    String? to,
    Duration? timeout,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _get('/api/analytics/overview', params: params.isEmpty ? null : params, timeout: timeout);
  }
  static Future<Map<String, dynamic>> getAnalyticsComms({
    String? from,
    String? to,
    Duration? timeout,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _get(
      '/api/analytics/comms',
      params: params.isEmpty ? null : params,
      timeout: timeout,
      extraHeaders: const {'Accept-Encoding': 'identity'},
    );
  }
  static Future<Map<String, dynamic>> getAnalyticsStudio({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _get('/api/analytics/studio', params: params.isEmpty ? null : params);
  }
  static Future<Map<String, dynamic>> getAnalyticsAgent(String agentId) async =>
      _get('/api/analytics/agents/$agentId');

  // Executive Dashboard KPI (call center style; ASA = Average Speed of Answer, AHT = Average Handled Time)
  // Tries /api/pulse/kpi/* first; on 404 falls back to /api/kpi/* for backends that only register routes in main.py.
  static Future<Map<String, dynamic>> _getKpiWithFallback(String pulsePath, String legacyPath, {String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final p = params.isEmpty ? null : params;
    try {
      return await _get(pulsePath, params: p);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return _get(legacyPath, params: p);
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getKpiOverview({String? from, String? to}) async =>
      _getKpiWithFallback('/api/pulse/kpi/overview', '/api/kpi/overview', from: from, to: to);

  static Future<Map<String, dynamic>> getKpiDepartmentSummary({String? from, String? to}) async =>
      _getKpiWithFallback('/api/pulse/kpi/department-summary', '/api/kpi/department-summary', from: from, to: to);

  static Future<Map<String, dynamic>> getKpiNpsBreakdown({String? from, String? to}) async =>
      _getKpiWithFallback('/api/pulse/kpi/nps-breakdown', '/api/kpi/nps-breakdown', from: from, to: to);

  // Students / Contacts (education: financial fields, filters)
  static Future<Map<String, dynamic>> listStudents({
    int? limit,
    int? offset,
    String? cursor,
    bool? hasBalance,
    bool? isOverdue,
    double? balanceMin,
    double? balanceMax,
    String? dueBefore,
    String? dueAfter,
    /// When false, backend skips expensive call-history merge (faster first paint; follow with true to enrich).
    bool enrichCalls = true,
    /// When true, backend includes total count of matching students (extra scan).
    bool includeTotal = false,
  }) async {
    final params = <String, dynamic>{};
    if (_defaultAccountId.isNotEmpty) params['account_id'] = _defaultAccountId;
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;
    if (cursor != null) params['cursor'] = cursor;
    if (hasBalance != null) params['has_balance'] = hasBalance;
    if (isOverdue != null) params['is_overdue'] = isOverdue;
    if (balanceMin != null) params['balance_min'] = balanceMin;
    if (balanceMax != null) params['balance_max'] = balanceMax;
    if (dueBefore != null) params['due_before'] = dueBefore;
    if (dueAfter != null) params['due_after'] = dueAfter;
    if (!enrichCalls) params['enrich_calls'] = false;
    if (includeTotal) params['include_total'] = true;
    return _get('/api/pulse/students', params: params.isEmpty ? null : params);
  }

  /// POST /api/pulse/students/match-phones
  /// Used by the campaign audience CSV picker to resolve student ids quickly
  /// without loading the full contact list into the client.
  static Future<Map<String, dynamic>> matchStudentsByCsvKeys({
    required List<String> studentIds,
    required List<String> phones,
  }) async {
    return _post('/api/pulse/students/match-phones', {
      'student_ids': studentIds,
      'phones': phones,
    });
  }

  static Future<Map<String, dynamic>> getStudent(String studentId) async =>
      _get('/api/pulse/students/$studentId');

  /// Call history for a contact/student + past_calls_summary (Phase 2).
  static Future<Map<String, dynamic>> getStudentCallHistory(String studentId) async =>
      _get('/api/pulse/students/$studentId/call-history');

  static Future<Map<String, dynamic>> createStudent({
    required String name,
    required String phone,
    String? email,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? studentId,
    String? notes,
    String? firstName,
    String? lastName,
    String? department,
    String? yearOfStudy,
    String? advisorName,
    String? bookingUrl,
  }) async =>
      _post('/api/pulse/students', {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
        if (balance != null) 'balance': balance,
        if (dueDate != null) 'due_date': dueDate,
        if (lateFee != null) 'late_fee': lateFee,
        if (studentId != null) 'student_id': studentId,
        if (notes != null) 'notes': notes,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (department != null) 'department': department,
        if (yearOfStudy != null) 'year_of_study': yearOfStudy,
        if (advisorName != null) 'advisor_name': advisorName,
        if (bookingUrl != null) 'booking_url': bookingUrl,
      });

  static Future<Map<String, dynamic>> updateStudent(
    String studentId, {
    String? name,
    String? phone,
    String? email,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? schoolStudentId,
    String? notes,
    Map<String, dynamic>? customFields,
    String? firstName,
    String? lastName,
    String? department,
    String? yearOfStudy,
    String? advisorName,
    String? bookingUrl,
  }) async =>
      _patch('/api/pulse/students/$studentId', {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (balance != null) 'balance': balance,
        if (dueDate != null) 'due_date': dueDate,
        if (lateFee != null) 'late_fee': lateFee,
        if (schoolStudentId != null) 'student_id': schoolStudentId,
        if (notes != null) 'notes': notes,
        if (customFields != null) 'custom_fields': customFields,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (department != null) 'department': department,
        if (yearOfStudy != null) 'year_of_study': yearOfStudy,
        if (advisorName != null) 'advisor_name': advisorName,
        if (bookingUrl != null) 'booking_url': bookingUrl,
      });

  static Future<void> deleteStudent(String studentId) async {
    await SpeariaApi.deleteJson(
      '/api/pulse/students/$studentId',
      params: <String, dynamic>{'account_id': _defaultAccountId},
    );
  }

  /// Cancel any scheduled/retry callback for a student.
  static Future<Map<String, dynamic>> cancelStudentCallback(String studentId) async =>
      _post('/api/pulse/students/$studentId/callback/cancel', {});

  /// GET /api/pulse/students/import/template — returns CSV template as string (for download or preview).
  static Future<String> getStudentsImportTemplate() async =>
      SpeariaApi.getText('/api/pulse/students/import/template', params: _defaultAccountId.isNotEmpty ? {'account_id': _defaultAccountId} : null);

  /// POST /api/pulse/students/import/csv — send CSV content. Optional [importName] tags the batch (e.g. "Spring 2026 Nursing Cohort") for campaign targeting.
  static Future<Map<String, dynamic>> postStudentsImportCsv(
    String csvContent, {
    String? importName,
    int? chunkSize,
  }) async {
    final body = <String, dynamic>{'csv': csvContent};
    if (importName != null && importName.trim().isNotEmpty) body['import_name'] = importName.trim();
    if (chunkSize != null) body['chunk_size'] = chunkSize;
    return _post('/api/pulse/students/import/csv', body);
  }

  /// GET /api/pulse/students/import/jobs/{job_id}
  static Future<Map<String, dynamic>> getStudentsImportJobStatus(String jobId) async {
    return _get('/api/pulse/students/import/jobs/$jobId');
  }

  /// POST /api/pulse/students/import/jobs/{job_id}/cancel
  static Future<Map<String, dynamic>> cancelStudentsImportJob(String jobId) async {
    return _post('/api/pulse/students/import/jobs/$jobId/cancel', {});
  }

  // Payments
  static Future<Map<String, dynamic>> listPayments({String? studentId}) async =>
      _get('/api/pulse/payments', params: studentId != null ? {'student_id': studentId} : null);

  static Future<Map<String, dynamic>> addPayment({
    required String studentId,
    required String amount,
    String? method,
    String? note,
  }) async =>
      _post('/api/pulse/payments', {
        'student_id': studentId,
        'amount': amount,
        if (method != null) 'method': method,
        if (note != null) 'note': note,
      });

  // Reminders
  static Future<Map<String, dynamic>> listReminders({String? studentId}) async =>
      _get('/api/pulse/reminders', params: studentId != null ? {'student_id': studentId} : null);

  static Future<Map<String, dynamic>> createReminder({
    required String studentId,
    String? agentId,
    String? reminderType,
    String? scheduledAt,
    String? message,
    String? messageType,
    String? notes,
  }) async =>
      _post('/api/pulse/reminders', {
        'student_id': studentId,
        if (agentId != null) 'agent_id': agentId,
        if (reminderType != null) 'reminder_type': reminderType,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (message != null) 'message': message,
        if (messageType != null) 'message_type': messageType,
        if (notes != null) 'notes': notes,
      });

  static Future<Map<String, dynamic>> getReminder(String reminderId) async =>
      _get('/api/pulse/reminders/$reminderId');

  static Future<Map<String, dynamic>> updateReminder(
    String reminderId, {
    String? studentId,
    String? reminderType,
    String? scheduledAt,
    String? message,
    String? status,
  }) async {
    final body = <String, dynamic>{
      if (studentId != null) 'student_id': studentId,
      if (reminderType != null) 'reminder_type': reminderType,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (message != null) 'message': message,
      if (status != null) 'status': status,
    };
    return _patch('/api/pulse/reminders/$reminderId', body);
  }

  static Future<void> deleteReminder(String reminderId) async {
    await SpeariaApi.deleteJson(
      '/api/pulse/reminders/$reminderId',
      params: <String, dynamic>{'account_id': _defaultAccountId},
    );
  }

  // Calls (offset = pagination). Use q to search entire call log by name or phone (substring/letter match).
  // noVapi: when true (default), skips per-call Vapi enrichment so list loads fast; use false when recordings/rich data needed in list.
  static Future<Map<String, dynamic>> listCalls({
    String? studentId,
    String? from,
    String? to,
    int? limit,
    int? offset,
    String? q,
    bool syncFromVapi = true,
    bool noVapi = true,
    Duration? timeout,
    bool shellScoped = false,
  }) async {
    final params = <String, dynamic>{};
    if (_defaultAccountId.isNotEmpty) params['account_id'] = _defaultAccountId;
    if (studentId != null) params['student_id'] = studentId;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (limit != null) params['limit'] = q != null && q.trim().isNotEmpty ? limit.clamp(1, 2000) : limit.clamp(1, 500);
    if (offset != null && offset > 0) params['offset'] = offset;
    if (syncFromVapi) params['sync_initiated'] = '1';
    if (noVapi) params['no_vapi'] = '1';
    final search = (q ?? '').trim();
    if (search.isNotEmpty) params['q'] = search;
    return _get('/api/pulse/calls',
        params: params.isEmpty ? null : params, timeout: timeout, shellScoped: shellScoped);
  }

  /// Same as [listCalls] with cold-start retries (Render wake-up).
  static Future<Map<String, dynamic>> listCallsWithRetry({
    String? studentId,
    String? from,
    String? to,
    int? limit,
    int? offset,
    String? q,
    bool syncFromVapi = true,
    bool noVapi = true,
    Duration? timeout,
    bool shellScoped = false,
  }) async {
    return SpeariaApi.runWithRetry(
      () => listCalls(
        studentId: studentId,
        from: from,
        to: to,
        limit: limit,
        offset: offset,
        q: q,
        syncFromVapi: syncFromVapi,
        noVapi: noVapi,
        timeout: timeout,
        shellScoped: shellScoped,
      ),
      maxAttempts: 2,
      delay: const Duration(seconds: 2),
    );
  }

  /// Same as [getCallsSuccessSummary] with cold-start retries.
  static Future<Map<String, dynamic>> getCallsSuccessSummaryWithRetry({
    String? from,
    String? to,
    Duration? timeout,
  }) async {
    return SpeariaApi.runWithRetry(
      () => getCallsSuccessSummary(from: from, to: to, timeout: timeout),
      maxAttempts: 2,
      delay: const Duration(seconds: 2),
    );
  }

  /// Delete one or more call log entries by their ids (as returned in listCalls).
  /// Uses DELETE /api/pulse/calls?ids=id1,id2,...
  static Future<Map<String, dynamic>> deleteCalls(List<String> callIds) async {
    if (callIds.isEmpty) {
      return {'ok': true, 'deleted': 0};
    }
    final ids = callIds.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
    if (ids.isEmpty) {
      return {'ok': false, 'error': 'no_valid_ids'};
    }
    final res = await SpeariaApi.deleteJson(
      '/api/pulse/calls',
      params: {
        'ids': ids.join(','),
      },
    );
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'ok': false, 'error': 'invalid_response'};
  }

  /// GET /api/pulse/calls/by-id/<call_id> – single call by vapi_call_id (for Wallet → Call detail).
  static Future<Map<String, dynamic>> getCallById(String callId) async =>
      _get('/api/pulse/calls/by-id/${Uri.encodeComponent(callId)}');

  /// Phase D: Resolution/success summary for dashboard
  static Future<Map<String, dynamic>> getCallsSuccessSummary({
    String? from,
    String? to,
    Duration? timeout,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _get('/api/pulse/calls/success-summary', params: params.isEmpty ? null : params, timeout: timeout);
  }

  /// Callback analytics across students (scheduled/completed/exhausted/etc.).
  static Future<Map<String, dynamic>> getCallbacksAnalytics() async =>
      _get('/api/pulse/callbacks/analytics');

  /// List students with active callbacks (scheduled / retry_wait / dialing).
  static Future<Map<String, dynamic>> listCallbacks() async =>
      _get('/api/pulse/callbacks');

  // Knowledge (Phase C: training – FAQ + policy)
  static Future<Map<String, dynamic>> getKnowledgePolicy() async =>
      _get('/api/pulse/knowledge/policy');

  static Future<Map<String, dynamic>> updateKnowledgePolicy({
    String? paymentPolicy,
    String? lateFeePolicy,
    String? contactInfo,
    String? defaultDueDays,
    String? notes,
  }) async =>
      _patch('/api/pulse/knowledge/policy', {
        if (paymentPolicy != null) 'payment_policy': paymentPolicy,
        if (lateFeePolicy != null) 'late_fee_policy': lateFeePolicy,
        if (contactInfo != null) 'contact_info': contactInfo,
        if (defaultDueDays != null) 'default_due_days': defaultDueDays,
        if (notes != null) 'notes': notes,
      });

  static Future<Map<String, dynamic>> listKnowledgeFaq() async =>
      _get('/api/pulse/knowledge/faq');

  static Future<Map<String, dynamic>> addKnowledgeFaq({
    required String question,
    required String answer,
    int? order,
  }) async =>
      _post('/api/pulse/knowledge/faq', {
        'question': question,
        'answer': answer,
        if (order != null) 'order': order,
      });

  static Future<Map<String, dynamic>> updateKnowledgeFaq(
    String faqId, {
    String? question,
    String? answer,
    int? order,
  }) async =>
      _patch('/api/pulse/knowledge/faq/$faqId', {
        if (question != null) 'question': question,
        if (answer != null) 'answer': answer,
        if (order != null) 'order': order,
      });

  static Future<void> deleteKnowledgeFaq(String faqId) async {
    await SpeariaApi.deleteJson(
      '/api/pulse/knowledge/faq/$faqId',
      params: <String, dynamic>{'account_id': _defaultAccountId},
    );
  }

  /// Org-wide training knowledge items (Vector RAG – replaces legacy FAQ/policy UI).
  static Future<Map<String, dynamic>> listTrainingKnowledgeItems() async =>
      _get('/api/pulse/knowledge/items');

  static Future<Map<String, dynamic>> addTrainingKnowledgeItem({
    required String question,
    required String answer,
  }) async =>
      _post('/api/pulse/knowledge/items', {
        'question': question,
        'answer': answer,
      });

  static Future<void> deleteTrainingKnowledgeItem(String itemId) async {
    await SpeariaApi.deleteJson(
      '/api/pulse/knowledge/items/$itemId',
      params: <String, dynamic>{'account_id': _defaultAccountId},
    );
  }

  /// Phase D RBAC: list members and their roles
  static Future<Map<String, dynamic>> listMembers() async =>
      _get('/api/pulse/members');

  /// Phase D RBAC: set role for a member (admin only)
  static Future<Map<String, dynamic>> setMemberRole(String userId, String role) async =>
      _patch('/api/pulse/members/$userId', {'role': role});

  /// Update member role, permissions, name, staff_id, phone, department, title, office, extension, campus, notes, booking_url (admin only).
  static Future<Map<String, dynamic>> updateMember(
    String userId, {
    String? role,
    List<String>? permissions,
    String? name,
    String? staffId,
    String? phone,
    String? email,
    String? department,
    String? title,
    String? office,
    String? extension,
    String? campus,
    String? notes,
    String? bookingUrl,
  }) async {
    final body = <String, dynamic>{};
    if (role != null && role.isNotEmpty) body['role'] = role;
    if (permissions != null) body['permissions'] = permissions;
    if (name != null) body['name'] = name.trim();
    if (staffId != null) body['staff_id'] = staffId.trim();
    if (phone != null) body['phone'] = phone.trim();
    if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();
    if (department != null && department.trim().isNotEmpty) body['department'] = department.trim();
    if (title != null && title.trim().isNotEmpty) body['title'] = title.trim();
    if (office != null && office.trim().isNotEmpty) body['office'] = office.trim();
    if (extension != null && extension.trim().isNotEmpty) body['extension'] = extension.trim();
    if (campus != null && campus.trim().isNotEmpty) body['campus'] = campus.trim();
    if (notes != null) body['notes'] = notes.trim();
    if (bookingUrl != null) body['booking_url'] = bookingUrl.trim();
    return _patch('/api/pulse/members/$userId', body);
  }

  /// Delete member from org (admin only).
  static Future<void> deleteMember(String userId) async {
    await SpeariaApi.deleteJson('/api/pulse/members/$userId');
  }

  /// Phase D RBAC: get current user's role
  /// Use [shellScoped] true for Pulse shell / global providers so tab switches don't cancel.
  static Future<Map<String, dynamic>> getMyRole({bool shellScoped = false}) async {
    final now = DateTime.now();
    if (_cachedMyRole != null &&
        _cachedMyRoleAt != null &&
        now.difference(_cachedMyRoleAt!) < _cacheTtlAccountRole) {
      return _cachedMyRole!;
    }
    final res = await _get('/api/pulse/members/me', shellScoped: shellScoped);
    _cachedMyRole = res;
    _cachedMyRoleAt = now;
    return res;
  }

  /// Invite a team member by email with role and optional permissions.
  /// Name is required; staff_id, phone, department, title, office, extension, campus are optional.
  static Future<Map<String, dynamic>> inviteMember({
    required String name,
    required String email,
    required String role,
    List<String>? permissions,
    String? staffId,
    String? phone,
    String? department,
    String? title,
    String? office,
    String? extension,
    String? campus,
    bool sendInviteEmail = true,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      'send_invite_email': sendInviteEmail,
    };
    if (permissions != null && permissions.isNotEmpty) {
      body['permissions'] = permissions;
    }
    if (staffId != null && staffId.trim().isNotEmpty) {
      body['staff_id'] = staffId.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    if (department != null && department.trim().isNotEmpty) {
      body['department'] = department.trim();
    }
    if (title != null && title.trim().isNotEmpty) {
      body['title'] = title.trim();
    }
    if (office != null && office.trim().isNotEmpty) {
      body['office'] = office.trim();
    }
    if (extension != null && extension.trim().isNotEmpty) {
      body['extension'] = extension.trim();
    }
    if (campus != null && campus.trim().isNotEmpty) {
      body['campus'] = campus.trim();
    }
    return _post('/api/pulse/members/invite', body);
  }

  /// Start outbound call. Backend requires agent_id so every call is tied to an agent.
  static Future<Map<String, dynamic>> startOutboundCall({
    required String agentId,
    required String studentPhone,
    required String studentName,
    String? studentId,
    String? phoneNumberId,
    String? numberId,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? schoolName,
  }) async {
    final body = <String, dynamic>{
      'account_id': _defaultAccountId,
      'agent_id': agentId,
      'student_phone': studentPhone,
      'student_name': studentName,
      'message_type': 'balance_reminder',
    };
    if (studentId != null) body['student_id'] = studentId;
    if (phoneNumberId != null) body['phone_number_id'] = phoneNumberId;
    if (numberId != null) body['number_id'] = numberId;
    if (balance != null) body['balance'] = balance;
    if (dueDate != null) body['due_date'] = dueDate;
    if (lateFee != null) body['late_fee'] = lateFee;
    if (schoolName != null) body['school_name'] = schoolName;
    return SpeariaApi.postJsonMap('/api/pulse/outbound/call', body: body);
  }

  // Settings
  static Future<Map<String, dynamic>> getSettings() async =>
      _get('/api/pulse/settings');

  static Future<Map<String, dynamic>> updateSettings({
    String? schoolName,
    String? defaultLateFee,
    String? currency,
    String? timezone,
    bool? inboundEnabled,
    String? primaryPhoneE164,
    String? vapiAssistantId,
    String? vapiPhoneNumberId,
    String? defaultAgentId,
    String? callScript,
  }) async =>
      _patch('/api/pulse/settings', {
        if (schoolName != null) 'school_name': schoolName,
        if (defaultLateFee != null) 'default_late_fee': defaultLateFee,
        if (currency != null) 'currency': currency,
        if (timezone != null) 'timezone': timezone,
        if (inboundEnabled != null) 'inbound_enabled': inboundEnabled,
        if (primaryPhoneE164 != null) 'primary_phone_e164': primaryPhoneE164,
        if (vapiAssistantId != null) 'vapi_assistant_id': vapiAssistantId,
        if (vapiPhoneNumberId != null) 'vapi_phone_number_id': vapiPhoneNumberId,
        if (defaultAgentId != null) 'default_agent_id': defaultAgentId,
        if (callScript != null) 'call_script': callScript,
      });

  static Future<Map<String, dynamic>> patchSettings(
    Map<String, dynamic> payload,
  ) async {
    return _patch('/api/pulse/settings', payload);
  }

  static Future<bool> sendTestEmail() async {
    final res = await _post('/api/pulse/settings/test-email', {});
    return res['ok'] == true;
  }

  // Reports
  static Future<Map<String, dynamic>> reportsSummary() async =>
      _get('/api/pulse/reports/summary');

  // AI Insights (optional backend endpoint; falls back to deriving from calls)
  static Future<Map<String, dynamic>> getInsights() async {
    try {
      return await _get('/api/pulse/insights');
    } catch (_) {
      return {};
    }
  }

  // -------------------------------------------------------------------------
  // Data integration (school DB → Firestore: webhook, CSV, API pull)
  // -------------------------------------------------------------------------

  /// GET integration config (modes, webhook_secret_set, api_pull_url, field_mapping, last_sync_at)
  static Future<Map<String, dynamic>> getIntegrationConfig() async =>
      _get('/api/pulse/integration/config');

  /// PUT/PATCH integration config (admin). Pass only fields to update.
  static Future<Map<String, dynamic>> setIntegrationConfig({
    bool? enabled,
    List<String>? modes,
    String? webhookSecret,
    String? apiPullUrl,
    Map<String, String>? apiPullHeaders,
    Map<String, String>? fieldMapping,
  }) async {
    final body = <String, dynamic>{};
    if (enabled != null) body['enabled'] = enabled;
    if (modes != null) body['modes'] = modes;
    if (webhookSecret != null) body['webhook_secret'] = webhookSecret;
    if (apiPullUrl != null) body['api_pull_url'] = apiPullUrl;
    if (apiPullHeaders != null) body['api_pull_headers'] = apiPullHeaders;
    if (fieldMapping != null) body['field_mapping'] = fieldMapping;
    return _patch('/api/pulse/integration/config', body);
  }

  /// Seed current account with demo data (school name, students, payments, VAPI placeholders).
  static Future<Map<String, dynamic>> seedDemo() async =>
      _post('/api/pulse/seed-demo', {});

  /// Full demo seed: org doc (with 6-digit account_id), students, payments, call logs, reminders, campaigns, knowledge, templates, members, audit_log, wallet_transactions, call_billing.
  static Future<Map<String, dynamic>> seedFull() async =>
      _post('/api/pulse/seed-full', {});

  /// Ingest CSV (admin/staff). Pass CSV string in body.
  static Future<Map<String, dynamic>> ingestCsv({
    required String csv,
    String? encoding,
  }) async =>
      _post('/api/pulse/integration/ingest/csv', {
        'csv': csv,
        if (encoding != null) 'encoding': encoding,
      });

  /// Trigger API pull sync for the school (admin/staff).
  static Future<Map<String, dynamic>> triggerIntegrationSync() async =>
      _post('/api/pulse/integration/sync', {});

  // School Integration (webhook for SIS/ERP — Phase 6)
  static Future<Map<String, dynamic>> getSchoolIntegration() async =>
      _get('/api/pulse/integrations/school');

  static Future<Map<String, dynamic>> patchSchoolIntegration({required bool enabled}) async =>
      _patch('/api/pulse/integrations/school', {'enabled': enabled});

  static Future<Map<String, dynamic>> regenerateSchoolIntegrationToken() async =>
      SpeariaApi.postJsonMap('/api/pulse/integrations/school/regenerate-token', body: _defaultAccountId.isNotEmpty ? {'account_id': _defaultAccountId} : {});

  static Future<Map<String, dynamic>> sendSchoolWebhookTest() async =>
      _post('/api/pulse/integrations/school/test', {});

  // -------------------------------------------------------------------------
  // CRM Integrations (Slate)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getSlateIntegration() async =>
      _get('/api/pulse/integrations/slate');

  static Future<Map<String, dynamic>> setSlateIntegration({
    bool? enabled,
    String? webhookUrl,
    String? authToken,
  }) async {
    return _patch('/api/pulse/integrations/slate', {
      if (enabled != null) 'enabled': enabled,
      if (webhookUrl != null) 'webhook_url': webhookUrl,
      if (authToken != null) 'auth_token': authToken,
    });
  }

  static Future<Map<String, dynamic>> testSlateIntegration() async =>
      _post('/api/pulse/integrations/slate/test', {});

  // -------------------------------------------------------------------------
  // Calendar Integrations (Calendly)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getCalendlyIntegration() async =>
      _get('/api/pulse/integrations/calendly');

  static Future<Map<String, dynamic>> setCalendlyIntegration({
    bool? enabled,
    String? eventTypeUri,
  }) async {
    return _patch('/api/pulse/integrations/calendly', {
      if (enabled != null) 'enabled': enabled,
      if (eventTypeUri != null) 'event_type_uri': eventTypeUri,
    });
  }

  static Future<Map<String, dynamic>> listCalendlyEventTypes() async =>
      _post('/api/pulse/integrations/calendly/event-types', {});

  static Future<Map<String, dynamic>> startCalendlyOAuth() async =>
      _get('/api/pulse/integrations/calendly/oauth/start',
          params: _defaultAccountId.isNotEmpty ? {'account_id': _defaultAccountId} : null,
          shellScoped: true);

  static Future<Map<String, dynamic>> disconnectCalendly() async =>
      _post('/api/pulse/integrations/calendly/disconnect', {});

  // -------------------------------------------------------------------------
  // Call templates (scripts for assistant)
  // -------------------------------------------------------------------------

  /// List call templates for the school.
  static Future<Map<String, dynamic>> listCallTemplates() async {
    try {
      return await _get('/api/pulse/call_templates');
    } catch (_) {
      return {'templates': []};
    }
  }

  /// Create a call template (name, body/script with placeholders).
  static Future<Map<String, dynamic>> createCallTemplate({
    required String name,
    required String body,
  }) async =>
      _post('/api/pulse/call_templates', {'name': name, 'body': body});

  /// Update a call template.
  static Future<Map<String, dynamic>> updateCallTemplate(
    String id, {
    String? name,
    String? body,
  }) async {
    final b = <String, dynamic>{};
    if (name != null) b['name'] = name;
    if (body != null) b['body'] = body;
    return _patch('/api/pulse/call_templates/$id', b);
  }

  /// Delete a call template.
  static Future<void> deleteCallTemplate(String id) async =>
      SpeariaApi.deleteJson('/api/pulse/call_templates/$id', params: {'account_id': _defaultAccountId});

  // -------------------------------------------------------------------------
  // AI Script Enhancer
  // -------------------------------------------------------------------------

  /// Enhance a raw script into a production-grade Vapi system prompt.
  static Future<Map<String, dynamic>> enhanceScript({
    required String script,
    String? context,
    String agentType = 'outbound_campaign',
    String tone = 'professional',
    String complianceMode = 'recording_disclosure',
    List<String>? requiredPhrases,
    List<String>? bannedPhrases,
    Map<String, dynamic>? variables,
    String language = 'en-US',
  }) async {
    final body = <String, dynamic>{
      'script': script,
      if (context != null && context.trim().isNotEmpty) 'context': context.trim(),
      'agentType': agentType,
      'tone': tone,
      'complianceMode': complianceMode,
      'requiredPhrases': requiredPhrases ?? const <String>[],
      'bannedPhrases': bannedPhrases ?? const <String>[],
      'variables': variables ?? const <String, dynamic>{},
      'language': language,
    };
    final res = await _post('/api/pulse/script/enhance', body);
    return Map<String, dynamic>.from(res as Map);
  }

  // -------------------------------------------------------------------------
  // Campaigns (bulk outbound calls by filters, snapshot-based execution)
  // -------------------------------------------------------------------------

  /// List campaigns for the school. Pass [limit] to control how many are returned (default 100).
  static Future<Map<String, dynamic>> listCampaigns({
    int limit = 100,
    String? cursor,
    Duration? timeout,
  }) async {
    try {
      return await _get(
        '/api/pulse/campaigns',
        params: {
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
        },
        timeout: timeout,
      );
    } catch (_) {
      return {'campaigns': []};
    }
  }

  /// Compact dashboard payload for instant first paint.
  static Future<Map<String, dynamic>> getDashboardSummary({
    String? from,
    String? to,
    int recentCallsLimit = 8,
    int recentCampaignsLimit = 8,
    Duration? timeout,
  }) async {
    final params = <String, dynamic>{
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      'recent_calls_limit': recentCallsLimit.clamp(1, 20),
      'recent_campaigns_limit': recentCampaignsLimit.clamp(1, 20),
    };
    try {
      return _get('/api/pulse/dashboard/summary', params: params, timeout: timeout);
    } on ApiException catch (e) {
      // Backward-compatible fallback for deployments that do not expose
      // /api/pulse/dashboard/summary yet.
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      final callsFuture = listCalls(
        from: from,
        to: to,
        limit: recentCallsLimit.clamp(1, 20),
        timeout: timeout,
      ).catchError((_) => <String, dynamic>{'calls': const []});
      final campaignsFuture = listCampaigns(
        limit: recentCampaignsLimit.clamp(1, 20),
        timeout: timeout,
      ).catchError((_) => <String, dynamic>{'campaigns': const []});
      final agentsFuture =
          listAgents(timeout: timeout).catchError((_) => <String, dynamic>{'agents': const []});
      final numbersFuture = listNumbers(timeout: timeout)
          .catchError((_) => <String, dynamic>{'numbers': const [], 'items': const []});
      final ubFuture = getUbStatus(timeout: timeout).catchError((_) => <String, dynamic>{});

      final results = await Future.wait<dynamic>([
        callsFuture,
        campaignsFuture,
        agentsFuture,
        numbersFuture,
        ubFuture,
      ]);
      final callsRes = Map<String, dynamic>.from(results[0] as Map);
      final campaignsRes = Map<String, dynamic>.from(results[1] as Map);
      final agentsRes = Map<String, dynamic>.from(results[2] as Map);
      final numbersRes = Map<String, dynamic>.from(results[3] as Map);
      final ubRes = Map<String, dynamic>.from(results[4] as Map);

      final recentCalls = ((callsRes['calls'] as List?) ?? const <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final recentCampaigns = ((campaignsRes['campaigns'] as List?) ?? const <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final operators = ((agentsRes['agents'] as List?) ?? const <dynamic>[]);
      final numbers = ((numbersRes['numbers'] as List?) ??
              (numbersRes['items'] as List?) ??
              const <dynamic>[])
          .toList();
      final completedCalls = recentCalls.where((c) {
        final status = (c['status'] ?? c['result'] ?? '').toString().toLowerCase();
        return status.contains('completed') || status.contains('success') || status.contains('answered');
      }).length;

      return {
        'ok': true,
        'setup': {
          'business_configured': true,
          'operator_count': operators.length,
          'number_live': numbers.isNotEmpty,
          'first_call_completed': completedCalls > 0,
          'ub_status': (ubRes['status'] ?? 'missing').toString().toLowerCase(),
          'training_number': (numbers.isNotEmpty ? (numbers.first['phone'] ?? numbers.first['number']) : null),
        },
        'kpi': {
          'calls_total': recentCalls.length,
        },
        'recent_calls': recentCalls,
        'recent_campaigns': recentCampaigns,
      };
    }
  }

  /// Get a single campaign by id (full details).
  static Future<Map<String, dynamic>> getCampaign(String campaignId) async =>
      _get('/api/pulse/campaigns/$campaignId');

  /// Detailed campaign report: campaign, agent, template, call items, and per-call insights.
  static Future<Map<String, dynamic>> getCampaignReport(String campaignId) async =>
      _get('/api/pulse/campaigns/${Uri.encodeComponent(campaignId)}/report');

  /// On-demand action items for a campaign call (OpenAI from transcript + operator goal). Returns { ok, action_items: [...] }.
  static Future<Map<String, dynamic>> getCallActionable(String campaignId, String vapiCallId) async =>
      _get('/api/pulse/campaigns/${Uri.encodeComponent(campaignId)}/calls/${Uri.encodeComponent(vapiCallId)}/actionable');

  /// Full campaign export: name, student id, phone, status, outcome, action insights (cached on call log when present).
  /// Large campaigns can take minutes, so callers can override timeout.
  static Future<Map<String, dynamic>> getCampaignExport(
    String campaignId, {
    Duration timeout = const Duration(minutes: 10),
  }) async =>
      _get('/api/pulse/campaigns/${Uri.encodeComponent(campaignId)}/export', timeout: timeout);

  static Future<Map<String, dynamic>> createCampaignExportJob(String campaignId) async =>
      _post('/api/pulse/campaigns/${Uri.encodeComponent(campaignId)}/export/jobs', {});

  static Future<Map<String, dynamic>> getCampaignExportJobStatus(String jobId) async =>
      _get('/api/pulse/campaigns/export/jobs/${Uri.encodeComponent(jobId)}');

  static Future<Map<String, dynamic>> downloadCampaignExportJob(String jobId) async =>
      _get('/api/pulse/campaigns/export/jobs/${Uri.encodeComponent(jobId)}/download', timeout: const Duration(minutes: 5));

  /// Server-built campaign CSV: `{ ok, filename, csv_content }`.
  ///
  /// Tries async job path (`POST .../export/jobs` with 90s timeout, poll, then download). If the
  /// server has no job API or creation fails, falls back to synchronous `GET .../export` (10 min).
  ///
  /// When a job runs to completion then fails terminal status, or poll times out, throws (no sync fallback).
  /// [onProgress] is only called along the job poll path.
  static Future<Map<String, dynamic>> fetchCampaignSpreadsheetExport(
    String campaignId, {
    void Function({required int processed, required int total, required String status})? onProgress,
  }) async {
    Map<String, dynamic> create;
    try {
      create = await _post(
        '/api/pulse/campaigns/${Uri.encodeComponent(campaignId)}/export/jobs',
        {},
        timeout: const Duration(seconds: 90),
      );
    } catch (_) {
      return getCampaignExport(campaignId, timeout: const Duration(minutes: 10));
    }

    final jobId = (create['job_id'] ?? '').toString();
    if (create['ok'] != true || jobId.isEmpty) {
      return getCampaignExport(campaignId, timeout: const Duration(minutes: 10));
    }

    Map<String, dynamic>? terminalStatus;
    for (var i = 0; i < 240; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final Map<String, dynamic> status;
      try {
        status = await getCampaignExportJobStatus(jobId);
      } catch (_) {
        return getCampaignExport(campaignId, timeout: const Duration(minutes: 10));
      }
      final processed = (status['processed_items'] as num?)?.toInt() ?? 0;
      final total = (status['total_items'] as num?)?.toInt() ?? 0;
      final stText = (status['status'] ?? '').toString();
      onProgress?.call(processed: processed, total: total, status: stText);
      final st = stText.toLowerCase();
      if (st == 'completed' || st == 'failed' || st == 'cancelled') {
        terminalStatus = status;
        break;
      }
    }
    if (terminalStatus == null) {
      throw Exception('Export timed out while waiting for completion');
    }
    final st = (terminalStatus['status'] ?? '').toString().toLowerCase();
    if (st != 'completed') {
      throw Exception(terminalStatus['error']?.toString() ?? 'Export ended with status: $st');
    }
    try {
      return await downloadCampaignExportJob(jobId);
    } catch (_) {
      return getCampaignExport(campaignId, timeout: const Duration(minutes: 10));
    }
  }

  /// List calls placed for a campaign (full call docs including transcript, outcome_type). Use [limit] to fetch more (e.g. 500 for "all").
  static Future<Map<String, dynamic>> getCampaignCalls(String campaignId, {int limit = 100}) async =>
      _get('/api/pulse/campaigns/${Uri.encodeComponent(campaignId)}/calls', params: {'limit': limit});

  /// Real-time campaign runner metrics (pool status + counters).
  static Future<Map<String, dynamic>> getCampaignMetrics(
    String campaignId, {
    Duration? timeout,
  }) async =>
      _get('/api/pulse/campaigns/$campaignId/metrics', timeout: timeout);

  /// Per-target campaign call items (queued/in_progress/completed/failed).
  static Future<Map<String, dynamic>> getCampaignCallItems(
    String campaignId, {
    String? status,
    int limit = 200,
    Duration? timeout,
  }) async =>
      _get(
        '/api/pulse/campaigns/$campaignId/call-items',
        params: {
          if (status != null && status.isNotEmpty) 'status': status,
          'limit': limit,
        },
        timeout: timeout,
      );

  /// Verify campaign integrity and counters (backend auto-heals minor issues).
  static Future<Map<String, dynamic>> verifyCampaign(String campaignId) async =>
      _get('/api/pulse/campaigns/$campaignId/verify');

  /// Manually reclaim stuck calls and refill the pool for a campaign.
  /// POST /api/pulse/campaigns/<id>/reclaim-stuck
  static Future<Map<String, dynamic>> reclaimStuckCampaign(String campaignId) async =>
      _post('/api/pulse/campaigns/$campaignId/reclaim-stuck', {});

  /// Preview audience count and sample for financial filters (education campaigns).
  static Future<Map<String, dynamic>> getCampaignsPreviewAudience({
    bool? hasBalance,
    bool? isOverdue,
    double? balanceMin,
    double? balanceMax,
    String? dueBefore,
    String? dueAfter,
  }) async {
    final params = <String, dynamic>{};
    if (hasBalance != null) params['has_balance'] = hasBalance;
    if (isOverdue != null) params['is_overdue'] = isOverdue;
    if (balanceMin != null) params['balance_min'] = balanceMin;
    if (balanceMax != null) params['balance_max'] = balanceMax;
    if (dueBefore != null) params['due_before'] = dueBefore;
    if (dueAfter != null) params['due_after'] = dueAfter;
    return _get('/api/pulse/campaigns/preview-audience', params: params.isEmpty ? null : params);
  }

  // ---------------- Campaign basics (no audience fields) ----------------

  /// Create campaign basics only (name/agent/profile/template/limits/schedule).
  /// Backend rejects any audience fields on this endpoint.
  static Future<Map<String, dynamic>> createCampaignBasics({
    required String name,
    String? agentId,
    String? profileId,
    String? templateId,
    int? maxConcurrent,
    int? maxAttempts,
    DateTime? scheduledAt,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (agentId != null && agentId.isNotEmpty) 'agent_id': agentId,
      if (profileId != null && profileId.isNotEmpty) 'profile_id': profileId,
      if (templateId != null && templateId.isNotEmpty) 'template_id': templateId,
      if (maxConcurrent != null) 'max_concurrent': maxConcurrent,
      if (maxAttempts != null) 'max_attempts': maxAttempts,
      if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    if (_defaultAccountId.isNotEmpty) body['account_id'] = _defaultAccountId;
    return _post('/api/pulse/campaigns', body);
  }

  /// Backwards-compatible wrapper for legacy callers.
  /// NOTE: audience-related arguments are intentionally ignored to respect
  /// backend invariants. Use createCampaignBasics + updateCampaignAudience instead.
  static Future<Map<String, dynamic>> createCampaign({
    required String name,
    String? agentId,
    String? profileId,
    String? templateId,
    List<String>? studentIds, // ignored
    Map<String, dynamic>? filters, // ignored
    String? audienceType, // ignored
    DateTime? scheduledAt,
  }) {
    return createCampaignBasics(
      name: name,
      agentId: agentId,
      profileId: profileId,
      templateId: templateId,
      scheduledAt: scheduledAt,
    );
  }

  /// Update campaign basics (no audience changes).
  static Future<Map<String, dynamic>> updateCampaignBasics(
    String campaignId, {
    String? name,
    String? agentId,
    String? profileId,
    String? templateId,
    int? maxConcurrent,
    int? maxAttempts,
    DateTime? scheduledAt,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (_defaultAccountId.isNotEmpty) body['account_id'] = _defaultAccountId;
    if (name != null) body['name'] = name;
    if (agentId != null) body['agent_id'] = agentId.isEmpty ? null : agentId;
    if (profileId != null) body['profile_id'] = profileId.isEmpty ? null : profileId;
    if (templateId != null) body['template_id'] = templateId;
    if (maxConcurrent != null) body['max_concurrent'] = maxConcurrent;
    if (maxAttempts != null) body['max_attempts'] = maxAttempts;
    if (scheduledAt != null) body['scheduled_at'] = scheduledAt.toIso8601String();
    if (notes != null) body['notes'] = notes;
    return _patch('/api/pulse/campaigns/$campaignId', body);
  }

  /// Backwards-compatible wrapper that now only updates basics.
  static Future<Map<String, dynamic>> updateCampaign(
    String campaignId, {
    String? name,
    String? agentId,
    String? profileId,
    String? templateId,
    List<String>? studentIds, // ignored
    Map<String, dynamic>? filters, // ignored
    DateTime? scheduledAt,
  }) {
    return updateCampaignBasics(
      campaignId,
      name: name,
      agentId: agentId,
      profileId: profileId,
      templateId: templateId,
      scheduledAt: scheduledAt,
    );
  }

  // ---------------- Audience & snapshot endpoints ----------------

  /// Configure campaign audience. This is the ONLY place audience_mode / filters / student_ids are sent.
  static Future<Map<String, dynamic>> updateCampaignAudience(
    String campaignId, {
    required String audienceMode, // 'FILTERS' | 'MANUAL'
    Map<String, dynamic>? audienceFilters,
    List<String>? studentIds,
  }) async {
    final body = <String, dynamic>{
      'audience_mode': audienceMode,
      if (_defaultAccountId.isNotEmpty) 'account_id': _defaultAccountId,
    };
    if (audienceMode == 'FILTERS') {
      body['audience_filters'] = audienceFilters ?? <String, dynamic>{};
    } else if (audienceMode == 'MANUAL') {
      body['student_ids'] = studentIds ?? <String>[];
    }
    final v = await SpeariaApi.patchJson('/api/pulse/campaigns/$campaignId/audience', body: body);
    return Map<String, dynamic>.from(v as Map);
  }

  /// Build immutable audience snapshot + validation.
  static Future<Map<String, dynamic>> prepareCampaign(String campaignId) async =>
      _post('/api/pulse/campaigns/$campaignId/prepare', {});

  /// Latest validation + snapshot status.
  static Future<Map<String, dynamic>> getCampaignValidation(String campaignId) async =>
      _get('/api/pulse/campaigns/$campaignId/validation');

  /// Paginated immutable audience snapshot.
  static Future<Map<String, dynamic>> getCampaignAudienceSnapshot(
    String campaignId, {
    int limit = 50,
    int offset = 0,
    String? source, // FILTERS | MANUAL
    bool? hasError,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (source != null && source.isNotEmpty) 'source': source,
      if (hasError != null) 'has_error': hasError,
    };
    return _get('/api/pulse/campaigns/$campaignId/audience-snapshot', params: params);
  }

  /// Start a snapshot-validated campaign run. This endpoint enforces that a complete,
  /// valid snapshot exists and will surface SNAPSHOT_NOT_READY / VALIDATION_FAILED codes.
  static Future<Map<String, dynamic>> startCampaignSnapshotRun(
    String campaignId, {
    int? maxConcurrent,
    int? maxAttempts,
    String? phoneNumberId,
  }) async {
    final body = <String, dynamic>{
      if (_defaultAccountId.isNotEmpty) 'account_id': _defaultAccountId,
      if (maxConcurrent != null) 'max_concurrent': maxConcurrent,
      if (maxAttempts != null) 'max_attempts': maxAttempts,
      if (phoneNumberId != null && phoneNumberId.isNotEmpty) 'phone_number_id': phoneNumberId,
    };
    return SpeariaApi.postJsonMap(
      '/api/pulse/campaigns/$campaignId/start',
      body: body,
      timeout: const Duration(seconds: 120),
    );
  }

  /// Backwards-compatible wrapper; deprecated. Use startCampaignSnapshotRun instead.
  static Future<Map<String, dynamic>> startCampaign(
    String campaignId, {
    List<String>? studentIds, // ignored
    int? maxConcurrent,
    int? maxAttempts,
    String? phoneNumberId,
  }) {
    return startCampaignSnapshotRun(
      campaignId,
      maxConcurrent: maxConcurrent,
      maxAttempts: maxAttempts,
      phoneNumberId: phoneNumberId,
    );
  }

  /// Retry calls for specific students in the same campaign (e.g. voicemail / not connected).
  /// Does not create a new campaign.
  static Future<Map<String, dynamic>> retryCampaignCalls(
    String campaignId,
    List<String> studentIds, {
    String? phoneNumberId,
  }) async {
    final body = <String, dynamic>{
      'student_ids': studentIds,
      if (phoneNumberId != null && phoneNumberId.isNotEmpty) 'phone_number_id': phoneNumberId,
    };
    return SpeariaApi.postJsonMap(
      '/api/pulse/campaigns/$campaignId/retry',
      body: body,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Rebuild audience: deletes snapshot and unlocks audience config.
  static Future<Map<String, dynamic>> rebuildCampaignAudience(String campaignId) async =>
      _post('/api/pulse/campaigns/$campaignId/rebuild-audience', {});

  /// Pause a running campaign (stops refilling the pool; active calls still finish).
  static Future<Map<String, dynamic>> pauseCampaign(String campaignId) async =>
      _post('/api/pulse/campaigns/$campaignId/pause', {});

  /// Resume a paused campaign (refills the pool again).
  static Future<Map<String, dynamic>> resumeCampaign(String campaignId) async =>
      _post('/api/pulse/campaigns/$campaignId/resume', {});

  /// Stop the campaign immediately: end all active calls and set status to stopped.
  static Future<Map<String, dynamic>> stopCampaign(String campaignId) async =>
      _post('/api/pulse/campaigns/$campaignId/stop', {});

  /// Delete a campaign (only draft or scheduled). Returns 404 if not found or not deletable.
  static Future<void> deleteCampaign(String campaignId) async {
    await SpeariaApi.deleteJson(
      '/api/pulse/campaigns/$campaignId',
      params: <String, dynamic>{'account_id': _defaultAccountId},
    );
  }

  // -------------------------------------------------------------------------
  // Billing (wallet, tier, usage)
  // -------------------------------------------------------------------------

  /// Use [shellScoped] true for Pulse shell / global billing providers.
  static Future<Map<String, dynamic>> getBillingWallet({Duration? timeout, bool shellScoped = false}) async {
    final now = DateTime.now();
    if (_cachedBillingWallet != null &&
        _cachedBillingWalletAt != null &&
        now.difference(_cachedBillingWalletAt!) < _cacheTtl) {
      return _cachedBillingWallet!;
    }
    final res = await _get('/api/billing/wallet', timeout: timeout, shellScoped: shellScoped);
    _cachedBillingWallet = res;
    _cachedBillingWalletAt = now;
    return res;
  }

  /// Create Stripe Checkout session for wallet pack or custom amount. Returns { url }.
  /// Use pack ('starter','growth','scale') or amountDollars (20–100000).
  static Future<Map<String, dynamic>> createCheckoutSession(
    String pack, {
    String? successUrl,
    String? cancelUrl,
    String? customerEmail,
    double? amountDollars,
  }) async {
    final body = <String, dynamic>{
      'account_id': _defaultAccountId,
    };
    if (amountDollars != null && amountDollars >= 20 && amountDollars <= 100000) {
      body['amount_dollars'] = amountDollars;
    } else {
      body['pack'] = pack;
    }
    if (successUrl != null) body['success_url'] = successUrl;
    if (cancelUrl != null) body['cancel_url'] = cancelUrl;
    if (customerEmail != null) body['customer_email'] = customerEmail;
    return SpeariaApi.postJsonMap('/api/billing/wallet/create-checkout-session', body: body);
  }

  static Future<Map<String, dynamic>> purchaseCredits(String pack) async =>
      SpeariaApi.postJsonMap('/api/billing/wallet/purchase', body: {
        'account_id': _defaultAccountId,
        'pack': pack,
      });

  static Future<Map<String, dynamic>> getBillingTransactions({
    int limit = 50,
    int offset = 0,
    String type = 'all',
  }) async =>
      _get('/api/billing/transactions', params: {
        'limit': limit,
        'offset': offset,
        'type': type,
      });

  static Future<Map<String, dynamic>> getBillingUsage({
    String? from,
    String? to,
    bool shellScoped = false,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _get('/api/billing/usage',
        params: params.isEmpty ? null : params, shellScoped: shellScoped);
  }

  static Future<Map<String, dynamic>> getBillingTier() async =>
      _get('/api/billing/tier');

  static Future<Map<String, dynamic>> setBillingTier(String tier) async {
    final v = await SpeariaApi.putJson('/api/billing/tier', body: {
      'account_id': _defaultAccountId,
      'tier': tier,
    });
    return Map<String, dynamic>.from(v as Map);
  }

  /// Enable/disable per-agent voice tier (Business plan only). All agents use account default when disabled.
  static Future<Map<String, dynamic>> setBillingPerAgentVoiceTier(bool enabled) async {
    final v = await SpeariaApi.putJson('/api/billing/per-agent-voice-tier', body: {
      'enabled': enabled,
    });
    return Map<String, dynamic>.from(v as Map);
  }

  // -------------------------------------------------------------------------
  // Subscription (plan selector: subscribe, cancel, upgrade)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getSubscription({bool shellScoped = false}) async =>
      _get('/api/billing/subscription', shellScoped: shellScoped);

  static Future<Map<String, dynamic>> subscribe(String plan) async =>
      _post('/api/billing/subscribe', {'plan': plan});

  static Future<Map<String, dynamic>> cancelSubscription() async {
    final v = await SpeariaApi.deleteJson('/api/billing/subscribe', params: {'account_id': _defaultAccountId});
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<Map<String, dynamic>> upgradeSubscription(String plan) async {
    final v = await SpeariaApi.putJson('/api/billing/subscription/upgrade', body: {'account_id': _defaultAccountId, 'plan': plan});
    return Map<String, dynamic>.from(v as Map);
  }

  // -------------------------------------------------------------------------
  // Add-ons (Shield, HIPAA)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> setAddonShield({required String numberId, required bool enabled}) async =>
      _patch('/api/billing/addons/shield', {'number_id': numberId, 'enabled': enabled});

  static Future<Map<String, dynamic>> setAddonHipaa({required bool enabled}) async =>
      _patch('/api/billing/addons/hipaa', {'enabled': enabled});

  // -------------------------------------------------------------------------
  // Voice library (GET /api/voices, POST /api/voices/preview)
  // -------------------------------------------------------------------------

  /// GET /api/voices?tier=neutral|natural|ultra|all. Returns list or grouped by tier.
  static Future<dynamic> getVoices({String tier = 'all'}) async =>
      _get('/api/voices', params: {'tier': tier});

  /// POST /api/voices/preview — free preview. Returns { audio_url } or { audio_base64, content_type }.
  static Future<Map<String, dynamic>> postVoicePreview({
    required String voiceId,
    required String provider,
    String? text,
  }) async {
    final body = <String, dynamic>{
      'voice_id': voiceId,
      'provider': provider,
      if (_defaultAccountId.isNotEmpty) 'account_id': _defaultAccountId,
    };
    if (text != null && text.isNotEmpty) body['text'] = text;
    return SpeariaApi.postJsonMap('/api/voices/preview', body: body);
  }

  // -------------------------------------------------------------------------
  // Outbound capacity (Part 2: phone numbers, primary vs campaign)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getOutboundPhoneNumbers({String? date}) async =>
      _get('/api/pulse/outbound/phone-numbers', params: date != null ? {'date': date} : null);

  static Future<Map<String, dynamic>> getOutboundCapacity() async =>
      _get('/api/pulse/outbound/capacity');

  /// Set primary outbound phone number for this account.
  /// Accepts either a Vapi phone_number_id (UUID) OR an E.164 number (e.g. +1888...) which backend can import.
  static Future<Map<String, dynamic>> setOutboundPrimary(
    String phoneNumberIdOrE164, {
    String? phoneNumberE164,
  }) async {
    final v = await SpeariaApi.putJson('/api/pulse/outbound/primary', body: {
      'account_id': _defaultAccountId,
      'phone_number_id': phoneNumberIdOrE164,
      if (phoneNumberE164 != null && phoneNumberE164.isNotEmpty) 'phone_number_e164': phoneNumberE164,
    });
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<Map<String, dynamic>> addOutboundCampaignNumber(String phoneNumberId, {String? label}) async =>
      _post('/api/pulse/outbound/phone-numbers', {
        'phone_number_id': phoneNumberId,
        if (label != null) 'label': label,
      });

  static Future<void> removeOutboundCampaignNumber(String phoneNumberId) async =>
      SpeariaApi.deleteJson(
        '/api/pulse/outbound/phone-numbers/$phoneNumberId',
        params: {'account_id': _defaultAccountId},
      );

  // -------------------------------------------------------------------------
  // Outbound number management (Twilio: buy, roles, warm-up, daily limits)
  // -------------------------------------------------------------------------

  /// GET /api/numbers – list owned numbers (includes attached primary from org). Sends account_id so backend returns merged list.
  /// Use [shellScoped] true for Pulse shell / global numbers providers.
  static Future<Map<String, dynamic>> listNumbers({Duration? timeout, bool shellScoped = false}) async {
    final now = DateTime.now();
    if (_cachedNumbers != null &&
        _cachedNumbersAt != null &&
        now.difference(_cachedNumbersAt!) < _cacheTtl) {
      return _cachedNumbers!;
    }
    final res = await _get('/api/numbers',
        params: {'account_id': _defaultAccountId}, timeout: timeout, shellScoped: shellScoped);
    _cachedNumbers = res;
    _cachedNumbersAt = now;
    return res;
  }

  /// POST /api/numbers/sync-from-vapi – link all VAPI numbers that are not yet in this account so they appear on the Phone Numbers page.
  static Future<Map<String, dynamic>> syncNumbersFromVapi() async =>
      _post('/api/numbers/sync-from-vapi', {});

  /// POST /api/numbers/attach – link an existing number to this account (no admin token). Number will appear on Phone Numbers page.
  static Future<Map<String, dynamic>> attachNumber({
    required String phoneNumberId,
    required String phoneNumberE164,
    String? friendlyName,
  }) async =>
      _post('/api/numbers/attach', {
        'phone_number_id': phoneNumberId,
        'phone_number_e164': phoneNumberE164,
        if (friendlyName != null && friendlyName.isNotEmpty) 'friendly_name': friendlyName,
      });

  /// POST /api/numbers/import – import an existing carrier number into VAPI and link it to this org.
  /// Credentials are provided one-time and are not stored server-side.
  static Future<Map<String, dynamic>> importNumber({
    required String provider,
    required String numberE164,
    String? friendlyName,
    bool setAsPrimary = true,
    String? twilioAccountSid,
    String? twilioAuthToken,
    String? telnyxApiKey,
    String? vonageApiKey,
    String? vonageApiSecret,
  }) async {
    final body = <String, dynamic>{
      'provider': provider.trim(),
      'number': numberE164.trim(),
      'set_as_primary': setAsPrimary,
      if (friendlyName != null && friendlyName.trim().isNotEmpty) 'friendly_name': friendlyName.trim(),
      if (twilioAccountSid != null && twilioAccountSid.trim().isNotEmpty) 'twilioAccountSid': twilioAccountSid.trim(),
      if (twilioAuthToken != null && twilioAuthToken.trim().isNotEmpty) 'twilioAuthToken': twilioAuthToken.trim(),
      if (telnyxApiKey != null && telnyxApiKey.trim().isNotEmpty) 'telnyxApiKey': telnyxApiKey.trim(),
      if (vonageApiKey != null && vonageApiKey.trim().isNotEmpty) 'vonageApiKey': vonageApiKey.trim(),
      if (vonageApiSecret != null && vonageApiSecret.trim().isNotEmpty) 'vonageApiSecret': vonageApiSecret.trim(),
    };
    return _post('/api/numbers/import', body);
  }

  /// GET /api/numbers/search — list available numbers with optional filters.
  /// Pass country, type (local|mobile|tollfree), limit, areaCode, voiceEnabled, smsEnabled, mmsEnabled, includeSuggested.
  static Future<Map<String, dynamic>> searchNumbers({
    String country = 'US',
    String type = 'local',
    int limit = 20,
    String? areaCode,
    bool? voiceEnabled,
    bool? smsEnabled,
    bool? mmsEnabled,
    bool includeSuggested = true,
  }) async {
    final params = <String, dynamic>{
      'country': country,
      'type': type,
      'limit': limit.toString(),
      'include_suggested': includeSuggested.toString(),
    };
    if (areaCode != null && areaCode.trim().isNotEmpty) params['area_code'] = areaCode.trim();
    if (voiceEnabled != null) params['voice_enabled'] = voiceEnabled.toString();
    if (smsEnabled != null) params['sms_enabled'] = smsEnabled.toString();
    if (mmsEnabled != null) params['mms_enabled'] = mmsEnabled.toString();
    return _get('/api/numbers/search', params: params);
  }

  /// POST /api/numbers/purchase – buy number (phone_number, friendly_name). Sends account_id for Pulse.
  /// Role is now determined server-side:
  /// - First number for an account becomes primary automatically.
  /// - Subsequent numbers are campaign numbers, but can be promoted to primary later.
  static Future<Map<String, dynamic>> purchaseNumber({
    required String phoneNumber,
    required String friendlyName,
  }) async =>
      _post('/api/numbers/purchase', {
        'account_id': _defaultAccountId,
        'phone_number': phoneNumber,
        'friendly_name': friendlyName,
      });

  /// PUT /api/numbers/<number_id> – update friendly_name, role, registered_freecaller
  static Future<Map<String, dynamic>> updateNumber(
    String numberId, {
    String? friendlyName,
    String? role,
    bool? registeredFreecaller,
  }) async {
    final body = <String, dynamic>{'account_id': _defaultAccountId};
    if (friendlyName != null) body['friendly_name'] = friendlyName;
    if (role != null) body['role'] = role;
    if (registeredFreecaller != null) body['registered_freecaller'] = registeredFreecaller;
    final v = await SpeariaApi.putJson('/api/numbers/$numberId', body: body);
    return Map<String, dynamic>.from(v as Map);
  }

  /// DELETE /api/numbers/<number_id>
  static Future<void> releaseNumber(String numberId) async =>
      SpeariaApi.deleteJson(
        '/api/numbers/$numberId',
        params: {'account_id': _defaultAccountId},
      );

  /// POST /api/numbers/<number_id>/register-freecaller
  static Future<Map<String, dynamic>> registerFreecaller(String numberId) async =>
      SpeariaApi.postJsonMap(
        '/api/numbers/$numberId/register-freecaller',
        body: {'account_id': _defaultAccountId},
      );

  /// GET /api/numbers/<number_id>/warm-up/status
  static Future<Map<String, dynamic>> getWarmUpStatus(String numberId) async =>
      _get('/api/numbers/$numberId/warm-up/status');

  /// GET /api/numbers/<number_id>/capacity — daily_limit, used_today, remaining_today, warning.
  static Future<Map<String, dynamic>> getNumberCapacity(String numberId) async =>
      _get('/api/numbers/$numberId/capacity');

  /// POST /api/numbers/<number_id>/warm-up/advance (manual from dev console)
  static Future<Map<String, dynamic>> advanceWarmUp(String numberId) async =>
      SpeariaApi.postJsonMap(
        '/api/numbers/$numberId/warm-up/advance',
        body: {'account_id': _defaultAccountId},
      );

  /// POST /api/pulse/campaigns/estimate – estimate days for contacts + number ids
  static Future<Map<String, dynamic>> campaignEstimate({
    required int totalContacts,
    required List<String> assignedNumberIds,
  }) async =>
      _post('/api/pulse/campaigns/estimate', {
        'total_contacts': totalContacts,
        'assigned_number_ids': assignedNumberIds,
      });

  /// GET /api/pulse/campaigns/estimate/quick?contacts=1000
  static Future<Map<String, dynamic>> campaignEstimateQuick({required int contacts}) async =>
      _get('/api/pulse/campaigns/estimate/quick', params: {'contacts': contacts});
}
