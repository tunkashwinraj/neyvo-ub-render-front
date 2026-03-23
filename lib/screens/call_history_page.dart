// lib/screens/call_history_page.dart
// Call logs — history with filters, date range, transcripts, export, recording link.
//
// Firestore lean contract (businesses/{accountId}/calls): expect
// vapi_call_id, from, to, status, duration_seconds, created_at, ended_at,
// recording_url, summary, transcript, student_id, campaign_id, agent_id, direction.
// Extra Vapi fields may be absent when FF_SINGLE_CALLS_PATH is on server.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/call_history_provider.dart';
import '../core/providers/call_history_selection_provider.dart';
import '../services/user_timezone_service.dart';
import '../utils/export_csv.dart';
import '../theme/neyvo_theme.dart';
import 'call_detail_page.dart';

/// Pulse shell breakpoint: list + detail side-by-side; sidebar stays visible.
const double _kCallHistorySplitBreakpoint = 900;

bool _sameCallRow(Map<String, dynamic>? a, Map<String, dynamic> b) {
  if (a == null) return false;
  final ia = (a['id'] ?? a['call_id'] ?? a['vapi_call_id'] ?? '').toString().trim();
  final ib = (b['id'] ?? b['call_id'] ?? b['vapi_call_id'] ?? '').toString().trim();
  if (ia.isNotEmpty && ib.isNotEmpty) return ia == ib;
  return identical(a, b);
}

class CallHistoryPage extends ConsumerStatefulWidget {
  const CallHistoryPage({
    super.key,
    this.initialDirection = 'outbound', // all | inbound | outbound
  });

  final String initialDirection;

  @override
  ConsumerState<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends ConsumerState<CallHistoryPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(callHistoryNotifierProvider.notifier).setSearchQuery(_searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final n = ref.read(callHistoryNotifierProvider.notifier);
      n.seedInitialDirection(widget.initialDirection);
      await n.reload();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Duration in seconds (int) or duration string from backend
  static String formatDuration(dynamic call) {
    final sec = call['duration_seconds'] ?? call['duration_sec'];
    if (sec != null) {
      final s = sec is int ? sec : int.tryParse(sec.toString()) ?? 0;
      if (s < 60) return '${s}s';
      final m = s ~/ 60;
      final r = s % 60;
      return r > 0 ? '${m}m ${r}s' : '${m}m';
    }
    final d = call['duration']?.toString();
    return d?.isNotEmpty == true ? d! : '?';
  }

  Future<void> _exportCsv(CallHistoryState s) async {
    final sb = StringBuffer();
    sb.writeln('Contact Name,Phone,Date,Status,Duration,Recording URL,Transcript');
    for (final c in s.filteredCalls) {
      final map = c;
      final name = (map['student_name']?.toString() ?? '').replaceAll(',', ';');
      final phone = map['student_phone']?.toString() ?? '';
      final date = (map['created_at_display'] ?? map['created_at'] ?? map['date'] ?? '').toString();
      final status = map['status']?.toString() ?? '';
      final duration = formatDuration(map);
      final recording = map['recording_url']?.toString() ?? '';
      final transcript = (map['transcript']?.toString() ?? '').replaceAll(RegExp(r'[\r\n]'), ' ');
      sb.writeln('"$name","$phone","$date","$status","$duration","$recording","$transcript"');
    }
    final filename = 'call_history_${DateTime.now().toIso8601String().split('T').first}.csv';
    await downloadCsv(filename, sb.toString(), context);
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'resolved':
        return NeyvoTheme.success;
      case 'failed':
      case 'error':
      case 'unresolved':
        return NeyvoTheme.error;
      case 'pending':
      case 'ringing':
        return NeyvoTheme.warning;
      case 'transferred':
      case 'no_answer':
        return NeyvoTheme.info;
      default:
        return NeyvoTheme.textMuted;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'success':
        return Icons.check_circle;
      case 'failed':
      case 'error':
        return Icons.error;
      case 'pending':
      case 'ringing':
        return Icons.access_time;
      default:
        return Icons.phone;
    }
  }

  Future<void> _showDeleteCallLogDialog(
    BuildContext context,
    String callId,
    String studentName,
    String date,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete call log?'),
        content: Text(
          'This will permanently remove this call log from history.\n\n'
          '${studentName.isNotEmpty ? studentName : "Call"}${date.isNotEmpty ? " · $date" : ""}',
          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final ok = await ref.read(callHistoryNotifierProvider.notifier).deleteCallLog(callId);
      if (!context.mounted) return;
      if (ok) {
        ref.read(callHistorySelectionProvider.notifier).clearIfMatches(callId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call log deleted'), backgroundColor: NeyvoTheme.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete call log'),
            backgroundColor: NeyvoTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: NeyvoTheme.error),
        );
      }
    }
  }

  Widget _emptyCallDetailPlaceholder() {
    return ColoredBox(
      color: NeyvoTheme.bgPrimary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(NeyvoSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_in_talk_outlined, size: 56, color: NeyvoTheme.textMuted.withValues(alpha: 0.7)),
              const SizedBox(height: NeyvoSpacing.md),
              Text(
                'Select a call',
                style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
              ),
              const SizedBox(height: NeyvoSpacing.sm),
              Text(
                'Choose a row in the list to view transcript, recording, billing, and technical details — without leaving Pulse.',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryListPane({
    required BuildContext context,
    required CallHistoryState s,
    required CallHistoryNotifier n,
    required List<dynamic> filtered,
    required Map<String, dynamic>? selected,
    required void Function(Map<String, dynamic>) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterStrip(context, s, n, filtered),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => n.reload(),
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(NeyvoSpacing.xl),
                        child: Column(
                          children: [
                            Icon(Icons.phone_outlined, size: 64, color: NeyvoTheme.textMuted),
                            const SizedBox(height: NeyvoSpacing.md),
                            Text(
                              s.allCalls.isEmpty
                                  ? 'No calls yet. Assign a phone number to an agent to start receiving calls.'
                                  : 'No calls found',
                              style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NeyvoSpacing.sm,
                      vertical: NeyvoSpacing.sm,
                    ),
                    itemCount: filtered.length + 1 + (s.hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: NeyvoSpacing.sm,
                            vertical: NeyvoSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Calls (${filtered.length})',
                                style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.textPrimary),
                              ),
                              if (filtered.length != s.allCalls.length)
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    n.clearSearch();
                                    n.setFilterStatus('all');
                                    n.setFilterOutcome('all');
                                  },
                                  child: const Text('Clear filters'),
                                ),
                            ],
                          ),
                        );
                      }
                      if (i == filtered.length + 1) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: NeyvoSpacing.md,
                            right: NeyvoSpacing.md,
                            bottom: NeyvoSpacing.lg,
                          ),
                          child: OutlinedButton(
                            onPressed: s.loadingMore ? null : () => n.loadMore(),
                            child: s.loadingMore
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Load more calls'),
                          ),
                        );
                      }
                      final idx = i - 1;
                      final call = filtered[idx] as Map<String, dynamic>;
                      return _buildCallRowCard(
                        context: context,
                        call: call,
                        selected: selected,
                        onSelect: onSelect,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterStrip(
    BuildContext context,
    CallHistoryState s,
    CallHistoryNotifier n,
    List<dynamic> filtered,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.md, vertical: NeyvoSpacing.sm),
      decoration: BoxDecoration(
        color: NeyvoTheme.bgSurface,
        border: Border(bottom: BorderSide(color: NeyvoTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, tv, _) {
                    return TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search in current page (name or phone)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: tv.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  n.clearSearch();
                                },
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: NeyvoSpacing.md),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: filtered.isEmpty ? null : () => _exportCsv(s),
                tooltip: 'Export CSV',
              ),
            ],
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: s.filterDirection,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelText: 'Direction',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'inbound', child: Text('Inbound', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'outbound', child: Text('Outbound', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => n.setFilterDirection(v ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: NeyvoSpacing.sm),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: s.dateRange,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelText: 'Date',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All time', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: '7d', child: Text('Last 7 days', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: '30d', child: Text('Last 30 days', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) async {
                        n.setDateRange(v ?? 'all');
                        await n.reload();
                      },
                    ),
                  ),
                  const SizedBox(width: NeyvoSpacing.sm),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: s.filterStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelText: 'Status',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'failed', child: Text('Failed', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'pending', child: Text('Pending', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => n.setFilterStatus(v ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: NeyvoSpacing.sm),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: s.filterOutcome,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelText: 'Outcome',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'callback', child: Text('Callback', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'booked', child: Text('Booked', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'handoff', child: Text('Handoff', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'missed', child: Text('Missed', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => n.setFilterOutcome(v ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: NeyvoSpacing.sm),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<CallHistorySort>(
                      value: s.sortBy,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelText: 'Sort',
                      ),
                      items: const [
                        DropdownMenuItem(value: CallHistorySort.dateNewest, child: Text('Date (newest)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: CallHistorySort.dateOldest, child: Text('Date (oldest)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: CallHistorySort.durationLongest, child: Text('Duration (longest)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: CallHistorySort.durationShortest, child: Text('Duration (shortest)', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => n.setSortBy(v ?? CallHistorySort.dateNewest),
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

  Widget _buildCallRowCard({
    required BuildContext context,
    required Map<String, dynamic> call,
    required Map<String, dynamic>? selected,
    required void Function(Map<String, dynamic>) onSelect,
  }) {
    final status = call['status']?.toString() ?? 'unknown';
    final studentName = (call['student_name'] ?? call['contact_name'] ?? call['caller'] ?? 'Unknown').toString();
    final studentPhone = (call['student_phone'] ?? call['to'] ?? call['phone_number'] ?? '').toString();
    final agentName = (call['profile_name'] ?? call['agent_name'] ?? call['managed_profile_name'] ?? '').toString();
    final numberCalled = (call['number_called'] ?? call['from'] ?? call['phone_number_id'] ?? '').toString();
    final outcomeLabel = (call['outcome'] ?? call['outcome_type'] ?? call['status'] ?? '').toString();
    final dateDisplay = (call['created_at_display'] ?? '').toString().trim();
    final dateRaw = call['started_at'] ?? call['created_at'] ?? call['timestamp'] ?? call['date'];
    final date = dateDisplay.isNotEmpty
        ? dateDisplay
        : (dateRaw != null ? UserTimezoneService.formatShort(dateRaw) : '');
    final durationStr = formatDuration(call);
    final statusColor = _getStatusColor(status);
    final successMetric = call['success_metric']?.toString();
    final attributedAmount = call['attributed_payment_amount']?.toString();
    final attributedAt = call['attributed_payment_at']?.toString();
    final outcomeType = call['outcome_type']?.toString();
    final creditsUsed = (call['credits_used'] ?? call['credits_charged']) as num?;
    final voiceTier = (call['voice_tier'] as String?)?.toLowerCase() ?? '';
    final creditsStr = creditsUsed != null ? '${creditsUsed is int ? creditsUsed : creditsUsed.toInt()} cr' : null;
    final tooltipStr = creditsStr != null
        ? '$creditsStr · $durationStr${voiceTier.isNotEmpty ? ' · ${voiceTier == 'neutral' ? 'Neutral' : voiceTier == 'natural' ? 'Natural' : voiceTier == 'ultra' ? 'Ultra' : voiceTier}' : ''}'
        : null;
    final routedIntentRaw = (call['routed_intent'] ?? call['primary_intent'] ?? call['analysis']?['primaryIntent']);
    final routedIntent = routedIntentRaw == null ? '' : routedIntentRaw.toString().trim();

    final showNumberCalled = numberCalled.isNotEmpty && numberCalled != studentPhone;
    final callId = (call['id'] ?? call['call_id'] ?? '').toString().trim();
    final canDelete = callId.isNotEmpty;
    final isSelected = _sameCallRow(selected, call);
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
      color: isSelected ? NeyvoTheme.bgHover : NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.sm),
        side: BorderSide(
          color: isSelected ? primary : NeyvoTheme.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => onSelect(Map<String, dynamic>.from(call)),
        onLongPress: canDelete ? () => _showDeleteCallLogDialog(context, callId, studentName, date) : null,
        borderRadius: BorderRadius.circular(NeyvoRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.md, vertical: NeyvoSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Icon(_getStatusIcon(status), color: statusColor, size: 22),
              ),
              const SizedBox(width: NeyvoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            studentName,
                            style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                          ),
                        ),
                        if (successMetric == 'payment_received')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: NeyvoTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Resolution achieved',
                              style: NeyvoType.labelSmall.copyWith(
                                color: NeyvoTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (studentPhone.isNotEmpty)
                      Text('Phone: $studentPhone', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                    if (agentName.isNotEmpty)
                      Text('Operator: $agentName', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                    if (showNumberCalled)
                      Text('Number dialed: $numberCalled', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                    if (outcomeLabel.isNotEmpty && outcomeLabel != 'unknown')
                      Text('Outcome: $outcomeLabel', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                    if (date.isNotEmpty)
                      Text('Date: $date', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                    Wrap(
                      spacing: NeyvoSpacing.sm,
                      runSpacing: NeyvoSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: NeyvoType.labelSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (routedIntent.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: NeyvoTheme.bgSurface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: NeyvoTheme.border),
                            ),
                            child: Text(
                              'Routed: ${routedIntent[0].toUpperCase()}${routedIntent.substring(1)}',
                              style: NeyvoType.bodySmall.copyWith(fontSize: 11, color: NeyvoTheme.textMuted),
                            ),
                          ),
                        if (durationStr != '?')
                          Text('· $durationStr', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                        if (creditsStr != null)
                          Tooltip(
                            message: tooltipStr ?? creditsStr,
                            child: Text('· $creditsStr', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.teal)),
                          ),
                        if (outcomeType != null && outcomeType.isNotEmpty)
                          Text('· ${outcomeType.replaceAll('_', ' ')}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                      ],
                    ),
                    if (attributedAmount != null && attributedAmount.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Payment received: $attributedAmount${attributedAt != null && attributedAt.isNotEmpty ? " ($attributedAt)" : ""}',
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.success, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: NeyvoTheme.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(callHistoryNotifierProvider);
    final n = ref.read(callHistoryNotifierProvider.notifier);
    if (s.loading && s.allCalls.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (s.error != null && s.allCalls.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Call History')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Something went wrong', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                const SizedBox(height: NeyvoSpacing.sm),
                Text(s.error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: NeyvoSpacing.lg),
                FilledButton(onPressed: () => n.reload(), child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = s.filteredCalls;
    final selected = ref.watch(callHistorySelectionProvider);
    final selNotifier = ref.read(callHistorySelectionProvider.notifier);
    final split = MediaQuery.sizeOf(context).width >= _kCallHistorySplitBreakpoint;
    final isDetailMobile = !split && selected != null;

    Future<void> copySelectedId() async {
      if (selected == null) return;
      final id = (selected['id'] ?? selected['call_id'] ?? selected['vapi_call_id'] ?? '').toString().trim();
      if (id.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call ID copied')));
    }

    return Scaffold(
      appBar: AppBar(
        leading: isDetailMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => selNotifier.clear(),
                tooltip: 'Back to list',
              )
            : null,
        automaticallyImplyLeading: !isDetailMobile,
        title: Text(isDetailMobile ? 'Call details' : 'Call history'),
        actions: [
          if (isDetailMobile)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy call ID',
              onPressed: copySelectedId,
            ),
          if (!isDetailMobile)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: s.loading ? null : () => n.reload(),
              tooltip: 'Refresh (load latest ${s.fetchSize} calls)',
            ),
        ],
      ),
      body: split
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 45,
                  child: _buildHistoryListPane(
                    context: context,
                    s: s,
                    n: n,
                    filtered: filtered,
                    selected: selected,
                    onSelect: selNotifier.select,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  flex: 55,
                  child: selected == null
                      ? _emptyCallDetailPlaceholder()
                      : CallDetailPage(
                          key: ValueKey<String>(
                            (selected['id'] ?? selected['call_id'] ?? selected['vapi_call_id'] ?? '').toString(),
                          ),
                          call: selected,
                          embedded: true,
                        ),
                ),
              ],
            )
          : selected != null
              ? CallDetailPage(
                  key: ValueKey<String>(
                    (selected['id'] ?? selected['call_id'] ?? selected['vapi_call_id'] ?? '').toString(),
                  ),
                  call: selected,
                  embedded: true,
                )
              : RefreshIndicator(
                  onRefresh: () => n.reload(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildFilterStrip(context, s, n, filtered),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(NeyvoSpacing.xl),
                            child: Column(
                              children: [
                                Icon(Icons.phone_outlined, size: 64, color: NeyvoTheme.textMuted),
                                const SizedBox(height: NeyvoSpacing.md),
                                Text(
                                  s.allCalls.isEmpty
                                      ? 'No calls yet. Assign a phone number to an agent to start receiving calls.'
                                      : 'No calls found',
                                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textMuted),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else ...[
                          ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: NeyvoSpacing.sm,
                              vertical: NeyvoSpacing.sm,
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length + 1 + (s.hasMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: NeyvoSpacing.sm,
                                    vertical: NeyvoSpacing.sm,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Calls (${filtered.length})',
                                        style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.textPrimary),
                                      ),
                                      if (filtered.length != s.allCalls.length)
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            n.clearSearch();
                                            n.setFilterStatus('all');
                                            n.setFilterOutcome('all');
                                          },
                                          child: const Text('Clear filters'),
                                        ),
                                    ],
                                  ),
                                );
                              }
                              if (i == filtered.length + 1) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: NeyvoSpacing.md,
                                    right: NeyvoSpacing.md,
                                    bottom: NeyvoSpacing.lg,
                                  ),
                                  child: OutlinedButton(
                                    onPressed: s.loadingMore ? null : () => n.loadMore(),
                                    child: s.loadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Load more calls'),
                                  ),
                                );
                              }
                              final idx = i - 1;
                              final call = filtered[idx];
                              return _buildCallRowCard(
                                context: context,
                                call: call,
                                selected: selected,
                                onSelect: selNotifier.select,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}
