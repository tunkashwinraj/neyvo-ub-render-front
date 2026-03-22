// lib/screens/call_detail_page.dart
// Call details aligned with lean Firestore + optional Vapi API merge (getCallById).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers/call_detail_provider.dart';
import '../services/user_timezone_service.dart';
import '../theme/neyvo_theme.dart';
import 'call_detail/call_detail_view_model.dart';

class CallDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> call;

  /// When true, renders body only (no [Scaffold]) so the Pulse shell sidebar stays visible.
  /// Used from [CallHistoryPage] split / stacked layout.
  final bool embedded;

  const CallDetailPage({super.key, required this.call, this.embedded = false});

  @override
  ConsumerState<CallDetailPage> createState() => _CallDetailPageState();
}

class _CallDetailPageState extends ConsumerState<CallDetailPage> {
  late String _providerKey;

  static const double _kContentMaxWidth = 800;

  @override
  void initState() {
    super.initState();
    _providerKey = callDetailProviderKey(widget.call);
    Future<void>.microtask(_ensureInitializedSafe);
  }

  @override
  void didUpdateWidget(covariant CallDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = callDetailProviderKey(widget.call);
    if (nextKey != _providerKey) {
      _providerKey = nextKey;
      Future<void>.microtask(_ensureInitializedSafe);
    }
  }

  void _ensureInitializedSafe() {
    if (!mounted) return;
    ref.read(callDetailUiCtrlProvider(_providerKey).notifier).ensureInitialized(widget.call);
  }

  static String formatDuration(Map<String, dynamic> c) {
    final sec = c['duration_seconds'] ?? c['duration'];
    if (sec != null) {
      final s = sec is int ? sec : int.tryParse(sec.toString()) ?? 0;
      if (s < 60) return '${s}s';
      final m = s ~/ 60;
      final r = s % 60;
      return r > 0 ? '${m}m ${r}s' : '${m}m';
    }
    return '—';
  }

  static String formatDate(dynamic v) => UserTimezoneService.format(v);

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'success') return NeyvoTheme.success;
    if (s == 'failed' || s == 'error') return NeyvoTheme.error;
    if (s.contains('progress') || s == 'ringing' || s == 'in_progress') return NeyvoTheme.warning;
    return NeyvoTheme.textTertiary;
  }

  Color _sentimentAccent(String sentiment) {
    final s = sentiment.toLowerCase();
    if (s.contains('positive')) return NeyvoTheme.success;
    if (s.contains('negative')) return NeyvoTheme.error;
    return NeyvoTheme.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(callDetailUiCtrlProvider(_providerKey));
    if (!ui.initialized) {
      final loading = const Center(child: CircularProgressIndicator());
      if (widget.embedded) {
        return Material(color: NeyvoTheme.bgPrimary, child: loading);
      }
      return Scaffold(
        backgroundColor: NeyvoTheme.bgPrimary,
        appBar: AppBar(
          backgroundColor: NeyvoTheme.bgSurface,
          title: Text('Call details', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: loading,
      );
    }

    final m = ui.merged;
    final callId = cdPrimaryCallId(m);
    final name = cdContactName(m);
    final fromVal = cdFromNumber(m);
    final toVal = cdToNumber(m);
    final ts = m['started_at'] ?? m['created_at'] ?? m['timestamp'] ?? m['ended_at'];
    final durationStr = formatDuration(m);
    final status = cdStatus(m).isEmpty ? '—' : cdStatus(m);
    final transcript = cdTranscript(m);
    final summaryText = cdSummary(m);
    final sentiment = cdSentiment(m);
    final recordingUrl = cdRecordingUrl(m);
    final stereoUrl = cdStereoUrl(m);
    final intent = cdStr(m, ['intent']);
    final outcomeStr = cdStr(m, ['outcome']);
    final outcomeType = cdStr(m, ['outcome_type']);
    final serviceReq = cdStr(m, ['service_requested']);
    final bookingId = cdStr(m, ['booking_id']);
    final bookingCreated = cdBool(m, ['booking_created']);

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final maxW = widget.embedded ? double.infinity : _kContentMaxWidth;
        final hPad = widget.embedded ? 20.0 : NeyvoSpacing.lg;

        Widget refreshBanner() {
          if (!ui.loading) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: NeyvoSpacing.md),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Refreshing call data…',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                  ),
                ),
              ],
            ),
          );
        }

        Widget? errorBanner() {
          if (ui.error == null || ui.error!.trim().isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(bottom: NeyvoSpacing.md),
            child: Material(
              color: NeyvoTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(NeyvoRadius.md),
              child: Padding(
                padding: const EdgeInsets.all(NeyvoSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_off, size: 20, color: NeyvoTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ui.error!,
                        style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final summaryHeader = _summaryHeader(
          name: name.isEmpty ? 'Unknown' : name,
          status: status,
          sentiment: sentiment,
          durationStr: durationStr,
          ts: ts,
          statusColor: _statusColor(status),
          sentimentAccent: sentiment.isEmpty ? NeyvoTheme.textMuted : _sentimentAccent(sentiment),
        );
        final participants = _participantsCard(fromVal: fromVal, toVal: toVal);
        final outcomeCard = _outcomeChips(
          intent: intent,
          outcome: outcomeStr,
          outcomeType: outcomeType,
          serviceRequested: serviceReq,
          bookingId: bookingId,
          bookingCreated: bookingCreated,
        );
        final recording = (recordingUrl.isNotEmpty || stereoUrl.isNotEmpty)
            ? _recordingCard(recordingUrl: recordingUrl, stereoUrl: stereoUrl)
            : null;
        final transcriptCard = _sectionCard(
          title: 'Transcript',
          icon: Icons.notes,
          child: SelectableText(
            transcript.isEmpty
                ? (summaryText.contains('HIPAA') ? summaryText : 'No transcript stored for this call.')
                : transcript,
            style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary, height: 1.55),
          ),
        );
        final analysisCard = _sectionCard(
          title: 'Summary & analysis',
          icon: Icons.auto_awesome,
          child: _aiBlock(summary: summaryText, sentiment: sentiment, merged: m),
        );

        final bottomSections = <Widget>[
          if (cdHasBilling(m)) ...[
            const SizedBox(height: NeyvoSpacing.lg),
            _billingCard(m),
          ],
          if (cdHasCostBlock(m)) ...[
            const SizedBox(height: NeyvoSpacing.lg),
            _costCard(m),
          ],
          if (cdConfigSnapshot(m) != null && cdConfigSnapshot(m)!.isNotEmpty) ...[
            const SizedBox(height: NeyvoSpacing.lg),
            _configSnapshotCard(cdConfigSnapshot(m)!),
          ],
          const SizedBox(height: NeyvoSpacing.sm),
          _expandableSection(
            context,
            title: 'IDs & technical',
            icon: Icons.tune,
            child: _technicalGrid(m),
          ),
          if (cdHasPerformance(m)) ...[
            const SizedBox(height: NeyvoSpacing.sm),
            _expandableSection(
              context,
              title: 'Call quality & tools',
              icon: Icons.speed,
              child: _performanceGrid(m),
            ),
          ],
          const SizedBox(height: NeyvoSpacing.sm),
          _expandableSection(
            context,
            title: 'Turn-by-turn (if available)',
            icon: Icons.chat_bubble_outline,
            child: _conversationBlock(m),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: NeyvoSpacing.sm),
            _expandableSection(
              context,
              title: 'Debug: allowlisted fields',
              icon: Icons.bug_report_outlined,
              child: SelectableText(
                cdDebugAllowlistedDump(m),
                style: NeyvoType.bodySmall.copyWith(
                  fontFamily: 'monospace',
                  color: NeyvoTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: NeyvoSpacing.xxl),
        ];

        final inner = wide
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  refreshBanner(),
                  if (errorBanner() != null) errorBanner()!,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summaryHeader,
                            const SizedBox(height: NeyvoSpacing.lg),
                            participants,
                            const SizedBox(height: NeyvoSpacing.lg),
                            outcomeCard,
                            if (recording != null) ...[
                              const SizedBox(height: NeyvoSpacing.lg),
                              recording,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: NeyvoSpacing.lg),
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            transcriptCard,
                            const SizedBox(height: NeyvoSpacing.lg),
                            analysisCard,
                          ],
                        ),
                      ),
                    ],
                  ),
                  ...bottomSections,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  refreshBanner(),
                  if (errorBanner() != null) errorBanner()!,
                  summaryHeader,
                  const SizedBox(height: NeyvoSpacing.lg),
                  participants,
                  const SizedBox(height: NeyvoSpacing.lg),
                  outcomeCard,
                  if (recording != null) ...[
                    const SizedBox(height: NeyvoSpacing.lg),
                    recording,
                  ],
                  const SizedBox(height: NeyvoSpacing.lg),
                  transcriptCard,
                  const SizedBox(height: NeyvoSpacing.lg),
                  analysisCard,
                  ...bottomSections,
                ],
              );

        final scroll = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, NeyvoSpacing.lg, hPad, NeyvoSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: inner,
          ),
        );

        if (widget.embedded) {
          return Material(color: NeyvoTheme.bgPrimary, child: scroll);
        }
        return Center(child: scroll);
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: NeyvoTheme.bgSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Call details', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            if (callId.isNotEmpty)
              Text(
                cdTruncate(callId, 36),
                style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (callId.isNotEmpty)
            IconButton(
              tooltip: 'Copy call ID',
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: callId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Call ID copied')),
                );
              },
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _summaryHeader({
    required String name,
    required String status,
    required String sentiment,
    required String durationStr,
    required dynamic ts,
    required Color statusColor,
    required Color sentimentAccent,
  }) {
    final dateStr = ts != null ? formatDate(ts) : '—';
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NeyvoTheme.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NeyvoRadius.md),
                  ),
                  child: const Icon(Icons.phone_in_talk, color: NeyvoTheme.teal, size: 28),
                ),
                const SizedBox(width: NeyvoSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Text(dateStr, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            avatar: Icon(Icons.timer_outlined, size: 16, color: NeyvoTheme.textSecondary),
                            label: Text(durationStr, style: NeyvoType.labelLarge),
                            backgroundColor: NeyvoTheme.bgHover,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          if (status != '—')
                            Chip(
                              label: Text(status, style: NeyvoType.labelLarge.copyWith(color: statusColor)),
                              side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
                              backgroundColor: statusColor.withValues(alpha: 0.08),
                            ),
                          if (sentiment.isNotEmpty)
                            Chip(
                              label: Text(sentiment, style: NeyvoType.labelLarge),
                              side: BorderSide(color: sentimentAccent.withValues(alpha: 0.4)),
                              backgroundColor: sentimentAccent.withValues(alpha: 0.08),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _participantsCard({required String fromVal, required String toVal}) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text('Participants', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            _kv(Icons.call_made, 'From', fromVal.isEmpty ? '—' : fromVal),
            _kv(Icons.call_received, 'To', toVal.isEmpty ? '—' : toVal),
          ],
        ),
      ),
    );
  }

  Widget _kv(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: NeyvoTheme.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(label, style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted)),
          ),
          Expanded(child: SelectableText(value, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary))),
        ],
      ),
    );
  }

  Widget _outcomeChips({
    required String intent,
    required String outcome,
    required String outcomeType,
    required String serviceRequested,
    required String bookingId,
    required bool bookingCreated,
  }) {
    final chips = <Widget>[];
    void add(String label, String v) {
      if (v.isEmpty) return;
      chips.add(
        Chip(
          label: Text('$label: ${cdTruncate(v, 48)}', style: NeyvoType.labelSmall),
          backgroundColor: NeyvoTheme.bgHover,
        ),
      );
    }

    add('Intent', intent);
    add('Outcome', outcome);
    add('Type', outcomeType);
    add('Service', serviceRequested);
    if (bookingId.isNotEmpty) add('Booking', bookingId);
    if (bookingCreated && bookingId.isEmpty) {
      chips.add(Chip(label: Text('Booking created', style: NeyvoType.labelSmall), backgroundColor: NeyvoTheme.teal.withValues(alpha: 0.1)));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text('Outcome & booking', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
  }

  Widget _recordingCard({required String recordingUrl, required String stereoUrl}) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.graphic_eq, color: NeyvoTheme.teal),
            title: Text('Recording', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            subtitle: Text(
              recordingUrl.isNotEmpty ? 'Opens in browser / player' : 'No mono recording URL',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
            ),
            trailing: recordingUrl.isNotEmpty
                ? FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(recordingUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open'),
                  )
                : null,
          ),
          if (stereoUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.multitrack_audio, color: NeyvoTheme.textMuted),
              title: Text('Stereo (API only)', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
              subtitle: const Text('Not stored on lean docs; shown if Vapi returns it'),
              onTap: () async {
                final uri = Uri.tryParse(stereoUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text(title, style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _aiBlock({required String summary, required String sentiment, required Map<String, dynamic> merged}) {
    final structured = cdStructuredEntries(cdStructuredAnalysis(merged));
    if (summary.isEmpty && sentiment.isEmpty && structured.isEmpty) {
      return Text('No summary or structured analysis for this call.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty)
          Text(summary, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary, height: 1.5)),
        if (sentiment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Chip(
            label: Text('Sentiment: $sentiment', style: NeyvoType.labelLarge),
            backgroundColor: NeyvoTheme.bgHover,
          ),
        ],
        if (structured.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Structured fields', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: structured
                .map(
                  (e) => Chip(
                    label: Text('${e.key}: ${e.value}', style: NeyvoType.labelSmall),
                    backgroundColor: NeyvoTheme.teal.withValues(alpha: 0.08),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _billingCard(Map<String, dynamic> m) {
    final credits = cdInt(m, ['credits_charged']);
    final charged = cdDouble(m, ['charged_amount_usd']);
    final failed = cdBool(m, ['billing_failed']);
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text('Billing (Pulse)', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            if (credits != null) _detailRow('Credits charged', credits.toString()),
            if (charged != null) _detailRow('Charged (USD)', charged.toStringAsFixed(2)),
            if (failed) _detailRow('Billing', 'Failed — see logs'),
          ],
        ),
      ),
    );
  }

  Widget _costCard(Map<String, dynamic> m) {
    final dur = cdInt(m, ['duration_seconds']) ?? cdInt(m, ['duration']);
    final cost = cdDouble(m, ['cost_usd', 'cost']);
    final cb = cdMap(m, 'cost_breakdown');
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text('Cost & duration', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            if (dur != null) _detailRow('Duration (sec)', dur.toString()),
            if (cost != null) _detailRow('Vapi cost (USD)', cost.toString()),
            if (cb != null && cb.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Cost breakdown', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted)),
              const SizedBox(height: 6),
              ...cb.entries.map((e) => _detailRow(e.key.toString(), e.value.toString())),
            ],
          ],
        ),
      ),
    );
  }

  Widget _configSnapshotCard(Map<String, dynamic> snap) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fingerprint, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text('Config attribution', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            ...snap.entries.map((e) => _detailRow(e.key.toString(), cdTruncate(e.value.toString(), 200))),
          ],
        ),
      ),
    );
  }

  Widget _technicalGrid(Map<String, dynamic> m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('VAPI call ID', cdStr(m, ['vapi_call_id'])),
        _detailRow('Call / doc ID', cdStr(m, ['call_id', 'call_sid', 'id'])),
        _detailRow('Account', cdStr(m, ['account_id'])),
        _detailRow('Business', cdStr(m, ['business_id'])),
        _detailRow('Campaign', cdStr(m, ['campaign_id'])),
        _detailRow('Student', cdStr(m, ['student_id'])),
        _detailRow('Profile', cdStr(m, ['profile_id'])),
        _detailRow('Assistant', cdStr(m, ['assistant_id', 'assistantId'])),
        _detailRow('Phone number ID', cdStr(m, ['phone_number_id', 'phoneNumberId'])),
        _detailRow('Type', cdStr(m, ['type'])),
        _detailRow('Direction', cdStr(m, ['direction'])),
        _detailRow('Vapi status', cdStr(m, ['vapi_status'])),
        _detailRow('Ended reason', cdStr(m, ['ended_reason'])),
        _detailRow('Started', formatDate(m['started_at'] ?? m['startedAt'])),
        _detailRow('Ended', formatDate(m['ended_at'] ?? m['endedAt'])),
        _detailRow('Created', formatDate(m['created_at'] ?? m['createdAt'])),
        _detailRow('Updated', formatDate(m['updated_at'] ?? m['updatedAt'])),
      ],
    );
  }

  Widget _performanceGrid(Map<String, dynamic> m) {
    final avgLatency = m['average_latency_ms'] ?? m['averageLatency'];
    final maxLatency = m['max_latency_ms'] ?? m['maxLatency'];
    final interrupts = m['interruptions_count'] ?? m['interruptionsCount'];
    final msgCount = m['messages_count'] ?? m['messagesCount'];
    final funcSummary = cdStr(m, ['function_summary']);
    final toolCalls = m['tool_calls'] ?? m['toolCalls'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avgLatency != null) _detailRow('Avg latency (ms)', avgLatency.toString()),
        if (maxLatency != null) _detailRow('Max latency (ms)', maxLatency.toString()),
        if (interrupts != null) _detailRow('Interruptions', interrupts.toString()),
        if (msgCount != null) _detailRow('Message turns (count)', msgCount.toString()),
        if (funcSummary.isNotEmpty) _detailRow('Function summary', funcSummary),
        if (toolCalls is List && toolCalls.isNotEmpty) _detailRow('Tool invocations', '${toolCalls.length}'),
      ],
    );
  }

  Widget _conversationBlock(Map<String, dynamic> m) {
    if (!cdHasTurnByTurn(m)) {
      return Text(
        'Turn-by-turn messages are not stored on the call document. Use the transcript above — '
        'or open this call in Vapi if enriched data is available.',
        style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted, height: 1.45),
      );
    }
    final messages = (m['messages'] ?? m['history'] ?? []) as List<dynamic>;
    return Column(
      children: messages.map((e) {
        final Map<String, dynamic> map = e is Map<String, dynamic>
            ? e
            : e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{};
        final role = (map['role'] ?? 'unknown').toString();
        var msg = (map['content'] ?? map['message'] ?? '').toString();
        if (msg.isEmpty && map['content'] is List) msg = (map['content'] as List).map((x) => x.toString()).join(' ');
        if (msg.isEmpty && (map['tool_calls'] != null || map['toolCalls'] != null)) msg = '[Tool calls]';
        final isUser = role == 'user';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser ? NeyvoTheme.bgHover : NeyvoTheme.teal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(NeyvoRadius.sm),
            border: Border.all(color: NeyvoTheme.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('[$role] ', style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted)),
              Expanded(child: SelectableText(msg, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _expandableSection(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.md),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          tilePadding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(NeyvoSpacing.lg, 0, NeyvoSpacing.lg, NeyvoSpacing.lg),
          leading: Icon(icon, size: 22, color: NeyvoTheme.textMuted),
          title: Text(title, style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textPrimary)),
          children: [child],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted)),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
