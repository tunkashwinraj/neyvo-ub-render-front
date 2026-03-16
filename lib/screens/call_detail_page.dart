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

  // ---------- Helpers ----------

  static String _formatDuration(dynamic c) {
    final sec = c['duration_seconds'] ?? c['duration_sec'] ?? c['duration'];
    if (sec == null) return '—';
    final s = sec is num ? sec.toInt() : int.tryParse(sec.toString()) ?? 0;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final r = s % 60;
    return r > 0 ? '${m}m ${r}s' : '${m}m';
  }

  static String _formatDate(dynamic v) => UserTimezoneService.format(v);

  static String _string(dynamic v) => (v ?? '').toString().trim();

  static Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = call;
    final artifact = (m['artifact'] as Map?) ?? const {};
    final analysis = (m['analysis'] as Map?) ?? const {};
    final customer = (m['customer'] as Map?) ?? const {};

    // IDs / core
    final callId = _string(m['id'] ?? m['call_sid'] ?? m['call_id'] ?? m['vapi_call_id']);
    final vapiCallId = _string(m['vapi_call_id'] ?? m['call_sid']);
    final status = _string(m['status'] ?? m['vapi_status']);
    final type = _string(m['type']);
    final direction = _string(m['direction']);
    final endedReason = _string(m['ended_reason'] ?? m['endedReason']);

    final startedAt = m['started_at'] ?? m['startedAt'] ?? m['created_at'] ?? m['createdAt'];
    final endedAt = m['ended_at'] ?? m['endedAt'] ?? m['updated_at'] ?? m['updatedAt'];
    final createdAt = m['created_at'] ?? m['createdAt'];

    final durationStr = _formatDuration(m);

    // Parties
    final customerName =
        _string(customer['name'] ?? m['customer_name'] ?? m['student_name']);
    final customerNumber =
        _string(customer['number'] ?? m['customer_phone'] ?? m['student_phone'] ?? m['from']);
    final customerEmail = _string(customer['email']);
    final toNumber = _string(m['to']);
    final accountId = _string(m['account_id'] ?? m['business_id']);
    final studentId = _string(m['student_id']);

    // Assistant / routing
    final assistantId = _string(m['assistant_id'] ?? m['assistantId']);
    final squadId = _string(m['squad_id'] ?? m['squadId']);
    final phoneNumberId = _string(m['phone_number_id'] ?? m['phoneNumberId']);
    final profileId = _string(m['profile_id']);
    final campaignId = _string(m['campaign_id']);

    // Recording URLs
    final monoRecordingUrl = _string(
      m['recording_url'] ??
          m['recordingUrl'] ??
          m['recording'] ??
          artifact['recording_url'] ??
          artifact['recordingUrl'],
    );
    final stereoRecordingUrl = _string(
      m['stereo_recording_url'] ??
          m['stereoRecordingUrl'] ??
          artifact['stereo_recording_url'] ??
          artifact['stereoRecordingUrl'],
    );
    final videoRecordingUrl = _string(
      m['video_recording_url'] ?? artifact['videoRecordingUrl'],
    );
    final pcapUrl = _string(m['pcap_url'] ?? artifact['pcapUrl']);

    // Transcript + messages
    final transcript = _string(
      m['transcript'] ?? m['transcription'] ?? artifact['transcript'],
    );
    final messages = (m['messages'] ?? m['history'] ?? []) as List<dynamic>;

    // AI analysis
    final summary = _string(
      m['summary'] ??
          m['analysis_summary'] ??
          analysis['summary'] ??
          m['ai_summary'],
    );
    final structuredData =
        (m['analysis_structured_data'] ?? analysis['structuredData']) as Map? ??
            const {};
    final successEvaluation =
        _string(m['analysis_success_evaluation'] ?? analysis['successEvaluation']);
    final sentiment = _string(
      m['sentiment'] ?? m['customer_sentiment'] ?? m['ai_sentiment'],
    );
    final callResolution = _string(m['call_resolution']);
    final callbackRequested = m['callback_requested'] == true;
    final callbackTime = _string(m['callback_time']);
    final callbackTimezone = _string(m['callback_timezone']);

    // Cost & performance
    final creditsCharged = m['credits_charged'];
    final chargedAmountUsd = m['charged_amount_usd'];
    final cost = m['cost'] ?? m['cost_usd'] ?? m['costUsd'];
    final costBreakdown = m['cost_breakdown'];
    final avgLatency = m['average_latency_ms'];
    final maxLatency = m['max_latency_ms'];
    final interrupts = m['interruptions_count'];
    final msgCount = m['messages_count'];

    // Outcome
    final intent = _string(
      m['intent'] ?? m['outcome'] ?? m['outcome_type'] ?? m['service_requested'],
    );
    final outcome = _string(m['outcome']);

    // Status color
    Color statusColor = NeyvoTheme.textTertiary;
    final st = status.toLowerCase();
    if (st == 'completed' || st == 'success' || st == 'ended') {
      statusColor = NeyvoTheme.success;
    } else if (st == 'failed' || st == 'error') {
      statusColor = NeyvoTheme.error;
    } else if (st.contains('progress') || st == 'ringing' || st == 'queued') {
      statusColor = NeyvoTheme.warning;
    }

    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: NeyvoTheme.bgSurface,
        title:
            Text('Call details', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        children: [
          _heroCard(
            name: customerName.isEmpty ? 'Unknown caller' : customerName,
            from: customerNumber,
            to: toNumber,
            startedAt: startedAt ?? createdAt,
            durationStr: durationStr,
            status: status,
            statusColor: statusColor,
            intent: intent,
            outcome: outcome,
          ),
          const SizedBox(height: NeyvoSpacing.lg),

          _sectionCard(
            title: 'Who this call was with',
            icon: Icons.person,
            child: _partiesSection(
              customerName: customerName,
              customerNumber: customerNumber,
              customerEmail: customerEmail,
              toNumber: toNumber,
              studentId: studentId,
              accountId: accountId,
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),

          _sectionCard(
            title: 'Assistant & routing',
            icon: Icons.smart_toy,
            child: _assistantSection(
              callId: callId,
              vapiCallId: vapiCallId,
              direction: direction,
              type: type,
              assistantId: assistantId,
              squadId: squadId,
              phoneNumberId: phoneNumberId,
              profileId: profileId,
              campaignId: campaignId,
              startedAt: startedAt,
              endedAt: endedAt,
              createdAt: createdAt,
              endedReason: endedReason,
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),

          _costAndCreditsCard(
            creditsCharged: creditsCharged,
            costUsd: cost,
            chargedAmountUsd: chargedAmountUsd,
            costBreakdown: costBreakdown,
          ),
          const SizedBox(height: NeyvoSpacing.lg),

          if (monoRecordingUrl.isNotEmpty ||
              stereoRecordingUrl.isNotEmpty ||
              videoRecordingUrl.isNotEmpty ||
              pcapUrl.isNotEmpty)
            _recordingCard(
              monoUrl: monoRecordingUrl,
              stereoUrl: stereoRecordingUrl,
              videoUrl: videoRecordingUrl,
              pcapUrl: pcapUrl,
            ),

          if (monoRecordingUrl.isNotEmpty ||
              stereoRecordingUrl.isNotEmpty ||
              videoRecordingUrl.isNotEmpty ||
              pcapUrl.isNotEmpty)
            const SizedBox(height: NeyvoSpacing.lg),

          _sectionCard(
            title: 'Transcript',
            icon: Icons.notes,
            child: SelectableText(
              transcript.isEmpty ? 'No transcript available' : transcript,
              style:
                  NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary, height: 1.4),
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),

          _sectionCard(
            title: 'AI insights',
            icon: Icons.auto_awesome,
            child: _aiSection(
              summary: summary,
              sentiment: sentiment,
              structured: structuredData,
              successEvaluation: successEvaluation,
              callResolution: callResolution,
              callbackRequested: callbackRequested,
              callbackTime: callbackTime,
              callbackTimezone: callbackTimezone,
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),

          _sectionCard(
            title: 'Performance',
            icon: Icons.speed,
            child: _performanceSection(
              avgLatency: avgLatency,
              maxLatency: maxLatency,
              interrupts: interrupts,
              msgCount: msgCount,
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),

          _sectionCard(
            title: 'Conversation turns',
            icon: Icons.chat,
            child: _conversationList(messages),
          ),
          const SizedBox(height: NeyvoSpacing.lg),

          _sectionCard(
            title: 'Raw data (debug)',
            icon: Icons.code,
            child: SelectableText(
              _prettyMap(m),
              style: NeyvoType.bodySmall
                  .copyWith(fontFamily: 'monospace', color: NeyvoTheme.textSecondary),
            ),
          ),
          const SizedBox(height: NeyvoSpacing.xxl),
        ],
      ),
    );
  }

  // ---------- UI sections ----------

  Widget _heroCard({
    required String name,
    required String from,
    required String to,
    required dynamic startedAt,
    required String durationStr,
    required String status,
    required Color statusColor,
    required String intent,
    required String outcome,
  }) {
    String dateStr = '—';
    if (startedAt != null) {
      dateStr = UserTimezoneService.format(startedAt);
    }

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
                      Text(name,
                          style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(dateStr,
                          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: NeyvoSpacing.xl),
            _infoRow(Icons.call_made, 'From', from),
            _infoRow(Icons.call_received, 'To', to),
            _infoRow(Icons.tag, 'Intent', intent),
            if (outcome.isNotEmpty) _infoRow(Icons.flag, 'Outcome', outcome),
            _infoRow(Icons.timer_outlined, 'Duration', durationStr),
            _infoRow(Icons.info_outline, 'Status', status, valueColor: statusColor),
          ],
        ),
      ),
    );
  }

  Widget _partiesSection({
    required String customerName,
    required String customerNumber,
    required String customerEmail,
    required String toNumber,
    required String studentId,
    required String accountId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Customer name', customerName),
        _detailRow('Customer phone', customerNumber),
        _detailRow('Customer email', customerEmail),
        _detailRow('Your number (phoneNumberId resolved separately)', toNumber),
        _detailRow('Student ID', studentId),
        _detailRow('Account ID', accountId),
      ],
    );
  }

  Widget _assistantSection({
    required String callId,
    required String vapiCallId,
    required String direction,
    required String type,
    required String assistantId,
    required String squadId,
    required String phoneNumberId,
    required String profileId,
    required String campaignId,
    required dynamic startedAt,
    required dynamic endedAt,
    required dynamic createdAt,
    required String endedReason,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Call ID', callId),
        _detailRow('Vapi call ID', vapiCallId),
        _detailRow('Direction', direction),
        _detailRow('Type', type),
        _detailRow('Assistant ID', assistantId),
        _detailRow('Squad ID', squadId),
        _detailRow('Phone number ID', phoneNumberId),
        _detailRow('Profile ID', profileId),
        _detailRow('Campaign ID', campaignId),
        _detailRow('Started at', _formatDate(startedAt ?? createdAt)),
        _detailRow('Ended at', _formatDate(endedAt)),
        _detailRow('Ended reason', endedReason),
      ],
    );
  }

  Widget _costAndCreditsCard({
    required dynamic creditsCharged,
    required dynamic costUsd,
    required dynamic chargedAmountUsd,
    required dynamic costBreakdown,
  }) {
    final credits = creditsCharged != null
        ? (creditsCharged is num ? creditsCharged.toInt() : int.tryParse('$creditsCharged'))
        : null;
    final cost = costUsd != null
        ? (costUsd is num ? costUsd.toDouble() : double.tryParse('$costUsd'))
        : null;
    final charged = chargedAmountUsd != null
        ? (chargedAmountUsd is num
            ? chargedAmountUsd.toDouble()
            : double.tryParse('$chargedAmountUsd'))
        : null;

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
                Icon(Icons.credit_card, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text('Cost & credits',
                    style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow(
              'Credits charged',
              credits != null ? '$credits' : '—',
            ),
            _detailRow(
              'Vapi cost (USD)',
              cost != null ? '\$${cost.toStringAsFixed(2)}' : '—',
            ),
            _detailRow(
              'Billed to org (USD)',
              charged != null ? '\$${charged.toStringAsFixed(2)}' : '—',
            ),
            if (costBreakdown is Map && costBreakdown.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Cost breakdown',
                  style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted)),
              const SizedBox(height: 4),
              ...costBreakdown.entries.map(
                (e) => _detailRow('  ${e.key}', '${e.value ?? ''}'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recordingCard({
    required String monoUrl,
    required String stereoUrl,
    required String videoUrl,
    required String pcapUrl,
  }) {
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
            leading: const Icon(Icons.audiotrack, color: NeyvoTheme.teal),
            title: Text('Audio recording',
                style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            subtitle: const Text('Tap to open in browser'),
            onTap: monoUrl.isNotEmpty ? () => _openUrl(monoUrl) : null,
          ),
          if (stereoUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.multitrack_audio, color: NeyvoTheme.textMuted),
              title: Text('Stereo recording',
                  style:
                      NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
              onTap: () => _openUrl(stereoUrl),
            ),
          if (videoUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.videocam, color: NeyvoTheme.textMuted),
              title: Text('Video recording',
                  style:
                      NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
              onTap: () => _openUrl(videoUrl),
            ),
          if (pcapUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.bug_report, color: NeyvoTheme.textMuted),
              title: Text('SIP debug (PCAP)',
                  style:
                      NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
              onTap: () => _openUrl(pcapUrl),
            ),
        ],
      ),
    );
  }

  Widget _aiSection({
    required String summary,
    required String sentiment,
    required Map structured,
    required String successEvaluation,
    required String callResolution,
    required bool callbackRequested,
    required String callbackTime,
    required String callbackTimezone,
  }) {
    final hasStructured = structured.isNotEmpty;
    final hasAnyCallback =
        callbackRequested || callbackTime.isNotEmpty || callbackTimezone.isNotEmpty;

    if (summary.isEmpty &&
        sentiment.isEmpty &&
        !hasStructured &&
        successEvaluation.isEmpty &&
        callResolution.isEmpty &&
        !hasAnyCallback) {
      return Text('No AI insights for this call.',
          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty)
          Text(
            summary,
            style: NeyvoType.bodyMedium.copyWith(
              color: NeyvoTheme.textPrimary,
              height: 1.4,
            ),
          ),
        if (sentiment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Chip(
            label: Text(sentiment),
            backgroundColor: NeyvoTheme.bgHover,
          ),
        ],
        if (callResolution.isNotEmpty) ...[
          const SizedBox(height: 8),
          _detailRow('Call resolution', callResolution),
        ],
        if (successEvaluation.isNotEmpty) ...[
          const SizedBox(height: 8),
          _detailRow('Success evaluation', successEvaluation),
        ],
        if (hasAnyCallback) ...[
          const SizedBox(height: 8),
          _detailRow('Callback requested', callbackRequested ? 'Yes' : 'No'),
          _detailRow('Callback time', callbackTime),
          _detailRow('Callback timezone', callbackTimezone),
        ],
        if (hasStructured) ...[
          const SizedBox(height: 12),
          Text('Structured data',
              style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textMuted)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: structured.entries
                .map(
                  (e) => Chip(
                    label: Text(
                      '${e.key}: ${e.value}',
                      style: NeyvoType.labelSmall,
                    ),
                    backgroundColor: NeyvoTheme.teal.withOpacity(0.1),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _performanceSection({
    required dynamic avgLatency,
    required dynamic maxLatency,
    required dynamic interrupts,
    required dynamic msgCount,
  }) {
    final hasAny = avgLatency != null ||
        maxLatency != null ||
        interrupts != null ||
        msgCount != null;
    if (!hasAny) {
      return Text('No performance data',
          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avgLatency != null)
          _detailRow('Avg latency (ms)', avgLatency.toString()),
        if (maxLatency != null)
          _detailRow('Max latency (ms)', maxLatency.toString()),
        if (interrupts != null)
          _detailRow('Interruptions', interrupts.toString()),
        if (msgCount != null)
          _detailRow('Messages count', msgCount.toString()),
      ],
    );
  }

  Widget _conversationList(List<dynamic> messages) {
    if (messages.isEmpty) {
      return Text('No conversation messages',
          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted));
    }
    return Column(
      children: messages.map((e) {
        final map = (e is Map) ? e as Map : <String, dynamic>{};
        final role = (map['role'] ?? 'unknown').toString();
        var msg = (map['content'] ?? map['message'] ?? '').toString();
        if (msg.isEmpty && map['content'] is List) {
          msg = (map['content'] as List).map((x) => x.toString()).join(' ');
        }
        if (msg.isEmpty &&
            (map['tool_calls'] != null || map['toolCalls'] != null)) {
          msg = '[Tool calls]';
        }
        final isUser = role == 'user';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser
                ? NeyvoTheme.bgHover
                : NeyvoTheme.teal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(NeyvoRadius.sm),
            border: Border.all(color: NeyvoTheme.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('[$role] ',
                  style: NeyvoType.labelSmall
                      .copyWith(color: NeyvoTheme.textMuted)),
              Expanded(
                child: SelectableText(
                  msg,
                  style: NeyvoType.bodySmall
                      .copyWith(color: NeyvoTheme.textPrimary),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------- Generic helpers ----------

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NeyvoTheme.textMuted),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: NeyvoType.bodyMedium.copyWith(
                color: valueColor ?? NeyvoTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: NeyvoType.labelSmall.copyWith(
                color: NeyvoTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: NeyvoType.bodySmall
                  .copyWith(color: NeyvoTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
                Icon(icon, size: 20, color: NeyvoTheme.teal),
                const SizedBox(width: 8),
                Text(title,
                    style: NeyvoType.titleMedium
                        .copyWith(color: NeyvoTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
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
