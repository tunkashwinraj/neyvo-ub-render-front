// lib/screens/campaigns_page.dart
// Campaigns: bulk outbound calls with filters, templates, and scheduling (like ad campaigns).

import 'dart:async';
import 'package:flutter/material.dart';
import '../api/spearia_api.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';
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
  String _filterType = 'all'; // all, balance_above, balance_below, has_due_date, overdue
  final _balanceMinController = TextEditingController();
  final _balanceMaxController = TextEditingController();
  bool _filterOverdueOnly = false;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detailRefreshTimer?.cancel();
    _nameController.dispose();
    _balanceMinController.dispose();
    _balanceMaxController.dispose();
    _smartBalanceMinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final agentsRes = await NeyvoPulseApi.listAgents();
      final agentsList = agentsRes['agents'] as List? ?? [];
      final agents = agentsList.cast<Map<String, dynamic>>();
      final isEdu = agents.any((a) => (a['industry']?.toString().toLowerCase() ?? '') == 'education');
      final studentsRes = await NeyvoPulseApi.listStudents();
      final studentsList = studentsRes['students'] as List? ?? [];
      _students = studentsList.cast<Map<String, dynamic>>();
      _agents = agents;
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
    if (!_isEducationOrg || _audienceMode != 'filters') return;
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
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
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

  List<Map<String, dynamic>> get _filteredStudents {
    var list = List<Map<String, dynamic>>.from(_students);
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
        _selectedStudentIds = _filteredStudents.map((s) => s['id'] as String? ?? '').where((e) => e.isNotEmpty).toSet();
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
            : _filteredStudents.map((s) => s['id'] as String? ?? '').where((e) => e.isNotEmpty).toList());
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
    try {
      await NeyvoPulseApi.createCampaign(
        name: name,
        agentId: _selectedAgentId,
        studentIds: useFilters ? null : ids,
        templateId: _useTemplate ? _selectedTemplateId : null,
        audienceType: useFilters ? 'filters' : 'contact_list',
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
          SnackBar(content: Text('Campaign "$name" created for ${ids.length} contacts'), backgroundColor: NeyvoTheme.success),
        );
        setState(() {
          _showCreateWizard = false;
          _wizardStep = 0;
          _nameController.clear();
          _selectedAgentId = null;
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

  Widget _buildCallerIdDropdown() {
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
    final validValue = _selectedStartPhoneNumberId != null && numbers.any((e) => e['id'] == _selectedStartPhoneNumberId)
        ? _selectedStartPhoneNumberId
        : (numbers.isNotEmpty ? numbers.first['id'] as String : null);
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        value: validValue,
        decoration: const InputDecoration(
          labelText: 'Caller ID',
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
    if (id == null) return;
    if (!_hasCreditsToRun && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No credits. Available: ${_walletCredits ?? 0}. Required per call: ~${_creditsPerMinute ?? 25} credits. Add credits in Billing to run campaigns.'),
        backgroundColor: NeyvoTheme.warning,
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    final isRerun = c['status'] == 'completed' || c['status'] == 'running';
    try {
      final res = await NeyvoPulseApi.startCampaign(id, phoneNumberId: _selectedStartPhoneNumberId);
      if (mounted) {
        _showCampaignStartResult(res, isRerun: isRerun);
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) _showInsufficientCreditsSnackBar(e);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete campaign?'),
        content: Text('"$campaignName" will be permanently deleted. Only draft or scheduled campaigns can be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await NeyvoPulseApi.deleteCampaign(campaignId);
      if (mounted) {
        setState(() {
          _selectedCampaignId = null;
          _stopDetailAutoRefresh();
        });
        _load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign deleted')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
    }
  }

  Future<void> _saveCampaignEdit({required String name, required List<String> studentIds, bool useFilters = false}) async {
    final id = _editingCampaignId!;
    try {
      await NeyvoPulseApi.updateCampaign(
        id,
        name: name,
        agentId: _selectedAgentId,
        templateId: _useTemplate ? _selectedTemplateId : null,
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
                        if (c['status'] == 'draft' || c['status'] == 'scheduled') ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit campaign',
                            onPressed: () {
                              _nameController.text = c['name']?.toString() ?? '';
                              _selectedAgentId = c['agent_id']?.toString();
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
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete campaign',
                            onPressed: () => _confirmDeleteCampaign(c['id']?.toString() ?? '', c['name']?.toString() ?? 'Campaign'),
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
      future: Future.wait([
        NeyvoPulseApi.getCampaign(campaignId),
        NeyvoPulseApi.getCampaignCalls(campaignId),
        NeyvoPulseApi.getCampaignMetrics(campaignId),
        NeyvoPulseApi.getCampaignCallItems(campaignId, limit: 500),
      ]).then((list) => {
            'campaign': list[0]['campaign'],
            'calls': (list[1]['calls'] as List?) ?? [],
            'metrics': (list[2]['metrics'] as Map?) ?? {},
            'items': (list[3]['items'] as List?) ?? [],
          }),
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
        final canStart = status == 'draft' || status == 'scheduled';
        final canRerun = status == 'completed' || status == 'running';
        final canEdit = status == 'draft' || status == 'scheduled';
        final templateId = c['template_id']?.toString();
        final templateList = templateId != null ? _templates.where((t) => t['id']?.toString() == templateId).toList() : <Map<String, dynamic>>[];
        final templateName = templateList.isNotEmpty ? (templateList.first['name']?.toString() ?? templateId) : (templateId ?? '—');
        final created = c['created_at'];
        final started = c['started_at'];
        String formatDate(dynamic v) {
          if (v == null) return '—';
          if (v is String) return v.length > 19 ? v.substring(0, 19) : v;
          return v.toString();
        }
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
              TextButton.icon(
                icon: const Icon(Icons.verified_outlined, size: 20),
                label: const Text('Verify'),
                onPressed: () async {
                  try {
                    final res = await NeyvoPulseApi.verifyCampaign(campaignId);
                    final ok = res['ok'] == true;
                    final issues = (res['issues'] as List? ?? []).map((e) => e.toString()).toList();
                    final fixes = (res['auto_fixes_applied'] as List? ?? []).map((e) => e.toString()).toList();
                    final stats = (res['stats'] as Map?) ?? {};
                    if (!context.mounted) return;
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(ok ? 'Campaign is healthy' : 'Verification issues found'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (issues.isEmpty)
                                Text('No issues detected.', style: NeyvoType.bodyMedium)
                              else ...[
                                Text('Issues:', style: NeyvoType.bodyMedium),
                                const SizedBox(height: 4),
                                ...issues.map((i) => Text('• $i', style: NeyvoType.bodySmall)),
                              ],
                              if (fixes.isNotEmpty) ...[
                                const SizedBox(height: NeyvoSpacing.md),
                                Text('Auto-fixes applied:', style: NeyvoType.bodyMedium),
                                const SizedBox(height: 4),
                                ...fixes.map((f) => Text('• $f', style: NeyvoType.bodySmall)),
                              ],
                              const SizedBox(height: NeyvoSpacing.md),
                              Text('Stats:', style: NeyvoType.bodyMedium),
                              const SizedBox(height: 4),
                              Text(
                                'active=${stats['active_count'] ?? '-'}, '
                                'in_progress=${stats['in_progress_count'] ?? '-'}, '
                                'queued=${stats['queued_count'] ?? '-'}, '
                                'retry=${stats['retry_wait_count'] ?? '-'}, '
                                'completed=${stats['completed_count'] ?? '-'}, '
                                'failed=${stats['failed_count'] ?? '-'}',
                                style: NeyvoType.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                        ],
                      ),
                    );
                    if (mounted) setState(() => _campaignDetailRefreshKey++);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error),
                      );
                    }
                  }
                },
              ),
              if (status == 'running')
                TextButton.icon(
                  icon: const Icon(Icons.pause_circle_outline, size: 20),
                  label: const Text('Pause'),
                  onPressed: () async {
                    try {
                      await NeyvoPulseApi.pauseCampaign(campaignId);
                      if (mounted) setState(() => _campaignDetailRefreshKey++);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                      }
                    }
                  },
                ),
              if (status == 'paused')
                TextButton.icon(
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  label: const Text('Resume'),
                  onPressed: () async {
                    try {
                      await NeyvoPulseApi.resumeCampaign(campaignId);
                      if (mounted) setState(() => _campaignDetailRefreshKey++);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                      }
                    }
                  },
                ),
              if (status == 'running' || status == 'paused')
                TextButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                  label: const Text('Stop'),
                  onPressed: () async {
                    try {
                      await NeyvoPulseApi.stopCampaign(campaignId);
                      if (mounted) {
                        setState(() => _campaignDetailRefreshKey++);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign stopped. All calls ended.')));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                      }
                    }
                  },
                ),
              if (canEdit) ...[
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Delete'),
                  onPressed: () => _confirmDeleteCampaign(campaignId, c['name']?.toString() ?? 'Campaign'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Edit'),
                  onPressed: () {
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
                  },
                ),
              ],
              if (canStart || canRerun)
                Padding(
                  padding: const EdgeInsets.only(right: NeyvoSpacing.md),
                  child: _buildCallerIdDropdown(),
                ),
              if (canStart)
                TextButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Start campaign'),
                  onPressed: () async {
                    if (!_ensureHasPhoneNumber()) return;
                    if (!_hasCreditsToRun && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('No credits. Available: ${_walletCredits ?? 0}. Required per call: ~${_creditsPerMinute ?? 25} credits. Add credits in Billing to run campaigns.'),
                        backgroundColor: NeyvoTheme.warning,
                        duration: const Duration(seconds: 5),
                      ));
                      return;
                    }
                    try {
                      final res = await NeyvoPulseApi.startCampaign(campaignId, phoneNumberId: _selectedStartPhoneNumberId);
                      if (mounted) {
                        _showCampaignStartResult(res, isRerun: false);
                        setState(() => _campaignDetailRefreshKey++);
                      }
                    } on ApiException catch (e) {
                      if (mounted) _showInsufficientCreditsSnackBar(e);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                    }
                  },
                ),
              if (canStart && audienceIds.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.playlist_add_check_circle_outlined, size: 20),
                  label: const Text('Start subset'),
                  onPressed: () => _startCampaignWithSubset(campaignId, audienceIds),
                ),
              if (canRerun)
                TextButton.icon(
                  icon: const Icon(Icons.replay, size: 20),
                  label: const Text('Rerun campaign'),
                  onPressed: () async {
                    if (!_ensureHasPhoneNumber()) return;
                    if (!_hasCreditsToRun && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('No credits. Available: ${_walletCredits ?? 0}. Required per call: ~${_creditsPerMinute ?? 25} credits. Add credits in Billing.'),
                        backgroundColor: NeyvoTheme.warning,
                        duration: const Duration(seconds: 5),
                      ));
                      return;
                    }
                    try {
                      final res = await NeyvoPulseApi.startCampaign(campaignId, phoneNumberId: _selectedStartPhoneNumberId);
                      if (mounted) {
                        _showCampaignStartResult(res, isRerun: true);
                        setState(() => _campaignDetailRefreshKey++);
                      }
                    } on ApiException catch (e) {
                      if (mounted) _showInsufficientCreditsSnackBar(e);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error));
                    }
                  },
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
                            _detailChip('Queued', '$queuedCount'),
                            _detailChip('Retry', '$retryWaitCount'),
                            _detailChip('Completed', '$completedCount'),
                            _detailChip('Failed', '$failedCount'),
                            _detailChip('Total', '$totalPlanned'),
                            _detailChip('Avg call', '${avgCallSeconds}s'),
                            if (totalCreditsUsed > 0) _detailChip('Credits used', '$totalCreditsUsed cr'),
                            if (totalCreditsUsed > 0 && calls.isNotEmpty) _detailChip('Avg / call', '${avgCreditsPerCall.toStringAsFixed(1)} cr'),
                            if (throughputPerMinute != null && throughputPerMinute > 0)
                              _detailChip('Throughput', '${throughputPerMinute.toStringAsFixed(1)} calls/min'),
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
                        ListTile(title: Text('Created', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)), trailing: Text(formatDate(created), style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary))),
                        ListTile(title: Text('Started', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)), trailing: Text(formatDate(started), style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary))),
                        ListTile(title: Text('Script template', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)), trailing: Text(templateName ?? '—', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary))),
                        if ((c['filters'] ?? c['student_ids']) != null)
                          ListTile(
                            title: const Text('Audience'),
                            subtitle: Text(
                              c['student_ids'] != null
                                  ? '${(c['student_ids'] as List).length} contacts selected'
                                  : 'Filters: ${c['filters']?.toString() ?? '—'}',
                              style: NeyvoType.bodySmall,
                            ),
                          ),
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = visible[i];
                          final st = sOf(it);
                          final name = (it['student_name'] ?? it['name'] ?? '—').toString();
                          final phone = (it['student_phone'] ?? it['phone'] ?? '—').toString();
                          final attempt = it['attempt'];
                          return ListTile(
                            leading: Icon(Icons.person_outline, color: statusColor(st)),
                            title: Text(name, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)),
                            subtitle: Text('$phone • ${statusLabel(st)}${attempt != null ? ' • attempt $attempt' : ''}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                            trailing: st == 'completed'
                                ? const Icon(Icons.check_circle_outline, color: NeyvoTheme.success)
                                : (st == 'failed' ? const Icon(Icons.error_outline, color: NeyvoTheme.error) : null),
                          );
                        },
                      ),
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
                        child: Text('${i + 1}', style: TextStyle(color: active || done ? Colors.white : NeyvoTheme.textMuted, fontSize: 12)),
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
                      ? (_editingCampaignId != null ? 'Save changes' : 'Launch campaign')
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
            if (_isEducationOrg) ...[
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
                          border: Border.all(color: _audienceMode == 'contact_list' ? NeyvoTheme.teal : NeyvoTheme.border),
                          borderRadius: BorderRadius.circular(8),
                          color: _audienceMode == 'contact_list' ? NeyvoTheme.teal.withValues(alpha: 0.1) : null,
                        ),
                        child: Center(child: Text('From Contact List', style: NeyvoType.bodyMedium.copyWith(color: _audienceMode == 'contact_list' ? NeyvoTheme.teal : NeyvoTheme.textSecondary))),
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
                          border: Border.all(color: _audienceMode == 'filters' ? NeyvoTheme.teal : NeyvoTheme.border),
                          borderRadius: BorderRadius.circular(8),
                          color: _audienceMode == 'filters' ? NeyvoTheme.teal.withValues(alpha: 0.1) : null,
                        ),
                        child: Center(child: Text('Smart Filter', style: NeyvoType.bodyMedium.copyWith(color: _audienceMode == 'filters' ? NeyvoTheme.teal : NeyvoTheme.textSecondary))),
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
              if (_audienceMode == 'contact_list') const Divider(),
            ],
            if (!_isEducationOrg || _audienceMode == 'contact_list') ...[
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    final id = s['id'] as String? ?? '';
                    final selected = !_manualAudienceSelection || _selectedStudentIds.contains(id);
                    return CheckboxListTile(
                      title: Text(s['name']?.toString() ?? '—'),
                      subtitle: Text('${s['phone'] ?? ''} • ${s['balance'] ?? ''}'),
                      value: selected,
                      onChanged: _manualAudienceSelection ? (v) => _toggleStudent(id) : null,
                    );
                  },
                ),
              ),
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
              'Use an agent for voice, prompt, and settings. You can optionally apply a script template for labeling or structured reminders.',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            DropdownButtonFormField<String>(
              value: _selectedAgentId ?? (_agents.isNotEmpty ? null : null),
              decoration: const InputDecoration(
                labelText: 'Agent',
                hintText: 'Select an agent (recommended)',
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('— No agent —')),
                ..._agents.map((a) => DropdownMenuItem<String>(
                  value: a['id']?.toString(),
                  child: Text(a['name']?.toString() ?? 'Unnamed agent'),
                )),
              ],
              onChanged: (v) => setState(() => _selectedAgentId = v),
            ),
            const SizedBox(height: NeyvoSpacing.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use script template (optional)'),
              subtitle: Text(
                'When enabled, calls will also use a structured script template for labeling and messaging. Without it, the agent\'s own script is used.',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
              ),
              value: _useTemplate,
              onChanged: (v) {
                setState(() {
                  _useTemplate = v;
                  if (!v) {
                    _selectedTemplateId = null;
                  } else if (_selectedTemplateId == null && _templates.isNotEmpty) {
                    _selectedTemplateId = _templates.first['id']?.toString();
                  }
                });
              },
            ),
            const SizedBox(height: NeyvoSpacing.md),
            if (_useTemplate)
              Builder(
                builder: (context) {
                  if (_templates.isEmpty) {
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'No templates yet. Create one in Templates.',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                          ),
                        ),
                      ],
                    );
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedTemplateId ?? (_templates.isNotEmpty ? _templates.first['id']?.toString() : null),
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: _templates
                        .map((t) => DropdownMenuItem(
                              value: t['id']?.toString(),
                              child: Text(t['name']?.toString() ?? 'Unnamed'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTemplateId = v),
                  );
                },
              ),
            const SizedBox(height: NeyvoSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, PulseRouteNames.templateScripts),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Manage templates'),
              ),
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
    final count = (_isEducationOrg && _audienceMode == 'filters')
        ? (_previewAudienceCount ?? 0)
        : (_selectedStudentIds.isEmpty ? _filteredStudents.length : _selectedStudentIds.length);
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
            ListTile(
              title: const Text('Agent'),
              trailing: Text(
                () {
                  if (_selectedAgentId != null && _selectedAgentId!.isNotEmpty) {
                    final list = _agents.where((a) => a['id']?.toString() == _selectedAgentId).toList();
                    if (list.isNotEmpty) return list.first['name']?.toString() ?? '—';
                  }
                  return '—';
                }(),
              ),
            ),
            ListTile(
              title: const Text('Template'),
              trailing: Text(
                () {
                  final list = _templates.where((t) => t['id']?.toString() == _selectedTemplateId).toList();
                  if (list.isNotEmpty) return list.first['name']?.toString() ?? '—';
                  if (_templates.isNotEmpty) return _templates.first['name']?.toString() ?? '—';
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
