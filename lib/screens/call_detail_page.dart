// lib/screens/call_detail_page.dart
// Full call details: everything VAPI provides — from/to, transcript, AI insights,
// cost, credits used, recording, and expandable VAPI/technical sections.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_timezone_service.dart';
import '../theme/neyvo_theme.dart';

class CallDetailPage extends StatelessWidget {
  final Map<String, dynamic> call;

  const CallDetailPage({super.key, required this.call});

  static String formatDuration(dynamic c) {
    final sec = c['duration_seconds'];
    if (sec != null) {
      final s = sec is int ? sec : int.tryParse(sec.toString()) ?? 0;
      if (s < 60) return '${s}s';
      final m = s ~/ 60;
      final r = s % 60;
      return r > 0 ? '${m}m ${r}s' : '${m}m';
    }
    final d = c['duration']?.toString();
    return (d != null && d.isNotEmpty) ? d : '—';
  }

  static String formatDate(dynamic v) => UserTimezoneService.format(v);

  @override
  Widget build(BuildContext context) {
    final merged = call;
    final fromVal = (merged['from'] ?? merged['customer_phone'] ?? merged['student_phone'] ?? '').toString().trim();
    final toVal = (merged['to'] ?? '').toString().trim();
    final name = (merged['customer_name'] ?? merged['student_name'] ?? '').toString().trim();
    final ts = merged['started_at'] ?? merged['created_at'] ?? merged['timestamp'] ?? merged['ended_at'];
    final intent = (merged['intent'] ?? merged['outcome'] ?? merged['outcome_type'] ?? merged['service_requested'] ?? '—').toString();
    final durationStr = formatDuration(merged);
    final status = (merged['status'] ?? '—').toString();
    final transcript = (merged['transcript'] ?? merged['transcription'] ?? '').toString();
    final recordingUrl = (merged['recording_url'] ?? merged['recordingUrl'] ?? '').toString().trim();
    final stereoUrl = (merged['stereo_recording_url'] ?? merged['stereoRecordingUrl'] ?? '').toString().trim();
    final creditsCharged = merged['credits_charged'];
    final costUsd = merged['cost'] ?? merged['cost_usd'] ?? merged['costUsd'];
    final summary = (merged['summary'] ?? merged['analysis_summary'] ?? merged['ai_summary'] ?? '').toString();
    final sentiment = (merged['sentiment'] ?? merged['customer_sentiment'] ?? merged['ai_sentiment'] ?? '').toString();

    Color statusColor = NeyvoTheme.textTertiary;
    if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'success') statusColor = NeyvoTheme.success;
    else if (status.toLowerCase() == 'failed' || status.toLowerCase() == 'error') statusColor = NeyvoTheme.error;
    else if (status.toLowerCase().contains('progress') || status.toLowerCase() == 'ringing') statusColor = NeyvoTheme.warning;

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
      body: ListView(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        children: [
          _heroCard(
            name: name.isEmpty ? 'Unknown' : name,
            from: fromVal,
            to: toVal,
            ts: ts,
            intent: intent,
            durationStr: durationStr,
            status: status,
            statusColor: statusColor,
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _costAndCreditsCard(creditsCharged: creditsCharged, costUsd: costUsd),
          if (recordingUrl.isNotEmpty || stereoUrl.isNotEmpty) ...[
            const SizedBox(height: NeyvoSpacing.lg),
            _recordingCard(recordingUrl: recordingUrl, stereoUrl: stereoUrl),
          ],
          const SizedBox(height: NeyvoSpacing.lg),
          _sectionCard(
            title: 'Transcript',
            icon: Icons.notes,
            child: SelectableText(
              transcript.isEmpty ? 'No transcript available' : transcript,
              style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary, height: 1.5),
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _sectionCard(
            title: 'AI Insights',
            icon: Icons.auto_awesome,
            child: _aiSection(summary: summary, sentiment: sentiment, merged: merged),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _expandableSection(context,
            title: 'Call info',
            icon: Icons.info_outline,
            child: _callInfoGrid(merged),
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          _expandableSection(context,
            title: 'VAPI core',
            icon: Icons.api,
            child: _vapiCoreGrid(merged),
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          _expandableSection(context,
            title: 'Cost & recordings',
            icon: Icons.attach_money,
            child: _costAndRecordingsGrid(merged),
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          _expandableSection(context,
            title: 'Performance & tools',
            icon: Icons.speed,
            child: _performanceGrid(merged),
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          _expandableSection(context,
            title: 'Conversation',
            icon: Icons.chat,
            child: _conversationList(merged),
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          _expandableSection(context,
            title: 'Raw data',
            icon: Icons.code,
            child: SelectableText(
              _prettyMap(merged),
              style: NeyvoType.bodySmall.copyWith(fontFamily: 'monospace', color: NeyvoTheme.textSecondary),
            ),
          ),
          const SizedBox(height: NeyvoSpacing.xxl),
        ],
      ),
    );
  }

  Widget _heroCard({
    required String name,
    required String from,
    required String to,
    required dynamic ts,
    required String intent,
    required String durationStr,
    required String status,
    required Color statusColor,
  }) {
    String dateStr = '—';
    if (ts != null) {
      if (ts is String) dateStr = ts.length > 19 ? ts.substring(0, 19).replaceAll('T', ' ') : ts;
      else dateStr = ts.toString();
    }
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeyvoRadius.lg), side: const BorderSide(color: NeyvoTheme.border)),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NeyvoTheme.teal.withOpacity(0.15),
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
                      const SizedBox(height: 4),
                      Text(dateStr, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: NeyvoSpacing.xl),
            _infoRow(Icons.call_made, 'From', from),
            _infoRow(Icons.call_received, 'To', to),
            _infoRow(Icons.tag, 'Intent / outcome', intent),
            _infoRow(Icons.timer_outlined, 'Duration', durationStr),
            _infoRow(Icons.info_outline, 'Status', status, valueColor: statusColor),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NeyvoTheme.textMuted),
          const SizedBox(width: 12),
          SizedBox(width: 120, child: Text('$label:', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted))),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: NeyvoType.bodyMedium.copyWith(color: valueColor ?? NeyvoTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costAndCreditsCard({dynamic creditsCharged, dynamic costUsd}) {
    final credits = creditsCharged != null ? (creditsCharged is int ? creditsCharged : int.tryParse(creditsCharged.toString())) : null;
    final cost = costUsd != null ? (costUsd is num ? costUsd.toDouble() : double.tryParse(costUsd.toString())) : null;
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeyvoRadius.lg), side: const BorderSide(color: NeyvoTheme.border)),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text('Cost & credits', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Credits used:', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted)),
                const SizedBox(width: 8),
                Text(
                  credits != null ? '$credits' : '—',
                  style: NeyvoType.titleMedium.copyWith(
                    color: credits != null && credits > 0 ? NeyvoTheme.teal : NeyvoTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Cost (USD):', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted)),
                const SizedBox(width: 8),
                Text(
                  cost != null ? '\$${cost.toStringAsFixed(2)}' : '—',
                  style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordingCard({required String recordingUrl, required String stereoUrl}) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeyvoRadius.lg), side: const BorderSide(color: NeyvoTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.audiotrack, color: NeyvoTheme.teal),
            title: Text('Recording', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            subtitle: const Text('Tap to open in browser'),
            onTap: recordingUrl.isNotEmpty
                ? () async {
                    final uri = Uri.tryParse(recordingUrl);
                    if (uri != null && await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                : null,
          ),
          if (stereoUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.multitrack_audio, color: NeyvoTheme.textMuted),
              title: Text('Stereo recording', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
              onTap: () async {
                final uri = Uri.tryParse(stereoUrl);
                if (uri != null && await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeyvoRadius.lg), side: const BorderSide(color: NeyvoTheme.border)),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text(title, style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _aiSection({required String summary, required String sentiment, required Map<String, dynamic> merged}) {
    final structured = merged['analysis_structured_data'];
    if (summary.isEmpty && sentiment.isEmpty && structured == null) {
      return Text(
        'No AI insights for this call.',
        style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty) Text(summary, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary, height: 1.5)),
        if (sentiment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Chip(label: Text(sentiment), backgroundColor: NeyvoTheme.bgHover),
        ],
        if (structured is Map && structured.isNotEmpty) ...[
          if (summary.isNotEmpty) const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (structured as Map).entries.map((e) => Chip(
              label: Text('${e.key}: ${e.value}', style: NeyvoType.labelSmall),
              backgroundColor: NeyvoTheme.teal.withOpacity(0.1),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _expandableSection(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeyvoRadius.md), side: const BorderSide(color: NeyvoTheme.border)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          tilePadding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(NeyvoSpacing.lg, 0, NeyvoSpacing.lg, NeyvoSpacing.lg),
          leading: Icon(icon, size: 20, color: NeyvoTheme.textMuted),
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
          SizedBox(width: 140, child: Text('$label:', style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary))),
        ],
      ),
    );
  }

  Widget _callInfoGrid(Map<String, dynamic> m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Call ID', (m['id'] ?? m['call_id'] ?? m['call_sid'] ?? '').toString()),
        _detailRow('VAPI call ID', (m['vapi_call_id'] ?? '').toString()),
        _detailRow('Campaign ID', (m['campaign_id'] ?? '').toString()),
        _detailRow('Direction', (m['direction'] ?? '').toString()),
        _detailRow('Student ID', (m['student_id'] ?? '').toString()),
        _detailRow('Ended reason', (m['ended_reason'] ?? '').toString()),
        _detailRow('Outcome type', (m['outcome_type'] ?? '').toString()),
      ],
    );
  }

  Widget _vapiCoreGrid(Map<String, dynamic> m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Type', (m['type'] ?? '').toString()),
        _detailRow('Status', (m['status'] ?? m['vapi_status'] ?? '').toString()),
        _detailRow('Phone number ID', (m['phone_number_id'] ?? m['phoneNumberId'] ?? '').toString()),
        _detailRow('Assistant ID', (m['assistant_id'] ?? m['assistantId'] ?? '').toString()),
        _detailRow('Started', formatDate(m['started_at'] ?? m['startedAt'])),
        _detailRow('Ended', formatDate(m['ended_at'] ?? m['endedAt'])),
        _detailRow('Created', formatDate(m['created_at'] ?? m['createdAt'])),
      ],
    );
  }

  Widget _costAndRecordingsGrid(Map<String, dynamic> m) {
    final cost = m['cost'] ?? m['cost_usd'] ?? m['costUsd'];
    final costStr = cost != null ? '\$${cost is num ? (cost as num).toStringAsFixed(2) : cost}' : '—';
    final credits = m['credits_charged'];
    final creditsStr = credits != null ? credits.toString() : '—';
    final cb = m['cost_breakdown'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Credits used', creditsStr),
        _detailRow('Cost (USD)', costStr),
        if (cb is Map && cb.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Breakdown:', style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted)),
          ...(cb.entries.map((e) => _detailRow('  ${e.key}', (e.value ?? '').toString()))),
        ],
        _detailRow('Recording URL', (m['recording_url'] ?? '').toString().trim()),
        _detailRow('Stereo recording', (m['stereo_recording_url'] ?? '').toString().trim()),
      ],
    );
  }

  Widget _performanceGrid(Map<String, dynamic> m) {
    final avgLatency = m['average_latency_ms'] ?? m['averageLatency'];
    final maxLatency = m['max_latency_ms'] ?? m['maxLatency'];
    final interrupts = m['interruptions_count'] ?? m['interruptionsCount'];
    final msgCount = m['messages_count'] ?? m['messagesCount'];
    final funcSummary = (m['function_summary'] ?? '').toString();
    final toolCalls = m['tool_calls'] ?? m['toolCalls'];
    final hasAny = avgLatency != null || maxLatency != null || interrupts != null || msgCount != null ||
        funcSummary.isNotEmpty || (toolCalls is List && toolCalls.isNotEmpty);
    if (!hasAny) {
      return Text('No performance data', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avgLatency != null) _detailRow('Avg latency (ms)', avgLatency.toString()),
        if (maxLatency != null) _detailRow('Max latency (ms)', maxLatency.toString()),
        if (interrupts != null) _detailRow('Interruptions', interrupts.toString()),
        if (msgCount != null) _detailRow('Messages count', msgCount.toString()),
        if (funcSummary.isNotEmpty) _detailRow('Function summary', funcSummary),
        if (toolCalls is List && toolCalls.isNotEmpty) _detailRow('Tool calls', '${toolCalls.length}'),
      ],
    );
  }

  Widget _conversationList(Map<String, dynamic> m) {
    final messages = (m['messages'] ?? m['history'] ?? []) as List<dynamic>;
    if (messages.isEmpty) {
      return Text('No conversation messages', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted));
    }
    return Column(
      children: messages.map((e) {
        final map = (e is Map) ? e as Map : <String, dynamic>{};
        final role = (map['role'] ?? 'unknown').toString();
        var msg = (map['content'] ?? map['message'] ?? '').toString();
        if (msg.isEmpty && map['content'] is List) msg = (map['content'] as List).map((x) => x.toString()).join(' ');
        if (msg.isEmpty && (map['tool_calls'] != null || map['toolCalls'] != null)) msg = '[Tool calls]';
        final isUser = role == 'user';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser ? NeyvoTheme.bgHover : NeyvoTheme.teal.withOpacity(0.08),
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

  String _prettyMap(Map<String, dynamic> m) {
    final lines = <String>[];
    for (final e in m.entries) {
      final v = e.value;
      if (v is Map || v is List) {
        lines.add('${e.key}: ${v.toString()}');
      } else {
        lines.add('${e.key}: $v');
      }
    }
    return lines.join('\n');
  }
}
