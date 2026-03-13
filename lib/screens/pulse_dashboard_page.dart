// Voice OS Home – Voice Command Center (not a SaaS dashboard).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import 'pulse_shell.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/ai_orb/neyvo_ai_orb.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../features/agents/create_agent_wizard.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../features/setup/setup_api_service.dart';

class PulseDashboardPage extends StatefulWidget {
  const PulseDashboardPage({super.key});

  @override
  State<PulseDashboardPage> createState() => _PulseDashboardPageState();
}

class _PulseDashboardPageState extends State<PulseDashboardPage> {
  bool _loading = true;
  String? _error;

  // When true, only the Voice OS KPIs / analytics section is refreshing.
  // This avoids showing a full-page loader when the date filter changes.
  bool _kpiLoading = false;

  // When true, only the \"University of Bridgeport Voice OS\" hero metrics
  // (top-left summary card) are refreshing in response to the duration filter.
  bool _ubHeroLoading = false;

  // Live call progress state for the hero \"Live calls\" card.
  bool _liveLoading = false;
  int _liveTotalCalls = 0;
  int _liveRunningCalls = 0;
  int _liveCompletedCalls = 0;
  int _liveIncompleteCalls = 0;
  int _liveFailedCalls = 0;
  int _liveVoicemailCalls = 0;
  int _liveRescheduledCalls = 0;
  Timer? _liveCallsTimer;

  bool _businessConfigured = false;
  bool _agentAttached = false;
  bool _numberLive = false;
  bool _firstCallCompleted = false;
  String _ubStatus = 'missing';
  int _operatorCount = 0;

  String? _trainingNumber;
  List<Map<String, dynamic>> _recentCalls = const [];
  Map<String, dynamic>? _perf;
  Map<String, dynamic>? _ubModel;

  Map<String, dynamic>? _successSummary;
  Map<String, dynamic>? _perfPrevious;
  Map<String, dynamic>? _successSummaryPrevious;

  String _callsSearchQuery = '';
  String? _callsResultFilter;
  String? _callsDepartmentFilter;

  List<Map<String, dynamic>> _recentCampaigns = const [];
  String? _campaignSemesterFilter;
  String? _campaignStatusFilter;

  // Global date filter (drives all dashboard KPIs and panels).
  String _datePreset = 'this_week'; // today, yesterday, this_week, this_month, this_year, custom
  DateTime? _fromDate;
  DateTime? _toDate;

  static const List<String> _recommendedOperators = [
    'Admissions Operator',
    'Student Financial Services Operator',
    'Registrar Operator',
    'Housing Operator',
    'IT Help Desk Operator',
    'General Front Desk Operator',
  ];

  /// Map dashboard label to UB department id for wizard deep-link.
  static String? _departmentIdForLabel(String label) {
    const map = {
      'Admissions Operator': 'admissions',
      'Student Financial Services Operator': 'student_financial_services',
      'Registrar Operator': 'registrar',
      'Housing Operator': 'residential_life_and_housing',
      'IT Help Desk Operator': 'information_technology_help_desk',
      'General Front Desk Operator': null,
    };
    return map[label];
  }

  @override
  void initState() {
    super.initState();
    _applyPresetWithoutReload('this_week');
    _load();
    _loadLiveCallStats();
  }

  // Compute a concrete date range for a given preset.
  void _applyPresetWithoutReload(String preset, {DateTimeRange? customRange}) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
        break;
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day);
        end = start.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
        break;
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        end = nextMonth.subtract(const Duration(microseconds: 1));
        break;
      case 'this_year':
        start = DateTime(now.year, 1, 1);
        final nextYear = DateTime(now.year + 1, 1, 1);
        end = nextYear.subtract(const Duration(microseconds: 1));
        break;
      case 'custom':
        if (customRange != null) {
          start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
          end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day)
              .add(const Duration(days: 1))
              .subtract(const Duration(microseconds: 1));
        } else {
          // Fallback to this week if custom not provided.
          final weekday = now.weekday; // 1 = Mon
          start = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: weekday - 1));
          end = start.add(const Duration(days: 7)).subtract(const Duration(microseconds: 1));
          preset = 'this_week';
        }
        break;
      case 'this_week':
      default:
        final weekday = now.weekday; // 1 = Mon
        start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday - 1));
        end = start.add(const Duration(days: 7)).subtract(const Duration(microseconds: 1));
        preset = 'this_week';
        break;
    }

    _datePreset = preset;
    _fromDate = start;
    _toDate = end;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialFirstDate = DateTime(now.year - 1, 1, 1);
    final initialLastDate = DateTime(now.year + 1, 12, 31);

    final range = await showDateRangePicker(
      context: context,
      firstDate: initialFirstDate,
      lastDate: initialLastDate,
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (range == null) return;

    setState(() {
      _applyPresetWithoutReload('custom', customRange: range);
    });
    // Refresh only the UB hero metrics for the new custom range
    // without reloading the rest of the dashboard.
    await _loadUbHeroSection();
  }

  String? _rangeLabel() {
    if (_fromDate == null || _toDate == null) return null;
    final from = _fromDate!;
    final to = _toDate!;
    final sameYear = from.year == to.year;
    final sameMonth = sameYear && from.month == to.month;
    String fmtMonth(int m) => _monthAbbrev(m);

    if (sameYear && sameMonth && from.day == to.day) {
      return '${fmtMonth(from.month)} ${from.day}, ${from.year}';
    }
    if (sameYear) {
      return '${fmtMonth(from.month)} ${from.day} – ${fmtMonth(to.month)} ${to.day}, ${from.year}';
    }
    return '${fmtMonth(from.month)} ${from.day}, ${from.year} – ${fmtMonth(to.month)} ${to.day}, ${to.year}';
  }

  String _monthAbbrev(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  Map<String, String?> _currentIsoRange() {
    final from = _fromDate;
    final to = _toDate;
    if (from == null || to == null) {
      return {'from': null, 'to': null};
    }
    String toIsoDay(DateTime d) => '${d.toUtc().toIso8601String().split('T').first}';
    return {
      'from': toIsoDay(from),
      'to': toIsoDay(to),
    };
  }

  Map<String, String?> _previousIsoRange() {
    final from = _fromDate;
    final to = _toDate;
    if (from == null || to == null) {
      return {'from': null, 'to': null};
    }
    final days = to.difference(from).inDays + 1;
    final prevEnd = from.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: days - 1));
    String toIsoDay(DateTime d) => '${d.toUtc().toIso8601String().split('T').first}';
    return {
      'from': toIsoDay(prevStart),
      'to': toIsoDay(prevEnd),
    };
  }

  Future<void> _load() async {
    final range = _currentIsoRange();
    final from = range['from'];
    final to = range['to'];
    final prevRange = _previousIsoRange();
    final prevFrom = prevRange['from'];
    final prevTo = prevRange['to'];
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SetupStatusApiService.getStatus(), // 0
        ManagedProfileApiService.listProfiles(), // 1
        NeyvoPulseApi.listNumbers(), // 2
        NeyvoPulseApi.listCalls(from: from, to: to), // 3
        NeyvoPulseApi.getAnalyticsOverview(from: from, to: to), // 4
        NeyvoPulseApi.getAnalyticsOverview(from: prevFrom, to: prevTo), // 5
        NeyvoPulseApi.getAccountInfo(), // 6
        NeyvoPulseApi.getUbStatus(), // 7
        NeyvoPulseApi.getCallsSuccessSummary(from: from, to: to), // 8
        NeyvoPulseApi.getCallsSuccessSummary(from: prevFrom, to: prevTo), // 9
      ]);

      final setup = results[0] as Map<String, dynamic>;
      final profiles = results[1] as Map<String, dynamic>;
      final numbersRes = results[2] as Map<String, dynamic>;
      final callsRes = results[3] as Map<String, dynamic>;
      final perf = results[4] as Map<String, dynamic>;
      final perfPrev = results[5] as Map<String, dynamic>;
      final account = results[6] as Map<String, dynamic>;
      final ubRes = results[7] as Map<String, dynamic>;
      final successSummary = results[8] as Map<String, dynamic>;
      final successSummaryPrev = results[9] as Map<String, dynamic>;
      final campaignsRes = await NeyvoPulseApi.listCampaigns();

      final business = Map<String, dynamic>.from(setup['business'] as Map? ?? {});
      final numbers = (numbersRes['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final profList = (profiles['profiles'] as List?)?.cast<dynamic>() ?? const [];
      final ubStatus = (ubRes['status'] as String?)?.toLowerCase() ?? 'missing';

      final calls = (callsRes['calls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final campaigns =
          (campaignsRes['campaigns'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final firstCallCompleted = calls.any((c) {
        final status = (c['status'] as String?)?.toLowerCase();
        if (status == 'completed' || status == 'success') return true;
        final endedAt = c['ended_at'];
        return endedAt != null && status != 'failed';
      });

      final businessConfigured =
          (business['status'] as String? ?? '').toLowerCase() == 'ready';

      final numberLive = numbers.isNotEmpty ||
          ((account['primary_phone_e164'] ?? account['primary_phone'])?.toString().trim().isNotEmpty == true);

      final attached = profList.any((p) {
        final m = Map<String, dynamic>.from(p as Map);
        return (m['attached_phone_number_id']?.toString().trim().isNotEmpty == true) ||
            (m['attached_vapi_phone_number_id']?.toString().trim().isNotEmpty == true);
      });

      final trainingNumber = (account['primary_phone_e164'] ?? account['primary_phone'])?.toString().trim();

      if (!mounted) return;
      setState(() {
        _businessConfigured = businessConfigured;
        _agentAttached = attached;
        _numberLive = numberLive;
        _firstCallCompleted = firstCallCompleted;
        _ubStatus = ubStatus;
        _operatorCount = profList.length;
        _trainingNumber = trainingNumber != null && trainingNumber.isNotEmpty ? trainingNumber : null;
        _recentCalls = calls.take(8).toList();
        _perf = perf;
        _ubModel = ubRes is Map ? Map<String, dynamic>.from(ubRes as Map) : null;
        _successSummary = successSummary;
        _perfPrevious = perfPrev;
        _successSummaryPrevious = successSummaryPrev;
        _recentCampaigns = campaigns.take(8).cast<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Reload only the live call statistics used by the hero "Live calls" card.
  /// This is lightweight compared to the full dashboard load and is safe to run
  /// periodically while calls are in progress.
  Future<void> _loadLiveCallStats() async {
    final range = _currentIsoRange();
    final from = range['from'];
    final to = range['to'];

    setState(() {
      _liveLoading = true;
    });

    try {
      final res = await NeyvoPulseApi.listCalls(from: from, to: to);
      final calls = (res['calls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (!mounted) return;
      _updateLiveCallStatsFromCalls(calls);
    } catch (_) {
      if (!mounted) return;
      // Live card errors should not take down the whole dashboard; we simply
      // stop showing the inline loader until the next refresh.
      setState(() {
        _liveLoading = false;
      });
    }
  }

  void _updateLiveCallStatsFromCalls(List<Map<String, dynamic>> calls) {
    int total = calls.length;
    int running = 0;
    int completed = 0;
    int incomplete = 0;
    int failed = 0;
    int voicemail = 0;
    int rescheduled = 0;

    for (final c in calls) {
      final statusRaw = (c['status'] ?? c['result'] ?? '').toString().toLowerCase();
      final endedAt = c['ended_at'];
      final isEnded = endedAt != null;
      final isExplicitFailed = statusRaw.contains('failed') || statusRaw.contains('error');
      final isRunning = !isEnded &&
          (statusRaw.contains('queued') ||
              statusRaw.contains('dial') ||
              statusRaw.contains('ring') ||
              statusRaw.contains('progress') ||
              statusRaw.contains('running') ||
              statusRaw.isEmpty);

      if (isRunning) {
        running++;
        continue;
      }

      final result = _mapCallResult(c);
      switch (result.key) {
        case 'goal_achieved':
        case 'answered':
          completed++;
          break;
        case 'voicemail':
          voicemail++;
          break;
        case 'rescheduled':
          rescheduled++;
          break;
        case 'no_answer':
          if (isExplicitFailed) {
            failed++;
          } else {
            incomplete++;
          }
          break;
        default:
          incomplete++;
      }
    }

    setState(() {
      _liveTotalCalls = total;
      _liveRunningCalls = running;
      _liveCompletedCalls = completed;
      _liveIncompleteCalls = incomplete;
      _liveFailedCalls = failed;
      _liveVoicemailCalls = voicemail;
      _liveRescheduledCalls = rescheduled;
      _liveLoading = false;
    });

    _ensureLiveTimer(running > 0);
  }

  void _ensureLiveTimer(bool hasRunningCalls) {
    if (hasRunningCalls) {
      if (_liveCallsTimer == null || !_liveCallsTimer!.isActive) {
        _liveCallsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          _loadLiveCallStats();
        });
      }
    } else {
      _liveCallsTimer?.cancel();
      _liveCallsTimer = null;
    }
  }

  /// Reload only the date-scoped Voice OS analytics (KPIs, charts, recent calls, success summary)
  /// without triggering the full-page loading spinner.
  Future<void> _loadKpiSection() async {
    final range = _currentIsoRange();
    final from = range['from'];
    final to = range['to'];
    final prevRange = _previousIsoRange();
    final prevFrom = prevRange['from'];
    final prevTo = prevRange['to'];

    setState(() {
      _kpiLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        NeyvoPulseApi.listCalls(from: from, to: to), // 0
        NeyvoPulseApi.getAnalyticsOverview(from: from, to: to), // 1
        NeyvoPulseApi.getAnalyticsOverview(from: prevFrom, to: prevTo), // 2
        NeyvoPulseApi.getCallsSuccessSummary(from: from, to: to), // 3
        NeyvoPulseApi.getCallsSuccessSummary(from: prevFrom, to: prevTo), // 4
      ]);

      final callsRes = results[0] as Map<String, dynamic>;
      final perf = results[1] as Map<String, dynamic>;
      final perfPrev = results[2] as Map<String, dynamic>;
      final successSummary = results[3] as Map<String, dynamic>;
      final successSummaryPrev = results[4] as Map<String, dynamic>;

      final calls = (callsRes['calls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final firstCallCompleted = calls.any((c) {
        final status = (c['status'] as String?)?.toLowerCase();
        if (status == 'completed' || status == 'success') return true;
        final endedAt = c['ended_at'];
        return endedAt != null && status != 'failed';
      });

      if (!mounted) return;
      setState(() {
        _firstCallCompleted = firstCallCompleted;
        _recentCalls = calls.take(8).toList();
        _perf = perf;
        _successSummary = successSummary;
        _perfPrevious = perfPrev;
        _successSummaryPrevious = successSummaryPrev;
        _kpiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _kpiLoading = false;
      });
    }
  }

  /// Reload only the \"University of Bridgeport Voice OS\" hero metrics.
  /// This is used by the duration filter so that changing the time range
  /// does not refresh the entire dashboard, only the top summary card.
  Future<void> _loadUbHeroSection() async {
    final range = _currentIsoRange();
    final from = range['from'];
    final to = range['to'];
    final prevRange = _previousIsoRange();
    final prevFrom = prevRange['from'];
    final prevTo = prevRange['to'];

    setState(() {
      _ubHeroLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        NeyvoPulseApi.listCalls(from: from, to: to), // 0
        NeyvoPulseApi.getAnalyticsOverview(from: from, to: to), // 1
        NeyvoPulseApi.getAnalyticsOverview(from: prevFrom, to: prevTo), // 2
        NeyvoPulseApi.getCallsSuccessSummary(from: from, to: to), // 3
        NeyvoPulseApi.getCallsSuccessSummary(from: prevFrom, to: prevTo), // 4
      ]);

      final callsRes = results[0] as Map<String, dynamic>;
      final perf = results[1] as Map<String, dynamic>;
      final perfPrev = results[2] as Map<String, dynamic>;
      final successSummary = results[3] as Map<String, dynamic>;
      final successSummaryPrev = results[4] as Map<String, dynamic>;

      final calls = (callsRes['calls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final firstCallCompleted = calls.any((c) {
        final status = (c['status'] as String?)?.toLowerCase();
        if (status == 'completed' || status == 'success') return true;
        final endedAt = c['ended_at'];
        return endedAt != null && status != 'failed';
      });

      if (!mounted) return;
      setState(() {
        _firstCallCompleted = firstCallCompleted;
        _recentCalls = calls.take(8).toList();
        _perf = perf;
        _successSummary = successSummary;
        _perfPrevious = perfPrev;
        _successSummaryPrevious = successSummaryPrev;
        _ubHeroLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _ubHeroLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _liveCallsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final ubReady = _ubStatus == 'ready';
    final showCreateFirstOperator = ubReady && _operatorCount == 0;

    // Keep the dedicated "create first operator" experience for empty state.
    if (showCreateFirstOperator) {
      return ClipRect(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        const NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 140),
                        const SizedBox(height: 20),
                        Text(
                          'Create your first Operator',
                          style: NeyvoTextStyles.title.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: NeyvoColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a department to create a voice operator. You can add more later.',
                          style: NeyvoTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        NeyvoGlassPanel(
                          glowing: true,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < _recommendedOperators.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: () async {
                                    final deptId = _departmentIdForLabel(_recommendedOperators[i]);
                                    if (deptId != null) {
                                      final created = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => CreateAgentWizard(initialDepartmentId: deptId),
                                      );
                                      if (created == true && mounted) {
                                        PulseShellController.navigatePulse(context, PulseRouteNames.agents);
                                      }
                                    } else {
                                      PulseShellController.navigatePulse(context, PulseRouteNames.agents);
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: i == 0 ? NeyvoColors.teal : NeyvoColors.bgRaised,
                                    foregroundColor: i == 0 ? NeyvoColors.white : NeyvoColors.textPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    i == 0 ? 'Create ${_recommendedOperators[i]}' : _recommendedOperators[i],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => PulseShellController.navigatePulse(context, PulseRouteNames.agents),
                                child: const Text('Choose another department'),
                              ),
                            ],
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
    }

    final callOk = _firstCallCompleted;
    final orbState = callOk ? NeyvoAIOrbState.idle : NeyvoAIOrbState.processing;

    return ClipRect(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GlobalDateFilterBar(
                          preset: _datePreset,
                          rangeLabel: _rangeLabel(),
                          onPresetChanged: (preset) {
                            setState(() {
                              _applyPresetWithoutReload(preset);
                            });
                            _loadUbHeroSection();
                          },
                          onCustomTap: () async {
                            await _pickCustomRange();
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildHeroSection(orbState, callOk, contentWidth),
                        const SizedBox(height: 24),
                        _buildInsightsSection(),
                        const SizedBox(height: 24),
                        _buildOperationsSection(callOk),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(NeyvoAIOrbState orbState, bool callOk, double contentWidth) {
    final callsTotal = (_perf?['calls_total'] as num?)?.toInt() ??
        (_perf?['total_calls'] as num?)?.toInt() ??
        _recentCalls.length;
    final callsTotalPrev = (_perfPrevious?['calls_total'] as num?)?.toInt() ??
        (_perfPrevious?['total_calls'] as num?)?.toInt();
    final resolutionPct = (_perf?['resolution_rate_pct'] as num?)?.toDouble() ??
        (_perf?['resolution_rate'] as num?)?.toDouble();
    final resolutionPrev = (_perfPrevious?['resolution_rate_pct'] as num?)?.toDouble() ??
        (_perfPrevious?['resolution_rate'] as num?)?.toDouble();
    final studentsReached = _computeUniqueStudentsReached();

    final totalCoreDepartments = _recommendedOperators.length;
    final coveredDepartments = _operatorCount.clamp(0, totalCoreDepartments);

    final ubModelStatus = _ubStatus;
    final envLabel = 'Prod';

    final heroCard = _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'University of Bridgeport Voice OS',
                  style: NeyvoTextStyles.heading.copyWith(fontSize: 18),
                ),
              ),
              if (_ubHeroLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NeyvoColors.teal,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: 'Voice OS',
                value: callOk ? 'Healthy' : 'Needs attention',
                color: callOk ? NeyvoColors.success : NeyvoColors.warning,
              ),
              _StatusChip(
                label: 'Coverage',
                value: '$coveredDepartments / $totalCoreDepartments departments',
              ),
              _StatusChip(
                label: 'UB model',
                value: ubModelStatus == 'ready'
                    ? 'Ready'
                    : ubModelStatus == 'building'
                        ? 'Building'
                        : 'Missing',
                color: ubModelStatus == 'ready'
                    ? NeyvoColors.success
                    : ubModelStatus == 'building'
                        ? NeyvoColors.info
                        : NeyvoColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _KpiCard(
                title: 'Calls handled',
                value: callsTotal > 0 ? callsTotal.toString() : '—',
                deltaPercent: _computeDeltaPercent(callsTotal.toDouble(), callsTotalPrev?.toDouble()),
              ),
              _KpiCard(
                title: 'Students reached',
                value: studentsReached > 0 ? studentsReached.toString() : '—',
                deltaPercent: null,
              ),
              _KpiCard(
                title: 'AI answer rate',
                value: resolutionPct == null ? '—' : '${resolutionPct.toStringAsFixed(1)}%',
                deltaPercent: _computeDeltaPercent(resolutionPct, resolutionPrev),
                isPercentage: true,
              ),
              _KpiCard(
                title: 'Goal completion rate',
                value: _goalCompletionRateLabel(_successSummary),
                deltaPercent: _computeDeltaPercent(
                  _goalCompletionRateValue(_successSummary),
                  _goalCompletionRateValue(_successSummaryPrevious),
                ),
                isPercentage: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Last updated just now · $envLabel',
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
        ],
      ),
    );

    final liveProgressCard = _LiveCallProgressCard(
      loading: _liveLoading,
      totalCalls: _liveTotalCalls,
      runningCalls: _liveRunningCalls,
      completedCalls: _liveCompletedCalls,
      incompleteCalls: _liveIncompleteCalls,
      failedCalls: _liveFailedCalls,
      voicemailCalls: _liveVoicemailCalls,
      rescheduledCalls: _liveRescheduledCalls,
    );
    final nextActionsCard = _SimpleCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next best actions', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              if (w < 600) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _NextActionCompact(icon: Icons.person_add_alt_1_outlined, label: 'Add operator', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.agents)),
                      const SizedBox(width: 8),
                      _NextActionCompact(icon: Icons.campaign_outlined, label: 'Campaigns', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.campaigns)),
                      const SizedBox(width: 8),
                      _NextActionCompact(icon: Icons.school_outlined, label: 'UB model', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.ubModelOverview)),
                      const SizedBox(width: 8),
                      _NextActionCompact(icon: Icons.analytics_outlined, label: 'Analytics', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.analytics)),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  Expanded(child: _NextActionCompact(icon: Icons.person_add_alt_1_outlined, label: 'Add operator', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.agents))),
                  const SizedBox(width: 8),
                  Expanded(child: _NextActionCompact(icon: Icons.campaign_outlined, label: 'Campaigns', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.campaigns))),
                  const SizedBox(width: 8),
                  Expanded(child: _NextActionCompact(icon: Icons.school_outlined, label: 'UB model', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.ubModelOverview))),
                  const SizedBox(width: 8),
                  Expanded(child: _NextActionCompact(icon: Icons.analytics_outlined, label: 'Analytics', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.analytics))),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (contentWidth < 800) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heroCard,
          const SizedBox(height: 16),
          liveProgressCard,
          const SizedBox(height: 16),
          nextActionsCard,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: heroCard),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: liveProgressCard),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: nextActionsCard),
      ],
    );
  }

  Widget _buildInsightsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        if (isNarrow) {
          return Column(
            children: [
              _VoiceCoverageCard(
                operatorCount: _operatorCount,
                totalCoreDepartments: _recommendedOperators.length,
                onCreateOperator: () async {
                  final created = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => const CreateAgentWizard(),
                  );
                  if (created == true && mounted) _load();
                },
              ),
              const SizedBox(height: 16),
              _CallsPerformanceCard(perf: _perf),
              const SizedBox(height: 16),
              _StudentFinancialImpactCard(perf: _perf),
              const SizedBox(height: 16),
              _UbModelCard(ubModel: _ubModel, status: _ubStatus),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _VoiceCoverageCard(
                    operatorCount: _operatorCount,
                    totalCoreDepartments: _recommendedOperators.length,
                    onCreateOperator: () async {
                      final created = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => const CreateAgentWizard(),
                      );
                      if (created == true && mounted) _load();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _CallsPerformanceCard(perf: _perf)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StudentFinancialImpactCard(perf: _perf)),
                const SizedBox(width: 16),
                Expanded(child: _UbModelCard(ubModel: _ubModel, status: _ubStatus)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationsSection(bool callOk) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SimpleCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_outlined, color: NeyvoColors.teal),
                        const SizedBox(width: 10),
                        Text('Active operations', style: NeyvoTextStyles.heading),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!callOk) ...[
                      Text(
                        'Make a quick test call to finalize setup, then launch campaigns for students.',
                        style: NeyvoTextStyles.body,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              PulseShellController.navigatePulse(context, PulseRouteNames.testCall),
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                          child: const Text('Make a test call'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _recentCallsTable(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SimpleCard(
                padding: const EdgeInsets.all(20),
                child: _buildRecentCampaignsPanel(),
              ),
              const SizedBox(height: 16),
              _SimpleCard(
                padding: const EdgeInsets.all(20),
                child: _buildLiveActivity(),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _SimpleCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_outlined, color: NeyvoColors.teal),
                        const SizedBox(width: 10),
                        Text('Active operations', style: NeyvoTextStyles.heading),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!callOk) ...[
                      Text(
                        'Make a quick test call to finalize setup, then launch campaigns for students.',
                        style: NeyvoTextStyles.body,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              PulseShellController.navigatePulse(context, PulseRouteNames.testCall),
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                          child: const Text('Make a test call'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _recentCallsTable(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: _SimpleCard(
                padding: const EdgeInsets.all(20),
                child: _buildLiveActivity(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: _SimpleCard(
                padding: const EdgeInsets.all(20),
                child: _buildRecentCampaignsPanel(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_toggle_off, color: NeyvoColors.teal),
            const SizedBox(width: 10),
            Text('Live activity', style: NeyvoTextStyles.heading),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentCalls.isEmpty)
          Text(
            'No recent activity yet. As students call or receive outbound calls, activity will appear here.',
            style: NeyvoTextStyles.body,
          )
        else
          Column(
            children: _recentCalls.take(5).map((c) {
              final dir = (c['direction'] as String?)?.toLowerCase() ?? 'inbound';
              final status = (c['status'] as String?)?.toLowerCase() ?? '—';
              final name =
                  (c['student_name'] ?? c['contact_name'] ?? c['caller'] ?? '—').toString();
              final dur = (c['duration_seconds'] as num?)?.toInt() ?? 0;
              final ok = status == 'completed' || status == 'success';
              final timeLabel = dur <= 0 ? '' : ' · ${dur}s';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      dir == 'inbound' ? Icons.call_received : Icons.call_made,
                      size: 18,
                      color: ok ? NeyvoColors.success : NeyvoColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$name · ${dir == 'inbound' ? 'Inbound' : 'Outbound'}$timeLabel',
                        style: NeyvoTextStyles.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _actionButton(
              icon: Icons.phone_in_talk_outlined,
              label: 'Call My AI',
              onTap: _showCallMyAi,
            ),
            _actionButton(
              icon: Icons.call_made_outlined,
              label: 'Start outbound',
              onTap: () =>
                  PulseShellController.navigatePulse(context, PulseRouteNames.dialer),
            ),
            _actionButton(
              icon: Icons.smart_toy_outlined,
              label: 'Edit operator',
              onTap: () =>
                  PulseShellController.navigatePulse(context, PulseRouteNames.agents),
            ),
            _actionButton(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Add credits',
              onTap: () =>
                  PulseShellController.navigatePulse(context, PulseRouteNames.billing),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentCampaignsPanel() {
    if (_recentCampaigns.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_mode_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Recent campaigns', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'No campaigns yet. When you launch campaigns, progress will appear here.',
            style: NeyvoTextStyles.body,
          ),
        ],
      );
    }

    final semesters = _distinctCampaignSemesters().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_mode_outlined, color: NeyvoColors.teal),
            const SizedBox(width: 10),
            Text('Recent campaigns', style: NeyvoTextStyles.heading),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isDense: true,
                decoration: const InputDecoration(
                  hintText: 'Semester',
                ),
                value: _campaignSemesterFilter,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All semesters')),
                  ...semesters.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _campaignSemesterFilter = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _campaignStatusFilter == null || _campaignStatusFilter!.isEmpty,
                    onSelected: (_) {
                      setState(() {
                        _campaignStatusFilter = null;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Running'),
                    selected: _campaignStatusFilter == 'running',
                    onSelected: (_) {
                      setState(() {
                        _campaignStatusFilter = 'running';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Complete'),
                    selected: _campaignStatusFilter == 'complete',
                    onSelected: (_) {
                      setState(() {
                        _campaignStatusFilter = 'complete';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Scheduled'),
                    selected: _campaignStatusFilter == 'scheduled',
                    onSelected: (_) {
                      setState(() {
                        _campaignStatusFilter = 'scheduled';
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._filteredCampaigns().map((c) {
          final name = (c['name'] ?? 'Untitled campaign').toString();
          final department = (c['department'] ?? c['target_department'] ?? '—').toString();
          final studentCount = (c['student_count'] as num?)?.toInt() ??
              (c['targets'] as List?)?.length ??
              0;
          final answered = (c['answered_count'] as num?)?.toInt() ?? 0;
          final voicemail = (c['voicemail_count'] as num?)?.toInt() ?? 0;
          final goalPct = (c['goal_completion_pct'] as num?)?.toDouble();
          final semester = _semesterLabelForCampaign(c);
          final statusInfo = _campaignStatusInfo(c);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: NeyvoColors.bgRaised.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NeyvoColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: NeyvoTextStyles.bodyPrimary),
                            const SizedBox(height: 2),
                            Text(
                              department,
                              style: NeyvoTextStyles.micro,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _semesterColor(semester).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _semesterColor(semester).withOpacity(0.6)),
                            ),
                            child: Text(
                              semester,
                              style: NeyvoTextStyles.micro.copyWith(
                                color: _semesterColor(semester),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '$studentCount students · $answered answered / $voicemail voicemail',
                          style: NeyvoTextStyles.micro,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: NeyvoColors.bgRaised,
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: (goalPct ?? 0).clamp(0, 100) / 100.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: NeyvoColors.teal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              goalPct == null
                                  ? '—'
                                  : '${goalPct.toStringAsFixed(0)}%',
                              style: NeyvoTextStyles.micro,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: statusInfo.color.withOpacity(0.6)),
                        ),
                        child: Text(
                          statusInfo.label,
                          style: NeyvoTextStyles.micro.copyWith(
                            color: statusInfo.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _performanceSnapshot() {
    final calls = (_perf?['calls_total'] as num?)?.toInt();
    final resolution = (_perf?['resolution_rate_pct'] as num?)?.toDouble() ??
        (_perf?['resolution_rate'] as num?)?.toDouble();
    final credits = (_perf?['credits_consumed'] as num?)?.toInt() ??
        (_perf?['credits_used'] as num?)?.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_graph_outlined, color: NeyvoColors.teal),
            const SizedBox(width: 10),
            Text('Performance snapshot', style: NeyvoTextStyles.heading),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricChip('Total calls', calls?.toString() ?? '—'),
            _metricChip('Resolution', resolution == null ? '—' : '${resolution.toStringAsFixed(1)}%'),
            _metricChip('Credits used', credits?.toString() ?? '—'),
          ],
        ),
      ],
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: NeyvoTextStyles.micro),
        ],
      ),
    );
  }

  Widget _recentCallsTable() {
    if (_recentCalls.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Recent calls', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          Text('No calls yet.', style: NeyvoTextStyles.body),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: NeyvoColors.teal),
            const SizedBox(width: 10),
            Text('Recent calls', style: NeyvoTextStyles.heading),
            const Spacer(),
            TextButton(
              onPressed: () => PulseShellController.navigatePulse(context, PulseRouteNames.calls),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Inline filters row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Search name or ID',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (value) {
                  setState(() {
                    _callsSearchQuery = value.trim();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                isDense: true,
                decoration: const InputDecoration(
                  hintText: 'Department',
                ),
                value: _callsDepartmentFilter,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Depts')),
                  const DropdownMenuItem(value: 'admissions', child: Text('Admissions')),
                  const DropdownMenuItem(value: 'fin_services', child: Text('Fin. Services')),
                  const DropdownMenuItem(value: 'registrar', child: Text('Registrar')),
                  const DropdownMenuItem(value: 'housing', child: Text('Housing')),
                  const DropdownMenuItem(value: 'it_help_desk', child: Text('IT Help Desk')),
                  const DropdownMenuItem(value: 'front_desk', child: Text('Front Desk')),
                ],
                onChanged: (value) {
                  setState(() {
                    _callsDepartmentFilter = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _callsResultFilter == null || _callsResultFilter!.isEmpty,
              onSelected: (_) {
                setState(() {
                  _callsResultFilter = null;
                });
              },
            ),
            ChoiceChip(
              label: const Text('Answered'),
              selected: _callsResultFilter == 'answered',
              onSelected: (_) {
                setState(() {
                  _callsResultFilter = 'answered';
                });
              },
            ),
            ChoiceChip(
              label: const Text('Voicemail'),
              selected: _callsResultFilter == 'voicemail',
              onSelected: (_) {
                setState(() {
                  _callsResultFilter = 'voicemail';
                });
              },
            ),
            ChoiceChip(
              label: const Text('No Answer'),
              selected: _callsResultFilter == 'no_answer',
              onSelected: (_) {
                setState(() {
                  _callsResultFilter = 'no_answer';
                });
              },
            ),
            ChoiceChip(
              label: const Text('Goal Achieved'),
              selected: _callsResultFilter == 'goal_achieved',
              onSelected: (_) {
                setState(() {
                  _callsResultFilter = 'goal_achieved';
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._filteredRecentCalls().map((c) {
          final name = (c['student_name'] ?? c['contact_name'] ?? c['caller'] ?? '—').toString();
          final studentId = (c['student_id'] ?? c['school_student_id'] ?? '').toString();
          final department = (c['department'] ?? c['operator_department'] ?? '—').toString();
          final durationSeconds = (c['duration_seconds'] as num?)?.toInt() ?? 0;
          final timestampRaw = c['started_at'] ?? c['ended_at'];
          final dateTime = timestampRaw is String ? DateTime.tryParse(timestampRaw) : null;
          final durationLabel = _formatDuration(durationSeconds);
          final timestampLabel = dateTime == null ? '—' : _formatTimestamp(dateTime);
          final resultInfo = _mapCallResult(c);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: NeyvoColors.bgRaised.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NeyvoColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: NeyvoTextStyles.bodyPrimary),
                        if (studentId.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'ID: $studentId',
                            style: NeyvoTextStyles.micro,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      department,
                      style: NeyvoTextStyles.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: resultInfo.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: resultInfo.color.withOpacity(0.6)),
                        ),
                        child: Text(
                          resultInfo.label,
                          style: NeyvoTextStyles.micro.copyWith(
                            color: resultInfo.color,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      durationLabel,
                      style: NeyvoTextStyles.micro,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      timestampLabel,
                      style: NeyvoTextStyles.micro,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _statusRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18, color: ok ? NeyvoColors.success : NeyvoColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: NeyvoTextStyles.bodyPrimary),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 220,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: NeyvoColors.textPrimary,
          side: const BorderSide(color: NeyvoColors.borderDefault),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  void _showCallMyAi() {
    final number = (_trainingNumber ?? '').trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No training number yet. Connect a number in Numbers Hub.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeyvoColors.bgBase,
        title: const Text('Call My AI'),
        content: Text(
          'Call this number now:\n\n$number',
          style: NeyvoTextStyles.bodyPrimary,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
            },
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
            child: const Text('Copy number'),
          ),
        ],
      ),
    );
  }

  int _computeUniqueStudentsReached() {
    final phones = <String>{};
    for (final c in _recentCalls) {
      final phone =
          (c['student_phone'] ?? c['to'] ?? c['phone_number'] ?? '').toString().trim();
      if (phone.isNotEmpty) phones.add(phone);
    }
    return phones.length;
  }

  List<Map<String, dynamic>> _filteredRecentCalls() {
    final query = _callsSearchQuery.toLowerCase();
    final resultFilter = _callsResultFilter;
    final deptFilter = _callsDepartmentFilter;

    return _recentCalls.where((c) {
      final name = (c['student_name'] ?? c['contact_name'] ?? c['caller'] ?? '')
          .toString()
          .toLowerCase();
      final studentId = (c['student_id'] ?? c['school_student_id'] ?? '')
          .toString()
          .toLowerCase();
      final department = (c['department'] ?? c['operator_department'] ?? '')
          .toString()
          .toLowerCase();

      if (query.isNotEmpty &&
          !name.contains(query) &&
          !studentId.contains(query)) {
        return false;
      }

      if (deptFilter != null && deptFilter.isNotEmpty) {
        final d = department;
        bool matchesDept = true;
        switch (deptFilter) {
          case 'admissions':
            matchesDept = d.contains('admissions');
            break;
          case 'fin_services':
            matchesDept = d.contains('financial') || d.contains('fin.');
            break;
          case 'registrar':
            matchesDept = d.contains('registrar');
            break;
          case 'housing':
            matchesDept = d.contains('housing') || d.contains('residential');
            break;
          case 'it_help_desk':
            matchesDept = d.contains('it help') || d.contains('help desk');
            break;
          case 'front_desk':
            matchesDept = d.contains('front desk') || d.contains('frontdesk');
            break;
        }
        if (!matchesDept) return false;
      }

      if (resultFilter != null && resultFilter.isNotEmpty) {
        final mapped = _mapCallResult(c).key;
        if (mapped != resultFilter) return false;
      }

      return true;
    }).toList();
  }

  Set<String> _distinctCallDepartments() {
    final set = <String>{};
    for (final c in _recentCalls) {
      final department = (c['department'] ?? c['operator_department'] ?? '')
          .toString()
          .trim();
      if (department.isNotEmpty) {
        set.add(department);
      }
    }
    return set;
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime dt) {
    // Simple, locale-agnostic formatting.
    final month = _monthAbbrev(dt.month);
    final day = dt.day;
    final year = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year · $hour:$minute $suffix';
  }

  _CallResultInfo _mapCallResult(Map<String, dynamic> call) {
    final statusRaw = (call['status'] ?? call['result'] ?? '').toString().toLowerCase();
    final goalAchieved = call['goal_completed'] == true ||
        (call['resolution'] ?? '').toString().toLowerCase() == 'goal_achieved';

    if (goalAchieved) {
      return const _CallResultInfo(
        key: 'goal_achieved',
        label: 'Goal Achieved',
        color: NeyvoColors.success,
      );
    }

    if (statusRaw.contains('resched')) {
      return const _CallResultInfo(
        key: 'rescheduled',
        label: 'Rescheduled',
        color: NeyvoColors.info,
      );
    }

    if (statusRaw.contains('voicemail')) {
      return const _CallResultInfo(
        key: 'voicemail',
        label: 'Voicemail',
        color: NeyvoColors.warning,
      );
    }

    if (statusRaw.contains('no_answer') ||
        statusRaw.contains('no-answer') ||
        statusRaw.contains('no answer') ||
        statusRaw.contains('failed')) {
      return const _CallResultInfo(
        key: 'no_answer',
        label: 'No Answer',
        color: NeyvoColors.error,
      );
    }

    if (statusRaw.contains('completed') ||
        statusRaw.contains('success') ||
        statusRaw.contains('answered')) {
      return const _CallResultInfo(
        key: 'answered',
        label: 'Answered',
        color: NeyvoColors.success,
      );
    }

    return const _CallResultInfo(
      key: 'answered',
      label: 'Answered',
      color: NeyvoColors.info,
    );
  }

  List<Map<String, dynamic>> _filteredCampaigns() {
    final statusFilter = _campaignStatusFilter;
    final semesterFilter = _campaignSemesterFilter;

    return _recentCampaigns.where((c) {
      if (semesterFilter != null &&
          semesterFilter.isNotEmpty &&
          _semesterLabelForCampaign(c) != semesterFilter) {
        return false;
      }
      if (statusFilter != null && statusFilter.isNotEmpty) {
        final statusKey = _campaignStatusInfo(c).key;
        if (statusKey != statusFilter) return false;
      }
      return true;
    }).toList();
  }

  Set<String> _distinctCampaignSemesters() {
    final set = <String>{};
    for (final c in _recentCampaigns) {
      set.add(_semesterLabelForCampaign(c));
    }
    return set;
  }

  String _semesterLabelForCampaign(Map<String, dynamic> c) {
    final raw = (c['scheduled_at'] ?? c['created_at'] ?? c['started_at'])?.toString();
    final dt = raw != null ? DateTime.tryParse(raw) : null;
    if (dt == null) return 'Unknown';
    final year = dt.year;
    final month = dt.month;
    String term;
    if (month >= 1 && month <= 4) {
      term = 'Spring';
    } else if (month >= 5 && month <= 8) {
      term = 'Summer';
    } else {
      term = 'Fall';
    }
    return '$term $year';
  }

  Color _semesterColor(String semester) {
    final lower = semester.toLowerCase();
    if (lower.startsWith('spring')) {
      return NeyvoColors.success;
    }
    if (lower.startsWith('summer')) {
      return NeyvoColors.info;
    }
    if (lower.startsWith('fall')) {
      return NeyvoColors.warning;
    }
    return NeyvoColors.borderSubtle;
  }

  _CampaignStatusInfo _campaignStatusInfo(Map<String, dynamic> c) {
    final raw = (c['status'] ?? '').toString().toLowerCase();
    if (raw.contains('running') || raw.contains('in_progress')) {
      return const _CampaignStatusInfo(
        key: 'running',
        label: 'Running',
        color: NeyvoColors.info,
      );
    }
    if (raw.contains('scheduled') || raw.contains('draft')) {
      return const _CampaignStatusInfo(
        key: 'scheduled',
        label: 'Scheduled',
        color: NeyvoColors.warning,
      );
    }
    if (raw.contains('completed') || raw.contains('complete') || raw.contains('finished')) {
      return const _CampaignStatusInfo(
        key: 'complete',
        label: 'Complete',
        color: NeyvoColors.success,
      );
    }
    return const _CampaignStatusInfo(
      key: 'running',
      label: 'Running',
      color: NeyvoColors.info,
    );
  }
}

class _CallResultInfo {
  const _CallResultInfo({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

class _CampaignStatusInfo {
  const _CampaignStatusInfo({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

double? _computeDeltaPercent(num? current, num? previous) {
  if (current == null || previous == null) return null;
  if (previous == 0) {
    return current > 0 ? 100 : null;
  }
  final delta = (current - previous) / previous * 100;
  if (delta.isNaN || delta.isInfinite) return null;
  return delta;
}

double? _goalCompletionRateValue(Map<String, dynamic>? summary) {
  if (summary == null) return null;
  final direct = (summary['success_rate_pct'] as num?)?.toDouble();
  if (direct != null) return direct;
  final goals = (summary['goals_completed'] as num?)?.toDouble();
  final total = (summary['total_calls'] as num?)?.toDouble();
  if (goals != null && total != null && total > 0) return (goals / total) * 100.0;
  // Fallback: nested success_summary (backend also returns resolution_rate_pct there)
  final nested = summary['success_summary'] as Map<String, dynamic>?;
  if (nested != null) {
    final pct = (nested['resolution_rate_pct'] as num?)?.toDouble();
    if (pct != null) return pct;
  }
  return null;
}

String _goalCompletionRateLabel(Map<String, dynamic>? summary) {
  final v = _goalCompletionRateValue(summary);
  if (v == null) return '—';
  return '${v.toStringAsFixed(1)}%';
}

enum _KpiDeltaDirection { up, down, flat, none }

_KpiDeltaDirection _directionForDelta(double? deltaPercent) {
  if (deltaPercent == null) return _KpiDeltaDirection.none;
  if (deltaPercent > 0.1) return _KpiDeltaDirection.up;
  if (deltaPercent < -0.1) return _KpiDeltaDirection.down;
  return _KpiDeltaDirection.flat;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    this.deltaPercent,
    this.isPercentage = false,
  });

  final String title;
  final String value;
  final double? deltaPercent;
  final bool isPercentage;

  @override
  Widget build(BuildContext context) {
    final dir = _directionForDelta(deltaPercent);
    final hasDelta = dir != _KpiDeltaDirection.none;
    IconData? icon;
    Color color = NeyvoColors.textMuted;

    if (hasDelta) {
      if (dir == _KpiDeltaDirection.up) {
        icon = Icons.arrow_upward_rounded;
        color = NeyvoColors.success;
      } else if (dir == _KpiDeltaDirection.down) {
        icon = Icons.arrow_downward_rounded;
        color = NeyvoColors.error;
      } else {
        icon = Icons.horizontal_rule_rounded;
      }
    }

    String deltaLabel() {
      if (deltaPercent == null) return '— vs prior period';
      final absVal = deltaPercent!.abs();
      final formatted = absVal >= 100 ? absVal.toStringAsFixed(0) : absVal.toStringAsFixed(1);
      final unit = isPercentage ? '%' : '%';
      final sign = deltaPercent! > 0 ? '+' : deltaPercent! < 0 ? '−' : '';
      return '$sign$formatted$unit vs prior';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: NeyvoTextStyles.heading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                deltaLabel(),
                style: NeyvoTextStyles.micro.copyWith(color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
      segments: const [
        ButtonSegment(value: '1d', label: Text('Today')),
        ButtonSegment(value: '7d', label: Text('7d')),
        ButtonSegment(value: '30d', label: Text('30d')),
      ],
      selected: {value},
      onSelectionChanged: (v) {
        if (v.isNotEmpty) onChanged(v.first);
      },
    );
  }
}

class _GlobalDateFilterBar extends StatelessWidget {
  const _GlobalDateFilterBar({
    required this.preset,
    required this.rangeLabel,
    required this.onPresetChanged,
    required this.onCustomTap,
  });

  final String preset;
  final String? rangeLabel;
  final ValueChanged<String> onPresetChanged;
  final VoidCallback onCustomTap;

  @override
  Widget build(BuildContext context) {
    final label = rangeLabel;
    return _SimpleCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _presetChip('Today', 'today'),
                _presetChip('Yesterday', 'yesterday'),
                _presetChip('This week', 'this_week'),
                _presetChip('This month', 'this_month'),
                _presetChip('This year', 'this_year'),
                _presetChip('Custom', 'custom', onTap: onCustomTap),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (label != null)
            Text(
              label,
              style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _presetChip(String text, String value, {VoidCallback? onTap}) {
    final bool selected = preset == value;
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) {
        if (value == 'custom') {
          onCustomTap();
        } else {
          onPresetChanged(value);
        }
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeyvoColors.borderDefault;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
          Text(
            value,
            style: NeyvoTextStyles.micro.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LiveCallProgressCard extends StatelessWidget {
  const _LiveCallProgressCard({
    required this.loading,
    required this.totalCalls,
    required this.runningCalls,
    required this.completedCalls,
    required this.incompleteCalls,
    required this.failedCalls,
    required this.voicemailCalls,
    required this.rescheduledCalls,
  });

  final bool loading;
  final int totalCalls;
  final int runningCalls;
  final int completedCalls;
  final int incompleteCalls;
  final int failedCalls;
  final int voicemailCalls;
  final int rescheduledCalls;

  @override
  Widget build(BuildContext context) {
    final hasCalls = totalCalls > 0;
    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Live calls', style: NeyvoTextStyles.heading),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NeyvoColors.teal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasCalls)
            Text(
              'No calls in this range yet. As calls start, live progress will appear here.',
              style: NeyvoTextStyles.body,
            )
          else ...[
            _statusBarRow('Running', runningCalls, totalCalls, NeyvoColors.info),
            _statusBarRow('Completed', completedCalls, totalCalls, NeyvoColors.success),
            _statusBarRow('Incomplete', incompleteCalls, totalCalls, NeyvoColors.warning),
            _statusBarRow('Failed', failedCalls, totalCalls, NeyvoColors.error),
            _statusBarRow('Voicemail', voicemailCalls, totalCalls, NeyvoColors.warning),
            _statusBarRow('Rescheduled', rescheduledCalls, totalCalls, NeyvoColors.info),
          ],
        ],
      ),
    );
  }

  Widget _statusBarRow(String label, int count, int total, Color color) {
    final fraction = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                ),
              ),
              Text(
                '$count',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: NeyvoColors.bgRaised.withOpacity(0.55),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeyvoColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NextActionCompact extends StatelessWidget {
  const _NextActionCompact({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 100),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: NeyvoColors.textPrimary,
          side: const BorderSide(color: NeyvoColors.borderDefault),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: NeyvoColors.teal),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: NeyvoTextStyles.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: NeyvoGlassPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: NeyvoColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: NeyvoTextStyles.micro,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: NeyvoColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCoverageCard extends StatelessWidget {
  const _VoiceCoverageCard({
    required this.operatorCount,
    required this.totalCoreDepartments,
    this.onCreateOperator,
  });

  final int operatorCount;
  final int totalCoreDepartments;
  /// When set, "Create operator" opens the same wizard as on the Operators page (showDialog CreateAgentWizard).
  final Future<void> Function()? onCreateOperator;

  @override
  Widget build(BuildContext context) {
    final covered = operatorCount.clamp(0, totalCoreDepartments);
    final uncovered = (totalCoreDepartments - covered).clamp(0, totalCoreDepartments);
    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: covered.toDouble(),
        color: NeyvoColors.teal,
        title: '',
        radius: 40,
      ),
      PieChartSectionData(
        value: uncovered.toDouble(),
        color: NeyvoColors.borderSubtle,
        title: '',
        radius: 32,
      ),
    ];

    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Voice coverage by department', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$covered of $totalCoreDepartments core UB departments have at least one operator.',
                      style: NeyvoTextStyles.body,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Admissions, Student Financial Services, Registrar, Housing, IT Help Desk, Front Desk.',
                      style: NeyvoTextStyles.micro,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onCreateOperator != null
                          ? () async {
                              await onCreateOperator!();
                            }
                          : () => Navigator.of(context, rootNavigator: true)
                              .pushNamed(PulseRouteNames.agents),
                      icon: const Icon(Icons.add),
                      label: const Text('Create operator'),
                      style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallsPerformanceCard extends StatelessWidget {
  const _CallsPerformanceCard({required this.perf});

  final Map<String, dynamic>? perf;

  @override
  Widget build(BuildContext context) {
    final seriesDynamic = (perf?['daily_calls'] as List?) ?? const [];
    final series = <FlSpot>[];
    for (var i = 0; i < seriesDynamic.length; i++) {
      final m = Map<String, dynamic>.from(seriesDynamic[i] as Map);
      final total = (m['total'] as num?)?.toDouble() ?? 0;
      series.add(FlSpot(i.toDouble(), total));
    }

    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Calls & performance', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          if (series.isEmpty)
            Text(
              'Call volume charts will appear here once you have more activity.',
              style: NeyvoTextStyles.body,
            )
          else
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: NeyvoColors.borderSubtle, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) =>
                            Text(v.toInt().toString(), style: NeyvoTextStyles.micro),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (v, _) =>
                            Text('D${v.toInt() + 1}', style: NeyvoTextStyles.micro),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: series.isEmpty ? 1 : series.last.x,
                  minY: 0,
                  maxY: series.isEmpty
                      ? 1
                      : (series.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2),
                  lineBarsData: [
                    LineChartBarData(
                      spots: series,
                      isCurved: true,
                      color: NeyvoColors.teal,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            NeyvoColors.tealGlow,
                            NeyvoColors.tealGlow.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentFinancialImpactCard extends StatelessWidget {
  const _StudentFinancialImpactCard({required this.perf});

  final Map<String, dynamic>? perf;

  @override
  Widget build(BuildContext context) {
    final impact = perf?['student_financial_impact'] as Map<String, dynamic>? ?? {};
    final collected = (impact['collected'] as num?)?.toDouble() ?? 0;
    final promised = (impact['promised'] as num?)?.toDouble() ?? 0;
    final atRisk = (impact['at_risk'] as num?)?.toDouble() ?? 0;
    final total = collected + promised + atRisk;

    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Student financial impact', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          if (total <= 0)
            Text(
              'Connect billing and run campaigns to see financial impact here.',
              style: NeyvoTextStyles.body,
            )
          else ...[
            Text(
              '\$${(collected + promised).toStringAsFixed(0)} collected / promised this week',
              style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _impactBar('Collected', collected, total, NeyvoColors.success),
                const SizedBox(width: 8),
                _impactBar('Promised', promised, total, NeyvoColors.info),
                const SizedBox(width: 8),
                _impactBar('At risk', atRisk, total, NeyvoColors.warning),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _impactBar(String label, double value, double total, Color color) {
    final fraction = total <= 0 ? 0.0 : value / total;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: color.withOpacity(0.18),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: NeyvoTextStyles.micro),
        ],
      ),
    );
  }
}

class _UbModelCard extends StatelessWidget {
  const _UbModelCard({required this.ubModel, required this.status});

  final Map<String, dynamic>? ubModel;
  final String status;

  @override
  Widget build(BuildContext context) {
    final model = ubModel ?? {};
    final sourceUrl = (model['source_url'] ?? 'https://www.bridgeport.edu').toString();
    final departmentsCount = (model['departmentsDiscovered'] as num?)?.toInt() ??
        (model['departments_count'] as num?)?.toInt() ??
        0;
    final faqCount =
        (model['faqTopicsCount'] as num?)?.toInt() ?? (model['faq_count'] as num?)?.toInt() ?? 0;

    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('UB model & knowledge', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'building') ...[
            Text(
              'Analyzing bridgeport.edu…',
              style: NeyvoTextStyles.body,
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              value: null,
              color: NeyvoColors.teal,
              backgroundColor: NeyvoColors.bgRaised,
            ),
          ] else if (status != 'ready') ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeyvoColors.warning.withOpacity(0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: NeyvoColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'UB model is not ready yet. Initialize from bridgeport.edu to unlock department-aware operators.',
                      style: NeyvoTextStyles.micro,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true)
                        .pushNamed(PulseRouteNames.ubModelOverview),
                    child: const Text('Open UB onboarding'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Source: $sourceUrl',
              style: NeyvoTextStyles.body,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badgeChip('$departmentsCount departments learned'),
                _badgeChip('$faqCount FAQ topics'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Admissions, Student Financial Services, Registrar, Housing, IT Help Desk and more are included in the model.',
              style: NeyvoTextStyles.micro,
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true)
                  .pushNamed(PulseRouteNames.ubModelOverview),
              child: const Text('View model'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Text(text, style: NeyvoTextStyles.micro),
    );
  }
}
