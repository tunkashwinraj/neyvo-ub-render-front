// lib/screens/campaigns_page.dart
// Campaigns: bulk outbound calls with filters, templates, and scheduling (like ad campaigns).

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../api/spearia_api.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../services/user_timezone_service.dart';
import '../theme/neyvo_theme.dart';
import '../utils/csv_import.dart';
import '../utils/export_csv.dart';
import '../widgets/neyvo_empty_state.dart';

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _agents = [];
  /// For contact-list campaigns only: quick lookup so the audience picker can show if a contact is already in another campaign.
  /// Key: student id, Value: list of campaign names.
  Map<String, List<String>> _studentCampaignNames = {};
  /// Latest known call time for each student (for audience picker hints).
  Map<String, DateTime> _lastCallAtByStudentId = {};
  /// Combined list for operator dropdown: each has 'value' (agent:id or profile:id), 'name', 'type' (agent|profile).
  List<Map<String, dynamic>> _operatorsForCampaign = [];
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  String? _error;
  bool _showCreateWizard = false;
  int _wizardStep = 0;
  String? _selectedCampaignId;
  int _campaignDetailRefreshKey = 0;
  Timer? _detailRefreshTimer;
  // Cache last successful detail payload so auto-refresh doesn't blank the UI.
  final Map<String, Map<String, dynamic>> _campaignDetailCache = {};
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
  String? _selectedTemplateId;
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
  /// Selected VAPI phone_number_id for this campaign run (null = use default).
  String? _selectedStartPhoneNumberId;
  /// Wallet credits and required per call (for campaign start gating and display).
  int? _walletCredits;
  int? _creditsPerMinute;
  bool _useTemplate = false;
  // Audience selection via CSV upload (Search by excel and selection).
  String _audienceCsvText = '';
  Set<String> _audienceCsvMatchedStudentIds = {};
  List<String> _audienceCsvErrors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detailRefreshTimer?.cancel();
    _nameController.dispose();
    _audienceSearchController.dispose();
    _balanceMinController.dispose();
    _balanceMaxController.dispose();
    _smartBalanceMinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Ensure account context so operator list (managed profiles) is scoped to current org
      if (NeyvoPulseApi.defaultAccountId.isEmpty) {
        try {
          final accountRes = await NeyvoPulseApi.getAccountInfo();
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
      // Load all students for campaign audience (high limit so contact list shows everyone)
      final studentsRes = await NeyvoPulseApi.listStudents(limit: 5000);
      final studentsList = studentsRes['students'] as List? ?? [];
      _students = studentsList.cast<Map<String, dynamic>>();

      // Latest call time per student (best-effort; used only for small UI hints).
      try {
        final callsRes = await NeyvoPulseApi.listCalls();
        final calls = (callsRes['calls'] as List?) ?? [];
        final latest = <String, DateTime>{};
        for (final raw in calls) {
          if (raw is! Map) continue;
          final call = Map<String, dynamic>.from(raw as Map);
          final sid = (call['student_id'] ?? call['studentId'] ?? '').toString().trim();
          if (sid.isEmpty) continue;
          final created = call['created_at'] ?? call['date'] ?? call['timestamp'];
          DateTime? dt;
          if (created is String) dt = DateTime.tryParse(created);
          if (created is int) dt = DateTime.fromMillisecondsSinceEpoch(created);
          if (created is double) dt = DateTime.fromMillisecondsSinceEpoch(created.toInt());
          if (dt == null) continue;
          final prev = latest[sid];
          if (prev == null || dt.isAfter(prev)) latest[sid] = dt;
        }
        _lastCallAtByStudentId = latest;
      } catch (_) {}
      _agents = agents;
      _operatorsForCampaign = operators;
      _templates = await _loadTemplates();
      _campaigns = await _loadCampaigns();
      // Check if account has a number: from account info (primary) or from GET /api/numbers
      bool hasNumber = false;
      try {
        final accountRes = await NeyvoPulseApi.getAccountInfo();
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
      String? selectedPhoneId;
      if (outbound.isNotEmpty) {
        final first = outbound.first;
        selectedPhoneId = (first['phone_number_id'] ?? first['id'] ?? '').toString().trim();
        if (selectedPhoneId?.isEmpty ?? true) selectedPhoneId = null;
      }
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
      if (mounted) setState(() {
        _isEducationOrg = isEdu;
        _hasPhoneNumber = hasNumber;
        _outboundPhoneNumbers = outbound;
        if (_selectedStartPhoneNumberId == null) _selectedStartPhoneNumberId = selectedPhoneId;
        _walletCredits = walletCredits;
        _creditsPerMinute = creditsPerMinute ?? 25;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
    _matchStudentsFromCsv(text);
  }

  Future<void> _downloadAudienceTemplate() async {
    // Reuse the existing students import template.
    if (kIsWeb) {
      final url = '${SpeariaApi.baseUrl}/api/pulse/students/import/template';
      final ok = await SpeariaApi.launchExternal(url);
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

  void _matchStudentsFromCsv(String csvText) {
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

    // Build lookup maps from existing students.
    String _normalizePhone(String p) => p.replaceAll(RegExp(r'[^0-9]'), '');
    final byStudentId = <String, String>{}; // student_id -> id
    final byPhone = <String, String>{}; // normalized phone -> id
    for (final s in _students) {
      final id = (s['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final sid = (s['student_id'] ?? '').toString();
      if (sid.isNotEmpty) byStudentId[sid.toLowerCase()] = id;
      final phone = (s['phone'] ?? s['phone_e164'] ?? '').toString();
      final norm = _normalizePhone(phone);
      if (norm.isNotEmpty && !byPhone.containsKey(norm)) {
        byPhone[norm] = id;
      }
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

    final matched = <String>{};
    final errs = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rowNum = i + 2; // header is row 1
      final sid = getVal(r, ['student_id', 'id', 'studentid']);
      final phone = getVal(r, ['phone', 'mobile', 'cell']);
      String? id;
      if (sid.isNotEmpty) {
        id = byStudentId[sid.toLowerCase()];
      }
      if (id == null && phone.isNotEmpty) {
        id = byPhone[_normalizePhone(phone)];
      }
      if (id != null && id.isNotEmpty) {
        matched.add(id);
      } else {
        errs.add('Row $rowNum: no matching student for id="$sid" phone="$phone"');
      }
    }

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

  Future<List<Map<String, dynamic>>> _loadTemplates() async {
    try {
      final res = await NeyvoPulseApi.listCallTemplates();
      final list = res['templates'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadCampaigns() async {
    try {
      final res = await NeyvoPulseApi.listCampaigns();
      final list = res['campaigns'] as List? ?? [];
      final campaigns = list.cast<Map<String, dynamic>>();
      // Build a student->campaigns lookup (only where the campaign explicitly stores student_ids).
      final byStudent = <String, Set<String>>{};
      for (final c in campaigns) {
        final ids = c['student_ids'];
        if (ids is! List) continue; // filter-based campaigns don't list student ids
        final cname = (c['name'] ?? c['id'] ?? 'Campaign').toString().trim();
        if (cname.isEmpty) continue;
        for (final raw in ids) {
          final sid = (raw ?? '').toString().trim();
          if (sid.isEmpty) continue;
          (byStudent[sid] ??= <String>{}).add(cname);
        }
      }
      if (mounted) {
        setState(() {
          _studentCampaignNames = byStudent.map((k, v) => MapEntry(k, v.toList()..sort()));
        });
      }
      return campaigns;
    } catch (_) {
      return [];
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
    final baseName = (originalCampaign['name'] ?? 'Campaign').toString().trim();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final retryName = '$baseName (Retry $date)';
    final agentId = (originalCampaign['agent_id'] ?? '').toString().trim();
    final profileId = (originalCampaign['profile_id'] ?? '').toString().trim();
    final templateId = (originalCampaign['template_id'] ?? '').toString().trim();

    try {
      final created = await NeyvoPulseApi.createCampaign(
        name: retryName,
        agentId: agentId.isNotEmpty ? agentId : null,
        profileId: profileId.isNotEmpty ? profileId : null,
        templateId: templateId.isNotEmpty ? templateId : null,
        studentIds: studentIds,
        audienceType: 'contact_list',
        filters: null,
        scheduledAt: null,
      );
      final newCampaign = (created['campaign'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final newId = (newCampaign['id'] ?? '').toString().trim();
      if (newId.isEmpty) throw Exception('Campaign created but no id returned');

      final res = await NeyvoPulseApi.startCampaign(newId, phoneNumberId: _selectedStartPhoneNumberId);
      if (!mounted) return;
      _showCampaignStartResult(res, isRerun: false);
      setState(() {
        _selectedCampaignId = newId;
        _detailStatusFilter = 'all';
        _campaignDetailRefreshKey++;
      });
      _startDetailAutoRefresh();
    } on ApiException catch (e) {
      if (mounted) _showInsufficientCreditsSnackBar(e);
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
      setState(() => _campaignDetailRefreshKey++);
    });
  }

  void _stopDetailAutoRefresh() {
    _detailRefreshTimer?.cancel();
    _detailRefreshTimer = null;
  }

  Future<void> _downloadCampaignReport(String campaignId) async {
    try {
      final res = await NeyvoPulseApi.getCampaignReport(campaignId);
      if (res['ok'] != true || !mounted) return;
      final campaign = Map<String, dynamic>.from(res['campaign'] as Map);
      final agent = res['agent'] != null ? Map<String, dynamic>.from(res['agent'] as Map) : null;
      final template = res['template'] != null ? Map<String, dynamic>.from(res['template'] as Map) : null;
      final items = (res['call_items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final callDetails = (res['call_details'] as Map?)?.map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map))) ?? {};
      final sb = StringBuffer();
      sb.writeln('Campaign Report');
      sb.writeln('Name,${_escapeCsv(campaign['name']?.toString() ?? '')}');
      sb.writeln('Status,${campaign['status'] ?? ''}');
      sb.writeln('Total Planned,${campaign['total_planned'] ?? ''}');
      sb.writeln('Created,${UserTimezoneService.format(campaign['created_at'])}');
      sb.writeln('');
      if (agent != null) {
        sb.writeln('Agent');
        sb.writeln('Name,${_escapeCsv(agent['name']?.toString() ?? '')}');
        sb.writeln('Voice Tier,${agent['voice_tier_override'] ?? agent['voice_tier'] ?? ''}');
        sb.writeln('');
      }
      if (template != null) {
        sb.writeln('Template,${_escapeCsv(template['name']?.toString() ?? template['id']?.toString() ?? '')}');
        sb.writeln('');
      }
      sb.writeln('Call Items');
      sb.writeln('Name,Phone,Student ID,Status,Attempt,VAPI Call ID,Duration (s),Summary,Sentiment');
      for (final it in items) {
        final vapiId = (it['vapi_call_id'] ?? '').toString();
        final detail = callDetails[vapiId];
        final duration = detail?['duration_seconds'] ?? '';
        final summary = _escapeCsv((detail?['summary'] ?? '').toString().replaceAll('\n', ' '));
        final sentiment = (detail?['sentiment'] ?? '').toString();
        sb.writeln('"${_escapeCsv(it['name']?.toString() ?? '')}","${_escapeCsv(it['phone']?.toString() ?? '')}",${it['student_id'] ?? ''},${it['status'] ?? ''},${it['attempt'] ?? ''},$vapiId,$duration,"$summary",$sentiment');
      }
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final name = (campaign['name'] ?? 'campaign').toString().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
      if (!mounted) return;
      await downloadCsv('campaign_report_${name}_$date.csv', '\uFEFF${sb.toString()}', context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: NeyvoTheme.error),
      );
    }
  }

  String _escapeCsv(String s) => s.replaceAll('"', '""');

  List<Map<String, dynamic>> get _filteredStudents {
    var list = List<Map<String, dynamic>>.from(_students);
    // When using the "Search by excel and selection" audience mode, restrict the
    // list to students matched from the uploaded CSV (if any).
    if (_audienceMode == 'excel' && _audienceCsvMatchedStudentIds.isNotEmpty) {
      list = list
          .where((s) => _audienceCsvMatchedStudentIds.contains((s['id'] ?? '').toString()))
          .toList();
    }
    if (_filterType == 'balance_above') {
      final min = double.tryParse(_balanceMinController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      list = list.where((s) {
        final b = s['balance'];
        if (b == null) return false;
        final v = double.tryParse(b.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return v >= min;
      }).toList();
    } else if (_filterType == 'balance_below') {
      final max = double.tryParse(_balanceMaxController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? double.infinity;
      list = list.where((s) {
        final b = s['balance'];
        if (b == null) return true;
        final v = double.tryParse(b.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return v <= max;
      }).toList();
    } else if (_filterOverdueOnly) {
      list = list.where((s) => (s['due_date'] ?? '').toString().trim().isNotEmpty).toList();
    }
    return list;
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
    setState(() {
      if (!_manualAudienceSelection) {
        _manualAudienceSelection = true;
      }
      if (_selectAll) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds =
            _filteredStudents.map((s) => s['id'] as String? ?? '').where((e) => e.isNotEmpty).toSet();
      }
      _selectAll = !_selectAll;
    });
  }

  Future<void> _launchCampaign() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter campaign name')));
      return;
    }
    final useFilters = _isEducationOrg && _audienceMode == 'filters';
    final ids = useFilters
        ? <String>[]
        : (_manualAudienceSelection
            ? _selectedStudentIds.toList()
            : _filteredStudents
                .map((s) => s['id'] as String? ?? '')
                .where((e) => e.isNotEmpty)
                .toList());
    if (!useFilters && _manualAudienceSelection && ids.isEmpty) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add a phone number to make calls. Go to Phone Numbers to link or purchase a number.'),
        backgroundColor: NeyvoTheme.warning,
        duration: Duration(seconds: 5),
      ),
    );
    return false;
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
    // Ensure immutable audience snapshot exists and validation has passed before starting.
    final ready = await _ensureCampaignSnapshotReady(id);
    if (!ready || !mounted) return;
    final isRerun = c['status'] == 'completed' || c['status'] == 'running';
    try {
      final res = await NeyvoPulseApi.startCampaign(id, phoneNumberId: _selectedStartPhoneNumberId);
      if (mounted) {
        _showCampaignStartResult(res, isRerun: isRerun);
        _load();
      }
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
            final phone = (s?['phone'] ?? '').toString().toLowerCase();
            final q = query.toLowerCase();
            return name.contains(q) || phone.contains(q);
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
                style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
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
      final res = await NeyvoPulseApi.startCampaign(campaignId, studentIds: selected.toList(), phoneNumberId: _selectedStartPhoneNumberId);
      if (mounted) {
        _showCampaignStartResult(res, isRerun: false);
        setState(() => _campaignDetailRefreshKey++);
      }
    } on ApiException catch (e) {
      if (mounted) _showInsufficientCreditsSnackBar(e);
    } catch (e) {
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
              style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
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
        body: buildNeyvoErrorState(onRetry: _load),
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
            style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
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
            if (!_hasPhoneNumber) ...[
              Card(
                color: NeyvoTheme.warning.withOpacity(0.15),
                child: Padding(
                  padding: const EdgeInsets.all(NeyvoSpacing.lg),
                  child: Row(
                    children: [
                      Icon(Icons.phone_missed, color: NeyvoTheme.warning),
                      const SizedBox(width: NeyvoSpacing.md),
                      Expanded(
                        child: Text(
                          'Add a phone number to make calls. Go to Phone Numbers to link or purchase a number.',
                          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NeyvoSpacing.lg),
            ],
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
              )
            else
              ..._campaigns.map((c) => Card(
                  color: NeyvoTheme.bgCard,
                  margin: const EdgeInsets.only(bottom: NeyvoSpacing.md),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: NeyvoTheme.bgHover, child: const Icon(Icons.campaign_outlined, color: NeyvoTheme.teal)),
                    title: Text(c['name']?.toString() ?? 'Unnamed', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                    subtitle: Text(
                      '${c['total_planned'] ?? c['student_count'] ?? 0} contacts • ${c['status'] ?? 'draft'}${(c['total_initiated'] ?? 0) > 0 ? ' • ${c['total_initiated']} placed' : ''}',
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                    ),
                    onTap: () => setState(() {
                      _detailStatusFilter = 'all';
                      _selectedCampaignId = c['id']?.toString();
                      _startDetailAutoRefresh();
                    }),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          tooltip: 'View & manage',
                          onPressed: () => setState(() {
                            _detailStatusFilter = 'all';
                            _selectedCampaignId = c['id']?.toString();
                            _startDetailAutoRefresh();
                          }),
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
                              _selectedTemplateId = c['template_id']?.toString();
                              _useTemplate = (_selectedTemplateId != null && _selectedTemplateId!.isNotEmpty);
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
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Start campaign',
                            onPressed: () => _startOrRerunCampaign(c),
                          ),
                        ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignDetailScreen(String campaignId) {
    return FutureBuilder<Map<String, dynamic>>(
      // Stable key so the detail screen doesn't fully rebuild/flash on every auto-refresh.
      key: ValueKey('campaign_detail_$campaignId'),
      future: () async {
        final campaignRes = await NeyvoPulseApi.getCampaign(campaignId);
        final camp = Map<String, dynamic>.from((campaignRes['campaign'] as Map?) ?? const {});
        final status = (camp['status'] ?? 'draft').toString().toLowerCase().trim();
        final isTerminal = status == 'completed' || status.startsWith('stopped') || status == 'cancelled' || status == 'deleted';

        final callsF = NeyvoPulseApi.getCampaignCalls(campaignId, limit: 500);
        final metricsF = NeyvoPulseApi.getCampaignMetrics(campaignId);
        final itemsF = NeyvoPulseApi.getCampaignCallItems(campaignId, limit: 500);
        final reportF = isTerminal ? NeyvoPulseApi.getCampaignReport(campaignId) : Future.value(<String, dynamic>{});

        final results = await Future.wait([callsF, metricsF, itemsF, reportF]);
        final callsRes = results[0] as Map<String, dynamic>;
        final metricsRes = results[1] as Map<String, dynamic>;
        final itemsRes = results[2] as Map<String, dynamic>;
        final reportRes = results[3] as Map<String, dynamic>;

        return {
          'campaign': camp,
          'calls': (callsRes['calls'] as List?) ?? [],
          'metrics': (metricsRes['metrics'] as Map?) ?? {},
          'items': (itemsRes['items'] as List?) ?? [],
          'report': reportRes,
        };
      }(),
      builder: (context, snapshot) {
        // Store latest good payload in cache.
        if (snapshot.hasData) {
          _campaignDetailCache[campaignId] = Map<String, dynamic>.from(snapshot.data!);
        }
        final cached = _campaignDetailCache[campaignId];
        final data = snapshot.data ?? cached;

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
        final canStart = status == 'draft' || status == 'scheduled';
        final canRerun = status == 'completed' || status == 'running';
        final canEdit = status == 'draft' || status == 'scheduled';
        // Can delete any campaign except when running (soft delete preserves data)
        final canDelete = status != 'running';
        final templateId = c['template_id']?.toString();
        final templateList = templateId != null ? _templates.where((t) => t['id']?.toString() == templateId).toList() : <Map<String, dynamic>>[];
        final templateName = templateList.isNotEmpty ? (templateList.first['name']?.toString() ?? templateId) : (templateId ?? '—');
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
        final audienceIds = (c['student_ids'] as List?)
                ?.map((e) => (e ?? '').toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            <String>[];

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
          if (status == 'draft' || status == 'scheduled') {
            return 'Not started yet';
          }
          return '—';
        }

        String audienceSummary() {
          if (c['student_ids'] != null) {
            return '${(c['student_ids'] as List).length} contacts selected';
          }
          if (c['filters'] != null) {
            return 'Filters: ${c['filters']?.toString() ?? '—'}';
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
                _stopDetailAutoRefresh();
              }),
            ),
            title: Text('Campaign details', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() => _campaignDetailRefreshKey++),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More actions',
                onSelected: (value) {
                  switch (value) {
                    case 'download':
                      _downloadCampaignReport(campaignId);
                      break;
                    case 'pause':
                      NeyvoPulseApi.pauseCampaign(campaignId).then((_) {
                        if (mounted) setState(() => _campaignDetailRefreshKey++);
                      }).catchError((e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                        }
                      });
                      break;
                    case 'resume':
                      NeyvoPulseApi.resumeCampaign(campaignId).then((_) {
                        if (mounted) setState(() => _campaignDetailRefreshKey++);
                      }).catchError((e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                        }
                      });
                      break;
                    case 'stop':
                      NeyvoPulseApi.stopCampaign(campaignId).then((_) {
                        if (mounted) {
                          setState(() => _campaignDetailRefreshKey++);
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
                      _selectedTemplateId = c['template_id']?.toString();
                      _useTemplate = (_selectedTemplateId != null && _selectedTemplateId!.isNotEmpty);
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
                    const PopupMenuItem(value: 'start', child: ListTile(leading: Icon(Icons.play_arrow, size: 20), title: Text('Start campaign'), dense: true)),
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
          body: SingleChildScrollView(
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
                Card(
                  color: NeyvoTheme.bgCard,
                  child: Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['name']?.toString() ?? 'Unnamed', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
                        const SizedBox(height: NeyvoSpacing.md),
                        Wrap(
                          spacing: NeyvoSpacing.lg,
                          runSpacing: NeyvoSpacing.sm,
                          children: [
                            _detailChip('Status', status),
                            _detailChip('Concurrency', '$activeCount / $maxConcurrent active'),
                            _detailChip('Total operations', '$totalOperations'),
                            _detailChip('Queued', '$queuedCount'),
                            _detailChip('Retry', '$retryWaitCount'),
                            _detailChip('Completed', '$completedCount'),
                            _detailChip('Failed', '$failedCount'),
                            _detailChip('Planned', '$totalPlanned'),
                            if (outcomeSummary.isNotEmpty) ...[
                              _detailChip('Answered', '${outcomeSummary['answered'] ?? 0}'),
                              _detailChip('Voicemail', '${outcomeSummary['voicemail'] ?? 0}'),
                              _detailChip('Not connected', '${outcomeSummary['not_connected'] ?? 0}'),
                            ],
                            _detailChip('Avg call', '${avgCallSeconds}s'),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: NeyvoTheme.bgHover,
                            valueColor: AlwaysStoppedAnimation<Color>(NeyvoTheme.teal),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${progressPct.toStringAsFixed(0)}% complete ($done / $totalPlanned)',
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                        ),
                        const SizedBox(height: NeyvoSpacing.sm),
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
                        if ((c['filters'] ?? c['student_ids']) != null) ...[
                          const SizedBox(height: NeyvoSpacing.md),
                          Text('Audience', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)),
                          const SizedBox(height: NeyvoSpacing.xs),
                          Text(
                            audienceSummary(),
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                          ),
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
                Text('Targets (${items.length})', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
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
                            setState(() => _campaignDetailRefreshKey++);
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
                        return NeyvoTheme.teal;
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
                          leading: Icon(Icons.phone_outlined, color: NeyvoTheme.teal),
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
        );
      },
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
                      if (i > 0) Expanded(child: Divider(color: done ? NeyvoTheme.teal : NeyvoTheme.border)),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: active ? NeyvoTheme.teal : (done ? NeyvoTheme.teal : NeyvoTheme.bgCard),
                        child: Text('${i + 1}', style: TextStyle(color: active || done ? NeyvoColors.white : NeyvoTheme.textMuted, fontSize: 12)),
                      ),
                      if (i < steps.length - 1) Expanded(child: Divider(color: done ? NeyvoTheme.teal : NeyvoTheme.border)),
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
                  style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
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
                              ? NeyvoTheme.teal
                              : NeyvoTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _audienceMode == 'contact_list'
                            ? NeyvoTheme.teal.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'From Contact List',
                          style: NeyvoType.bodyMedium.copyWith(
                            color: _audienceMode == 'contact_list'
                                ? NeyvoTheme.teal
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
                              ? NeyvoTheme.teal
                              : NeyvoTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _audienceMode == 'filters'
                            ? NeyvoTheme.teal.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Smart Filter',
                          style: NeyvoType.bodyMedium.copyWith(
                            color: _audienceMode == 'filters'
                                ? NeyvoTheme.teal
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
                              ? NeyvoTheme.teal
                              : NeyvoTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _audienceMode == 'excel'
                            ? NeyvoTheme.teal.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Search by Excel & selection',
                          textAlign: TextAlign.center,
                          style: NeyvoType.bodyMedium.copyWith(
                            color: _audienceMode == 'excel'
                                ? NeyvoTheme.teal
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
                        Text('${_previewAudienceCount!} students match these filters', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.teal)),
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
                onChanged: (v) => setState(() => _filterType = v ?? 'all'),
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
                onChanged: (v) => setState(() => _filterOverdueOnly = v ?? false),
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
                          style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${filtered.length} contacts match', style: NeyvoType.bodyMedium),
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
                final q = _audienceSearchController.text.trim().toLowerCase();
                final visible = q.isEmpty
                    ? filtered
                    : filtered.where((s) {
                        final name = (s['name'] ?? '').toString().toLowerCase();
                        final phone = (s['phone'] ?? '').toString().toLowerCase();
                        final sid = (s['student_id'] ?? s['id'] ?? '').toString().toLowerCase();
                        return name.contains(q) || phone.contains(q) || sid.contains(q);
                      }).toList();
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
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
