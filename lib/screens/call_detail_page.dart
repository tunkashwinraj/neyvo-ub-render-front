// lib/screens/call_detail_page.dart
// Full call details: student, status, duration, transcript, recording, outcome, attribution.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/spearia_theme.dart';

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
    return d?.isNotEmpty == true ? d : '—';
  }

  static String formatDate(dynamic v) {
    if (v == null) return '—';
    if (v is String) return v.length > 19 ? v.substring(0, 19).replaceAll('T', ' ') : v;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final status = call['status']?.toString() ?? '—';
    final studentName = call['student_name']?.toString() ?? 'Unknown';
    final studentPhone = call['student_phone']?.toString() ?? '—';
    final studentId = call['student_id']?.toString() ?? '—';
    final created = call['created_at'];
    final ended = call['ended_at'];
    final durationStr = formatDuration(call);
    final transcript = call['transcript']?.toString() ?? '';
    final recordingUrl = call['recording_url']?.toString();
    final outcomeType = call['outcome_type']?.toString() ?? '—';
    final successMetric = call['success_metric']?.toString();
    final attributedPaymentId = call['attributed_payment_id']?.toString();
    final attributedPaymentAmount = call['attributed_payment_amount']?.toString();
    final attributedPaymentAt = call['attributed_payment_at']?.toString();
    final campaignId = call['campaign_id']?.toString();
    final vapiCallId = call['vapi_call_id']?.toString();
    final callId = call['id']?.toString() ?? '—';

    Color statusColor = SpeariaAura.textMuted;
    if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'success') statusColor = SpeariaAura.success;
    else if (status.toLowerCase() == 'failed' || status.toLowerCase() == 'error') statusColor = SpeariaAura.error;
    else if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'ringing') statusColor = SpeariaAura.warning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reach details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reach summary', style: SpeariaType.titleLarge),
                    const SizedBox(height: SpeariaSpacing.md),
                    _row('Reach ID', callId),
                    _row('Contact', studentName),
                    _row('Phone', studentPhone),
                    _row('Contact ID', studentId),
                    _row('Status', status, valueColor: statusColor),
                    _row('Duration', durationStr),
                    _row('Started', formatDate(created)),
                    _row('Ended', formatDate(ended)),
                    if (outcomeType != '—') _row('Outcome', outcomeType.replaceAll('_', ' ')),
                    if (vapiCallId != null && vapiCallId.isNotEmpty) _row('VAPI call ID', vapiCallId),
                    if (campaignId != null && campaignId.isNotEmpty) _row('Campaign ID', campaignId),
                  ],
                ),
              ),
            ),
            if (successMetric != null && successMetric.isNotEmpty) ...[
              const SizedBox(height: SpeariaSpacing.lg),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
                child: Padding(
                  padding: const EdgeInsets.all(SpeariaSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Resolution', style: SpeariaType.titleLarge),
                      const SizedBox(height: SpeariaSpacing.md),
                      _row('Success metric', successMetric.replaceAll('_', ' '), valueColor: SpeariaAura.success),
                      if (attributedPaymentAmount != null && attributedPaymentAmount.isNotEmpty)
                        _row('Attributed payment', attributedPaymentAmount),
                      if (attributedPaymentAt != null && attributedPaymentAt.isNotEmpty)
                        _row('Attributed at', formatDate(attributedPaymentAt)),
                      if (attributedPaymentId != null && attributedPaymentId.isNotEmpty)
                        _row('Payment ID', attributedPaymentId),
                    ],
                  ),
                ),
              ),
            ],
            if (recordingUrl != null && recordingUrl.isNotEmpty) ...[
              const SizedBox(height: SpeariaSpacing.lg),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
                child: ListTile(
                  leading: Icon(Icons.audiotrack, color: SpeariaAura.primary),
                  title: const Text('Recording'),
                  subtitle: const Text('Tap to open recording'),
                  onTap: () async {
                    final uri = Uri.tryParse(recordingUrl);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: SpeariaSpacing.lg),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transcript', style: SpeariaType.titleLarge),
                    const SizedBox(height: SpeariaSpacing.md),
                    if (transcript.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(SpeariaSpacing.md),
                        decoration: BoxDecoration(
                          color: SpeariaAura.bgDark,
                          borderRadius: BorderRadius.circular(SpeariaRadius.sm),
                        ),
                        child: SelectableText(transcript, style: SpeariaType.bodyMedium),
                      )
                    else
                      Text('No transcript available', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SpeariaSpacing.xl),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Raw data', style: SpeariaType.titleMedium.copyWith(color: SpeariaAura.textSecondary)),
                    const SizedBox(height: SpeariaSpacing.sm),
                    SelectableText(
                      _prettyMap(call),
                      style: SpeariaType.bodySmall.copyWith(fontFamily: 'monospace'),
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

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted))),
          Expanded(
            child: Text(
              value,
              style: SpeariaType.bodyMedium.copyWith(color: valueColor ?? SpeariaAura.textPrimary),
            ),
          ),
        ],
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
