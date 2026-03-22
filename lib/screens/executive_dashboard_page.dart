// Executive Dashboard – rebuild per spec: tabs, date filter, KPIs from listCalls,
// Live Call Activity, Call Resolution, CSAT, Recent Call Logs, Quick Actions.
// Data from NeyvoPulseApi; 60s auto-refresh (45s min gap). Call Resolution donut is custom-painted.

import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/neyvo_api.dart';
import '../core/providers/executive_launch_sections_provider.dart';
import '../pulse_route_names.dart';
import '../services/user_timezone_service.dart';
import '../theme/neyvo_theme.dart';
import 'pulse_shell.dart';

enum _DateRange { today, yesterday, thisWeek, thisMonth, thisYear, custom }

class ExecutiveDashboardPage extends ConsumerStatefulWidget {
  const ExecutiveDashboardPage({super.key});

  @override
  ConsumerState<ExecutiveDashboardPage> createState() => _ExecutiveDashboardPageState();
}

class _ExecutiveDashboardPageState extends ConsumerState<ExecutiveDashboardPage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;
  final _DateRange _dateRange = _DateRange.thisWeek;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _loading = true;
  bool _refreshing = false;
  /// First load failed before any successful payload; full-screen retry only in that case.
  String? _initialLoadError;
  /// Non-fatal: background refresh or retry failed but cached dashboard data is shown.
  String? _criticalBanner;
  String? _deferredError;
  int _loadVersion = 0;
  bool _hasSuccessfulCriticalLoad = false;

  List<Map<String, dynamic>> _calls = [];
  List<Map<String, dynamic>> _recentCalls = [];

  String? _runningCampaignId;
  List<Map<String, dynamic>> _campaignItems = [];
  Map<String, dynamic>? _campaignMetrics;

  Map<String, dynamic>? _successSummary;

  Timer? _refreshTimer;
  late AnimationController _pulseController;
  /// Skips overlapping periodic refreshes (timer is 60s; min gap 45s).
  DateTime? _lastRefreshAt;
  int _consecutiveRefreshFailures = 0;
  static const int _baseRefreshSeconds = 60;
  static const int _maxRefreshSeconds = 300;

  void _schedulePeriodicRefresh({required int seconds}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: seconds), (_) => _refresh());
  }

  void _onRefreshSuccess() {
    if (_consecutiveRefreshFailures > 0) {
      _consecutiveRefreshFailures = 0;
      _schedulePeriodicRefresh(seconds: _baseRefreshSeconds);
    }
  }

  void _onRefreshFailure() {
    _consecutiveRefreshFailures++;
    if (_consecutiveRefreshFailures >= 3) {
      final newSeconds = (_baseRefreshSeconds * _consecutiveRefreshFailures)
          .clamp(_baseRefreshSeconds, _maxRefreshSeconds);
      _schedulePeriodicRefresh(seconds: newSeconds);
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _load();
    _schedulePeriodicRefresh(seconds: _baseRefreshSeconds);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String get _fromIso {
    final now = UserTimezoneService.userLocalNow();
    switch (_dateRange) {
      case _DateRange.today:
        return _dayStartEnd(now).start;
      case _DateRange.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return _dayStartEnd(y).start;
      case _DateRange.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return _dayStartEnd(monday).start;
      case _DateRange.thisMonth:
        return _dayStartEnd(DateTime(now.year, now.month, 1)).start;
      case _DateRange.thisYear:
        return _dayStartEnd(DateTime(now.year, 1, 1)).start;
      case _DateRange.custom:
        if (_customFrom != null) return _toIsoDate(_customFrom!);
        return _dayStartEnd(now).start;
    }
  }

  String get _toIso {
    final now = DateTime.now();
    switch (_dateRange) {
      case _DateRange.today:
        return _dayStartEnd(now).end;
      case _DateRange.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return _dayStartEnd(y).end;
      case _DateRange.thisWeek:
      case _DateRange.thisMonth:
      case _DateRange.thisYear:
        return _dayStartEnd(now).end;
      case _DateRange.custom:
        if (_customTo != null) return _toIsoDateEndOfDay(_customTo!);
        return _dayStartEnd(now).end;
    }
  }

  ({String start, String end}) _dayStartEnd(DateTime d) {
    final start = DateTime(d.year, d.month, d.day, 0, 0, 0);
    final end = DateTime(d.year, d.month, d.day, 23, 59, 59);
    return (start: start.toIso8601String(), end: end.toIso8601String());
  }

  String _toIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';
  String _toIsoDateEndOfDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T23:59:59';

  ({String from, String to}) _priorRange() {
    final now = UserTimezoneService.userLocalNow();
    switch (_dateRange) {
      case _DateRange.today:
        final y = now.subtract(const Duration(days: 1));
        final p = _dayStartEnd(y);
        return (from: p.start, to: p.end);
      case _DateRange.yesterday:
        final y = now.subtract(const Duration(days: 2));
        final p = _dayStartEnd(y);
        return (from: p.start, to: p.end);
      case _DateRange.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final prevMonday = monday.subtract(const Duration(days: 7));
        return (from: _dayStartEnd(prevMonday).start, to: _dayStartEnd(prevMonday.add(const Duration(days: 6))).end);
      case _DateRange.thisMonth:
        final prev = DateTime(now.year, now.month - 1, 1);
        final lastPrev = DateTime(now.year, now.month, 0);
        return (from: _dayStartEnd(prev).start, to: _dayStartEnd(lastPrev).end);
      case _DateRange.thisYear:
        return (from: _dayStartEnd(DateTime(now.year - 1, 1, 1)).start, to: _dayStartEnd(DateTime(now.year - 1, 12, 31)).end);
      case _DateRange.custom:
        return (from: _fromIso, to: _toIso);
    }
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _initialLoadError = null;
      _criticalBanner = null;
      _deferredError = null;
    });
    await _fetchCritical(version: version);
    if (mounted) setState(() => _loading = false);
    unawaited(_fetchDeferred(version: version));
  }

  Future<void> _refresh() async {
    if (_loading || _selectedTabIndex != 0) return;
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastRefreshAt != null && now.difference(_lastRefreshAt!) < const Duration(seconds: 45)) {
      return;
    }
    _lastRefreshAt = now;
    setState(() => _refreshing = true);
    ref.invalidate(executiveCriticalProvider(_rangeModel()));
    ref.invalidate(executiveDeferredProvider(_rangeModel()));
    await _fetchCritical(version: _loadVersion);
    unawaited(_fetchDeferred(version: _loadVersion));
    if (mounted) setState(() => _refreshing = false);
  }

  ExecutiveRange _rangeModel() {
    final prior = _priorRange();
    return ExecutiveRange(
      from: _fromIso,
      to: _toIso,
      priorFrom: prior.from,
      priorTo: prior.to,
    );
  }

  Future<void> _fetchCritical({required int version}) async {
    try {
      final critical = await ref.read(executiveCriticalProvider(_rangeModel()).future).timeout(
            NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy),
          );
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _initialLoadError = null;
        _criticalBanner = null;
        _hasSuccessfulCriticalLoad = true;
        _calls = critical.calls;
        _recentCalls = critical.recentCalls;
        _successSummary = critical.successSummary;
      });
      _onRefreshSuccess();
    } on TimeoutException {
      _applyCriticalFailure(
        version,
        'Dashboard request timed out. Pull to refresh or check your connection.',
      );
    } catch (e) {
      _applyCriticalFailure(version, e.toString());
    }
  }

  void _applyCriticalFailure(int version, String message) {
    if (!mounted || version != _loadVersion) return;
    final hasCache = _hasSuccessfulCriticalLoad ||
        _calls.isNotEmpty ||
        _recentCalls.isNotEmpty ||
        _successSummary != null;
    if (hasCache) {
      _onRefreshFailure();
    }
    setState(() {
      if (hasCache) {
        _criticalBanner = message;
        _initialLoadError = null;
      } else {
        _initialLoadError = message;
        _criticalBanner = null;
      }
    });
  }

  Future<void> _fetchDeferred({required int version}) async {
    try {
      final deferred = await ref.read(executiveDeferredProvider(_rangeModel()).future);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _runningCampaignId = deferred.runningCampaignId;
        _campaignItems = deferred.campaignItems;
        _campaignMetrics = deferred.campaignMetrics;
        _deferredError = null;
      });
    } catch (e) {
      if (!mounted || version != _loadVersion) return;
      setState(() => _deferredError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeyvoColors.bgBase,
      body: _selectedTabIndex == 0
          ? CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTabs(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: _buildMainContent(),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabs(),
                  const SizedBox(height: 12),
                  _buildComingSoon(),
                ],
              ),
            ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['Executive Dashboard', 'Department Performance', 'Weekly Performance'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _selectedTabIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? NeyvoColors.ubLightBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tabs[i],
                    style: NeyvoTextStyles.body.copyWith(
                      color: active ? Colors.white : NeyvoTheme.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Fixed height for all three KPI cards (Live Call Activity, Call Resolution, CSAT)
  /// so they stay aligned and same size; content scrolls inside if needed.
  static const double _kTopPanelHeight = 340;

  Widget _buildTopPanel({
    required Widget child,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return SizedBox(
      height: _kTopPanelHeight,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: NeyvoTheme.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_loading && !_hasSuccessfulCriticalLoad) {
      return _buildExecutiveFirstLoadSkeleton();
    }
    if (_initialLoadError != null && !_hasSuccessfulCriticalLoad) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_initialLoadError!, style: TextStyle(color: NeyvoTheme.error)),
              const SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_criticalBanner != null) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: NeyvoTheme.borderSubtle),
            ),
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: NeyvoColors.warning),
              title: Text(
                _criticalBanner!,
                style: NeyvoTextStyles.body.copyWith(color: NeyvoTheme.textPrimary),
              ),
              trailing: TextButton(onPressed: _load, child: const Text('Retry')),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildExecutiveContent(),
      ],
    );
  }

  Widget _buildComingSoon() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Text('Coming soon', style: NeyvoTextStyles.heading.copyWith(color: NeyvoTheme.textMuted)),
          ),
        ),
      ),
    );
  }

  /// Layout-matched placeholders for first critical load (replaces a lone spinner).
  Widget _buildExecutiveFirstLoadSkeleton() {
    Widget skeletonPanel() {
      return SizedBox(
        height: _kTopPanelHeight,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: NeyvoTheme.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 160,
                  height: 16,
                  decoration: BoxDecoration(
                    color: NeyvoTheme.textMuted.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: NeyvoTheme.textMuted.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: NeyvoTheme.textMuted.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
        final grid = narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  skeletonPanel(),
                  const SizedBox(height: 16),
                  skeletonPanel(),
                  const SizedBox(height: 16),
                  skeletonPanel(),
                  const SizedBox(height: 16),
                  skeletonPanel(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: skeletonPanel()),
                      const SizedBox(width: 16),
                      Expanded(child: skeletonPanel()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: skeletonPanel()),
                      const SizedBox(width: 16),
                      Expanded(child: skeletonPanel()),
                    ],
                  ),
                ],
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabs(),
            const SizedBox(height: 12),
            grid,
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: NeyvoTheme.borderSubtle),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 14,
                        decoration: BoxDecoration(
                          color: NeyvoTheme.textMuted.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        4,
                        (i) => Padding(
                          padding: EdgeInsets.only(bottom: i < 3 ? 8 : 0),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: NeyvoTheme.textMuted.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExecutiveContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_deferredError != null) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: NeyvoTheme.borderSubtle),
            ),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: NeyvoColors.warning),
              title: const Text('Some advanced metrics are delayed. Core dashboard remains available.'),
              trailing: TextButton(onPressed: () => _fetchDeferred(version: _loadVersion), child: const Text('Retry')),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Two rows, two columns: [Quick Actions | Live Call Activity], [Call Resolution | CSAT]
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 800;
            if (narrow) {
              return Column(
                children: [
                  _buildQuickActionsPanel(),
                  const SizedBox(height: 16),
                  _buildLiveCallActivityPanel(),
                  const SizedBox(height: 16),
                  _buildCallResolutionPanel(),
                  const SizedBox(height: 16),
                  _buildCsatPanel(),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildQuickActionsPanel()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildLiveCallActivityPanel()),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCallResolutionPanel()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCsatPanel()),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            if (narrow) {
              return Column(
                children: [
                  _buildRecentCallLogsPanel(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRecentCallLogsPanel()),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _formatDuration(dynamic call) {
    final sec = call['duration_seconds'] ?? call['duration_sec'];
    if (sec != null) {
      final s = sec is int ? sec : int.tryParse(sec.toString()) ?? 0;
      if (s < 60) return '${s}s';
      final m = s ~/ 60;
      final r = s % 60;
      return r > 0 ? '${m}m ${r}s' : '${m}m';
    }
    final d = call['duration']?.toString();
    return d?.isNotEmpty == true ? d! : '—';
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  Widget _buildLiveCallActivityPanel() {
    final total = _campaignMetrics?['total_planned'] != null
        ? (_campaignMetrics!['total_planned'] is int ? _campaignMetrics!['total_planned'] as int : int.tryParse(_campaignMetrics!['total_planned'].toString()) ?? _campaignItems.length)
        : _campaignItems.isEmpty ? 0 : _campaignItems.length;
    final queue = _campaignItems.where((e) => ((e['status'] as String?) ?? '').toLowerCase() == 'queued').length;
    final ongoing = _campaignItems.where((e) {
      final s = ((e['status'] as String?) ?? '').toLowerCase();
      return s == 'in_progress' || s == 'dialing';
    }).length;
    final unanswered = _campaignItems.where((e) {
      final o = ((e['outcome'] as String?) ?? '').toLowerCase();
      return o == 'no_answer' || o == 'voicemail';
    }).length;
    final scheduled = _campaignItems.where((e) {
      final s = ((e['status'] as String?) ?? '').toLowerCase();
      return s == 'scheduled' || s.contains('callback');
    }).length;
    final failed = _campaignItems.where((e) {
      final s = ((e['status'] as String?) ?? '').toLowerCase();
      final o = ((e['outcome'] as String?) ?? '').toLowerCase();
      return s == 'failed' || o == 'failed';
    }).length;

    final totalForBars = total > 0 ? total : 1;
    final completion = total > 0 ? ((total - queue - ongoing) / total * 100) : 0.0;
    String estimatedRemaining = '—';
    if (_campaignMetrics != null && total > 0 && (queue + ongoing) > 0) {
      final throughput = (_campaignMetrics!['throughput_per_minute'] as num?)?.toDouble();
      if (throughput != null && throughput > 0) {
        final remaining = (queue + ongoing).toDouble() / throughput;
        estimatedRemaining = '~${remaining.round()} min';
      }
    }

    final hasRunningCampaign = _runningCampaignId != null || _campaignItems.isNotEmpty;
    final semanticColors = [
      Colors.indigo,
      Colors.amber,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.grey.shade700,
    ];
    const rainbowColors = [
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFDD835),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
    ];
    final rowColors = hasRunningCampaign ? semanticColors : rainbowColors;

    final rows = [
      ('Total Contacts', total, rowColors[0]),
      ('In Queue', queue, rowColors[1]),
      ('On-going / Talking', ongoing, rowColors[2]),
      ('Unanswered / VM', unanswered, rowColors[3]),
      ('Scheduled / Callback', scheduled, rowColors[4]),
      ('Failed', failed, rowColors[5]),
    ];

    final completionStr = total > 0 ? '${completion.toStringAsFixed(0)}%' : '0%';
    final estRemainingParts = estimatedRemaining.startsWith('~')
        ? (estimatedRemaining.split(' ')..removeWhere((s) => s.isEmpty))
        : <String>[];
    final estRemainingValue = estRemainingParts.isNotEmpty ? estRemainingParts[0] : estimatedRemaining;
    final estRemainingUnit = estRemainingParts.length > 1 ? estRemainingParts[1] : '';

    return _buildTopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Live Call Activity', style: NeyvoTextStyles.heading),
                    const SizedBox(height: 4),
                    Text('Current campaign progress', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
                  ],
                ),
                if (_refreshing)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: Colors.green.shade700, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('Updating', style: NeyvoTextStyles.micro.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: NeyvoTheme.borderSubtle),
          const SizedBox(height: 12),
          if (!hasRunningCampaign)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('No campaign is currently running.', style: NeyvoTextStyles.label.copyWith(color: NeyvoTheme.textMuted)),
            ),
          ...rows.map((r) => _LiveBarRow(label: r.$1, count: r.$2, pct: totalForBars > 0 ? (r.$2 / totalForBars) : 0, color: r.$3)),
          const SizedBox(height: 12),
          Divider(height: 1, color: NeyvoTheme.borderSubtle),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Completion:', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(completionStr, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.ubPurple, fontWeight: FontWeight.w700)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Est. remaining:', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(estRemainingValue, style: NeyvoTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                  if (estRemainingUnit.isNotEmpty)
                    Text(estRemainingUnit, style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
                ],
              ),
            ],
          ),
        ],
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }

  Widget _buildCallResolutionPanel() {
    final total = _calls.length;
    final succeeded = _calls.where((c) {
      final o = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '';
      return o == 'answered' || o == 'completed' || o == 'goal_achieved' || o == 'success';
    }).length;
    int resolved;
    final summary = _successSummary?['success_summary'] as Map<String, dynamic>?;
    if (summary != null && summary['calls_with_payment_received'] != null) {
      final v = summary['calls_with_payment_received'];
      resolved = (v is int ? v : int.tryParse(v.toString()) ?? 0).clamp(0, total);
    } else {
      resolved = _calls.where((c) {
        final o = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '';
        return o == 'goal_achieved' || (c['success_metric'] ?? '').toString().toLowerCase() == 'payment_received';
      }).length;
    }

    // Fallback: if we have succeeded calls but no explicit "resolved" signal,
    // treat all succeeded calls as resolved so the resolution rate matches success rate.
    if (resolved == 0 && succeeded > 0) {
      resolved = succeeded;
    }

    final unresolved = total - succeeded;
    final resolutionPct = total > 0 ? (resolved / total * 100) : 0.0;
    final succeededNotResolved = succeeded - resolved;

    return _buildTopPanel(
      child: Column(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Call Resolution', style: NeyvoTextStyles.heading),
                const SizedBox(height: 4),
                Text('Success rate by outcome', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ResolutionBar(label: 'Calls Received', value: total, total: total, color: Colors.orange),
          _ResolutionBar(label: 'Calls Succeeded', value: succeeded, total: total, color: Colors.purple),
          _ResolutionBar(label: 'Resolution Count', value: resolved, total: total, color: Colors.blue),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResolutionDonutChart(
                resolutionPct: resolutionPct,
                succeededNotResolvedPct: total > 0 ? (succeededNotResolved / total * 100) : 0.0,
                unresolvedPct: total > 0 ? ((total - succeeded) / total * 100).clamp(0.0, 100.0) : 100.0,
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendRow('Received', total, Colors.orange),
                      _LegendRow('Succeeded', succeeded, Colors.purple),
                      _LegendRow('Resolved', resolved, Colors.blue),
                      _LegendRow('Unresolved', unresolved, Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  Widget _buildCsatPanel() {
    return _buildTopPanel(
      child: Column(
        children: [
          Text('Customer Satisfaction Score', style: NeyvoTextStyles.heading),
          const SizedBox(height: 4),
          Text('CSAT · Based on post-call surveys', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            height: 90,
            child: CustomPaint(
              painter: _HalfDoughnutPainter(
                value: null,
                noDataColors: [
                  Colors.green,
                  Colors.green.shade700,
                  Colors.yellow.shade700,
                  Colors.red,
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('—', style: NeyvoTextStyles.title.copyWith(fontSize: 20)),
                    Text('awaiting data', style: NeyvoTextStyles.micro),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _CsatLegendItem('Satisfied (5★)', Colors.green),
              _CsatLegendItem('Good (4★)', Colors.green.shade700),
              _CsatLegendItem('Neutral (3★)', Colors.yellow.shade700),
              _CsatLegendItem('Poor (1-2★)', Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Text('Connect post-call survey to populate CSAT', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
        ],
      ),
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  Widget _buildRecentCallLogsPanel() {
    final sorted = List<Map<String, dynamic>>.from(_recentCalls)
      ..sort((a, b) {
        final da = _parseDate(a['created_at'] ?? a['date']);
        final db = _parseDate(b['created_at'] ?? b['date']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    final list = sorted.take(5).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Call Logs', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Text('No recent calls', style: NeyvoTextStyles.label.copyWith(color: NeyvoTheme.textMuted))
            else
              Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(0.8), 3: FlexColumnWidth(0.8), 4: FlexColumnWidth(0.6), 5: FlexColumnWidth(0.8)},
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: NeyvoColors.bgOverlay),
                    children: [
                      _tableHeader('Student'),
                      _tableHeader('Campaign'),
                      _tableHeader('Direction'),
                      _tableHeader('Outcome'),
                      _tableHeader('Duration'),
                      _tableHeader('Time'),
                    ],
                  ),
                  ...list.map((c) {
                    final name = (c['student_name'] ?? c['customer_name'] ?? '—').toString();
                    final phone = (c['student_phone'] ?? c['customer_phone'] ?? '').toString();
                    final campaign = (c['campaign_name'] ?? '—').toString();
                    final direction = ((c['direction'] ?? 'outbound') as String).toLowerCase();
                    final outcome = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '—';
                    final duration = _formatDuration(c);
                    final created = _parseDate(c['created_at'] ?? c['date']);
                    final timeStr = created != null ? DateFormat('MMM d, HH:mm').format(created) : '—';
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('$name\n$phone', style: NeyvoTextStyles.micro, maxLines: 2, overflow: TextOverflow.ellipsis)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text(campaign, style: NeyvoTextStyles.micro, overflow: TextOverflow.ellipsis)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: _OutcomePill(label: direction, outcome: direction)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: _OutcomePill(label: outcome, outcome: outcome)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text(duration, style: NeyvoTextStyles.micro)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text(timeStr, style: NeyvoTextStyles.micro)),
                      ],
                    );
                  }),
                ],
              ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.calls),
              child: Text('View all →', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.ubLightBlue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text(t, style: NeyvoTextStyles.label));

  Widget _buildQuickActionsPanel() {
    return SizedBox(
      height: _kTopPanelHeight,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text('Quick Actions', style: NeyvoTextStyles.heading),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 2.6,
                  children: [
                _QuickActionButton(icon: Icons.person_add_outlined, label: 'Add Operator', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.agents)),
                _QuickActionButton(icon: Icons.campaign_outlined, label: 'Campaigns', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.campaigns)),
                _QuickActionButton(icon: Icons.psychology_outlined, label: 'Goodwin Model', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.ubModelOverview)),
                _QuickActionButton(icon: Icons.analytics_outlined, label: 'Analytics', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.analytics)),
                _QuickActionButton(icon: Icons.call_outlined, label: 'Start Outbound', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.calls)),
                _QuickActionButton(icon: Icons.add_card_outlined, label: 'Add Credits', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.wallet)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomDateRangeDialog extends StatefulWidget {
  final DateTime initialFrom;
  final DateTime initialTo;

  const _CustomDateRangeDialog({required this.initialFrom, required this.initialTo});

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom date range'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('From'),
            subtitle: Text(DateFormat.yMMMd().format(_from)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _from,
                firstDate: DateTime(2020),
                lastDate: UserTimezoneService.userLocalNow(),
              );
              if (d != null) setState(() => _from = d);
            },
          ),
          ListTile(
            title: const Text('To'),
            subtitle: Text(DateFormat.yMMMd().format(_to)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _to,
                firstDate: DateTime(2020),
                lastDate: UserTimezoneService.userLocalNow(),
              );
              if (d != null) setState(() => _to = d);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (from: _from, to: _to)),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _LiveBarRow extends StatelessWidget {
  final String label;
  final int count;
  final double pct;
  final Color color;

  const _LiveBarRow({required this.label, required this.count, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    final fill = pct.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: NeyvoTextStyles.micro.copyWith(color: color))),
          Expanded(
            child: SizedBox(
              height: 20,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        if (fill > 0)
                          Container(
                            width: (w * fill).clamp(0.0, w),
                            height: 20,
                            color: color,
                          ),
                        Expanded(
                          child: Container(
                            height: 20,
                            color: Colors.grey.shade200,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text('$count', style: NeyvoTextStyles.micro, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// Donut chart for Call Resolution: blue (resolved), purple (succeeded not resolved), grey (rest).
/// Matches reference: large ring, hollow center, big bold % and smaller "resolved" label.
class _ResolutionDonutChart extends StatelessWidget {
  final double resolutionPct;
  final double succeededNotResolvedPct;
  final double unresolvedPct;

  const _ResolutionDonutChart({
    required this.resolutionPct,
    required this.succeededNotResolvedPct,
    required this.unresolvedPct,
  });

  static const double _size = 140.0;
  static const double _strokeWidth = 18.0;
  static const Color _blue = Color(0xFF418AF8);
  static const Color _purple = Color(0xFF8A4ECB);
  static const Color _grey = Color(0xFFE8EAEF);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_size, _size),
            painter: _ResolutionDonutPainter(
              resolutionPct: resolutionPct,
              succeededNotResolvedPct: succeededNotResolvedPct,
              unresolvedPct: unresolvedPct,
              strokeWidth: _strokeWidth,
              blue: _blue,
              purple: _purple,
              grey: _grey,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${resolutionPct.toStringAsFixed(0)}%',
                style: NeyvoTextStyles.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: NeyvoTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'resolved',
                style: NeyvoTextStyles.micro.copyWith(
                  color: NeyvoTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolutionDonutPainter extends CustomPainter {
  final double resolutionPct;
  final double succeededNotResolvedPct;
  final double unresolvedPct;
  final double strokeWidth;
  final Color blue;
  final Color purple;
  final Color grey;

  _ResolutionDonutPainter({
    required this.resolutionPct,
    required this.succeededNotResolvedPct,
    required this.unresolvedPct,
    required this.strokeWidth,
    required this.blue,
    required this.purple,
    required this.grey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startFromTop = -pi / 2;

    double sweepBlue = (resolutionPct / 100 * 2 * pi).clamp(0.0, 2 * pi);
    double sweepPurple = (succeededNotResolvedPct / 100 * 2 * pi).clamp(0.0, 2 * pi);
    double remaining = 2 * pi - sweepBlue - sweepPurple;
    if (remaining < 0) remaining = 0;
    double sweepGrey = remaining;

    void drawSegment(double start, double sweep, Color color) {
      if (sweep <= 0) return;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    double cursor = startFromTop;
    drawSegment(cursor, sweepBlue, blue);
    cursor += sweepBlue;
    drawSegment(cursor, sweepPurple, purple);
    cursor += sweepPurple;
    drawSegment(cursor, sweepGrey, grey);
  }

  @override
  bool shouldRepaint(covariant _ResolutionDonutPainter oldDelegate) {
    return oldDelegate.resolutionPct != resolutionPct
        || oldDelegate.succeededNotResolvedPct != succeededNotResolvedPct
        || oldDelegate.unresolvedPct != unresolvedPct;
  }
}

class _ResolutionBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ResolutionBar({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: NeyvoTextStyles.micro.copyWith(color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 20,
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            NumberFormat('#,###').format(value),
            style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _LegendRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              text: TextSpan(
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textPrimary),
                children: [
                  TextSpan(text: '$label: '),
                  TextSpan(text: '$value', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HalfDoughnutPainter extends CustomPainter {
  final double? value;
  final List<Color>? noDataColors;

  _HalfDoughnutPainter({this.value, this.noDataColors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 12.0;

    if (value == null && noDataColors != null && noDataColors!.length >= 4) {
      final segmentSweep = pi / noDataColors!.length;
      for (var i = 0; i < noDataColors!.length; i++) {
        final paint = Paint()
          ..color = noDataColors![i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, pi + i * segmentSweep, segmentSweep, false, paint);
      }
    } else {
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, pi, pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CsatLegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _CsatLegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: NeyvoTextStyles.micro),
      ],
    );
  }
}

class _OutcomePill extends StatelessWidget {
  final String label;
  final String outcome;

  const _OutcomePill({required this.label, required this.outcome});

  Color get _color {
    final o = outcome.toLowerCase();
    if (o == 'goal_achieved' || o == 'completed' || o == 'success') return Colors.green;
    if (o == 'dropped' || o == 'no_answer') return Colors.red;
    if (o == 'voicemail') return Colors.amber;
    if (o == 'in_progress' || o == 'dialing') return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: NeyvoTextStyles.micro.copyWith(color: _color)),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: NeyvoTextStyles.micro, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
