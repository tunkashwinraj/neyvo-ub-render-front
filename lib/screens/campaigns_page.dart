// lib/screens/campaigns_page.dart
// Campaigns: bulk outbound calls with filters, templates, and scheduling (like ad campaigns).

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../../theme/spearia_theme.dart';

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  String? _error;
  bool _showCreateWizard = false;
  int _wizardStep = 0;
  String? _selectedCampaignId;
  int _campaignDetailRefreshKey = 0;
  String? _editingCampaignId;
  Map<String, dynamic>? _editCampaignData;

  // Wizard state
  final _nameController = TextEditingController();
  String _filterType = 'all'; // all, balance_above, balance_below, has_due_date, overdue
  final _balanceMinController = TextEditingController();
  final _balanceMaxController = TextEditingController();
  bool _filterOverdueOnly = false;
  String? _selectedTemplateId;
  DateTime? _scheduledAt;
  bool _scheduleNow = true;
  Set<String> _selectedStudentIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceMinController.dispose();
    _balanceMaxController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final studentsRes = await NeyvoPulseApi.listStudents();
      final studentsList = studentsRes['students'] as List? ?? [];
      _students = studentsList.cast<Map<String, dynamic>>();
      _templates = await _loadTemplates();
      _campaigns = await _loadCampaigns();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
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
      if (_selectedStudentIds.contains(id)) {
        _selectedStudentIds.remove(id);
      } else {
        _selectedStudentIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
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
    final ids = _selectedStudentIds.isEmpty
        ? _filteredStudents.map((s) => s['id'] as String? ?? '').where((e) => e.isNotEmpty).toList()
        : _selectedStudentIds.toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students selected')));
      return;
    }
    if (_editingCampaignId != null) {
      await _saveCampaignEdit(name: name, studentIds: ids);
      return;
    }
    try {
      await NeyvoPulseApi.createCampaign(
        name: name,
        studentIds: ids,
        templateId: _selectedTemplateId,
        scheduledAt: _scheduleNow ? null : _scheduledAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign "$name" created for ${ids.length} students'), backgroundColor: SpeariaAura.success),
        );
        setState(() {
          _showCreateWizard = false;
          _wizardStep = 0;
          _nameController.clear();
          _selectedStudentIds.clear();
          _selectAll = false;
        });
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: SpeariaAura.error));
      }
    }
  }

  Future<void> _startOrRerunCampaign(Map<String, dynamic> c) async {
    final id = c['id']?.toString();
    if (id == null) return;
    final isRerun = c['status'] == 'completed' || c['status'] == 'running';
    try {
      final res = await NeyvoPulseApi.startCampaign(id);
      if (mounted) {
        final initiated = res['total_initiated'] ?? 0;
        final failed = res['total_failed'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isRerun
                ? 'Rerun started. $initiated call(s) placed.${failed > 0 ? ' $failed failed.' : ''}'
                : 'Campaign started. $initiated call(s) placed.${failed > 0 ? ' $failed failed.' : ''}'),
            backgroundColor: SpeariaAura.success,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: SpeariaAura.error));
    }
  }

  Future<void> _saveCampaignEdit({required String name, required List<String> studentIds}) async {
    final id = _editingCampaignId!;
    try {
      await NeyvoPulseApi.updateCampaign(
        id,
        name: name,
        templateId: _selectedTemplateId,
        studentIds: studentIds,
        scheduledAt: _scheduleNow ? null : _scheduledAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign updated'), backgroundColor: SpeariaAura.success),
        );
        setState(() {
          _editingCampaignId = null;
          _editCampaignData = null;
          _showCreateWizard = false;
          _wizardStep = 0;
          _nameController.clear();
          _selectedStudentIds.clear();
          _selectAll = false;
        });
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: SpeariaAura.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _campaigns.isEmpty && _selectedCampaignId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showCreateWizard) {
      return _buildWizard();
    }

    if (_selectedCampaignId != null) {
      return _buildCampaignDetailScreen(_selectedCampaignId!);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpeariaSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(_error!, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error)),
            const SizedBox(height: SpeariaSpacing.md),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Launch bulk call campaigns (e.g. 500, 1K, 10K calls) by audience and script.',
                style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
              ),
              FilledButton.icon(
                onPressed: () => setState(() {
                  _showCreateWizard = true;
                  _wizardStep = 0;
                  _nameController.clear();
                  _selectedStudentIds.clear();
                }),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Create campaign'),
              ),
            ],
          ),
          const SizedBox(height: SpeariaSpacing.xl),
          Text('Recent campaigns', style: SpeariaType.titleLarge),
          const SizedBox(height: SpeariaSpacing.md),
          if (_campaigns.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.campaign_outlined, size: 48, color: SpeariaAura.textMuted),
                      const SizedBox(height: SpeariaSpacing.md),
                      Text('No campaigns yet', style: SpeariaType.bodyLarge.copyWith(color: SpeariaAura.textSecondary)),
                      const SizedBox(height: SpeariaSpacing.sm),
                      TextButton.icon(
                        onPressed: () => setState(() => _showCreateWizard = true),
                        icon: const Icon(Icons.add),
                        label: const Text('Create your first campaign'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._campaigns.map((c) => Card(
                  margin: const EdgeInsets.only(bottom: SpeariaSpacing.md),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                    title: Text(c['name']?.toString() ?? 'Unnamed'),
                    subtitle: Text(
                      '${c['total_planned'] ?? c['student_count'] ?? 0} students • ${c['status'] ?? 'draft'}${(c['total_initiated'] ?? 0) > 0 ? ' • ${c['total_initiated']} placed' : ''}',
                      style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
                    ),
                    onTap: () => setState(() => _selectedCampaignId = c['id']?.toString()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          tooltip: 'View & manage',
                          onPressed: () => setState(() => _selectedCampaignId = c['id']?.toString()),
                        ),
                        if (c['status'] == 'draft' || c['status'] == 'scheduled')
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Start campaign',
                            onPressed: () => _startOrRerunCampaign(c),
                          ),
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
    );
  }

  Widget _buildCampaignDetailScreen(String campaignId) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('campaign_detail_${campaignId}_$_campaignDetailRefreshKey'),
      future: Future.wait([
        NeyvoPulseApi.getCampaign(campaignId),
        NeyvoPulseApi.getCampaignCalls(campaignId),
      ]).then((list) => {'campaign': list[0]['campaign'], 'calls': (list[1]['calls'] as List?) ?? []}),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedCampaignId = null),
              ),
              title: const Text('Campaign details'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        final c = data['campaign'] as Map<String, dynamic>? ?? {};
        final calls = (data['calls'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedCampaignId = null),
            ),
            title: const Text('Campaign details'),
            actions: [
              if (canEdit)
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Edit'),
                  onPressed: () {
                    _nameController.text = c['name']?.toString() ?? '';
                    _selectedTemplateId = c['template_id']?.toString();
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
              if (canStart)
                TextButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Start campaign'),
                  onPressed: () async {
                    try {
                      final res = await NeyvoPulseApi.startCampaign(campaignId);
                      if (mounted) {
                        final initiated = res['total_initiated'] ?? 0;
                        final failed = res['total_failed'] ?? 0;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$initiated call(s) placed.${failed > 0 ? ' $failed failed.' : ''}'),
                            backgroundColor: SpeariaAura.success,
                          ),
                        );
                        setState(() => _campaignDetailRefreshKey++);
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: SpeariaAura.error));
                    }
                  },
                ),
              if (canRerun)
                TextButton.icon(
                  icon: const Icon(Icons.replay, size: 20),
                  label: const Text('Rerun campaign'),
                  onPressed: () async {
                    try {
                      final res = await NeyvoPulseApi.startCampaign(campaignId);
                      if (mounted) {
                        final initiated = res['total_initiated'] ?? 0;
                        final failed = res['total_failed'] ?? 0;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rerun started. $initiated call(s) placed.${failed > 0 ? ' $failed failed.' : ''}'),
                            backgroundColor: SpeariaAura.success,
                          ),
                        );
                        setState(() => _campaignDetailRefreshKey++);
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: SpeariaAura.error));
                    }
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(SpeariaSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(SpeariaSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['name']?.toString() ?? 'Unnamed', style: SpeariaType.titleLarge),
                        const SizedBox(height: SpeariaSpacing.md),
                        Wrap(
                          spacing: SpeariaSpacing.lg,
                          runSpacing: SpeariaSpacing.sm,
                          children: [
                            _detailChip('Status', status),
                            _detailChip('Planned', '${c['total_planned'] ?? 0}'),
                            _detailChip('Placed', '${c['total_initiated'] ?? 0}'),
                            _detailChip('Failed', '${c['total_failed'] ?? 0}'),
                          ],
                        ),
                        const Divider(height: SpeariaSpacing.xl),
                        ListTile(title: const Text('Created'), trailing: Text(formatDate(created))),
                        ListTile(title: const Text('Started'), trailing: Text(formatDate(started))),
                        ListTile(title: const Text('Script template'), trailing: Text(templateName ?? '—')),
                        if ((c['filters'] ?? c['student_ids']) != null)
                          ListTile(
                            title: const Text('Audience'),
                            subtitle: Text(
                              c['student_ids'] != null
                                  ? '${(c['student_ids'] as List).length} students selected'
                                  : 'Filters: ${c['filters']?.toString() ?? '—'}',
                              style: SpeariaType.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.xl),
                Text('Calls (${calls.length})', style: SpeariaType.titleMedium),
                const SizedBox(height: SpeariaSpacing.sm),
                if (calls.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(SpeariaSpacing.lg),
                    child: Text('No calls yet. Start the campaign to place calls.', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary)),
                  )
                else
                  ...calls.take(50).map((call) => Card(
                        margin: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
                        child: ListTile(
                          leading: Icon(Icons.phone_outlined, color: SpeariaAura.primary),
                          title: Text(call['student_name']?.toString() ?? '—'),
                          subtitle: Text('${call['student_phone'] ?? '—'} • ${call['status'] ?? '—'}'),
                          trailing: Text(formatDate(call['created_at']), style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
                        ),
                      )),
                if (calls.length > 50)
                  Padding(
                    padding: const EdgeInsets.only(top: SpeariaSpacing.sm),
                    child: Text('Showing first 50 of ${calls.length} calls', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
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
      label: Text('$label: $value', style: SpeariaType.labelSmall),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildWizard() {
    final steps = ['Name & goal', 'Audience', 'Script', 'Schedule', 'Review'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpeariaSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _showCreateWizard = false;
                  _wizardStep = 0;
                  _editingCampaignId = null;
                  _editCampaignData = null;
                }),
              ),
              Text(_editingCampaignId != null ? 'Edit campaign' : 'Create campaign', style: SpeariaType.headlineMedium),
            ],
          ),
          const SizedBox(height: SpeariaSpacing.lg),
          // Step indicator
          Row(
            children: List.generate(steps.length, (i) {
              final active = i == _wizardStep;
              final done = i < _wizardStep;
              return Expanded(
                child: Row(
                  children: [
                    if (i > 0) Expanded(child: Divider(color: done ? SpeariaAura.primary : SpeariaAura.border)),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: active ? SpeariaAura.primary : (done ? SpeariaAura.primary : SpeariaAura.bgDark),
                      child: Text('${i + 1}', style: TextStyle(color: active || done ? Colors.white : SpeariaAura.textMuted, fontSize: 12)),
                    ),
                    if (i < steps.length - 1) Expanded(child: Divider(color: done ? SpeariaAura.primary : SpeariaAura.border)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: SpeariaSpacing.sm),
          Center(child: Text(steps[_wizardStep], style: SpeariaType.titleMedium.copyWith(color: SpeariaAura.textSecondary))),
          const SizedBox(height: SpeariaSpacing.xl),
          if (_wizardStep == 0) _stepName(),
          if (_wizardStep == 1) _stepAudience(),
          if (_wizardStep == 2) _stepScript(),
          if (_wizardStep == 3) _stepSchedule(),
          if (_wizardStep == 4) _stepReview(),
          const SizedBox(height: SpeariaSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_wizardStep > 0)
                TextButton(
                  onPressed: () => setState(() => _wizardStep--),
                  child: const Text('Back'),
                ),
              const SizedBox(width: SpeariaSpacing.md),
              FilledButton(
                onPressed: () {
                  if (_wizardStep < steps.length - 1) {
                    setState(() => _wizardStep++);
                  } else {
                    _launchCampaign();
                  }
                },
                child: Text(_wizardStep == steps.length - 1
                    ? (_editingCampaignId != null ? 'Save changes' : 'Launch campaign')
                    : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepName() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
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
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter audience', style: SpeariaType.titleMedium),
            const SizedBox(height: SpeariaSpacing.md),
            DropdownButtonFormField<String>(
              value: _filterType,
              decoration: const InputDecoration(labelText: 'Filter by'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All students')),
                DropdownMenuItem(value: 'balance_above', child: Text('Balance above amount')),
                DropdownMenuItem(value: 'balance_below', child: Text('Balance below amount')),
                DropdownMenuItem(value: 'has_due_date', child: Text('Has due date')),
              ],
              onChanged: (v) => setState(() => _filterType = v ?? 'all'),
            ),
            if (_filterType == 'balance_above') ...[
              const SizedBox(height: SpeariaSpacing.md),
              TextField(
                controller: _balanceMinController,
                decoration: const InputDecoration(labelText: 'Min balance (\$)'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_filterType == 'balance_below') ...[
              const SizedBox(height: SpeariaSpacing.md),
              TextField(
                controller: _balanceMaxController,
                decoration: const InputDecoration(labelText: 'Max balance (\$)'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: SpeariaSpacing.md),
            CheckboxListTile(
              title: const Text('Only students with due date'),
              value: _filterOverdueOnly,
              onChanged: (v) => setState(() => _filterOverdueOnly = v ?? false),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${filtered.length} students match', style: SpeariaType.bodyMedium),
                TextButton.icon(
                  onPressed: _toggleSelectAll,
                  icon: Icon(_selectAll ? Icons.deselect : Icons.select_all, size: 18),
                  label: Text(_selectAll ? 'Deselect all' : 'Select all'),
                ),
              ],
            ),
            const SizedBox(height: SpeariaSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final s = filtered[i];
                  final id = s['id'] as String? ?? '';
                  final selected = _selectedStudentIds.isEmpty || _selectedStudentIds.contains(id);
                  return CheckboxListTile(
                    title: Text(s['name']?.toString() ?? '—'),
                    subtitle: Text('${s['phone'] ?? ''} • ${s['balance'] ?? ''}'),
                    value: selected,
                    onChanged: (v) => _toggleStudent(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepScript() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conversation script', style: SpeariaType.titleMedium),
            const SizedBox(height: SpeariaSpacing.sm),
            Text(
              'Choose the script the assistant will use for this campaign.',
              style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
            ),
            const SizedBox(height: SpeariaSpacing.md),
            if (_templates.isEmpty)
              Text('No templates yet. Create one in Scripts.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted))
            else
              DropdownButtonFormField<String>(
                value: _selectedTemplateId ?? (_templates.isNotEmpty ? _templates.first['id']?.toString() : null),
                decoration: const InputDecoration(labelText: 'Template'),
                items: _templates.map((t) => DropdownMenuItem(value: t['id']?.toString(), child: Text(t['name']?.toString() ?? 'Unnamed'))).toList(),
                onChanged: (v) => setState(() => _selectedTemplateId = v),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepSchedule() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule', style: SpeariaType.titleMedium),
            const SizedBox(height: SpeariaSpacing.md),
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
    final count = _selectedStudentIds.isEmpty ? _filteredStudents.length : _selectedStudentIds.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review', style: SpeariaType.titleMedium),
            const SizedBox(height: SpeariaSpacing.md),
            ListTile(title: const Text('Campaign name'), trailing: Text(_nameController.text.trim().isEmpty ? '—' : _nameController.text.trim())),
            ListTile(title: const Text('Audience'), trailing: Text('$count students')),
            ListTile(
              title: const Text('Script'),
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
