// lib/screens/campaigns_page.dart
// Campaigns: bulk outbound calls with filters, templates, and scheduling (like ad campaigns).

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_response_cache.dart';
import '../api/neyvo_api.dart';
import '../core/providers/campaigns_provider.dart';
import '../core/providers/account_provider.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../services/user_timezone_service.dart';
import '../theme/neyvo_theme.dart';
import '../utils/csv_import.dart';
import '../utils/export_csv.dart';
import '../utils/phone_util.dart';
import '../widgets/neyvo_empty_state.dart';
import 'call_detail_page.dart';

class CampaignsPage extends ConsumerStatefulWidget {
  const CampaignsPage({super.key});

  @override
  ConsumerState<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends ConsumerState<CampaignsPage> {
  List<Map<String, dynamic>> _campaigns = [];
  static const int _campaignsPageSize = 25;
  String? _campaignsCursor;
  bool _campaignsHasMore = false;
  bool _campaignsLoadingMore = false;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _agents = [];
  static const int _studentsPageLimit = 50;
  int _studentsOffset = 0;
  int _studentsTotal = 0;
  String? _studentsCursor;
  bool _studentsHasMore = false;
  bool _studentsInitialLoading = false;
  bool _studentsLoadingMore = false;
  final ScrollController _audienceScrollController = ScrollController();
  bool _selectAllInProgress = false;
  String? _allMatchingIdsCacheKey;
  Set<String> _allMatchingIdsCache = {};
  /// For contact-list campaigns only: quick lookup so the audience picker can show if a contact is already in another campaign.
  /// Key: student id, Value: list of campaign names.
  Map<String, List<String>> _studentCampaignNames = {};
  /// Latest known call time for each student (for audience picker hints).
  Map<String, DateTime> _lastCallAtByStudentId = {};
  /// Combined list for operator dropdown: each has 'value' (agent:id or profile:id), 'name', 'type' (agent|profile).
  List<Map<String, dynamic>> _operatorsForCampaign = [];
  bool _loading = true;
  String? _error;
  bool _showCreateWizard = false;
  int _wizardStep = 0;
  String? _selectedCampaignId;
  /// Full detail fetch (campaign + calls + metrics); recreated on explicit refresh only — not every 5s tick.
  Future<Map<String, dynamic>>? _campaignDetailBundleFuture;
  String? _selectedActionsTabVapiCallId;
  /// On-demand action items per vapi_call_id (GET .../calls/{id}/actionable).
  final Map<String, List<dynamic>> _actionItemsCache = {};
  String? _loadingActionItemsVapiId;
  Timer? _detailRefreshTimer;
  // Cache last successful detail payload so auto-refresh doesn't blank the UI.
  final Map<String, Map<String, dynamic>> _campaignDetailCache = {};
  // Track heavy detail fetch state (items/report) so first paint is fast.
  final Map<String, bool> _campaignDetailHeavyInFlight = {};
  final Map<String, DateTime> _campaignDetailHeavyFetchedAt = {};
  static const Duration _campaignDetailHeavyTtl = Duration(seconds: 20);
  /// When set, builder uses cache for this campaign (report was refetched after actionable 404).
  String? _campaignReportRefetchedForActionItems;
  String _detailStatusFilter = 'all'; // all|queued|in_progress|completed|failed|retry_wait
  String? _editingCampaignId;
  Map<String, dynamic>? _editCampaignData;
  bool _isEducationOrg = false;

  // Wizard state
  final _nameController = TextEditingController();
  final _audienceSearchController = TextEditingController();
  String _filterType = 'all'; // all, balance_above, balance_below, has_due_date, overdue
  final _balanceMinController = TextEditingController();
  final _balanceMaxController = TextEditingController();
  bool _filterOverdueOnly = false;
  /// Selected operator: "agent:uuid" or "profile:uuid" (used for campaign create).
  String? _selectedOperatorValue;
  /// Raw agent id when editing (campaign.agent_id); used with _selectedOperatorValue.
  String? _selectedAgentId;
  DateTime? _scheduledAt;
  bool _scheduleNow = true;
  Set<String> _selectedStudentIds = {};
  bool _selectAll = false;
  bool _manualAudienceSelection = false;
  String _audienceMode = 'contact_list';
  bool _smartHasBalance = true;
  bool _smartOverdueOnly = false;
  final _smartBalanceMinController = TextEditingController();
  String? _smartDueBefore;
  int? _previewAudienceCount;
  List<Map<String, dynamic>> _previewAudienceSample = [];
  bool _previewLoading = false;
  /// Fix 2: true if account has at least one phone number (for gating Start campaign).
  bool _hasPhoneNumber = false;
  /// Outbound phone numbers for campaign start (caller ID dropdown).
  List<Map<String, dynamic>> _outboundPhoneNumbers = [];
  /// Selected VAPI phone_number_id for this campaign run (null = omit override; backend uses
  /// campaign_phone_number_id if set, else operator attachment, else org primary).
  String? _selectedStartPhoneNumberId;
  /// Wallet credits and required per call (for campaign start gating and display).
  int? _walletCredits;
  int? _creditsPerMinute;
  // Campaign diagnostics (one-click troubleshooting panel).
  String? _diagEndpoint;
  int? _diagStatusCode;
  String? _diagBackendCode;
  String? _diagBackendMessage;
  DateTime? _diagLastStartSuccessAt;
  DateTime? _diagLastStartFailedAt;
  // Audience selection via CSV upload (Search by excel and selection).
  String _audienceCsvText = '';
  Set<String> _audienceCsvMatchedStudentIds = {};
  List<String> _audienceCsvErrors = [];

  @override
  void initState() {
    super.initState();
    _audienceScrollController.addListener(_onAudienceScroll);
    _load();
  }

  @override
  void dispose() {
    _detailRefreshTimer?.cancel();
    _nameController.dispose();
    _audienceSearchController.dispose();
    _audienceScrollController.dispose();
    _balanceMinController.dispose();
    _balanceMaxController.dispose();
    _smartBalanceMinController.dispose();
    super.dispose();
  }

  void _onAudienceScroll() {
    if (!_audienceScrollController.hasClients) return;
    if (_audienceSearchController.text.trim().isNotEmpty) return; // avoid load-more during client-side search
    if (_studentsLoadingMore || !_studentsHasMore) return;
    final maxScroll = _audienceScrollController.position.maxScrollExtent;
    final currentScroll = _audienceScrollController.position.pixels;
    if (maxScroll - currentScroll <= 250) {
      unawaited(_loadMoreStudents());
    }
  }

  Future<void> _load() async {
    final swrKey = '${NeyvoPulseApi.defaultAccountId}_campaigns';
    final cachedCamp = ApiResponseCache.get(swrKey);
    if (cachedCamp is Map<String, dynamic>) {
      setState(() {
        _students = List<Map<String, dynamic>>.from(
          (cachedCamp['students'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _studentsTotal = cachedCamp['studentsTotal'] is int ? (cachedCamp['studentsTotal'] as int) : 0;
        _studentsCursor = cachedCamp['studentsCursor'] as String?;
        _studentsOffset = cachedCamp['studentsOffset'] is int ? (cachedCamp['studentsOffset'] as int) : _students.length;
        _studentsHasMore = cachedCamp['studentsHasMore'] is bool
            ? (cachedCamp['studentsHasMore'] as bool)
            : (_studentsTotal > _studentsOffset);
        _campaigns = List<Map<String, dynamic>>.from(
          (cachedCamp['campaigns'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _campaignsCursor = cachedCamp['campaignsCursor'] as String?;
        _campaignsHasMore = cachedCamp['campaignsHasMore'] is bool ? (cachedCamp['campaignsHasMore'] as bool) : false;
        _agents = List<Map<String, dynamic>>.from(
          (cachedCamp['agents'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _operatorsForCampaign = List<Map<String, dynamic>>.from(
          (cachedCamp['operators'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _isEducationOrg = cachedCamp['isEdu'] == true;
        _hasPhoneNumber = cachedCamp['hasPhone'] == true;
        _outboundPhoneNumbers = List<Map<String, dynamic>>.from(
          (cachedCamp['outbound'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        final wc = cachedCamp['walletCredits'];
        if (wc is int) _walletCredits = wc;
        final cpm = cachedCamp['creditsPerMinute'];
        if (cpm is int) _creditsPerMinute = cpm;
        _loading = false;
        _error = null;
      });
    } else {
      setState(() => _loading = true);
    }
    try {
      // Ensure account context so operator list (managed profiles) is scoped to current org
      if (NeyvoPulseApi.defaultAccountId.isEmpty) {
        try {
          final accountRes = await ref.read(accountInfoProvider.future);
          final accountId = (accountRes['id'] ?? accountRes['account_id'] ?? '').toString().trim();
          if (accountId.isNotEmpty) NeyvoPulseApi.setDefaultAccountId(accountId);
        } catch (_) {}
      }
      final agentsRes = await NeyvoPulseApi.listAgents();
      final agentsList = agentsRes['agents'] as List? ?? [];
      final agents = agentsList.cast<Map<String, dynamic>>();
      final isEdu = agents.any((a) => (a['industry']?.toString().toLowerCase() ?? '') == 'education');
      // Load managed profiles (operators) and combine with unified agents for campaign operator dropdown.
      List<Map<String, dynamic>> operators = [];
      try {
        final profilesRes = await ManagedProfileApiService.listProfiles();
        final profilesList = (profilesRes['profiles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final p in profilesList) {
          final id = (p['profile_id'] ?? p['id'] ?? '').toString();
          final name = (p['profile_name'] ?? p['name'] ?? 'Unnamed operator').toString();
          if (id.isNotEmpty) operators.add({'value': 'profile:$id', 'name': name, 'type': 'profile'});
        }
      } catch (_) {}
      for (final a in agents) {
        final id = (a['id'] ?? '').toString();
        final name = (a['name'] ?? 'Unnamed operator').toString();
        if (id.isNotEmpty) operators.add({'value': 'agent:$id', 'name': name, 'type': 'agent'});
      }
      // Pagination for the contact picker: only load the first page to keep the wizard responsive.
      final studentsRes = await NeyvoPulseApi.listStudents(
        limit: _studentsPageLimit,
        cursor: '__start__',
        enrichCalls: false,
        includeTotal: true,
      );
      final studentsList = (studentsRes['students'] as List?) ?? studentsRes['items'] as List? ?? [];
      _students = studentsList.cast<Map<String, dynamic>>();
      _studentsTotal = studentsRes['total'] is int ? studentsRes['total'] as int : 0;
      _studentsCursor = (studentsRes['next_cursor'] as String?) ?? (studentsRes['nextCursor'] as String?);
      _studentsOffset = _students.length;
      _studentsHasMore = _studentsCursor != null;
      _lastCallAtByStudentId = {};
      _agents = agents;
      _operatorsForCampaign = operators;
      await _loadCampaigns(reset: true);
      // Check if account has a number: from account info (primary) or from GET /api/numbers
      bool hasNumber = false;
      try {
        final accountRes = await ref.read(accountInfoProvider.future);
        final pid = (accountRes['primary_phone_number_id'] ?? accountRes['vapi_phone_number_id'] ?? '').toString().trim();
        if (pid.isNotEmpty) {
          hasNumber = true;
        } else {
          final numbers = accountRes['numbers'] as List? ?? [];
          if (numbers.isNotEmpty) hasNumber = true;
        }
        if (!hasNumber) {
          final numbersRes = await NeyvoPulseApi.listNumbers();
          final list = numbersRes['numbers'] as List? ?? numbersRes['items'] as List? ?? [];
          if (list.isNotEmpty) hasNumber = true;
        }
      } catch (_) {}
      // Load outbound phone numbers for campaign start dropdown
      List<Map<String, dynamic>> outbound = [];
      try {
        final outRes = await NeyvoPulseApi.getOutboundPhoneNumbers();
        final raw = outRes['phone_numbers'] as List? ?? [];
        outbound = raw.cast<Map<String, dynamic>>();
      } catch (_) {}
      // Load wallet credits for campaign start gating and display
      int? walletCredits;
      int? creditsPerMinute;
      try {
        final wallet = await NeyvoPulseApi.getBillingWallet();
        walletCredits = (wallet['wallet_credits'] ?? wallet['credits'] ?? 0) as int?;
        if (walletCredits == null && wallet['credits'] != null) walletCredits = int.tryParse(wallet['credits'].toString());
        creditsPerMinute = (wallet['credits_per_minute'] ?? 25) as int?;
        if (creditsPerMinute == null) creditsPerMinute = int.tryParse((wallet['credits_per_minute'] ?? 25).toString()) ?? 25;
      } catch (_) {}
      ApiResponseCache.set(
        swrKey,
        <String, dynamic>{
          'students': _students,
          'studentsTotal': _studentsTotal,
          'studentsOffset': _studentsOffset,
          'studentsCursor': _studentsCursor,
          'studentsHasMore': _studentsHasMore,
          'campaigns': _campaigns,
          'campaignsCursor': _campaignsCursor,
          'campaignsHasMore': _campaignsHasMore,
          'agents': _agents,
          'operators': _operatorsForCampaign,
          'isEdu': isEdu,
          'hasPhone': hasNumber,
          'outbound': outbound,
          'walletCredits': walletCredits,
          'creditsPerMinute': creditsPerMinute ?? 25,
        },
        ttl: const Duration(seconds: 60),
      );
      if (mounted) setState(() {
        _isEducationOrg = isEdu;
        _hasPhoneNumber = hasNumber;
        _outboundPhoneNumbers = outbound;
        // Do not default _selectedStartPhoneNumberId to the first org number: leave null so
        // startCampaign omits phone_number_id and the backend uses operator attachment / primary.
        _walletCredits = walletCredits;
        _creditsPerMinute = creditsPerMinute ?? 25;
        _loading = false;
      });
    } on ApiException catch (e) {
      String msg = e.message;
      final uri = e.uri?.toString() ?? '';
      _recordCampaignDiagnostic(
        endpoint: '/api/pulse/campaigns',
        statusCode: e.statusCode,
        backendCode: _extractBackendCode(e.payload),
        backendMessage: _extractBackendMessage(e.payload, fallback: e.message),
        success: false,
      );
      if ((e.statusCode == 404 || e.statusCode == 405) &&
          uri.contains('/api/pulse/campaigns')) {
        msg =
            'Campaign API is not available on the current backend (${e.statusCode}). '
            'You are likely connected to a write-only/partial service. '
            'Point API_BASE_URL to the full Neyvo backend that exposes GET /api/pulse/campaigns.';
      }
      if (mounted) {
        if (cachedCamp == null) {
          setState(() {
            _error = msg;
            _loading = false;
          });
        }
      }
    } catch (e) {
      _recordCampaignDiagnostic(
        endpoint: '/api/pulse/campaigns',
        backendMessage: e.toString(),
        success: false,
      );
      if (mounted) {
        if (cachedCamp == null) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
      }
    }
  }

  String? _extractBackendCode(dynamic payload) {
    if (payload is Map) {
      return (payload['code'] ?? payload['error_code'] ?? payload['error'])?.toString();
    }
    return null;
  }

  String? _extractBackendMessage(dynamic payload, {String? fallback}) {
    if (payload is Map) {
      final value = (payload['message'] ?? payload['detail'] ?? payload['error'])?.toString();
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return fallback;
  }

  void _recordCampaignDiagnostic({
    required String endpoint,
    int? statusCode,
    String? backendCode,
    String? backendMessage,
    required bool success,
  }) {
    if (!mounted) return;
    setState(() {
      _diagEndpoint = endpoint;
      _diagStatusCode = statusCode;
      _diagBackendCode = backendCode;
      _diagBackendMessage = backendMessage;
      if (success) {
        _diagLastStartSuccessAt = DateTime.now();
      } else {
        _diagLastStartFailedAt = DateTime.now();
      }
    });
  }

  Future<void> _loadPreviewAudience() async {
    if (_audienceMode != 'filters') return;
    setState(() => _previewLoading = true);
    try {
      final res = await NeyvoPulseApi.getCampaignsPreviewAudience(
        hasBalance: _smartHasBalance,
        isOverdue: _smartOverdueOnly,
        balanceMin: double.tryParse(_smartBalanceMinController.text.replaceAll(RegExp(r'[^0-9.]'), '')),
        dueBefore: _smartDueBefore,
      );
      if (mounted) {
        setState(() {
          _previewAudienceCount = res['count'] as int? ?? 0;
          _previewAudienceSample = List<Map<String, dynamic>>.from((res['sample'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
          _previewLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _previewAudienceCount = null;
        _previewAudienceSample = [];
        _previewLoading = false;
      });
    }
  }

  // --- Audience selection via CSV (Search by excel and selection) ---

  Future<void> _pickAudienceCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
    final text = String.fromCharCodes(result.files.single.bytes!);
    await _matchStudentsFromCsv(text);
  }

  Future<void> _downloadAudienceTemplate() async {
    // Reuse the existing students import template.
    if (kIsWeb) {
      final url = '${NeyvoApi.baseUrl}/api/pulse/students/import/template';
      final ok = await NeyvoApi.launchExternal(url);
      if (ok) return;
    }
    try {
      final template = await NeyvoPulseApi.getStudentsImportTemplate();
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Student CSV template'),
            content: SingleChildScrollView(
              child: SelectableText(
                template,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template: name,phone,email,student_id,balance,due_date,late_fee,notes (first_name/last_name also supported)',
          ),
        ),
      );
    }
  }

  Future<void> _matchStudentsFromCsv(String csvText) async {
    List<Map<String, String>> rows;
    try {
      rows = parseCsvToMaps(csvText);
    } catch (e) {
      setState(() {
        _audienceCsvText = csvText;
        _audienceCsvMatchedStudentIds = {};
        _audienceCsvErrors = ['Invalid CSV format: $e'];
      });
      return;
    }
    if (rows.isEmpty) {
      setState(() {
        _audienceCsvText = csvText;
        _audienceCsvMatchedStudentIds = {};
        _audienceCsvErrors = ['CSV has no data rows'];
      });
      return;
    }

    String getVal(Map<String, String> r, List<String> keys) {
      for (final k in keys) {
        for (final key in r.keys) {
          if (key.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
              k.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '')) {
            final v = r[key]?.trim() ?? '';
            if (v.isNotEmpty) return v;
          }
        }
      }
      return '';
    }

    // Extract candidate lookup keys from the CSV first.
    String _normalizePhone(String p) => p.replaceAll(RegExp(r'[^0-9]'), '');
    final csvStudentIds = <String>{};
    final csvPhones = <String>{};
    final extracted = List<Map<String, String>>.generate(rows.length, (i) => <String, String>{});

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final sid = getVal(r, ['student_id', 'id', 'studentid']);
      final phone = getVal(r, ['phone', 'mobile', 'cell']);
      extracted[i] = {'student_id': sid, 'phone': phone};
      if (sid.isNotEmpty) csvStudentIds.add(sid);
      if (phone.isNotEmpty) csvPhones.add(phone);
    }

    // Ask the backend to resolve ids without needing the full (1000+ row) student list in memory.
    final dialogFuture = mounted
        ? showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Matching contacts'),
              content: Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Matching ${rows.length} rows…')),
                ],
              ),
            ),
          )
        : Future<void>.value();

    final matched = <String>{};
    final errs = <String>[];
    try {
      final res = await NeyvoPulseApi.matchStudentsByCsvKeys(
        studentIds: csvStudentIds.toList(),
        phones: csvPhones.toList(),
      );

      final byStudentId = (res['student_id_to_id'] as Map?)?.cast<String, dynamic>() ?? {};
      final byPhone = (res['phone_norm_to_id'] as Map?)?.cast<String, dynamic>() ?? {};

      for (var i = 0; i < rows.length; i++) {
        final rowNum = i + 2; // header is row 1
        final sid = extracted[i]['student_id'] ?? '';
        final phone = extracted[i]['phone'] ?? '';
        String? id;
        if (sid.isNotEmpty) {
          id = byStudentId[sid.toLowerCase()]?.toString();
        }
        if ((id == null || id.isEmpty) && phone.isNotEmpty) {
          final d = _normalizePhone(phone);
          id = byPhone[d]?.toString();
          // Backend stores E.164 as +1…; map keys may be 11-digit while CSV digits are 10.
          if ((id == null || id.isEmpty) && d.length == 10) {
            id = byPhone['1$d']?.toString();
          }
        }

        if (id != null && id.isNotEmpty) {
          matched.add(id);
        } else {
          errs.add('Row $rowNum: no matching student for id="$sid" phone="$phone"');
        }
      }
    } catch (e) {
      errs.add('Matching failed: $e');
    } finally {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
      await dialogFuture;
    }

    if (!mounted) return;
    setState(() {
      _audienceCsvText = csvText;
      _audienceCsvMatchedStudentIds = matched;
      _audienceCsvErrors = errs;
      // Seed manual selection with all matched students.
      _manualAudienceSelection = true;
      _selectedStudentIds = matched;
      _selectAll = matched.isNotEmpty;
    });
  }

  Map<String, List<String>> _buildStudentCampaignNames(List<Map<String, dynamic>> campaigns) {
    final byStudent = <String, Set<String>>{};
    for (final c in campaigns) {
      final ids = c['student_ids'];
      if (ids is! List) continue;
      final cname = (c['name'] ?? c['id'] ?? 'Campaign').toString().trim();
      if (cname.isEmpty) continue;
      for (final raw in ids) {
        final sid = (raw ?? '').toString().trim();
        if (sid.isEmpty) continue;
        (byStudent[sid] ??= <String>{}).add(cname);
      }
    }
    return byStudent.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

  Future<void> _loadCampaigns({required bool reset}) async {
    if (_campaignsLoadingMore) return;
    if (!reset && !_campaignsHasMore) return;
    if (!mounted) return;
    setState(() {
      _campaignsLoadingMore = true;
      if (reset) {
        _campaignsCursor = null;
      }
    });

    try {
      final res = await NeyvoPulseApi.listCampaigns(
        limit: _campaignsPageSize,
        cursor: reset ? '__start__' : _campaignsCursor,
      );
      final list = res['campaigns'] as List? ?? [];
      final page = list.cast<Map<String, dynamic>>();
      final nextCursor = (res['next_cursor'] ?? res['nextCursor'])?.toString();

      if (!mounted) return;
      setState(() {
        if (reset) {
          _campaigns = page;
        } else {
          final existing = _campaigns.map((e) => (e['id'] ?? '').toString()).where((e) => e.isNotEmpty).toSet();
          final deduped = page.where((e) => !existing.contains((e['id'] ?? '').toString())).toList();
          _campaigns.addAll(deduped);
        }
        _campaignsCursor = nextCursor;
        _campaignsHasMore = nextCursor != null;
        _studentCampaignNames = _buildStudentCampaignNames(_campaigns);
        _campaignsLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _campaignsLoadingMore = false;
        if (reset) {
          _campaigns = [];
          _campaignsCursor = null;
          _campaignsHasMore = false;
          _studentCampaignNames = {};
        }
      });
    }
  }

  String? _campaignHintForStudent(String studentId) {
    final names = _studentCampaignNames[studentId];
    if (names == null || names.isEmpty) return null;
    const maxShow = 2;
    final shown = names.take(maxShow).join(', ');
    final more = names.length - maxShow;
    return more > 0 ? 'In campaigns: $shown +$more more' : 'In campaigns: $shown';
  }

  String? _calledBeforeHintForStudent(String studentId) {
    final dt = _lastCallAtByStudentId[studentId];
    if (dt == null) return null;
    final formatted = UserTimezoneService.format(dt.toIso8601String());
    if (formatted.trim().isEmpty) return null;
    return 'Called before: $formatted';
  }

  bool _isVoicemailText(String text) {
    final t = text.toLowerCase();
    return t.contains('voicemail') ||
        t.contains('left a message') ||
        t.contains('left message') ||
        t.contains('after the tone') ||
        t.contains('mailbox') ||
        t.contains('beep');
  }

  bool _isCallbackRequestedText(String text) {
    final t = text.toLowerCase();
    return t.contains('callback') ||
        t.contains('call back') ||
        t.contains('call-back') ||
        t.contains('scheduled a callback') ||
        t.contains('schedule a callback') ||
        t.contains('requested a callback');
  }

  /// Map each student's campaign call to one of: Answered, Voicemail, Not Connected.
  /// Returns { outcome, callbackRequested } where callbackRequested suppresses retry.
  Map<String, dynamic> _deriveCampaignCallOutcome({
    required Map<String, dynamic> callItem,
    required Map<String, dynamic>? callDetail,
  }) {
    final itemStatus = (callItem['status'] ?? '').toString().toLowerCase().trim();
    final summary = (callDetail?['summary'] ?? callItem['summary'] ?? '').toString();
    final transcript = (callDetail?['transcript_snippet'] ?? callItem['transcript'] ?? '').toString();
    final endedReason = (callDetail?['ended_reason'] ?? callItem['ended_reason'] ?? '').toString();

    final combined = ('$summary\n$transcript\n$endedReason').trim();
    final callbackMentioned = combined.isNotEmpty && _isCallbackRequestedText(combined);

    // Not Connected: explicit failure or no transcript/summary at all.
    final hasAnyText = transcript.trim().isNotEmpty || summary.trim().isNotEmpty;
    if (itemStatus == 'failed' || (!hasAnyText && itemStatus != 'completed')) {
      // Callback is only meaningful for Answered conversations.
      return {'outcome': 'Not Connected', 'callbackRequested': false};
    }

    if (_isVoicemailText(combined)) {
      // Voicemail scripts often say “call back”; ignore that for retry.
      return {'outcome': 'Voicemail', 'callbackRequested': false};
    }

    // If we have any conversational content (or completed) and not voicemail, treat as Answered.
    if (itemStatus == 'completed' || hasAnyText) {
      return {'outcome': 'Answered', 'callbackRequested': callbackMentioned};
    }

    return {'outcome': 'Not Connected', 'callbackRequested': false};
  }

  Future<void> _retryCampaignCalls({
    required Map<String, dynamic> originalCampaign,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) return;
    if (!_ensureHasPhoneNumber()) return;
    if (!_hasCreditsToRun && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No credits. Available: ${_walletCredits ?? 0}. Required per call: ~${_creditsPerMinute ?? 25} credits. Add credits in Billing.'),
        backgroundColor: NeyvoTheme.warning,
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    final campaignId = (originalCampaign['id'] ?? '').toString().trim();
    if (campaignId.isEmpty) return;

    try {
      final res = await NeyvoPulseApi.retryCampaignCalls(
        campaignId,
        studentIds,
        phoneNumberId: _selectedStartPhoneNumberId,
      );
      if (!mounted) return;
      final totalRetry = res['total_retry'] ?? studentIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Retry: $totalRetry call(s) queued in same campaign.'),
          backgroundColor: NeyvoTheme.success,
        ),
      );
      setState(() => _detailStatusFilter = 'all');
      _reloadFullCampaignDetail();
      _load();
      _startDetailAutoRefresh();
    } on ApiException catch (e) {
      if (mounted) {
        final payload = e.payload;
        if (payload is Map && payload['error'] == 'insufficient_credits') {
          _showInsufficientCreditsSnackBar(e);
        } else {
          final msg = payload is Map
              ? (payload['message'] ?? payload['error'] ?? e.message)
              : e.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg?.toString() ?? e.toString()), backgroundColor: NeyvoTheme.error),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: $e'), backgroundColor: NeyvoTheme.error),
      );
    }
  }

  void _startDetailAutoRefresh() {
    _detailRefreshTimer?.cancel();
    _detailRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _selectedCampaignId == null) return;
      unawaited(_refreshCampaignDetailMetricsLight(_selectedCampaignId!));
    });
  }

  void _stopDetailAutoRefresh() {
    _detailRefreshTimer?.cancel();
    _detailRefreshTimer = null;
  }

  Future<Map<String, dynamic>> _fetchCampaignDetailBundle(String campaignId) async {
    final campaignRes = await NeyvoPulseApi.getCampaign(campaignId);
    final camp = Map<String, dynamic>.from((campaignRes['campaign'] as Map?) ?? const {});
    final callsF = NeyvoPulseApi.getCampaignCalls(campaignId, limit: 120);
    final metricsF = NeyvoPulseApi.getCampaignMetrics(campaignId);
    final results = await Future.wait([callsF, metricsF]);
    final callsRes = results[0] as Map<String, dynamic>;
    final metricsRes = results[1] as Map<String, dynamic>;
    final cached = _campaignDetailCache[campaignId];
    final cachedItems = (cached?['items'] as List?) ?? const [];
    final cachedReport = (cached?['report'] as Map?) ?? const {};

    if (_shouldRefreshHeavyDetail(campaignId)) {
      unawaited(_prefetchHeavyCampaignDetail(campaignId));
    }

    return {
      'campaign': camp,
      'calls': (callsRes['calls'] as List?) ?? [],
      'metrics': (metricsRes['metrics'] as Map?) ?? {},
      'items': cachedItems,
      'report': cachedReport,
    };
  }

  void _reloadFullCampaignDetail() {
    final id = _selectedCampaignId;
    if (id == null) return;
    setState(() {
      _campaignDetailBundleFuture = _fetchCampaignDetailBundle(id);
    });
  }

  /// Light 5s tick: metrics (+ counter fields) only; keeps call list / report until explicit refresh or heavy TTL.
  Future<void> _refreshCampaignDetailMetricsLight(String campaignId) async {
    try {
      final metricsRes = await NeyvoPulseApi.getCampaignMetrics(campaignId);
      if (!mounted || _selectedCampaignId != campaignId) return;
      final metrics = Map<String, dynamic>.from((metricsRes['metrics'] as Map?) ?? const {});
      final cached = Map<String, dynamic>.from(_campaignDetailCache[campaignId] ?? const {});
      cached['metrics'] = metrics;
      final camp = Map<String, dynamic>.from((cached['campaign'] as Map?) ?? const {});
      const metricCampaignKeys = <String>[
        'queued_count',
        'active_count',
        'completed_count',
        'failed_count',
        'retry_wait_count',
        'total_planned',
        'status',
        'max_concurrent',
        'last_error',
        'last_cloud_task_error',
        'last_cloud_task_error_type',
        'last_cloud_task_error_at',
        'last_cloud_task_error_attempt',
        'snapshot_status',
        'snapshot_audience_size',
        'audience_mode',
        'updated_at',
        'started_at',
      ];
      for (final k in metricCampaignKeys) {
        if (!metrics.containsKey(k)) continue;
        camp[k] = metrics[k];
      }
      cached['campaign'] = camp;
      _campaignDetailCache[campaignId] = cached;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _downloadCampaignReport(String campaignId) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 8),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Preparing campaign report…',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
    try {
      final res = await NeyvoPulseApi.fetchCampaignSpreadsheetExport(campaignId);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (res['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Download failed'),
            backgroundColor: NeyvoTheme.error,
          ),
        );
        return;
      }
      final filename = res['filename']?.toString() ?? 'campaign_export.csv';
      final csvContent = res['csv_content']?.toString() ?? '';
      await downloadCsv(filename, '\uFEFF$csvContent', context);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: NeyvoTheme.error),
        );
      }
    }
  }

  bool _shouldRefreshHeavyDetail(String campaignId) {
    if (_campaignDetailHeavyInFlight[campaignId] == true) return false;
    final last = _campaignDetailHeavyFetchedAt[campaignId];
    if (last == null) return true;
    return DateTime.now().difference(last) >= _campaignDetailHeavyTtl;
  }

  Future<void> _prefetchHeavyCampaignDetail(String campaignId) async {
    if (_campaignDetailHeavyInFlight[campaignId] == true) return;
    _campaignDetailHeavyInFlight[campaignId] = true;
    try {
      final results = await Future.wait<dynamic>([
        NeyvoPulseApi.getCampaignCallItems(campaignId, limit: 300),
        NeyvoPulseApi.getCampaignReport(campaignId),
      ]);
      if (!mounted || _selectedCampaignId != campaignId) return;
      final itemsRes = Map<String, dynamic>.from(results[0] as Map);
      final reportRes = Map<String, dynamic>.from(results[1] as Map);
      final existing = Map<String, dynamic>.from(_campaignDetailCache[campaignId] ?? const {});
      existing['items'] = (itemsRes['items'] as List?) ?? const [];
      existing['report'] = reportRes;
      _campaignDetailCache[campaignId] = existing;
      _campaignDetailHeavyFetchedAt[campaignId] = DateTime.now();
      setState(() {});
    } catch (_) {
      // Keep existing detail visible; next refresh can retry.
    } finally {
      _campaignDetailHeavyInFlight[campaignId] = false;
    }
  }

  /// Full campaign export (CSV: name, id, phone, status, outcome, saved action insights).
  /// Uses async export job when available; otherwise synchronous GET /export.
  Future<void> _exportCampaignFull(String campaignId) async {
    if (!mounted) return;
    final DateTime exportStartedAt = DateTime.now();
    int processedItems = 0;
    int? totalItems;
    String exportStatusLabel = 'Preparing export job...';
    void Function(void Function())? setDialogState;
    String _elapsedLabel() {
      final elapsed = DateTime.now().difference(exportStartedAt);
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds % 60;
      if (minutes <= 0) return '${seconds}s';
      return '${minutes}m ${seconds}s';
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, localSetState) {
          setDialogState = localSetState;
          final int safeTotal = totalItems ?? 0;
          final int safeProcessed = processedItems.clamp(0, safeTotal > 0 ? safeTotal : processedItems);
          final double? progress = safeTotal > 0 ? (safeProcessed / safeTotal).clamp(0.0, 1.0) : null;
          return AlertDialog(
            title: const Text('Building export'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: NeyvoSpacing.md),
                Text(
                  exportStatusLabel,
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (safeTotal > 0) ...[
                  const SizedBox(height: NeyvoSpacing.sm),
                  Text(
                    '$safeProcessed / $safeTotal contacts processed',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: NeyvoSpacing.xs),
                Text(
                  'Elapsed: ${_elapsedLabel()}',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                Text(
                  'Uses saved action insights from each call when available. Large lists may still take a short while.',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
    try {
      final res = await NeyvoPulseApi.fetchCampaignSpreadsheetExport(
        campaignId,
        onProgress: ({required int processed, required int total, required String status}) {
          if (!mounted) return;
          setDialogState?.call(() {
            processedItems = processed;
            totalItems = total;
            exportStatusLabel =
                status.isNotEmpty ? 'Status: $status' : 'Processing contacts...';
          });
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (res['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error']?.toString() ?? 'Export failed'), backgroundColor: NeyvoTheme.error),
        );
        return;
      }
      final filename = res['filename']?.toString() ?? 'campaign_export.csv';
      final csvContent = res['csv_content']?.toString() ?? '';
      await downloadCsv(filename, '\uFEFF$csvContent', context);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: NeyvoTheme.error),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    var list = List<Map<String, dynamic>>.from(_students);
    // When using the "Search by excel and selection" audience mode, restrict the
    // list to students matched from the uploaded CSV (if any).
    if (_audienceMode == 'excel' && _audienceCsvMatchedStudentIds.isNotEmpty) {
      list = list
          .where((s) => _audienceCsvMatchedStudentIds.contains((s['id'] ?? '').toString()))
          .toList();
    }
    return list;
  }

  void _resetStudentsPaginationAndReload() {
    // Only intended for the contact picker (contact_list mode).
    _allMatchingIdsCacheKey = null;
    _allMatchingIdsCache.clear();
    unawaited(_loadStudentsPage(reset: true));
  }

  Future<void> _loadMoreStudents() async {
    await _loadStudentsPage(reset: false);
  }

  Future<void> _loadStudentsPage({required bool reset}) async {
    if (_studentsLoadingMore || _studentsInitialLoading) return;
    if (reset) {
      if (!mounted) return;
      setState(() {
        _studentsInitialLoading = true;
        _students = [];
        _studentsOffset = 0;
        _studentsTotal = 0;
        _studentsCursor = null;
        _studentsHasMore = false;
      });
    } else {
      if (!_studentsHasMore) return;
      if (!mounted) return;
      setState(() {
        _studentsLoadingMore = true;
      });
    }

    try {
      final cursorToken = reset ? '__start__' : _studentsCursor;
      final double? balanceMin = _filterType == 'balance_above'
          ? double.tryParse(_balanceMinController.text.replaceAll(RegExp(r'[^0-9.]'), ''))
          : null;
      final double? balanceMax = _filterType == 'balance_below'
          ? double.tryParse(_balanceMaxController.text.replaceAll(RegExp(r'[^0-9.]'), ''))
          : null;
      final String? dueBefore = (_filterOverdueOnly || _filterType == 'has_due_date') ? '9999-12-31' : null;

      final studentsRes = await NeyvoPulseApi.listStudents(
        limit: _studentsPageLimit,
        cursor: cursorToken,
        enrichCalls: false,
        includeTotal: reset,
        balanceMin: balanceMin,
        balanceMax: balanceMax,
        dueBefore: dueBefore,
      );

      final itemsRaw = (studentsRes['students'] as List?) ?? studentsRes['items'] as List? ?? [];
      final items = itemsRaw.cast<Map<String, dynamic>>();
      final nextCursor = (studentsRes['next_cursor'] as String?) ?? (studentsRes['nextCursor'] as String?);

      if (!mounted) return;

      setState(() {
        if (reset) {
          _students = items;
          _studentsTotal = studentsRes['total'] is int ? studentsRes['total'] as int : 0;
          _studentsOffset = _students.length;
        } else {
          final existing = _students
              .map((s) => (s['id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet();
          final deduped = items.where((s) {
            final id = (s['id'] ?? '').toString();
            return id.isNotEmpty && !existing.contains(id);
          }).toList();
          _students.addAll(deduped);
          _studentsOffset += deduped.length;
        }

        _studentsCursor = nextCursor;
        _studentsHasMore = nextCursor != null;

        _studentsLoadingMore = false;
        _studentsInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _studentsLoadingMore = false;
        _studentsInitialLoading = false;
        if (reset) {
          _students = [];
          _studentsOffset = 0;
          _studentsTotal = 0;
          _studentsCursor = null;
          _studentsHasMore = false;
        }
      });
    }
  }

  String _allMatchingIdsCacheKeyForCurrentFilters() {
    final min = _balanceMinController.text.trim();
    final max = _balanceMaxController.text.trim();
    return 'mode=$_audienceMode|filter=$_filterType|min=$min|max=$max|due=$_filterOverdueOnly';
  }

  Map<String, dynamic> _studentsFilterArgsForList() {
    final double? balanceMin = _filterType == 'balance_above'
        ? double.tryParse(_balanceMinController.text.replaceAll(RegExp(r'[^0-9.]'), ''))
        : null;
    final double? balanceMax = _filterType == 'balance_below'
        ? double.tryParse(_balanceMaxController.text.replaceAll(RegExp(r'[^0-9.]'), ''))
        : null;
    final String? dueBefore = (_filterOverdueOnly || _filterType == 'has_due_date') ? '9999-12-31' : null;
    return {
      'balanceMin': balanceMin,
      'balanceMax': balanceMax,
      'dueBefore': dueBefore,
    };
  }

  Future<Set<String>> _collectAllMatchingStudentIds({void Function(int loaded, int? total)? onProgress}) async {
    // Excel mode uses the CSV match set (already computed).
    if (_audienceMode == 'excel') {
      final ids = _audienceCsvMatchedStudentIds;
      onProgress?.call(ids.length, ids.length);
      return ids;
    }

    final cacheKey = _allMatchingIdsCacheKeyForCurrentFilters();
    if (_allMatchingIdsCacheKey == cacheKey) {
      onProgress?.call(_allMatchingIdsCache.length, _allMatchingIdsCache.length);
      return _allMatchingIdsCache;
    }

    final args = _studentsFilterArgsForList();
    final pageLimit = 200;
    int? total;
    final ids = <String>{};
    String? cursorToken = '__start__';

    try {
      while (true) {
        final res = await NeyvoPulseApi.listStudents(
          limit: pageLimit,
          cursor: cursorToken,
          enrichCalls: false,
          includeTotal: total == null,
          balanceMin: args['balanceMin'] as double?,
          balanceMax: args['balanceMax'] as double?,
          dueBefore: args['dueBefore'] as String?,
        );
        final itemsRaw = (res['students'] as List?) ?? res['items'] as List? ?? [];
        final items = itemsRaw.cast<Map<String, dynamic>>();
        if (total == null) {
          total = res['total'] is int ? res['total'] as int : null;
        }
        for (final s in items) {
          final id = (s['id'] ?? s['student_id'] ?? '').toString().trim();
          if (id.isNotEmpty) ids.add(id);
        }
        cursorToken = (res['next_cursor'] as String?) ?? (res['nextCursor'] as String?);
        onProgress?.call(ids.length, total);

        if (cursorToken == null) break;
        if (total != null && ids.length >= total) break;
        if (items.length < pageLimit) break;
        if (items.isEmpty) break;
      }
    } catch (e) {
      // Preserve previous cache if any; rethrow so caller can display an error.
      rethrow;
    }

    _allMatchingIdsCacheKey = cacheKey;
    _allMatchingIdsCache = ids;
    return ids;
  }

  Future<Set<String>> _collectAllMatchingStudentIdsWithProgressDialog() async {
    int loaded = 0;
    int? total;
    bool started = false;
    final completer = Completer<Set<String>>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (!started) {
              started = true;
              unawaited(() async {
                try {
                  final ids = await _collectAllMatchingStudentIds(
                    onProgress: (l, t) {
                      loaded = l;
                      total = t;
                      setDialogState(() {});
                    },
                  );
                  Navigator.of(dialogContext).pop();
                  completer.complete(ids);
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  completer.completeError(e);
                }
              }());
            }

            final pct = (total != null && total! > 0) ? (loaded / total!) : null;
            return AlertDialog(
              title: const Text('Selecting all contacts'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: pct),
                  const SizedBox(height: NeyvoSpacing.md),
                  Text(
                    total != null ? 'Selected $loaded of $total' : 'Selected $loaded…',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return await completer.future;
  }

  void _toggleStudent(String id) {
    setState(() {
      if (!_manualAudienceSelection) {
        _manualAudienceSelection = true;
        _selectAll = false;
        _selectedStudentIds = {id};
        return;
      }
      if (_selectedStudentIds.contains(id)) {
        _selectedStudentIds.remove(id);
      } else {
        _selectedStudentIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    if (_selectAllInProgress) return;
    if (_selectAll) {
      setState(() {
        _selectedStudentIds.clear();
        _selectAll = false;
      });
      return;
    }

    setState(() {
      if (!_manualAudienceSelection) _manualAudienceSelection = true;
      _selectAllInProgress = true;
    });

    unawaited(() async {
      try {
        final ids = await _collectAllMatchingStudentIdsWithProgressDialog();
        if (!mounted) return;
        setState(() {
          _selectedStudentIds = ids;
          _selectAll = true;
          _selectAllInProgress = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _selectAllInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Select all failed: $e'), backgroundColor: NeyvoTheme.error),
        );
      }
    }());
  }

  Future<void> _launchCampaign() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter campaign name')));
      return;
    }
    final useFilters = _isEducationOrg && _audienceMode == 'filters';
    final List<String> ids;
    if (useFilters) {
      ids = <String>[];
    } else if (_manualAudienceSelection) {
      ids = _selectedStudentIds.toList();
    } else {
      // "All matching" needs the full id set, not just the first loaded page.
      final allIds = await _collectAllMatchingStudentIdsWithProgressDialog();
      ids = allIds.toList();
    }
    if (!useFilters && ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contacts selected')));
      return;
    }
    if (useFilters && (_previewAudienceCount == null || _previewAudienceCount! == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students match the selected filters')));
      return;
    }
    if (_editingCampaignId != null) {
      await _saveCampaignEdit(name: name, studentIds: ids, useFilters: useFilters);
      return;
    }
    String? agentId;
    String? profileId;
    if (_selectedOperatorValue != null && _selectedOperatorValue!.isNotEmpty) {
      if (_selectedOperatorValue!.startsWith('profile:')) {
        profileId = _selectedOperatorValue!.substring(8);
      } else if (_selectedOperatorValue!.startsWith('agent:')) {
        agentId = _selectedOperatorValue!.substring(6);
      }
    }
    try {
      final created = await NeyvoPulseApi.createCampaign(
        name: name,
        agentId: agentId,
        profileId: profileId,
        templateId: null,
        // Audience is now configured via updateCampaignAudience after basics are created.
        studentIds: null,
        audienceType: null,
        filters: null,
        scheduledAt: _scheduleNow ? null : _scheduledAt,
      );
      // Configure campaign audience (manual selection or filters) using the new audience API.
      final campaign =
          (created['campaign'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final campaignId = (campaign['id'] ?? '').toString().trim();
      if (campaignId.isNotEmpty) {
        if (useFilters) {
          await NeyvoPulseApi.updateCampaignAudience(
            campaignId,
            audienceMode: 'FILTERS',
            audienceFilters: {
              'has_balance': _smartHasBalance,
              'is_overdue': _smartOverdueOnly,
              if (_smartBalanceMinController.text.trim().isNotEmpty)
                'balance_min': double.tryParse(
                  _smartBalanceMinController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                ),
              if (_smartDueBefore != null && _smartDueBefore!.isNotEmpty)
                'due_before': _smartDueBefore,
            },
          );
        } else {
          await NeyvoPulseApi.updateCampaignAudience(
            campaignId,
            audienceMode: 'MANUAL',
            studentIds: ids,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign "$name" created for ${ids.length} contacts'), backgroundColor: NeyvoTheme.success),
        );
        setState(() {
          _showCreateWizard = false;
          _wizardStep = 0;
          _nameController.clear();
          _selectedOperatorValue = null;
          _selectedStudentIds.clear();
          _selectAll = false;
          _manualAudienceSelection = false;
        });
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
      }
    }
  }

  void _showCampaignStartResult(Map<String, dynamic> res, {bool isRerun = false}) {
    final alreadyRunning = res['already_running'] == true ||
        (res['message']?.toString().toLowerCase().contains('already running') ?? false);
    if (alreadyRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campaign is already running.'),
          backgroundColor: NeyvoTheme.warning,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final initiated = res['total_initiated'] ?? 0;
    final failed = res['total_failed'] ?? 0;
    final failureReason = res['failure_reason']?.toString();
    final failureMessage = res['failure_message']?.toString() ?? '';
    String text = isRerun
        ? 'Rerun: $initiated reach(es) started.${failed > 0 ? ' $failed failed.' : ''}'
        : '$initiated reach(es) started.${failed > 0 ? ' $failed failed.' : ''}';
    if (failureReason == 'vapi_daily_limit' && failureMessage.isNotEmpty) {
      text = 'Calls could not be placed: VAPI limit (concurrency or plan). Check VAPI dashboard → Settings/Billing and Analytics. For scale, use your own Twilio number in VAPI (Phone Numbers → Add → Twilio) and set that number ID in backend env.';
    } else if (failureMessage.isNotEmpty && failed > 0) {
      text = '$text ${failureMessage.length > 80 ? '${failureMessage.substring(0, 80)}…' : failureMessage}';
    }
    final isError = failed > 0 && initiated == 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? NeyvoTheme.error : NeyvoTheme.success,
        duration: isError ? const Duration(seconds: 8) : const Duration(seconds: 4),
      ),
    );
  }

  bool _ensureHasPhoneNumber() {
    if (_hasPhoneNumber) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Campaign cannot start because no outbound phone number is configured. Add one in Phone Numbers.',
          ),
          backgroundColor: NeyvoTheme.error,
          duration: Duration(seconds: 6),
        ),
      );
    }
    return false;
  }

  String _formatDiagTs(DateTime? value) {
    if (value == null) return '—';
    return UserTimezoneService.format(value.toIso8601String());
  }

  Widget _buildCampaignDiagnosticsPanel() {
    final hasData = _diagEndpoint != null ||
        _diagStatusCode != null ||
        (_diagBackendCode?.isNotEmpty ?? false) ||
        (_diagBackendMessage?.isNotEmpty ?? false) ||
        _diagLastStartSuccessAt != null ||
        _diagLastStartFailedAt != null;
    return Card(
      color: NeyvoTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart_outlined, size: 18),
                const SizedBox(width: NeyvoSpacing.sm),
                Text('Campaign diagnostics', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: NeyvoSpacing.sm),
            if (!hasData)
              Text(
                'No campaign start diagnostics yet. Start a campaign to capture endpoint/status details.',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
              )
            else ...[
              SelectableText(
                'Endpoint: ${_diagEndpoint ?? '—'}',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text('Status code: ${_diagStatusCode?.toString() ?? '—'}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
              const SizedBox(height: 4),
              Text('Backend code: ${_diagBackendCode ?? '—'}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
              const SizedBox(height: 4),
              SelectableText(
                'Backend message: ${_diagBackendMessage ?? '—'}',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
              ),
              const SizedBox(height: NeyvoSpacing.sm),
              Text('Last start success: ${_formatDiagTs(_diagLastStartSuccessAt)}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.success)),
              const SizedBox(height: 4),
              Text('Last start failure: ${_formatDiagTs(_diagLastStartFailedAt)}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasCreditsToRun => (_walletCredits ?? 0) >= (_creditsPerMinute ?? 25);

  void _showInsufficientCreditsSnackBar(ApiException e) {
    final payload = e.payload;
    if (payload is Map && payload['error'] == 'insufficient_credits') {
      final av = payload['available_credits'] ?? 0;
      final req = payload['required_credits'] ?? payload['required_credits_per_call'] ?? 25;
      final msg = payload['message']?.toString() ?? 'Not enough credits to run this campaign.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$msg Available: $av credits. Required per call: $req credits. Add credits in Billing.'),
        backgroundColor: NeyvoTheme.error,
        duration: const Duration(seconds: 6),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: NeyvoTheme.error));
    }
  }

  Widget _buildCallerIdDropdown({Map<String, dynamic>? campaign}) {
    final numbers = _outboundPhoneNumbers
        .map((n) => {'id': (n['phone_number_id'] ?? n['id'] ?? '').toString().trim(), 'n': n})
        .where((e) => (e['id'] as String).isNotEmpty)
        .toList();
    if (numbers.isEmpty) return const SizedBox.shrink();
    final itemList = numbers.map((e) {
      final id = e['id'] as String;
      final n = e['n'] as Map<String, dynamic>;
      final label = (n['label'] ?? n['role'] ?? id).toString();
      final used = n['daily_used'] ?? 0;
      final limit = n['daily_limit'] ?? 150;
      return DropdownMenuItem<String>(
        value: id,
        child: Text(
          '$label ($used/$limit today)',
          overflow: TextOverflow.ellipsis,
          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary),
        ),
      );
    }).toList();
    final campaignPnId = (campaign?['campaign_phone_number_id'] ?? '').toString().trim();
    final preferId = campaignPnId.isNotEmpty && numbers.any((e) => e['id'] == campaignPnId)
        ? campaignPnId
        : null;
    final validValue = preferId ??
        (_selectedStartPhoneNumberId != null && numbers.any((e) => e['id'] == _selectedStartPhoneNumberId)
            ? _selectedStartPhoneNumberId
            : (numbers.isNotEmpty ? numbers.first['id'] as String : null));
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        value: validValue,
        decoration: const InputDecoration(
          labelText: 'Outbound number',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        isExpanded: true,
        items: itemList,
        onChanged: (v) => setState(() => _selectedStartPhoneNumberId = v),
      ),
    );
  }

  Future<void> _startOrRerunCampaign(Map<String, dynamic> c) async {
    if (!_ensureHasPhoneNumber()) return;
    final id = c['id']?.toString();
    if (id == null || id.isEmpty) return;
    if (!_hasCreditsToRun && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No credits. Available: ${_walletCredits ?? 0}. Required per call: ~${_creditsPerMinute ?? 25} credits. Add credits in Billing to run campaigns.'),
        backgroundColor: NeyvoTheme.warning,
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    final statusRun = (c['status'] ?? '').toString().toLowerCase().trim();
    final isRerun = statusRun == 'completed' || statusRun == 'running';
    // For first-time start, ensure snapshot and validation are ready. For rerun, skip (snapshot already existed).
    if (!isRerun) {
      final ready = await _ensureCampaignSnapshotReady(id);
      if (!ready || !mounted) return;
    }
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Starting campaign… (this can take a minute for large audiences)'),
            duration: Duration(minutes: 2),
          ),
        );
      }
      final endpoint = '/api/pulse/campaigns/$id/start';
      final res = await NeyvoPulseApi.startCampaign(id, phoneNumberId: _selectedStartPhoneNumberId);
      _recordCampaignDiagnostic(
        endpoint: endpoint,
        statusCode: 200,
        backendCode: (res['code'] ?? res['error_code'])?.toString(),
        backendMessage: (res['message'] ?? 'Campaign started successfully').toString(),
        success: true,
      );
      if (mounted) {
        _showCampaignStartResult(res, isRerun: isRerun);
        _load();
      }
    } on ApiException catch (e) {
      _recordCampaignDiagnostic(
        endpoint: '/api/pulse/campaigns/$id/start',
        statusCode: e.statusCode,
        backendCode: _extractBackendCode(e.payload),
        backendMessage: _extractBackendMessage(e.payload, fallback: e.message),
        success: false,
      );
      if (mounted) {
        final payload = e.payload;
        final campaignCode = NeyvoPulseApi.campaignErrorCodeFrom(e);
        if (payload is Map && payload['error'] == 'insufficient_credits') {
          _showInsufficientCreditsSnackBar(e);
        } else if (campaignCode == 'VAPI_RATE_LIMITED') {
          final msg = payload is Map
              ? (payload['message'] ?? 'Vapi rate limit / concurrency limit reached. Calls will retry automatically with backoff.')
              : 'Vapi rate limit / concurrency limit reached. Calls will retry automatically with backoff.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg.toString()),
              backgroundColor: NeyvoTheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          final msg = payload is Map
              ? (payload['message'] ?? payload['error'] ?? e.message)
              : e.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg?.toString() ?? e.toString()), backgroundColor: NeyvoTheme.error),
          );
        }
      }
    } catch (e) {
      _recordCampaignDiagnostic(
        endpoint: '/api/pulse/campaigns/$id/start',
        backendMessage: e.toString(),
        success: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error),
        );
      }
    }
  }

  /// Ensure the campaign has a completed, valid audience snapshot before starting.
  /// Returns true when ready to launch; otherwise shows a user-facing message and returns false.
  Future<bool> _ensureCampaignSnapshotReady(String campaignId) async {
    try {
      Map<String, dynamic> validation = {};
      try {
        final v = await NeyvoPulseApi.getCampaignValidation(campaignId);
        validation = Map<String, dynamic>.from(v as Map);
      } catch (_) {
        validation = {};
      }

      String status = (validation['snapshot_status'] ?? 'none').toString().toLowerCase().trim();
      Map<String, dynamic>? report =
          (validation['validation_report'] as Map?)?.cast<String, dynamic>();
      bool ok = report != null && report['ok'] == true;

      // If there's no complete snapshot yet, run prepare once.
      if (status != 'complete') {
        final res = await NeyvoPulseApi.prepareCampaign(campaignId);
        final preparedValidation =
            (res['validation'] as Map?)?.cast<String, dynamic>();
        if (preparedValidation != null) {
          report = preparedValidation;
          ok = report?['ok'] == true;
        }
        // Refresh authoritative status from /validation.
        try {
          final v2 = await NeyvoPulseApi.getCampaignValidation(campaignId);
          final vv = Map<String, dynamic>.from(v2 as Map);
          status = (vv['snapshot_status'] ?? status).toString().toLowerCase().trim();
          report =
              (vv['validation_report'] as Map?)?.cast<String, dynamic>() ?? report;
          ok = ok || (report != null && report['ok'] == true);
        } catch (_) {
          // If validation fetch fails, fall through to status checks below.
        }
      }

      if (status != 'complete') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Audience snapshot is not ready. Go to Preview & Prepare and run "Lock Audience & Run Validation".'),
              backgroundColor: NeyvoTheme.error,
            ),
          );
        }
        return false;
      }
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Validation failed. Fix the issues shown in Preview & Prepare and run validation again.'),
              backgroundColor: NeyvoTheme.error,
            ),
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not prepare campaign: $e'),
            backgroundColor: NeyvoTheme.error,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _startCampaignWithSubset(String campaignId, List<String> allowedStudentIds) async {
    if (!_ensureHasPhoneNumber()) return;
    if (!_hasCreditsToRun && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No credits. Available: ${_walletCredits ?? 0}. Required per call: ~${_creditsPerMinute ?? 25} credits. Add credits in Billing.'),
        backgroundColor: NeyvoTheme.warning,
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    // Subset runs must still respect the immutable prepared audience snapshot.
    final ready = await _ensureCampaignSnapshotReady(campaignId);
    if (!ready || !mounted) return;
    final byId = <String, Map<String, dynamic>>{};
    for (final s in _students) {
      final id = (s['id'] ?? '').toString();
      if (id.isNotEmpty) byId[id] = s;
    }
    final ordered = allowedStudentIds.where((id) => id.isNotEmpty).toList();
    final selected = <String>{};
    String query = '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final visible = ordered.where((id) {
            if (query.trim().isEmpty) return true;
            final s = byId[id];
            final name = (s?['name'] ?? '').toString().toLowerCase();
            final phone = (s?['phone'] ?? '').toString();
            final q = query.toLowerCase();
            return name.contains(q) ||
                phone.toLowerCase().contains(q) ||
                phoneMatchesSearchQuery(phone, query);
          }).toList();
          return AlertDialog(
            title: const Text('Start with selected contacts'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setLocal(() => query = v),
                  ),
                  const SizedBox(height: NeyvoSpacing.md),
                  Row(
                    children: [
                      Text('${selected.length} selected', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setLocal(() {
                          selected
                            ..clear()
                            ..addAll(visible);
                        }),
                        child: const Text('Select visible'),
                      ),
                      TextButton(
                        onPressed: () => setLocal(() => selected.clear()),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: NeyvoSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      itemBuilder: (_, i) {
                        final id = visible[i];
                        final s = byId[id] ?? {};
                        final name = (s['name'] ?? '—').toString();
                        final phone = (s['phone'] ?? '').toString();
                        final isSelected = selected.contains(id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => setLocal(() {
                            if (isSelected) {
                              selected.remove(id);
                            } else {
                              selected.add(id);
                            }
                          }),
                          title: Text(name),
                          subtitle: Text(phone),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                onPressed: selected.isEmpty ? null : () => Navigator.of(ctx).pop(true),
                child: const Text('Start'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      final endpoint = '/api/pulse/campaigns/$campaignId/start';
      final res = await NeyvoPulseApi.startCampaign(campaignId, studentIds: selected.toList(), phoneNumberId: _selectedStartPhoneNumberId);
      _recordCampaignDiagnostic(
        endpoint: endpoint,
        statusCode: 200,
        backendCode: (res['code'] ?? res['error_code'])?.toString(),
        backendMessage: (res['message'] ?? 'Campaign subset started successfully').toString(),
        success: true,
      );
      if (mounted) {
        _showCampaignStartResult(res, isRerun: false);
        _reloadFullCampaignDetail();
      }
    } on ApiException catch (e) {
      _recordCampaignDiagnostic(
        endpoint: '/api/pulse/campaigns/$campaignId/start',
        statusCode: e.statusCode,
        backendCode: _extractBackendCode(e.payload),
        backendMessage: _extractBackendMessage(e.payload, fallback: e.message),
        success: false,
      );
      if (mounted) _showInsufficientCreditsSnackBar(e);
    } catch (e) {
      _recordCampaignDiagnostic(
        endpoint: '/api/pulse/campaigns/$campaignId/start',
        backendMessage: e.toString(),
        success: false,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
    }
  }

  Future<void> _confirmDeleteCampaign(String campaignId, String campaignName) async {
    final confirmName = campaignName.trim().isEmpty ? 'Campaign' : campaignName.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteCampaignConfirmDialog(
        confirmName: confirmName,
        onCancel: () => Navigator.of(ctx).pop(false),
        onDelete: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await NeyvoPulseApi.deleteCampaign(campaignId);
      if (mounted) {
        setState(() {
          _selectedCampaignId = null;
          _selectedActionsTabVapiCallId = null;
          _stopDetailAutoRefresh();
        });
        _load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign deleted. Data is kept for records.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
    }
  }

  Future<void> _saveCampaignEdit({required String name, required List<String> studentIds, bool useFilters = false}) async {
    final id = _editingCampaignId!;
    String? agentId;
    String? profileId;
    if (_selectedOperatorValue != null && _selectedOperatorValue!.isNotEmpty) {
      if (_selectedOperatorValue!.startsWith('profile:')) {
        profileId = _selectedOperatorValue!.substring(8);
      } else if (_selectedOperatorValue!.startsWith('agent:')) {
        agentId = _selectedOperatorValue!.substring(6);
      }
    }
    try {
      await NeyvoPulseApi.updateCampaign(
        id,
        name: name,
        agentId: agentId,
        profileId: profileId,
        templateId: null,
        studentIds: useFilters ? null : studentIds,
        filters: useFilters ? {
          'has_balance': _smartHasBalance,
          'is_overdue': _smartOverdueOnly,
          if (_smartBalanceMinController.text.trim().isNotEmpty) 'balance_min': double.tryParse(_smartBalanceMinController.text.replaceAll(RegExp(r'[^0-9.]'), '')),
          if (_smartDueBefore != null && _smartDueBefore!.isNotEmpty) 'due_before': _smartDueBefore,
        } : null,
        scheduledAt: _scheduleNow ? null : _scheduledAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign updated'), backgroundColor: NeyvoTheme.success),
        );
        setState(() {
          _editingCampaignId = null;
          _editCampaignData = null;
          _showCreateWizard = false;
          _wizardStep = 0;
          _nameController.clear();
          _selectedAgentId = null;
          _selectedOperatorValue = null;
          _selectedStudentIds.clear();
          _selectAll = false;
          _manualAudienceSelection = false;
        });
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(campaignsNotifierProvider);
    if (_campaigns.isEmpty && asyncValue.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_campaigns.isEmpty && asyncValue.hasError) {
      return Center(child: Text('Error: ${asyncValue.error}'));
    }
    if (_showCreateWizard) {
      return _buildWizard();
    }

    if (_selectedCampaignId != null) {
      return _buildCampaignDetailScreen(_selectedCampaignId!);
    }

    if (_loading && _campaigns.isEmpty) {
      return Scaffold(
        backgroundColor: NeyvoTheme.bgPrimary,
        appBar: AppBar(
          title: Text('Campaigns', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
          backgroundColor: NeyvoTheme.bgSurface,
          foregroundColor: NeyvoTheme.textPrimary,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, PulseRouteNames.students),
              icon: const Icon(Icons.people_outlined, size: 18),
              label: const Text('Contacts'),
            ),
            const SizedBox(width: NeyvoSpacing.sm),
            FilledButton.icon(
              onPressed: () => setState(() {
                _showCreateWizard = true;
                _wizardStep = 0;
                _nameController.clear();
                _selectedStudentIds.clear();
                _manualAudienceSelection = false;
                _selectAll = false;
              }),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create Campaign'),
              style: FilledButton.styleFrom(
                backgroundColor: true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: NeyvoSpacing.md),
          ],
        ),
        body: buildNeyvoLoadingState(),
      );
    }

    if (_error != null && _campaigns.isEmpty) {
      return Scaffold(
        backgroundColor: NeyvoTheme.bgPrimary,
        appBar: AppBar(
          title: Text('Campaigns', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
          backgroundColor: NeyvoTheme.bgSurface,
          foregroundColor: NeyvoTheme.textPrimary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(NeyvoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCampaignDiagnosticsPanel(),
              const SizedBox(height: NeyvoSpacing.lg),
              buildNeyvoErrorState(onRetry: _load),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        title: Text('Campaigns', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        backgroundColor: NeyvoTheme.bgSurface,
        foregroundColor: NeyvoTheme.textPrimary,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, PulseRouteNames.students),
            icon: const Icon(Icons.people_outlined, size: 18),
            label: const Text('Contacts'),
          ),
          const SizedBox(width: NeyvoSpacing.sm),
          FilledButton.icon(
            onPressed: () => setState(() {
              _showCreateWizard = true;
              _wizardStep = 0;
              _nameController.clear();
              _selectedStudentIds.clear();
              _manualAudienceSelection = false;
              _selectAll = false;
            }),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Create Campaign'),
            style: FilledButton.styleFrom(
              backgroundColor: true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: NeyvoSpacing.md),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Text(_error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error)),
              const SizedBox(height: NeyvoSpacing.md),
            ],
            _buildCampaignDiagnosticsPanel(),
            const SizedBox(height: NeyvoSpacing.lg),
            Text('Campaigns', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
            const SizedBox(height: NeyvoSpacing.sm),
            Text(
              'Launch bulk outbound call campaigns by audience and script.',
              style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: NeyvoSpacing.xl),
            if (_campaigns.isEmpty)
              buildNeyvoEmptyState(
                context: context,
                title: 'No campaigns yet',
                subtitle: 'Launch your first outbound campaign. Select an agent, upload contacts, and start calling.',
                buttonLabel: 'Create Campaign',
                onAction: () => setState(() => _showCreateWizard = true),
                icon: Icons.campaign_outlined,
                actionButtonColor: true ? Theme.of(context).colorScheme.primary : null,
              )
            else
              ..._campaigns.map((c) => Card(
                    color: NeyvoTheme.bgCard,
                    margin: const EdgeInsets.only(bottom: NeyvoSpacing.md),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: NeyvoTheme.bgHover,
                        child: Icon(
                          Icons.campaign_outlined,
                          color: true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(c['name']?.toString() ?? 'Unnamed', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                      subtitle: Text(
                        '${c['total_planned'] ?? c['student_count'] ?? 0} contacts • ${c['status'] ?? 'draft'}${(c['total_initiated'] ?? 0) > 0 ? ' • ${c['total_initiated']} placed' : ''}',
                        style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                      ),
                      onTap: () {
                        final id = c['id']?.toString();
                        if (id == null) return;
                        setState(() {
                          _detailStatusFilter = 'all';
                          _selectedCampaignId = id;
                          _selectedActionsTabVapiCallId = null;
                          _campaignDetailBundleFuture = _fetchCampaignDetailBundle(id);
                        });
                        _startDetailAutoRefresh();
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined),
                            tooltip: 'View & manage',
                            onPressed: () {
                              final id = c['id']?.toString();
                              if (id == null) return;
                              setState(() {
                                _detailStatusFilter = 'all';
                                _selectedCampaignId = id;
                                _selectedActionsTabVapiCallId = null;
                                _campaignDetailBundleFuture = _fetchCampaignDetailBundle(id);
                              });
                              _startDetailAutoRefresh();
                            },
                          ),
                          if (c['status'] != 'running')
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete campaign',
                              onPressed: () => _confirmDeleteCampaign(c['id']?.toString() ?? '', c['name']?.toString() ?? 'Campaign'),
                            ),
                          if (c['status'] == 'draft' || c['status'] == 'scheduled') ...[
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit campaign',
                              onPressed: () {
                                _nameController.text = c['name']?.toString() ?? '';
                                final aid = (c['agent_id'] ?? '').toString().trim();
                                final pid = (c['profile_id'] ?? '').toString().trim();
                                _selectedAgentId = aid.isNotEmpty ? aid : null;
                                _selectedOperatorValue = pid.isNotEmpty ? 'profile:$pid' : (aid.isNotEmpty ? 'agent:$aid' : null);
                                _selectedStudentIds = {};
                                final ids = c['student_ids'];
                                if (ids is List) _selectedStudentIds = ids.map((e) => e?.toString()).whereType<String>().toSet();
                                _scheduleNow = c['scheduled_at'] == null;
                                _scheduledAt = null;
                                if (c['scheduled_at'] != null) _scheduledAt = DateTime.tryParse(c['scheduled_at'].toString());
                                setState(() {
                                  _editingCampaignId = c['id']?.toString();
                                  _editCampaignData = Map<String, dynamic>.from(c);
                                  _showCreateWizard = true;
                                  _wizardStep = 0;
                                });
                              },
                            ),
                          ],
                          if (c['status'] == 'draft' ||
                              c['status'] == 'scheduled' ||
                              c['status'] == 'ready')
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              tooltip: 'Run campaign',
                              onPressed: () => _startOrRerunCampaign(c),
                            ),
                          if (c['status'] == 'completed' || c['status'] == 'running')
                            IconButton(
                              icon: const Icon(Icons.replay),
                              tooltip: 'Rerun campaign',
                              onPressed: () => _startOrRerunCampaign(c),
                            ),
                        ],
                      ),
                    ),
                  )),
            if (_campaigns.isNotEmpty) ...[
              const SizedBox(height: NeyvoSpacing.sm),
              Text(
                'Loaded ${_campaigns.length} campaigns',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
              ),
              const SizedBox(height: NeyvoSpacing.sm),
              Center(
                child: _campaignsHasMore
                    ? FilledButton(
                        onPressed: _campaignsLoadingMore ? null : () => _loadCampaigns(reset: false),
                        child: _campaignsLoadingMore
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Load more'),
                      )
                    : Text('No more campaigns', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignDetailScreen(String campaignId) {
    _campaignDetailBundleFuture ??= _fetchCampaignDetailBundle(campaignId);
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('campaign_detail_$campaignId'),
      future: _campaignDetailBundleFuture,
      builder: (context, snapshot) {
        // Store latest good payload in cache.
        if (snapshot.hasData) {
          _campaignDetailCache[campaignId] = Map<String, dynamic>.from(snapshot.data!);
        }
        final cached = _campaignDetailCache[campaignId];
        final preferRefetchedReport = _campaignReportRefetchedForActionItems == campaignId && cached != null;
        final data = preferRefetchedReport ? cached : (snapshot.data ?? cached);

        // First load only: show full-screen loader.
        if (data == null) {
          return Scaffold(
            backgroundColor: NeyvoTheme.bgPrimary,
            appBar: AppBar(
              backgroundColor: NeyvoTheme.bgSurface,
              foregroundColor: NeyvoTheme.textPrimary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedCampaignId = null;
                  _selectedActionsTabVapiCallId = null;
                  _campaignReportRefetchedForActionItems = null;
                  _campaignDetailBundleFuture = null;
                  _stopDetailAutoRefresh();
                }),
              ),
              title: Text('Campaign details', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final c = data['campaign'] as Map<String, dynamic>? ?? {};
        final calls = (data['calls'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final metrics = Map<String, dynamic>.from((data['metrics'] as Map? ?? const {}));
        final items = (data['items'] as List?)?.cast<dynamic>().map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        final status = c['status']?.toString() ?? 'draft';
        final statusLower = status.toLowerCase().trim();
        final isTerminal = statusLower == 'completed' || statusLower.startsWith('stopped') || statusLower == 'cancelled' || statusLower == 'deleted';
        final report = (data['report'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final callDetails = (report['call_details'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
            ) ??
            const <String, Map<String, dynamic>>{};
        final outcomeSummary = (report['outcome_summary'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v is int) ? v : (int.tryParse(v?.toString() ?? '') ?? 0)),
            ) ??
            const <String, int>{};
        final operatorGoal = report['operator_goal']?.toString() ?? '';
        final canStart =
            statusLower == 'draft' || statusLower == 'scheduled' || statusLower == 'ready';
        final canRerun = statusLower == 'completed' || statusLower == 'running';
        final canEdit = statusLower == 'draft' || statusLower == 'scheduled';
        // Can delete any campaign except when running (soft delete preserves data)
        final canDelete = status != 'running';
        final templateName = c['template_id']?.toString() ?? '—';
        final created = c['created_at'];
        final started = c['started_at'];
        String formatDate(dynamic v) => UserTimezoneService.format(v);
        int asInt(dynamic v, [int def = 0]) {
          if (v == null) return def;
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse(v.toString()) ?? def;
        }

        final totalPlanned = asInt(metrics['total_planned'] ?? c['total_planned'] ?? c['student_count'] ?? 0);
        final queuedCount = asInt(metrics['queued_count'] ?? c['queued_count'] ?? 0);
        final activeCount = asInt(metrics['active_count'] ?? c['active_count'] ?? 0);
        final retryWaitCount = asInt(metrics['retry_wait_count'] ?? c['retry_wait_count'] ?? 0);
        final completedCount = asInt(metrics['completed_count'] ?? c['completed_count'] ?? c['total_completed'] ?? 0);
        final failedCount = asInt(metrics['failed_count'] ?? c['failed_count'] ?? c['total_failed'] ?? 0);
        final maxConcurrent = asInt(metrics['max_concurrent'] ?? c['max_concurrent'] ?? 10, 10);
        final done = completedCount + failedCount;
        final totalOperations = asInt(metrics['total_operations'] ?? done, done);
        final progress = totalPlanned > 0 ? (done / totalPlanned).clamp(0.0, 1.0) : 0.0;
        final progressPct = (metrics['progress_percentage'] as num?)?.toDouble() ?? (progress * 100.0);
        final eta = metrics['estimated_completion_time'];
        final elapsedMinutes = (metrics['elapsed_minutes'] as num?)?.toDouble();
        final throughputPerMinute = (metrics['throughput_per_minute'] as num?)?.toDouble();
        final avgCallSeconds = asInt(metrics['average_call_duration_seconds'] ?? 45, 45);
        final totalCreditsUsed = calls.fold<int>(0, (sum, call) {
          final v = call['credits_used'] ?? call['credits_charged'];
          if (v is int) return sum + v;
          if (v is num) return sum + v.toInt();
          return sum + (int.tryParse(v?.toString() ?? '') ?? 0);
        });
        final avgCreditsPerCall = calls.isNotEmpty ? (totalCreditsUsed / calls.length) : 0.0;
        final audienceMode = (c['audience_mode'] ?? '').toString().trim().toUpperCase();
        final manualAudienceIds = (c['manual_student_ids'] as List?)
                ?.map((e) => (e ?? '').toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            <String>[];
        final legacyAudienceIds = (c['student_ids'] as List?)
                ?.map((e) => (e ?? '').toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            <String>[];
        final audienceIds = audienceMode == 'MANUAL' ? manualAudienceIds : legacyAudienceIds;

        String operatorLabel() {
          final pid = (c['profile_id'] ?? '').toString().trim();
          final aid = (c['agent_id'] ?? '').toString().trim();
          if (pid.isNotEmpty) {
            final list = _operatorsForCampaign.where((o) => o['value'] == 'profile:$pid').toList();
            if (list.isNotEmpty) return list.first['name']?.toString() ?? '—';
          }
          if (aid.isNotEmpty) {
            final list = _operatorsForCampaign.where((o) => o['value'] == 'agent:$aid').toList();
            if (list.isNotEmpty) return list.first['name']?.toString() ?? '—';
          }
          return '—';
        }

        String outboundNumberLabel() {
          final campaignPnId = (c['campaign_phone_number_id'] ?? '').toString().trim();
          if (campaignPnId.isNotEmpty) {
            for (final n in _outboundPhoneNumbers) {
              final id = (n['phone_number_id'] ?? n['id'] ?? '').toString().trim();
              if (id == campaignPnId) {
                return (n['label'] ?? n['role'] ?? n['phone_number'] ?? id).toString();
              }
            }
            return campaignPnId;
          }
          if (statusLower == 'draft' || statusLower == 'scheduled' || statusLower == 'ready') {
            return 'Not started yet';
          }
          return '—';
        }

        String audienceSummary() {
          if (audienceMode == 'MANUAL') {
            return '${manualAudienceIds.length} contacts selected';
          }
          if (audienceMode == 'FILTERS') {
            final snapshotSize = asInt(c['snapshot_audience_size'] ?? 0);
            final planned = asInt(c['total_planned'] ?? 0);
            final count = snapshotSize > 0 ? snapshotSize : planned;
            return count > 0 ? 'Filters • $count contacts' : 'Filters audience';
          }
          if (manualAudienceIds.isNotEmpty) {
            return '${manualAudienceIds.length} contacts selected';
          }
          if (legacyAudienceIds.isNotEmpty) {
            return '${legacyAudienceIds.length} contacts selected';
          }
          if (c['filters'] != null) {
            return 'Filters audience';
          }
          return '—';
        }
        return Scaffold(
          backgroundColor: NeyvoTheme.bgPrimary,
          appBar: AppBar(
            backgroundColor: NeyvoTheme.bgSurface,
            foregroundColor: NeyvoTheme.textPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedCampaignId = null;
                _selectedActionsTabVapiCallId = null;
                _campaignDetailBundleFuture = null;
                _stopDetailAutoRefresh();
              }),
            ),
            title: Text('Campaign details', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _reloadFullCampaignDetail,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More actions',
                onSelected: (value) {
                  switch (value) {
                    case 'download':
                      _downloadCampaignReport(campaignId);
                      break;
                    case 'export':
                      _exportCampaignFull(campaignId);
                      break;
                    case 'pause':
                      NeyvoPulseApi.pauseCampaign(campaignId).then((_) {
                        if (mounted) _reloadFullCampaignDetail();
                      }).catchError((e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                        }
                      });
                      break;
                    case 'resume':
                      NeyvoPulseApi.resumeCampaign(campaignId).then((_) {
                        if (mounted) _reloadFullCampaignDetail();
                      }).catchError((e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                        }
                      });
                      break;
                    case 'stop':
                      NeyvoPulseApi.stopCampaign(campaignId).then((_) {
                        if (mounted) {
                          _reloadFullCampaignDetail();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign stopped. All calls ended.')));
                        }
                      }).catchError((e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                        }
                      });
                      break;
                    case 'delete':
                      _confirmDeleteCampaign(campaignId, c['name']?.toString() ?? 'Campaign');
                      break;
                    case 'edit':
                      _nameController.text = c['name']?.toString() ?? '';
                      _selectedStudentIds = {};
                      final ids = c['student_ids'];
                      if (ids is List) {
                        _selectedStudentIds = ids.map((e) => e?.toString()).whereType<String>().toSet();
                      }
                      _scheduleNow = c['scheduled_at'] == null;
                      _scheduledAt = null;
                      if (c['scheduled_at'] != null) {
                        _scheduledAt = DateTime.tryParse(c['scheduled_at'].toString());
                      }
                      _filterType = 'all';
                      setState(() {
                        _editingCampaignId = campaignId;
                        _editCampaignData = Map<String, dynamic>.from(c);
                        _showCreateWizard = true;
                        _selectedCampaignId = null;
                        _campaignDetailBundleFuture = null;
                        _selectedActionsTabVapiCallId = null;
                        _wizardStep = 0;
                      });
                      break;
                    case 'start':
                      _startOrRerunCampaign(c);
                      break;
                    case 'start_subset':
                      _startCampaignWithSubset(campaignId, audienceIds);
                      break;
                    case 'rerun':
                      _startOrRerunCampaign(c);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'download', child: ListTile(leading: Icon(Icons.download_outlined, size: 20), title: Text('Download report'), dense: true)),
                  const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.table_chart_outlined, size: 20), title: Text('Export campaign (CSV)'), dense: true)),
                  if (status == 'running')
                    const PopupMenuItem(value: 'pause', child: ListTile(leading: Icon(Icons.pause_circle_outline, size: 20), title: Text('Pause'), dense: true)),
                  if (status == 'paused')
                    const PopupMenuItem(value: 'resume', child: ListTile(leading: Icon(Icons.play_circle_outline, size: 20), title: Text('Resume'), dense: true)),
                  if (status == 'running' || status == 'paused')
                    const PopupMenuItem(value: 'stop', child: ListTile(leading: Icon(Icons.stop_circle_outlined, size: 20), title: Text('Stop'), dense: true)),
                  if (canDelete)
                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, size: 20), title: Text('Delete'), dense: true)),
                  if (canEdit)
                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined, size: 20), title: Text('Edit'), dense: true)),
                  if (canStart)
                    const PopupMenuItem(
                        value: 'start',
                        child: ListTile(
                            leading: Icon(Icons.play_arrow, size: 20), title: Text('Run campaign'), dense: true)),
                  if (canStart && audienceIds.isNotEmpty)
                    const PopupMenuItem(value: 'start_subset', child: ListTile(leading: Icon(Icons.playlist_add_check_circle_outlined, size: 20), title: Text('Start subset'), dense: true)),
                  if (canRerun)
                    const PopupMenuItem(value: 'rerun', child: ListTile(leading: Icon(Icons.replay, size: 20), title: Text('Rerun campaign'), dense: true)),
                ],
              ),
              if (canStart || canRerun)
                Padding(
                  padding: const EdgeInsets.only(right: NeyvoSpacing.md),
                  child: _buildCallerIdDropdown(campaign: c),
                ),
            ],
          ),
          body: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: NeyvoTheme.bgSurface,
                  child: TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: NeyvoTheme.textSecondary,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Actions'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(NeyvoSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Credits: available and required per call (campaigns need credits to place calls)
                            Card(
                  color: (_walletCredits ?? 0) == 0 ? NeyvoTheme.warning.withOpacity(0.15) : NeyvoTheme.bgCard,
                  child: Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          (_walletCredits ?? 0) == 0 ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
                          size: 20,
                          color: (_walletCredits ?? 0) == 0 ? NeyvoTheme.warning : NeyvoTheme.textSecondary,
                        ),
                        const SizedBox(width: NeyvoSpacing.sm),
                        Expanded(
                          child: Text(
                            (_walletCredits ?? 0) == 0
                                ? 'No credits to run campaigns. Add credits in Billing to place calls.'
                                : 'Available credits: ${_walletCredits ?? 0}  •  Required per call: ~${_creditsPerMinute ?? 25} credits (~1 min)',
                            style: NeyvoType.bodySmall.copyWith(
                              color: (_walletCredits ?? 0) == 0 ? NeyvoTheme.warning : NeyvoTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: NeyvoSpacing.md),
                _buildCampaignLiveOverviewCard(
                  context: context,
                  campaignName: c['name']?.toString() ?? 'Unnamed',
                  statusRaw: status,
                  totalPlanned: totalPlanned,
                  queuedCount: queuedCount,
                  activeCount: activeCount,
                  completedCount: completedCount,
                  failedCount: failedCount,
                  retryWaitCount: retryWaitCount,
                  maxConcurrent: maxConcurrent,
                  done: done,
                  progress: progress,
                  progressPct: progressPct,
                  audienceSummaryText: audienceSummary(),
                  snapshotStatus: (c['snapshot_status'] ?? metrics['snapshot_status'] ?? 'none').toString(),
                ),
                const SizedBox(height: NeyvoSpacing.md),
                if (canStart)
                  Card(
                    color: NeyvoTheme.bgCard,
                    child: Padding(
                      padding: const EdgeInsets.all(NeyvoSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.play_circle_outline, size: 22, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: NeyvoSpacing.sm),
                              Text(
                                'Run campaign',
                                style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: NeyvoSpacing.sm),
                          Text(
                            'Audience is prepared. Confirm the outbound number in the header, then launch.',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                          ),
                          const SizedBox(height: NeyvoSpacing.md),
                          Wrap(
                            spacing: NeyvoSpacing.md,
                            runSpacing: NeyvoSpacing.sm,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _startOrRerunCampaign(c),
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text('Run campaign'),
                              ),
                              if (audienceIds.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () => _startCampaignWithSubset(campaignId, audienceIds),
                                  icon: const Icon(Icons.playlist_add_check_circle_outlined, size: 20),
                                  label: const Text('Start subset'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (canStart) const SizedBox(height: NeyvoSpacing.md),
                Builder(
                  builder: (context) {
                    final lastErr = (metrics['last_error'] ?? c['last_error'])?.toString().trim() ?? '';
                    final cloudErr = (metrics['last_cloud_task_error'] ?? c['last_cloud_task_error'])?.toString().trim() ?? '';
                    final cloudType = (metrics['last_cloud_task_error_type'] ?? c['last_cloud_task_error_type'])?.toString().trim() ?? '';
                    if (lastErr.isEmpty && cloudErr.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: NeyvoSpacing.md),
                      child: Card(
                        color: NeyvoTheme.error.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(NeyvoSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: NeyvoTheme.error, size: 22),
                                  const SizedBox(width: NeyvoSpacing.sm),
                                  Text(
                                    'Attention needed',
                                    style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.error, fontSize: 16),
                                  ),
                                ],
                              ),
                              if (lastErr.isNotEmpty) ...[
                                const SizedBox(height: NeyvoSpacing.sm),
                                Text(lastErr, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary)),
                              ],
                              if (cloudErr.isNotEmpty) ...[
                                const SizedBox(height: NeyvoSpacing.sm),
                                Text(
                                  cloudType.isNotEmpty ? 'Background task ($cloudType): $cloudErr' : 'Background task: $cloudErr',
                                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Card(
                  color: NeyvoTheme.bgCard,
                  child: Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Details', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.md, vertical: NeyvoSpacing.xs),
                              decoration: BoxDecoration(
                                color: _campaignStatusBadgeColor(statusLower).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _campaignStatusBadgeColor(statusLower).withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                _campaignStatusLabel(status),
                                style: NeyvoType.labelLarge.copyWith(color: _campaignStatusBadgeColor(statusLower), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: NeyvoSpacing.md),
                        Text('More stats', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted)),
                        const SizedBox(height: NeyvoSpacing.xs),
                        Wrap(
                          spacing: NeyvoSpacing.lg,
                          runSpacing: NeyvoSpacing.sm,
                          children: [
                            _detailChip('Operations done', '$totalOperations'),
                            _detailChip('Avg call', '${avgCallSeconds}s'),
                            if (outcomeSummary.isNotEmpty) ...[
                              _detailChip('Answered', '${outcomeSummary['answered'] ?? 0}'),
                              _detailChip('Voicemail', '${outcomeSummary['voicemail'] ?? 0}'),
                              _detailChip('Not connected', '${outcomeSummary['not_connected'] ?? 0}'),
                            ],
                            if (totalCreditsUsed > 0) _detailChip('Credits used', '$totalCreditsUsed cr'),
                            if (totalCreditsUsed > 0 && calls.isNotEmpty) _detailChip('Avg / call', '${avgCreditsPerCall.toStringAsFixed(1)} cr'),
                            if (throughputPerMinute != null && throughputPerMinute > 0)
                              _detailChip('Throughput', '${throughputPerMinute.toStringAsFixed(1)} calls/min'),
                            // Snapshot / audience readiness badge
                            Builder(
                              builder: (context) {
                                final snapshotStatusRaw = (c['snapshot_status'] ?? 'none').toString();
                                final snapshotStatus = snapshotStatusRaw.toString().toLowerCase();
                                final snapshotSize = (c['snapshot_audience_size'] as int?) ?? 0;
                                String label;
                                String value;
                                if (snapshotStatus == 'complete') {
                                  label = 'Snapshot';
                                  value = 'Ready • $snapshotSize contacts';
                                } else if (snapshotStatus == 'invalid') {
                                  label = 'Snapshot';
                                  value = 'Needs fix • $snapshotSize contacts';
                                } else if (snapshotStatus == 'in_progress') {
                                  label = 'Snapshot';
                                  value = 'Preparing…';
                                } else {
                                  label = 'Snapshot';
                                  value = 'Not prepared';
                                }
                                return _detailChip(label, value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: NeyvoSpacing.md),
                        Row(
                          children: [
                            if (elapsedMinutes != null && elapsedMinutes > 0)
                              Text(
                                'Elapsed: ${elapsedMinutes.toStringAsFixed(1)} min',
                                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                              ),
                            const SizedBox(width: NeyvoSpacing.lg),
                            if (eta != null)
                              Text(
                                'ETA: ${formatDate(eta)}',
                                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                              ),
                          ],
                        ),
                        const Divider(height: NeyvoSpacing.xl),
                        _metaRow('Created', formatDate(created)),
                        _metaRow('Started', formatDate(started)),
                        _metaRow('Script template', templateName ?? '—'),
                        _metaRow('Operator', operatorLabel()),
                        _metaRow('Outbound number', outboundNumberLabel()),
                        const SizedBox(height: NeyvoSpacing.md),
                        Text('Audience & targets', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)),
                        const SizedBox(height: NeyvoSpacing.xs),
                        Text(
                          totalPlanned > 0
                              ? '$totalPlanned contact(s) in this campaign • ${audienceSummary()}'
                              : audienceSummary(),
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary, height: 1.35),
                        ),
                        if ((c['filters'] ?? c['student_ids']) != null || items.isNotEmpty) ...[
                          const SizedBox(height: NeyvoSpacing.sm),
                          if (items.isNotEmpty)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: items.length,
                                itemBuilder: (context, i) {
                                  final it = items[i];
                                  final name = (it['student_name'] ?? it['name'] ?? '—').toString();
                                  final phone = (it['student_phone'] ?? it['phone'] ?? '').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(left: NeyvoSpacing.md, bottom: 4),
                                    child: Text(
                                      phone.isEmpty ? name : '$name • $phone',
                                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                                    ),
                                  );
                                },
                              ),
                            )
                          else if (c['student_ids'] != null && (c['student_ids'] as List).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: NeyvoSpacing.md, top: 4),
                              child: Text(
                                'Contact names and numbers will appear after the campaign is started.',
                                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: NeyvoSpacing.xl),
                Text(
                  items.isEmpty
                      ? 'Targets (load with Refresh or wait — list updates on demand)'
                      : 'Targets (${items.length}) — $queuedCount queued • $activeCount live • $completedCount done',
                  style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'pending', label: Text('Pending')),
                        ButtonSegment(value: 'in_progress', label: Text('In progress')),
                        ButtonSegment(value: 'completed', label: Text('Done')),
                        ButtonSegment(value: 'failed', label: Text('Failed')),
                      ],
                      selected: {_detailStatusFilter},
                      onSelectionChanged: (v) => setState(() => _detailStatusFilter = v.first),
                    ),
                    const Spacer(),
                    if (isTerminal) ...[
                      Builder(builder: (context) {
                        final eligibleIds = items.where((it) {
                          final st = (it['status'] ?? '').toString().toLowerCase().trim();
                          final vapiId = (it['vapi_call_id'] ?? it['call_id'] ?? '').toString().trim();
                          final detail = vapiId.isNotEmpty ? callDetails[vapiId] : null;
                          final derived = _deriveCampaignCallOutcome(callItem: it, callDetail: detail);
                          final outcome = (derived['outcome'] ?? '').toString();
                          final callbackRequested = derived['callbackRequested'] == true;
                          if (callbackRequested) return false;
                          if (outcome == 'Voicemail' || outcome == 'Not Connected') return true;
                          // Some failures may still be 'failed' without details; treat as Not Connected.
                          return st == 'failed';
                        }).map((it) => (it['student_id'] ?? '').toString().trim()).where((id) => id.isNotEmpty).toSet().toList();

                        if (eligibleIds.isEmpty) return const SizedBox.shrink();
                        return TextButton.icon(
                          icon: const Icon(Icons.redo, size: 20),
                          label: Text('Retry all (${eligibleIds.length})'),
                          onPressed: () => _retryCampaignCalls(originalCampaign: c, studentIds: eligibleIds),
                        );
                      }),
                      const SizedBox(width: NeyvoSpacing.sm),
                    ],
                    if (_detailStatusFilter == 'pending')
                      TextButton.icon(
                        icon: const Icon(Icons.play_circle_outline, size: 20),
                        label: const Text('Call pending'),
                        onPressed: () async {
                          try {
                            final res = await NeyvoPulseApi.reclaimStuckCampaign(campaignId);
                            if (!mounted) return;
                            final ok = res['ok'] == true;
                            final issues = (res['issues'] as List?)?.join(', ');
                            final text = ok
                                ? 'Checked pending calls and refilled capacity if needed.'
                                : 'Checked pending calls.${issues != null && issues.isNotEmpty ? ' Issues: $issues' : ''}';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(text),
                                backgroundColor: ok ? NeyvoTheme.success : NeyvoTheme.warning,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                            _reloadFullCampaignDetail();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to trigger pending calls: $e'),
                                backgroundColor: NeyvoTheme.error,
                              ),
                            );
                          }
                        },
                      ),
                    Text(
                      'Active: $activeCount • Queued: $queuedCount • Retry: $retryWaitCount',
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                Builder(builder: (context) {
                  List<Map<String, dynamic>> visible = List<Map<String, dynamic>>.from(items);
                  String sOf(Map<String, dynamic> it) => (it['status'] ?? '').toString();
                  if (_detailStatusFilter == 'pending') {
                    visible = visible.where((it) {
                      final st = sOf(it);
                      return st == 'queued' || st == 'retry_wait';
                    }).toList();
                  } else if (_detailStatusFilter == 'in_progress') {
                    visible = visible.where((it) {
                      final st = sOf(it);
                      return st == 'in_progress' || st == 'dialing';
                    }).toList();
                  } else if (_detailStatusFilter != 'all') {
                    visible = visible.where((it) => sOf(it) == _detailStatusFilter).toList();
                  }

                  Color statusColor(String st) {
                    switch (st) {
                      case 'completed':
                        return NeyvoTheme.success;
                      case 'failed':
                        return NeyvoTheme.error;
                      case 'in_progress':
                      case 'dialing':
                        return Theme.of(context).colorScheme.primary;
                      case 'retry_wait':
                        return NeyvoTheme.warning;
                      default:
                        return NeyvoTheme.textMuted;
                    }
                  }

                  String statusLabel(String st) {
                    switch (st) {
                      case 'in_progress':
                        return 'In progress';
                      case 'retry_wait':
                        return 'Retry scheduled';
                      default:
                        return st.isEmpty ? '—' : st;
                    }
                  }

                  if (visible.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(NeyvoSpacing.lg),
                      child: Text('No targets in this view.', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
                    );
                  }

                  return Card(
                    color: NeyvoTheme.bgCard,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                          final it = visible[i];
                          final st = sOf(it);
                          final name = (it['student_name'] ?? it['name'] ?? '—').toString();
                          final phone = (it['student_phone'] ?? it['phone'] ?? '—').toString();
                          final attempt = it['attempt'];
                          final vapiId = (it['vapi_call_id'] ?? it['call_id'] ?? '').toString().trim();
                          final detail = vapiId.isNotEmpty ? callDetails[vapiId] : null;
                          final derived = isTerminal
                              ? _deriveCampaignCallOutcome(callItem: it, callDetail: detail)
                              : const <String, dynamic>{};
                          final outcome = (derived['outcome'] ?? '').toString();
                          final callbackRequested = derived['callbackRequested'] == true;
                          final backendOutcomeType = (detail?['outcome_type'] ?? detail?['success_metric'] ?? '').toString().trim();

                          Color outcomeColor(String o) {
                            switch (o) {
                              case 'Answered':
                                return NeyvoTheme.success;
                              case 'Voicemail':
                                return NeyvoTheme.warning;
                              case 'Not Connected':
                                return NeyvoTheme.error;
                              default:
                                return NeyvoTheme.textMuted;
                            }
                          }

                          final subtitleLines = <String>[
                            '$phone • ${statusLabel(st)}${attempt != null ? ' • attempt $attempt' : ''}',
                            if (isTerminal && outcome.isNotEmpty) 'Outcome: $outcome${backendOutcomeType.isNotEmpty ? ' • $backendOutcomeType' : ''}',
                            if (isTerminal && outcome == 'Answered' && callbackRequested) 'Callback requested',
                          ].where((e) => e.trim().isNotEmpty).toList();
                          final studentId = (it['student_id'] ?? it['id'] ?? '').toString().trim();
                          final canRetryThis = isTerminal &&
                              studentId.isNotEmpty &&
                              !callbackRequested &&
                              (outcome == 'Voicemail' || outcome == 'Not Connected');
                          return ListTile(
                            leading: Icon(Icons.person_outline, color: statusColor(st)),
                            title: Text(name, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)),
                            subtitle: Text(
                              subtitleLines.join('\n'),
                              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: canRetryThis
                                ? TextButton(
                                    onPressed: () => _retryCampaignCalls(originalCampaign: c, studentIds: [studentId]),
                                    child: const Text('Retry Call'),
                                  )
                                : (st == 'completed'
                                    ? const Icon(Icons.check_circle_outline, color: NeyvoTheme.success)
                                    : (st == 'failed'
                                        ? const Icon(Icons.error_outline, color: NeyvoTheme.error)
                                        : (isTerminal && outcome.isNotEmpty)
                                            ? Icon(Icons.circle, size: 12, color: outcomeColor(outcome))
                                            : null)),
                          );
                      },
                    ),
                  );
                }),
                const SizedBox(height: NeyvoSpacing.xl),
                Text('Placed calls (${calls.length})', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                const SizedBox(height: NeyvoSpacing.sm),
                if (calls.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.lg),
                    child: Text('No calls yet. Start the campaign to place calls.', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
                  )
                else
                  ...calls.take(50).map((call) => Card(
                        color: NeyvoTheme.bgCard,
                        margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                        child: ListTile(
                          leading: Icon(Icons.phone_outlined, color: Theme.of(context).colorScheme.primary),
                          title: Text(call['student_name']?.toString() ?? '—', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)),
                          subtitle: Text('${call['student_phone'] ?? '—'} • ${call['status'] ?? '—'}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                          trailing: Text(formatDate(call['created_at']), style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                        ),
                      )),
                if (calls.length > 50)
                  Padding(
                    padding: const EdgeInsets.only(top: NeyvoSpacing.sm),
                    child: Text('Showing first 50 of ${calls.length} calls', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                  ),
                const SizedBox(height: NeyvoSpacing.xl),
                Card(
                  color: NeyvoTheme.bgCard,
                  child: Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: NeyvoTheme.error, size: 24),
                            const SizedBox(width: 10),
                            Text('Danger zone', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.error)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          canDelete
                              ? 'Remove this campaign from the list. Campaign data is kept for records. Type the campaign name to confirm.'
                              : 'Cannot delete while campaign is running. Stop the campaign first, then you can delete it.',
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: canDelete ? () => _confirmDeleteCampaign(campaignId, c['name']?.toString() ?? 'Campaign') : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NeyvoTheme.error,
                              side: BorderSide(color: NeyvoTheme.error),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            label: Text(canDelete ? 'Delete campaign' : 'Delete campaign (disabled - campaign is running)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
                      _buildCampaignDetailActionsTab(
                        campaignId: campaignId,
                        campaign: c,
                        status: status,
                        canStart: canStart,
                        canRerun: canRerun,
                        canEdit: canEdit,
                        canDelete: canDelete,
                        audienceIds: audienceIds,
                        items: items,
                        callDetails: callDetails,
                        outcomeSummary: outcomeSummary,
                        operatorGoal: operatorGoal,
                        selectedVapiCallId: _selectedActionsTabVapiCallId,
                        onSelectVapiCallId: (id) => setState(() {
                          _selectedActionsTabVapiCallId = id;
                          _loadingActionItemsVapiId = null;
                        }),
                        actionItemsCache: _actionItemsCache,
                        loadingActionItemsVapiId: _loadingActionItemsVapiId,
                        onFetchActionItems: (vapiId) => _fetchActionItemsForCall(campaignId, vapiId),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchActionItemsForCall(String campaignId, String vapiCallId) async {
    if (vapiCallId.isEmpty) return;
    setState(() => _loadingActionItemsVapiId = vapiCallId);
    try {
      final res = await NeyvoPulseApi.getCallActionable(campaignId, vapiCallId);
      if (!mounted) return;
      final list = res['action_items'];
      setState(() {
        _actionItemsCache[vapiCallId] = list is List ? List<dynamic>.from(list) : <dynamic>[];
        _loadingActionItemsVapiId = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingActionItemsVapiId = null);
      if (e.statusCode == 404 || e.statusCode == null) {
        _actionItemsCache[vapiCallId] = [];
        _refetchCampaignReportForActionItems(campaignId);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingActionItemsVapiId = null);
    }
  }

  /// On 404 from actionable endpoint: refetch campaign report so call_details may include action_items.
  Future<void> _refetchCampaignReportForActionItems(String campaignId) async {
    try {
      final reportRes = await NeyvoPulseApi.getCampaignReport(campaignId);
      if (!mounted || reportRes['ok'] != true) return;
      final cached = _campaignDetailCache[campaignId];
      if (cached != null) {
        final updated = Map<String, dynamic>.from(cached);
        updated['report'] = reportRes;
        _campaignDetailCache[campaignId] = updated;
        setState(() => _campaignReportRefetchedForActionItems = campaignId);
      }
    } catch (_) {}
  }

  Widget _buildCampaignDetailActionsTab({
    required String campaignId,
    required Map<String, dynamic> campaign,
    required String status,
    required bool canStart,
    required bool canRerun,
    required bool canEdit,
    required bool canDelete,
    required List<String> audienceIds,
    required List<Map<String, dynamic>> items,
    required Map<String, Map<String, dynamic>> callDetails,
    required Map<String, int> outcomeSummary,
    required String operatorGoal,
    required String? selectedVapiCallId,
    required void Function(String?) onSelectVapiCallId,
    required Map<String, List<dynamic>> actionItemsCache,
    required String? loadingActionItemsVapiId,
    required void Function(String) onFetchActionItems,
  }) {
    return Padding(
      padding: const EdgeInsets.all(NeyvoSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Campaign actions',
            style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          Text(
            'Start, pause, or manage this campaign. Select a student on the left to view focused action items (critical / success / neutral). Use "View full call details" for transcript and summary.',
            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          Wrap(
            spacing: NeyvoSpacing.md,
            runSpacing: NeyvoSpacing.md,
            children: [
              if (canStart)
                FilledButton.icon(
                  onPressed: () => _startOrRerunCampaign(campaign),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Run campaign'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (canStart && audienceIds.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _startCampaignWithSubset(campaignId, audienceIds),
                  icon: const Icon(Icons.playlist_add_check_circle_outlined, size: 20),
                  label: const Text('Start subset'),
                ),
              if (canRerun)
                OutlinedButton.icon(
                  onPressed: () => _startOrRerunCampaign(campaign),
                  icon: const Icon(Icons.replay, size: 20),
                  label: const Text('Rerun campaign'),
                ),
              if (status == 'running')
                OutlinedButton.icon(
                  onPressed: () {
                    NeyvoPulseApi.pauseCampaign(campaignId).then((_) {
                      if (mounted) _reloadFullCampaignDetail();
                    }).catchError((e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error),
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.pause_circle_outline, size: 20),
                  label: const Text('Pause'),
                ),
              if (status == 'paused')
                OutlinedButton.icon(
                  onPressed: () {
                    NeyvoPulseApi.resumeCampaign(campaignId).then((_) {
                      if (mounted) _reloadFullCampaignDetail();
                    }).catchError((e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error),
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  label: const Text('Resume'),
                ),
              if (status == 'running' || status == 'paused')
                OutlinedButton.icon(
                  onPressed: () {
                    NeyvoPulseApi.stopCampaign(campaignId).then((_) {
                      if (mounted) {
                        _reloadFullCampaignDetail();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Campaign stopped. All calls ended.')),
                        );
                      }
                    }).catchError((e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error),
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                  label: const Text('Stop'),
                  style: OutlinedButton.styleFrom(foregroundColor: NeyvoTheme.error),
                ),
              OutlinedButton.icon(
                onPressed: () => _downloadCampaignReport(campaignId),
                icon: const Icon(Icons.download_outlined, size: 20),
                label: const Text('Download report'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportCampaignFull(campaignId),
                icon: const Icon(Icons.table_chart_outlined, size: 20),
                label: const Text('Export campaign'),
              ),
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: () {
                    _nameController.text = campaign['name']?.toString() ?? '';
                    _selectedStudentIds = {};
                    final ids = campaign['student_ids'];
                    if (ids is List) {
                      _selectedStudentIds = ids.map((e) => e?.toString()).whereType<String>().toSet();
                    }
                    _scheduleNow = campaign['scheduled_at'] == null;
                    _scheduledAt = null;
                    if (campaign['scheduled_at'] != null) {
                      _scheduledAt = DateTime.tryParse(campaign['scheduled_at'].toString());
                    }
                    _filterType = 'all';
                    setState(() {
                      _editingCampaignId = campaignId;
                      _editCampaignData = Map<String, dynamic>.from(campaign);
                      _showCreateWizard = true;
                      _selectedCampaignId = null;
                      _selectedActionsTabVapiCallId = null;
                      _wizardStep = 0;
                    });
                  },
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Edit campaign'),
                ),
              if (canDelete)
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteCampaign(campaignId, campaign['name']?.toString() ?? 'Campaign'),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Delete campaign'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NeyvoTheme.error,
                    side: BorderSide(color: NeyvoTheme.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: NeyvoTheme.bgHover.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeyvoTheme.border),
                    ),
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              'No call items yet',
                              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final it = items[index];
                              final vapiId = (it['vapi_call_id'] ?? it['call_id'] ?? '').toString().trim();
                              final detail = vapiId.isNotEmpty ? callDetails[vapiId] : null;
                              final derived = _deriveCampaignCallOutcome(callItem: it, callDetail: detail);
                              String outcomeLabel = derived['outcome'] as String? ?? 'Pending';
                              final itemStatus = (it['status'] ?? '').toString().toLowerCase();
                              if (outcomeLabel == 'Not Connected' && (itemStatus == 'queued' || itemStatus == 'dialing' || itemStatus == 'in_progress')) {
                                outcomeLabel = 'In progress';
                              } else if (outcomeLabel == 'Not Connected' && itemStatus != 'failed' && itemStatus != 'completed') {
                                outcomeLabel = 'Pending';
                              }
                              final name = (it['student_name'] ?? it['name'] ?? 'Unknown').toString();
                              final phone = (it['phone_number'] ?? it['phone'] ?? '—').toString();
                              final selectionKey = vapiId.isNotEmpty ? vapiId : 'item:${it['id'] ?? index}';
                              final isSelected = selectedVapiCallId == selectionKey;
                              return Material(
                                color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                                child: InkWell(
                                  onTap: () => onSelectVapiCallId(selectionKey),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.sm, vertical: NeyvoSpacing.xs),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                name,
                                                style: NeyvoType.bodyMedium.copyWith(
                                                  color: NeyvoTheme.textPrimary,
                                                  fontWeight: isSelected ? FontWeight.w600 : null,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                phone,
                                                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: NeyvoSpacing.xs),
                                        _actionsOutcomeChip(outcomeLabel),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: NeyvoSpacing.md),
                Expanded(
                  flex: 80,
                  child: _buildActionsDetailPanel(
                    operatorGoal: operatorGoal,
                    selectedVapiCallId: selectedVapiCallId,
                    items: items,
                    callDetails: callDetails,
                    actionItemsCache: actionItemsCache,
                    loadingActionItemsVapiId: loadingActionItemsVapiId,
                    onFetchActionItems: onFetchActionItems,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsOutcomeChip(String label) {
    Color bg;
    if (label == 'Answered') bg = NeyvoTheme.success.withValues(alpha: 0.2);
    else if (label == 'Voicemail') bg = NeyvoTheme.warning.withValues(alpha: 0.2);
    else if (label == 'In progress' || label == 'Pending') bg = NeyvoTheme.bgHover;
    else bg = NeyvoTheme.textSecondary.withValues(alpha: 0.2);
    return Chip(
      label: Text(label, style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textPrimary)),
      backgroundColor: bg,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildActionsDetailPanel({
    required String operatorGoal,
    required String? selectedVapiCallId,
    required List<Map<String, dynamic>> items,
    required Map<String, Map<String, dynamic>> callDetails,
    required Map<String, List<dynamic>> actionItemsCache,
    required String? loadingActionItemsVapiId,
    required void Function(String) onFetchActionItems,
  }) {
    Map<String, dynamic>? selectedItem;
    String? vapiIdForDetail;
    if (selectedVapiCallId != null && selectedVapiCallId.isNotEmpty) {
      if (selectedVapiCallId.startsWith('item:')) {
        final id = selectedVapiCallId.substring(5);
        for (final it in items) {
          if (it['id']?.toString() == id) {
            selectedItem = it;
            break;
          }
        }
      } else {
        vapiIdForDetail = selectedVapiCallId;
        for (final it in items) {
          if ((it['vapi_call_id'] ?? it['call_id'] ?? '').toString().trim() == selectedVapiCallId) {
            selectedItem = it;
            break;
          }
        }
      }
    }
    if (selectedVapiCallId == null || selectedVapiCallId.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: NeyvoTheme.bgHover.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NeyvoTheme.border),
        ),
        child: Center(
          child: Text(
            'Select a student to view action items',
            style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
          ),
        ),
      );
    }
    final detail = vapiIdForDetail != null ? callDetails[vapiIdForDetail] : null;
    final actionable = detail?['actionable_summary'] as Map<String, dynamic>?;
    List<dynamic>? actionItems = actionable?['action_items'] as List<dynamic>?;
    if ((actionItems == null || actionItems.isEmpty) && detail != null) {
      actionItems = _deriveActionItemsFromDetail(detail, actionable);
    }
    if ((actionItems == null || actionItems.isEmpty) && vapiIdForDetail != null) {
      final cached = actionItemsCache[vapiIdForDetail];
      if (cached != null && cached.isNotEmpty) actionItems = cached;
    }
    final isLoading = vapiIdForDetail != null && loadingActionItemsVapiId == vapiIdForDetail;
    if (vapiIdForDetail != null && (actionItems == null || actionItems.isEmpty) && !isLoading && actionItemsCache[vapiIdForDetail] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onFetchActionItems(vapiIdForDetail!);
      });
    }
    final outcomeType = (detail?['outcome_type'] ?? '').toString();
    String displayOutcome = outcomeType.isNotEmpty ? outcomeType : '—';
    if (displayOutcome == '—' && selectedItem != null) {
      final derived = _deriveCampaignCallOutcome(callItem: selectedItem, callDetail: detail);
      displayOutcome = derived['outcome'] as String? ?? '—';
    }

    // Build call map for "View full call details" -> CallDetailPage
    final callMapForDetail = Map<String, dynamic>.from(detail ?? {});
    if (vapiIdForDetail != null) callMapForDetail['vapi_call_id'] = vapiIdForDetail;
    callMapForDetail['transcript'] = detail?['transcript_full'] ?? detail?['transcript_snippet'];
    if (selectedItem != null) {
      callMapForDetail['student_name'] = selectedItem['student_name'] ?? selectedItem['name'];
      callMapForDetail['from'] = selectedItem['phone_number'] ?? selectedItem['phone'];
    }

    final supportTags = _deriveSupportTagsFromDetail(detail, actionable, actionItems);

    return Container(
      decoration: BoxDecoration(
        color: NeyvoTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NeyvoTheme.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _actionsOutcomeChip(displayOutcome),
                const SizedBox(width: NeyvoSpacing.md),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CallDetailPage(call: callMapForDetail)),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View full call details'),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: NeyvoSpacing.lg),
            if (supportTags.isNotEmpty) ...[
              Text(
                'Support requested',
                style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textSecondary),
              ),
              const SizedBox(height: NeyvoSpacing.xs),
              Wrap(
                spacing: NeyvoSpacing.xs,
                runSpacing: NeyvoSpacing.xs,
                children: supportTags.map(_supportTagChip).toList(),
              ),
              const SizedBox(height: NeyvoSpacing.lg),
            ],
            Text(
              'Action items',
              style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: NeyvoSpacing.sm),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: NeyvoSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (actionItems != null && actionItems!.isNotEmpty) ...[
              ...() {
                final items = actionItems!;
                return List.generate(items.length, (i) {
                  final item = items[i];
                  if (item is! Map) return const SizedBox.shrink();
                final text = (item['text'] ?? '').toString().trim();
                final category = (item['category'] ?? 'neutral').toString().toLowerCase();
                if (text.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                  child: _buildActionItemCard(
                    index: i + 1,
                    text: text,
                    category: category,
                    supportTags: supportTags,
                  ),
                );
                });
              }(),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: NeyvoSpacing.md),
                child: Text(
                  'No actionable items for this call. View full call details for transcript and summary.',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build action items from analysis_structured_data or old actionable_summary when action_items is missing.
  List<dynamic>? _deriveActionItemsFromDetail(Map<String, dynamic> detail, Map<String, dynamic>? actionable) {
    final list = <Map<String, String>>[];
    final analysis = detail['analysis_structured_data'] as Map<String, dynamic>?;
    if (analysis != null && analysis.isNotEmpty) {
      final support = analysis['support_area_mentioned']?.toString().trim();
      if (support != null && support.isNotEmpty && support != 'none') {
        final label = support == 'multiple'
            ? 'Student needs support in multiple areas'
            : 'Student needs ${support.replaceAll('_', ' ')} support';
        list.add({'text': label, 'category': 'critical'});
      }
      if (analysis['callback_requested'] == true) {
        list.add({'text': 'Callback requested', 'category': 'critical'});
      }
      if (analysis['reschedule_requested'] == true) {
        list.add({'text': 'Reschedule requested', 'category': 'critical'});
      }
      final resolution = analysis['call_resolution']?.toString().trim();
      if (resolution != null && resolution.isNotEmpty) {
        final isSuccess = resolution == 'resolved' || resolution == 'voicemail_left';
        list.add({
          'text': 'Call resolution: ${resolution.replaceAll('_', ' ')}',
          'category': isSuccess ? 'success' : 'neutral',
        });
      }
    }
    if (actionable != null) {
      final needs = actionable['support_needs'];
      if (needs is List && needs.isNotEmpty) {
        for (final n in needs) {
          final s = n?.toString().trim();
          if (s != null && s.isNotEmpty) {
            list.add({'text': 'Student needs: $s', 'category': 'critical'});
          }
        }
      }
      final suggested = actionable['suggested_actions'];
      if (suggested is List && suggested.isNotEmpty) {
        for (final a in suggested) {
          final s = a?.toString().trim();
          if (s != null && s.isNotEmpty) {
            list.add({'text': s, 'category': 'critical'});
          }
        }
      }
    }
    return list.isEmpty ? null : list;
  }

  List<String> _deriveSupportTagsFromDetail(
    Map<String, dynamic>? detail,
    Map<String, dynamic>? actionable,
    List<dynamic>? actionItems,
  ) {
    final tags = <String>{};

    // 1) Prefer explicit structured signal when present.
    final analysis = detail?['analysis_structured_data'] as Map<String, dynamic>?;
    final support = analysis?['support_area_mentioned']?.toString().trim().toLowerCase();
    if (support != null && support.isNotEmpty && support != 'none') {
      if (support == 'multiple') {
        // Fall back to keyword inference below.
      } else if (support == 'transportation') {
        tags.add('transportation');
      } else if (support == 'academic' || support == 'academics') {
        tags.add('academics');
      } else if (support == 'student_services' || support == 'career_support') {
        tags.add('career_support');
      }
    }

    // 2) Infer from action item text (backend-derived).
    final blob = (actionItems ?? const [])
        .whereType<Map>()
        .map((m) => (m['text'] ?? '').toString().toLowerCase())
        .join(' ');
    if (blob.isNotEmpty) {
      if (blob.contains('transportation') || blob.contains('bus pass') || blob.contains('getting to campus')) {
        tags.add('transportation');
      }
      if (blob.contains('academic') || blob.contains('tutor') || blob.contains('textbook') || blob.contains('advis')) {
        tags.add('academics');
      }
      if (blob.contains('career') || blob.contains('co-op') || blob.contains('coop') || blob.contains('student services') || blob.contains('case management')) {
        tags.add('career_support');
      }
    }

    // 3) Infer from legacy actionable fields if present.
    if (actionable != null) {
      final needs = actionable['support_needs'];
      if (needs is List) {
        final nblob = needs.map((x) => (x ?? '').toString().toLowerCase()).join(' ');
        if (nblob.contains('transport')) tags.add('transportation');
        if (nblob.contains('academic') || nblob.contains('tutor') || nblob.contains('textbook') || nblob.contains('advis')) tags.add('academics');
        if (nblob.contains('career') || nblob.contains('co-op') || nblob.contains('case') || nblob.contains('student services')) tags.add('career_support');
      }
    }

    final out = tags.toList();
    out.sort();
    return out;
  }

  Widget _supportTagChip(String tag) {
    final label = switch (tag) {
      'transportation' => 'Transportation',
      'academics' => 'Academics',
      'career_support' => 'Career support',
      _ => tag,
    };
    final Color bg;
    final Color fg;
    switch (tag) {
      case 'transportation':
        bg = NeyvoTheme.info.withValues(alpha: 0.18);
        fg = NeyvoTheme.info;
        break;
      case 'academics':
        bg = NeyvoTheme.success.withValues(alpha: 0.18);
        fg = NeyvoTheme.success;
        break;
      case 'career_support':
        bg = NeyvoTheme.warning.withValues(alpha: 0.20);
        fg = NeyvoTheme.warning;
        break;
      default:
        bg = NeyvoTheme.bgHover;
        fg = NeyvoTheme.textSecondary;
    }
    return Chip(
      label: Text(label, style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textPrimary)),
      backgroundColor: bg,
      side: BorderSide(color: fg.withValues(alpha: 0.45)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildActionItemCard({
    required int index,
    required String text,
    required String category,
    List<String> supportTags = const [],
  }) {
    Color bg;
    Color fg;
    if (category == 'critical') {
      bg = NeyvoTheme.error.withValues(alpha: 0.15);
      fg = NeyvoTheme.error;
    } else if (category == 'success') {
      bg = NeyvoTheme.success.withValues(alpha: 0.15);
      fg = NeyvoTheme.success;
    } else {
      bg = NeyvoTheme.warning.withValues(alpha: 0.2);
      fg = NeyvoTheme.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.sm, vertical: NeyvoSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (supportTags.isNotEmpty) ...[
            Wrap(
              spacing: NeyvoSpacing.xs,
              runSpacing: NeyvoSpacing.xs,
              children: supportTags.map(_supportTagChip).toList(),
            ),
            const SizedBox(height: NeyvoSpacing.xs),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index.',
                style: NeyvoType.bodyMedium.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: NeyvoSpacing.xs),
              Expanded(
                child: Text(
                  text,
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _campaignStatusLabel(String statusRaw) {
    final s = statusRaw.toLowerCase().trim();
    switch (s) {
      case 'running':
        return 'Running';
      case 'paused':
        return 'Paused';
      case 'completed':
        return 'Completed';
      case 'draft':
        return 'Draft';
      case 'scheduled':
        return 'Scheduled';
      case 'stopped_no_credits':
        return 'Stopped (credits)';
      case 'stopped':
        return 'Stopped';
      case 'failed':
        return 'Failed';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'ready':
        return 'Ready';
      default:
        if (s.startsWith('stopped')) return 'Stopped';
        if (statusRaw.isEmpty) return 'Unknown';
        return statusRaw;
    }
  }

  Color _campaignStatusBadgeColor(String statusLower) {
    if (statusLower == 'running') {
      return Colors.green.shade700;
    }
    if (statusLower == 'paused') {
      return Colors.orange.shade800;
    }
    if (statusLower == 'completed') {
      return Theme.of(context).colorScheme.primary;
    }
    if (statusLower == 'draft' || statusLower == 'scheduled' || statusLower == 'ready') {
      return NeyvoTheme.textSecondary;
    }
    if (statusLower.startsWith('stopped') ||
        statusLower == 'failed' ||
        statusLower == 'cancelled' ||
        statusLower == 'canceled' ||
        statusLower == 'stopped_no_credits') {
      return NeyvoTheme.error;
    }
    return NeyvoTheme.textSecondary;
  }

  Widget _pipelineStatCell(String title, String value, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: NeyvoSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: NeyvoTheme.textSecondary),
          const SizedBox(height: 4),
          Text(value, style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w700)),
          Text(title, style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textSecondary, fontWeight: FontWeight.w600)),
          Text(subtitle, style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCampaignLiveOverviewCard({
    required BuildContext context,
    required String campaignName,
    required String statusRaw,
    required int totalPlanned,
    required int queuedCount,
    required int activeCount,
    required int completedCount,
    required int failedCount,
    required int retryWaitCount,
    required int maxConcurrent,
    required int done,
    required double progress,
    required double progressPct,
    required String audienceSummaryText,
    required String snapshotStatus,
  }) {
    final s = statusRaw.toLowerCase().trim();
    final scheme = Theme.of(context).colorScheme;

    String headline = '';
    String detail = '';
    IconData icon = Icons.campaign_outlined;
    Color accent = NeyvoTheme.textSecondary;

    if (s == 'running') {
      accent = scheme.primary;
      icon = Icons.phone_in_talk_outlined;
      if (activeCount > 0 && queuedCount > 0) {
        headline = 'Live — dialing now';
        detail =
            '$activeCount on active calls • $queuedCount waiting in queue • $done of $totalPlanned contacts finished';
      } else if (activeCount > 0) {
        headline = 'Live — finishing remaining calls';
        detail = '$activeCount active — queue empty • $done of $totalPlanned finished';
      } else if (queuedCount > 0) {
        headline = 'Starting calls';
        detail =
            '$queuedCount contact(s) queued — up to $maxConcurrent calls can run in parallel';
      } else {
        headline = 'Running';
        detail = 'Queue empty — $done of $totalPlanned contacts processed';
      }
    } else if (s == 'paused') {
      accent = Colors.orange.shade800;
      icon = Icons.pause_circle_outline;
      headline = 'Paused';
      detail =
          '$queuedCount still queued${activeCount > 0 ? ' • $activeCount were active' : ''} — resume to continue dialing';
    } else if (s == 'completed') {
      accent = scheme.primary;
      icon = Icons.check_circle_outline;
      headline = 'Completed';
      detail =
          '$completedCount succeeded${failedCount > 0 ? ' • $failedCount failed' : ''} out of $totalPlanned targets';
    } else if (s == 'draft' || s == 'scheduled' || s == 'ready') {
      accent = NeyvoTheme.textSecondary;
      icon = Icons.edit_calendar_outlined;
      if (s == 'scheduled') {
        headline = 'Scheduled';
      } else if (s == 'ready') {
        // "Ready" is a backend status meaning snapshot/validation passed — dialing only begins after Run campaign.
        headline = 'Prepared — not dialing yet';
      } else {
        headline = 'Draft';
      }
      if (s == 'ready') {
        detail =
            'Audience is locked and valid. Tap Run campaign (card below or ⋮ menu) to start calls • $totalPlanned contact(s).';
      } else {
        detail = 'Audience: $audienceSummaryText • $totalPlanned target(s) when you launch';
      }
    } else if (s.startsWith('stopped') || s == 'stopped_no_credits') {
      accent = NeyvoTheme.error;
      icon = Icons.stop_circle_outlined;
      headline = s == 'stopped_no_credits' ? 'Stopped — credits' : 'Stopped';
      detail = 'Progress saved at $done of $totalPlanned • $queuedCount were still queued';
    } else if (s == 'failed') {
      accent = NeyvoTheme.error;
      icon = Icons.error_outline;
      headline = 'Failed';
      detail = 'Campaign ended with an error — see Attention needed above';
    } else {
      accent = NeyvoTheme.textSecondary;
      icon = Icons.campaign_outlined;
      headline = _campaignStatusLabel(statusRaw);
      detail = 'Audience: $audienceSummaryText';
    }

    if (s == 'running' && retryWaitCount > 0) {
      detail += ' • $retryWaitCount in retry wait (cooldown)';
    }

    final snap = snapshotStatus.toLowerCase();
    String? snapshotHint;
    if (s == 'running' && snap.isNotEmpty && snap != 'complete' && snap != 'none') {
      snapshotHint = snap == 'in_progress'
          ? 'Audience snapshot still preparing — calls may wait briefly.'
          : 'Audience snapshot: $snap — confirm Prepare & preview if dialing stalls.';
    }

    return Card(
      elevation: 0,
      color: accent.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 28),
                const SizedBox(width: NeyvoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaignName,
                        style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(headline, style: NeyvoType.titleMedium.copyWith(color: accent, fontWeight: FontWeight.w600, fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary, height: 1.35),
                      ),
                      if (snapshotHint != null) ...[
                        const SizedBox(height: NeyvoSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 18, color: NeyvoTheme.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(snapshotHint, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: NeyvoSpacing.lg),
            Text('How the run is moving', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted)),
            const SizedBox(height: NeyvoSpacing.sm),
            Row(
              children: [
                Expanded(child: _pipelineStatCell('Targets', '$totalPlanned', 'audience', Icons.groups_outlined)),
                Expanded(child: _pipelineStatCell('In queue', '$queuedCount', 'waiting to dial', Icons.queue_music_outlined)),
                Expanded(child: _pipelineStatCell('Live now', '$activeCount', 'of $maxConcurrent lines', Icons.call_outlined)),
                Expanded(
                  child: _pipelineStatCell(
                    'Finished',
                    '$completedCount',
                    failedCount > 0 ? '$failedCount failed' : 'completed',
                    Icons.task_alt_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: NeyvoSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: NeyvoTheme.bgHover,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${progressPct.toStringAsFixed(0)}% complete — $done of $totalPlanned contacts'
              '${retryWaitCount > 0 ? ' • $retryWaitCount retry wait' : ''}',
              style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Chip(
      label: Text('$label: $value', style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textSecondary)),
      backgroundColor: NeyvoTheme.bgHover,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              (value.isEmpty ? '—' : value),
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizard() {
    final steps = ['Name & goal', 'Audience', 'Script', 'Schedule', 'Review'];
    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: NeyvoTheme.bgSurface,
        foregroundColor: NeyvoTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _showCreateWizard = false;
            _wizardStep = 0;
            _editingCampaignId = null;
            _editCampaignData = null;
          }),
        ),
        title: Text(_editingCampaignId != null ? 'Edit campaign' : 'Create campaign', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: NeyvoSpacing.lg),
            Row(
              children: List.generate(steps.length, (i) {
                final active = i == _wizardStep;
                final done = i < _wizardStep;
                return Expanded(
                  child: Row(
                    children: [
                      if (i > 0) Expanded(child: Divider(color: done ? Theme.of(context).colorScheme.primary : NeyvoTheme.border)),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: active ? Theme.of(context).colorScheme.primary : (done ? Theme.of(context).colorScheme.primary : NeyvoTheme.bgCard),
                        child: Text('${i + 1}', style: TextStyle(color: active || done ? NeyvoColors.white : NeyvoTheme.textMuted, fontSize: 12)),
                      ),
                      if (i < steps.length - 1) Expanded(child: Divider(color: done ? Theme.of(context).colorScheme.primary : NeyvoTheme.border)),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: NeyvoSpacing.sm),
            Center(child: Text(steps[_wizardStep], style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textSecondary))),
            const SizedBox(height: NeyvoSpacing.xl),
            if (_wizardStep == 0) _stepName(),
            if (_wizardStep == 1) _stepAudience(),
            if (_wizardStep == 2) _stepScript(),
            if (_wizardStep == 3) _stepSchedule(),
            if (_wizardStep == 4) _stepReview(),
            const SizedBox(height: NeyvoSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_wizardStep > 0)
                  TextButton(
                    onPressed: () => setState(() => _wizardStep--),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: NeyvoSpacing.md),
                FilledButton(
                  onPressed: () {
                    if (_wizardStep < steps.length - 1) {
                      setState(() => _wizardStep++);
                    } else {
                      _launchCampaign();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary,
                  ),
                  child: Text(_wizardStep == steps.length - 1
                      ? (_editingCampaignId != null ? 'Save changes' : 'Create campaign')
                      : 'Next'),
                ),
              ],
            ),
        ],
        ),
      ),
    );
  }

  Widget _stepName() {
    return Card(
      color: NeyvoTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Campaign name',
                hintText: 'e.g. March balance reminder - high balance',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepAudience() {
    final filtered = _filteredStudents;
    return Card(
      color: NeyvoTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audience', style: NeyvoType.titleMedium),
            const SizedBox(height: NeyvoSpacing.md),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _audienceMode = 'contact_list';
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(NeyvoSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _audienceMode == 'contact_list'
                              ? Theme.of(context).colorScheme.primary
                              : NeyvoTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _audienceMode == 'contact_list'
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'From Contact List',
                          style: NeyvoType.bodyMedium.copyWith(
                            color: _audienceMode == 'contact_list'
                                ? Theme.of(context).colorScheme.primary
                                : NeyvoTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: NeyvoSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _audienceMode = 'filters';
                      _loadPreviewAudience();
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(NeyvoSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _audienceMode == 'filters'
                              ? Theme.of(context).colorScheme.primary
                              : NeyvoTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _audienceMode == 'filters'
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Smart Filter',
                          style: NeyvoType.bodyMedium.copyWith(
                            color: _audienceMode == 'filters'
                                ? Theme.of(context).colorScheme.primary
                                : NeyvoTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: NeyvoSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _audienceMode = 'excel';
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(NeyvoSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _audienceMode == 'excel'
                              ? Theme.of(context).colorScheme.primary
                              : NeyvoTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _audienceMode == 'excel'
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Search by Excel & selection',
                          textAlign: TextAlign.center,
                          style: NeyvoType.bodyMedium.copyWith(
                            color: _audienceMode == 'excel'
                                ? Theme.of(context).colorScheme.primary
                                : NeyvoTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
              if (_audienceMode == 'filters') ...[
                const SizedBox(height: NeyvoSpacing.lg),
                CheckboxListTile(
                  title: const Text('Has balance (only students with a balance on file)'),
                  value: _smartHasBalance,
                  onChanged: (v) => setState(() {
                    _smartHasBalance = v ?? true;
                    _loadPreviewAudience();
                  }),
                ),
                CheckboxListTile(
                  title: const Text('Overdue students only'),
                  value: _smartOverdueOnly,
                  onChanged: (v) => setState(() {
                    _smartOverdueOnly = v ?? false;
                    _loadPreviewAudience();
                  }),
                ),
                TextField(
                  controller: _smartBalanceMinController,
                  decoration: const InputDecoration(labelText: 'Balance minimum (\$)'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _loadPreviewAudience(),
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                ListTile(
                  title: Text(_smartDueBefore == null ? 'Due date before (optional)' : 'Due before: $_smartDueBefore'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (d != null && mounted) setState(() {
                      _smartDueBefore = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                      _loadPreviewAudience();
                    });
                  },
                ),
                const SizedBox(height: NeyvoSpacing.md),
                if (_previewLoading)
                  const Padding(padding: EdgeInsets.all(NeyvoSpacing.md), child: Center(child: CircularProgressIndicator()))
                else if (_previewAudienceCount != null)
                  Container(
                    padding: const EdgeInsets.all(NeyvoSpacing.md),
                    decoration: BoxDecoration(color: NeyvoTheme.bgHover, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_previewAudienceCount!} students match these filters', style: NeyvoType.titleMedium.copyWith(color: Theme.of(context).colorScheme.primary)),
                        if (_previewAudienceSample.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ..._previewAudienceSample.take(3).map((s) => Text('• ${s['name'] ?? '—'} ${s['phone'] ?? ''}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary))),
                        ],
                      ],
                    ),
                  ),
              ],
              if (_audienceMode == 'contact_list' || _audienceMode == 'excel')
                const Divider(),
            if (_audienceMode == 'excel') ...[
              const SizedBox(height: NeyvoSpacing.md),
              Text('Search by excel and selection',
                  style: NeyvoType.titleMedium),
              const SizedBox(height: NeyvoSpacing.sm),
              Text(
                'Upload the same CSV template used for student import. We will match rows to existing students by student ID or phone so you can select them for this campaign.',
                style:
                    NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _pickAudienceCsv,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload CSV'),
                  ),
                  const SizedBox(width: NeyvoSpacing.sm),
                  TextButton(
                    onPressed: _downloadAudienceTemplate,
                    child: const Text('Download template'),
                  ),
                ],
              ),
              if (_audienceCsvText.isNotEmpty) ...[
                const SizedBox(height: NeyvoSpacing.sm),
                Text(
                  '${_audienceCsvMatchedStudentIds.length} students matched from CSV.'
                  '${_audienceCsvErrors.isEmpty ? '' : ' Some rows could not be matched.'}',
                  style: NeyvoType.bodySmall,
                ),
                if (_audienceCsvErrors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: NeyvoSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _audienceCsvErrors
                          .take(3)
                          .map(
                            (e) => Text(
                              '• $e',
                              style: NeyvoType.bodySmall
                                  .copyWith(color: NeyvoTheme.error),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
              const SizedBox(height: NeyvoSpacing.lg),
            ],
            if (_audienceMode == 'contact_list' || _audienceMode == 'excel') ...[
              if (_isEducationOrg) const SizedBox(height: NeyvoSpacing.md),
              Text('Selection mode', style: NeyvoType.titleMedium),
              const SizedBox(height: NeyvoSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All matching')),
                  ButtonSegment(value: 'manual', label: Text('Select manually')),
                ],
                selected: {_manualAudienceSelection ? 'manual' : 'all'},
                onSelectionChanged: (v) => setState(() {
                  final mode = v.first;
                  _manualAudienceSelection = mode == 'manual';
                  if (!_manualAudienceSelection) {
                    _selectedStudentIds.clear();
                    _selectAll = false;
                  }
                }),
              ),
              const SizedBox(height: NeyvoSpacing.lg),
              Text('Filter audience', style: NeyvoType.titleMedium),
              const SizedBox(height: NeyvoSpacing.sm),
              DropdownButtonFormField<String>(
                value: _filterType,
                decoration: const InputDecoration(labelText: 'Filter by'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All contacts')),
                  DropdownMenuItem(value: 'balance_above', child: Text('Balance above amount')),
                  DropdownMenuItem(value: 'balance_below', child: Text('Balance below amount')),
                  DropdownMenuItem(value: 'has_due_date', child: Text('Has due date')),
                ],
                onChanged: (v) {
                  setState(() => _filterType = v ?? 'all');
                  _resetStudentsPaginationAndReload();
                },
              ),
              if (_filterType == 'balance_above') ...[
                const SizedBox(height: NeyvoSpacing.md),
                TextField(
                  controller: _balanceMinController,
                  decoration: const InputDecoration(labelText: 'Min balance (\$)'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_filterType == 'balance_below') ...[
                const SizedBox(height: NeyvoSpacing.md),
                TextField(
                  controller: _balanceMaxController,
                  decoration: const InputDecoration(labelText: 'Max balance (\$)'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: NeyvoSpacing.md),
              CheckboxListTile(
                title: const Text('Only contacts with due date'),
                value: _filterOverdueOnly,
                onChanged: (v) {
                  setState(() => _filterOverdueOnly = v ?? false);
                  _resetStudentsPaginationAndReload();
                },
              ),
              const Divider(),
              if (filtered.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: NeyvoSpacing.xl),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: NeyvoTheme.textMuted),
                        const SizedBox(height: NeyvoSpacing.md),
                        Text(
                          'No contacts in this account yet.',
                          style: NeyvoType.bodyLarge.copyWith(color: NeyvoTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: NeyvoSpacing.sm),
                        Text(
                          'Add contacts from the Contacts page, then return here to create a campaign.',
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: NeyvoSpacing.lg),
                        FilledButton.icon(
                          onPressed: () => Navigator.pushNamed(context, PulseRouteNames.students),
                          icon: const Icon(Icons.people, size: 20),
                          label: const Text('Go to Contacts'),
                          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_studentsTotal > 0 ? _studentsTotal : filtered.length} contacts match', style: NeyvoType.bodyMedium),
                  if (_manualAudienceSelection)
                    TextButton.icon(
                      onPressed: _toggleSelectAll,
                      icon: Icon(_selectAll ? Icons.deselect : Icons.select_all, size: 18),
                      label: Text(_selectAll ? 'Clear' : 'Select all'),
                    )
                  else
                    Text('All matching will be called', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                ],
              ),
              const SizedBox(height: NeyvoSpacing.sm),
              TextField(
                controller: _audienceSearchController,
                decoration: const InputDecoration(
                  labelText: 'Search contacts',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: NeyvoSpacing.sm),
              Builder(builder: (context) {
                final rawQ = _audienceSearchController.text.trim();
                final q = rawQ.toLowerCase();
                final visible = q.isEmpty
                    ? filtered
                    : filtered.where((s) {
                        final name = (s['name'] ?? '').toString().toLowerCase();
                        final phone = (s['phone'] ?? '').toString();
                        final sid = (s['student_id'] ?? s['id'] ?? '').toString().toLowerCase();
                        return name.contains(q) ||
                            phone.toLowerCase().contains(q) ||
                            phoneMatchesSearchQuery(phone, rawQ) ||
                            sid.contains(q);
                      }).toList();
                // Bounded list height so Flutter can lazily build rows (no shrinkWrap freeze on 1000+ contacts).
                return SizedBox(
                  height: 520,
                  child: ListView.builder(
                    controller: _audienceScrollController,
                    itemCount: visible.length +
                        ((q.isEmpty && (_studentsHasMore || _studentsLoadingMore || _studentsInitialLoading)) ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= visible.length) {
                        return Padding(
                          padding: const EdgeInsets.all(NeyvoSpacing.md),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: NeyvoSpacing.sm),
                                Text(
                                  _studentsInitialLoading
                                      ? 'Loading contacts…'
                                      : (_studentsLoadingMore ? 'Loading more…' : 'Load more'),
                                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final s = visible[i];
                      final id = s['id'] as String? ?? '';
                      final campaignHint = id.isEmpty ? null : _campaignHintForStudent(id);
                      final calledBeforeHint = id.isEmpty ? null : _calledBeforeHintForStudent(id);
                      final selected = !_manualAudienceSelection || _selectedStudentIds.contains(id);
                      return CheckboxListTile(
                        isThreeLine: true,
                        title: Text(
                          s['name']?.toString() ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            '${s['phone'] ?? ''} • ${s['balance'] ?? ''}'.trim(),
                            if (campaignHint != null && campaignHint.isNotEmpty) campaignHint,
                            if (calledBeforeHint != null && calledBeforeHint.isNotEmpty) calledBeforeHint,
                          ].where((e) => e.isNotEmpty).join('\n'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: selected,
                        onChanged: _manualAudienceSelection ? (v) => _toggleStudent(id) : null,
                      );
                    },
                  ),
                );
              }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepScript() {
    return Card(
      color: NeyvoTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conversation script', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            const SizedBox(height: NeyvoSpacing.sm),
            Text(
              'Select an operator for voice, prompt, and call settings.',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            DropdownButtonFormField<String>(
              value: _operatorsForCampaign.any((o) => o['value'] == _selectedOperatorValue)
                  ? _selectedOperatorValue
                  : null,
              decoration: const InputDecoration(
                labelText: 'Operator',
                hintText: 'Select an operator (recommended)',
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('— No operator —')),
                ..._operatorsForCampaign.map((o) => DropdownMenuItem<String>(
                  value: o['value'] as String?,
                  child: Text(o['name']?.toString() ?? 'Unnamed operator'),
                )),
              ],
              onChanged: (v) => setState(() => _selectedOperatorValue = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepSchedule() {
    return Card(
      color: NeyvoTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            const SizedBox(height: NeyvoSpacing.md),
            RadioListTile<bool>(
              title: const Text('Start immediately'),
              value: true,
              groupValue: _scheduleNow,
              onChanged: (v) => setState(() => _scheduleNow = true),
            ),
            RadioListTile<bool>(
              title: const Text('Schedule for later'),
              value: false,
              groupValue: _scheduleNow,
              onChanged: (v) => setState(() => _scheduleNow = false),
            ),
            if (!_scheduleNow)
              ListTile(
                title: Text(_scheduledAt == null ? 'Pick date & time' : '${_scheduledAt.toString().substring(0, 16)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (date == null || !mounted) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time == null || !mounted) return;
                  setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepReview() {
    final useFilters = _isEducationOrg && _audienceMode == 'filters';
    final isManual = !useFilters && _manualAudienceSelection;
    final count = useFilters
        ? (_previewAudienceCount ?? 0)
        : (isManual ? _selectedStudentIds.length : _filteredStudents.length);
    // Build list of {name, phone} for audience display
    List<Map<String, String>> reviewContacts = [];
    if (useFilters) {
      for (final s in _previewAudienceSample) {
        reviewContacts.add({
          'name': (s['name'] ?? '—').toString(),
          'phone': (s['phone'] ?? '').toString(),
        });
      }
      if ((_previewAudienceCount ?? 0) > _previewAudienceSample.length) {
        reviewContacts.add({'name': '… and ${(_previewAudienceCount! - _previewAudienceSample.length)} more', 'phone': ''});
      }
    } else {
      final students = isManual
          ? _filteredStudents.where((s) => _selectedStudentIds.contains((s['id'] ?? '').toString())).toList()
          : _filteredStudents;
      for (final s in students) {
        reviewContacts.add({
          'name': (s['name'] ?? '—').toString(),
          'phone': (s['phone'] ?? '').toString(),
        });
      }
    }
    return Card(
      color: NeyvoTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            const SizedBox(height: NeyvoSpacing.md),
            ListTile(title: const Text('Campaign name'), trailing: Text(_nameController.text.trim().isEmpty ? '—' : _nameController.text.trim())),
            ListTile(
              title: const Text('Audience'),
              trailing: Text(_isEducationOrg && _audienceMode == 'filters' ? '$count students (smart filter)' : '$count contacts'),
            ),
            if (reviewContacts.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: reviewContacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final r = reviewContacts[i];
                    final name = r['name'] ?? '—';
                    final phone = (r['phone'] ?? '').toString().trim();
                    return Padding(
                      padding: const EdgeInsets.only(left: NeyvoSpacing.md),
                      child: Text(
                        phone.isEmpty ? name : '$name • $phone',
                        style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: NeyvoSpacing.sm),
            ListTile(
              title: const Text('Operator'),
              trailing: Text(
                () {
                  if (_selectedOperatorValue != null && _selectedOperatorValue!.isNotEmpty) {
                    final list = _operatorsForCampaign.where((o) => o['value'] == _selectedOperatorValue).toList();
                    if (list.isNotEmpty) return list.first['name']?.toString() ?? '—';
                  }
                  return '—';
                }(),
              ),
            ),
            ListTile(title: const Text('When'), trailing: Text(_scheduleNow ? 'Immediately' : (_scheduledAt?.toString().substring(0, 16) ?? 'Not set'))),
          ],
        ),
      ),
    );
  }
}

/// Dialog to confirm campaign deletion by typing the campaign name (same pattern as operator delete).
class _DeleteCampaignConfirmDialog extends StatefulWidget {
  const _DeleteCampaignConfirmDialog({
    required this.confirmName,
    required this.onCancel,
    required this.onDelete,
  });

  final String confirmName;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  State<_DeleteCampaignConfirmDialog> createState() => _DeleteCampaignConfirmDialogState();
}

class _DeleteCampaignConfirmDialogState extends State<_DeleteCampaignConfirmDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches => _controller.text.trim() == widget.confirmName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NeyvoTheme.bgSurface,
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: NeyvoTheme.error, size: 28),
          const SizedBox(width: 12),
          const Text('Delete campaign'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campaign data will be kept for records but the campaign will be removed from the list. Running campaigns cannot be deleted.\n\nType \'${widget.confirmName}\' to confirm.',
            style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.confirmName,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: NeyvoTheme.bgPrimary,
            ),
            style: NeyvoType.bodyMedium,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _matches ? widget.onDelete : null,
          style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.error),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
