// lib/screens/audit_log_page.dart
// Phase D: Audit log – who did what, when

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
                          final details = e['details'];
                          final createdAt = _formatTime(e['created_at']);
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              title: Text(
                                _formatAction(action),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Resource: $resource${resourceId != null ? ' · $resourceId' : ''}'),
                                  if (userId != null && userId.isNotEmpty)
                                    Text('By: $userId', style: TextStyle(color: NeyvoColors.textSecondary, fontSize: 12)),
                                  Text(createdAt, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  if (details != null && details is Map && details.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        details.toString(),
                                        style: TextStyle(color: Colors.grey[700], fontSize: 11),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
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
