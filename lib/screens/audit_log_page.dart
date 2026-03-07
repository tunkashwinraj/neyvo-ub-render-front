// lib/screens/audit_log_page.dart
// Phase D: Audit log – who did what, when (old UI style, expandable details)

import 'dart:convert';

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<dynamic> _entries = [];
  bool _loading = true;
  String? _error;
  String? _filterResource;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NeyvoPulseApi.getAuditLog(
        resource: _filterResource,
        limit: 200,
      );
      final list = res['entries'] as List? ?? [];
      if (mounted) {
        setState(() {
          _entries = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatAction(String? action) {
    if (action == null || action.isEmpty) return '—';
    return action
        .replaceAll('.', ' ')
        .split(' ')
        .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  String _formatTime(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.length > 19) return s.substring(0, 19).replaceFirst('T', ' ');
    return s;
  }

  /// Format details as readable key-value pairs (old UI style, but full content).
  String _formatDetails(dynamic details) {
    if (details == null) return '';
    if (details is Map) {
      final buf = StringBuffer();
      for (final e in details.entries) {
        final k = e.key.toString();
        final v = e.value;
        String vStr;
        if (v is Map || v is List) {
          try {
            vStr = const JsonEncoder.withIndent('  ').convert(v);
          } catch (_) {
            vStr = v.toString();
          }
        } else {
          vStr = v?.toString() ?? 'null';
        }
        if (buf.isNotEmpty) buf.write('\n');
        buf.write('$k: $vStr');
      }
      return buf.toString();
    }
    return details.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit log'),
        actions: [
          if (_filterResource != null)
            TextButton(
              onPressed: () {
                setState(() => _filterResource = null);
                _load();
              },
              child: const Text('Clear filter'),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterResource = value.isEmpty ? null : value);
              _load();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '', child: Text('All resources')),
              const PopupMenuItem(value: 'student', child: Text('Students')),
              const PopupMenuItem(value: 'payment', child: Text('Payments')),
              const PopupMenuItem(value: 'faq', child: Text('FAQ')),
              const PopupMenuItem(value: 'policy', child: Text('Policy')),
              const PopupMenuItem(value: 'campaign', child: Text('Campaigns')),
              const PopupMenuItem(value: 'integration', child: Text('Integration')),
              const PopupMenuItem(value: 'integration_config', child: Text('Integration config')),
              const PopupMenuItem(value: 'call_template', child: Text('Call templates')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _entries.isEmpty
                  ? const Center(child: Text('No audit entries yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _entries.length,
                        itemBuilder: (context, i) {
                          final e = _entries[i] as Map<String, dynamic>;
                          final action = e['action']?.toString() ?? '—';
                          final resource = e['resource']?.toString() ?? '—';
                          final resourceId = e['resource_id']?.toString();
                          final userId = e['user_id']?.toString();
                          final entryId = e['id']?.toString();
                          final details = e['details'];
                          final createdAt = _formatTime(e['created_at']);
                          final hasDetails = details != null &&
                              ((details is Map && details.isNotEmpty) ||
                                  (details is! Map && details.toString().isNotEmpty));
                          final canExpand = hasDetails || (entryId != null && entryId.isNotEmpty);

                          Widget tileContent = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Resource: $resource${resourceId != null ? ' · $resourceId' : ''}',
                                style: TextStyle(color: NeyvoColors.textSecondary, fontSize: 13),
                              ),
                              if (userId != null && userId.isNotEmpty)
                                Text(
                                  'By: $userId',
                                  style: TextStyle(color: NeyvoColors.textMuted, fontSize: 12),
                                ),
                              Text(
                                createdAt,
                                style: TextStyle(color: NeyvoColors.textMuted, fontSize: 12),
                              ),
                              if (hasDetails)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _formatDetails(details),
                                    style: TextStyle(color: NeyvoColors.textMuted, fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: canExpand
                                ? ExpansionTile(
                                    initiallyExpanded: false,
                                    leading: Icon(
                                      Icons.expand_more,
                                      color: NeyvoColors.textMuted,
                                    ),
                                    title: Text(
                                      _formatAction(action),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: tileContent,
                                    ),
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (entryId != null && entryId.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Text(
                                                  'Entry ID: $entryId',
                                                  style: TextStyle(
                                                    color: NeyvoColors.textMuted,
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ),
                                            if (hasDetails) ...[
                                              Text(
                                                'Details',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  color: NeyvoColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: NeyvoColors.bgOverlay,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: NeyvoColors.borderSubtle),
                                                ),
                                                child: SelectableText(
                                                  _formatDetails(details),
                                                  style: TextStyle(
                                                    color: NeyvoColors.textPrimary,
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : ListTile(
                                    leading: Icon(Icons.history, color: NeyvoColors.textMuted),
                                    title: Text(
                                      _formatAction(action),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: tileContent,
                                    ),
                                    isThreeLine: true,
                                  ),
                          );
                        },
                      ),
                    ),
    );
  }
}
