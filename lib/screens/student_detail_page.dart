// lib/screens/student_detail_page.dart
// Enhanced student detail page with payment history, call history, and quick actions

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../../api/spearia_api.dart' show ApiException;
import '../theme/neyvo_theme.dart';

class StudentDetailPage extends StatefulWidget {
  final String studentId;
  final VoidCallback? onUpdated;

  const StudentDetailPage({super.key, required this.studentId, this.onUpdated});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _student;
  List<dynamic> _payments = [];
  List<dynamic> _calls = [];
  String _pastCallsSummary = '';
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _balance = TextEditingController();
  final _dueDate = TextEditingController();
  final _lateFee = TextEditingController();
  final _studentId = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  bool _calling = false;

  List<Map<String, dynamic>> _agents = [];
  String? _selectedAgentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _balance.dispose();
    _dueDate.dispose();
    _lateFee.dispose();
    _studentId.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final studentRes = await NeyvoPulseApi.getStudent(widget.studentId);
      final paymentsRes = await NeyvoPulseApi.listPayments(studentId: widget.studentId);
      final callsRes = await NeyvoPulseApi.listCalls(studentId: widget.studentId);
      List<Map<String, dynamic>> agentsList = [];
      try {
        final agentsRes = await NeyvoPulseApi.listAgents();
        agentsList = (agentsRes['agents'] as List? ?? []).cast<Map<String, dynamic>>();
      } catch (_) {}
      String pastSummary = '';
      List<dynamic> callsList = callsRes['calls'] as List? ?? [];
      try {
        final historyRes = await NeyvoPulseApi.getStudentCallHistory(widget.studentId);
        pastSummary = historyRes['past_calls_summary']?.toString() ?? '';
        final historyCalls = historyRes['calls'] as List? ?? [];
        if (historyCalls.isNotEmpty) callsList = historyCalls;
      } catch (_) {}
      final s = studentRes['student'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _student = s;
          _payments = paymentsRes['payments'] as List? ?? [];
          _calls = callsList;
          _pastCallsSummary = pastSummary;
          _agents = agentsList;
          _selectedAgentId ??= agentsList.isNotEmpty ? (agentsList.first['id'] ?? agentsList.first['agent_id'])?.toString() : null;
          _loading = false;
          _name.text = s['name']?.toString() ?? '';
          _phone.text = s['phone']?.toString() ?? '';
          _email.text = s['email']?.toString() ?? '';
          _balance.text = s['balance']?.toString() ?? '';
          _dueDate.text = s['due_date']?.toString() ?? '';
          _lateFee.text = s['late_fee']?.toString() ?? '';
          _studentId.text = s['student_id']?.toString() ?? '';
          _notes.text = s['notes']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_student == null) return;
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.updateStudent(
        widget.studentId,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        balance: _balance.text.trim().isEmpty ? null : _balance.text.trim(),
        dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
        lateFee: _lateFee.text.trim().isEmpty ? null : _lateFee.text.trim(),
        schoolStudentId: _studentId.text.trim().isEmpty ? null : _studentId.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
        widget.onUpdated?.call();
        _load();
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _call() async {
    final phone = _phone.text.trim();
    final name = _name.text.trim();
    if (phone.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone and name required')));
      return;
    }

    final agentId = (_selectedAgentId ?? (_agents.isNotEmpty ? (_agents.first['id'] ?? _agents.first['agent_id'])?.toString() : null))?.trim();
    if (agentId == null || agentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create/select an agent before calling')));
      return;
    }
    setState(() => _calling = true);
    try {
      final res = await NeyvoPulseApi.startOutboundCall(
        agentId: agentId,
        studentPhone: phone,
        studentName: name,
        studentId: widget.studentId,
        balance: _balance.text.trim().isEmpty ? null : _balance.text.trim(),
        dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
        lateFee: _lateFee.text.trim().isEmpty ? null : _lateFee.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Call started')),
        );
        widget.onUpdated?.call();
        _load();
        setState(() => _calling = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _calling = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _calling = false);
      }
    }
  }

  Future<void> _confirmDeleteStudent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete contact?'),
        content: const Text('This contact and their payment and reach history will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await NeyvoPulseApi.deleteStudent(widget.studentId);
      if (mounted) {
        widget.onUpdated?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact deleted')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addPayment() async {
    final amountC = TextEditingController();
    final methodC = TextEditingController();
    final noteC = TextEditingController();
    
    final navigator = Navigator.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', hintText: '\$100.00'),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: methodC,
                decoration: const InputDecoration(labelText: 'Payment Method', hintText: 'Credit Card, Cash, etc.'),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: noteC,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => navigator.pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (amountC.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount required')));
                return;
              }
              try {
                await NeyvoPulseApi.addPayment(
                  studentId: widget.studentId,
                  amount: amountC.text.trim(),
                  method: methodC.text.trim().isEmpty ? null : methodC.text.trim(),
                  note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
                );
                if (context.mounted) {
                  navigator.pop();
                  _load();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Add Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact')),
        body: Center(child: Text(_error!, style: TextStyle(color: NeyvoColors.error))),
      );
    }
    
    final balance = _balance.text.trim();
    final dueDate = _dueDate.text.trim();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_student?['name']?.toString() ?? 'Contact'),
        actions: [
          IconButton(
            icon: _calling 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.phone),
            onPressed: _calling ? null : _call,
            tooltip: 'Reach out to contact',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') _confirmDeleteStudent();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete contact'))),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details', icon: Icon(Icons.person_outline)),
            Tab(text: 'Payments', icon: Icon(Icons.payment_outlined)),
            Tab(text: 'Calls', icon: Icon(Icons.phone_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Details Tab
          ListView(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            children: [
              // Financial Summary Card
              if (balance.isNotEmpty || dueDate.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Financial Summary', style: NeyvoType.titleLarge),
                        const SizedBox(height: NeyvoSpacing.md),
                        if (balance.isNotEmpty)
                          _InfoRow(label: 'Balance', value: balance, color: NeyvoTheme.accent),
                        if (dueDate.isNotEmpty)
                          _InfoRow(label: 'Due Date', value: dueDate, color: NeyvoColors.info),
                        if (_lateFee.text.trim().isNotEmpty)
                          _InfoRow(label: 'Late Fee', value: _lateFee.text.trim(), color: NeyvoColors.warning),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: NeyvoSpacing.lg),
              
              // Quick Actions
              Text('Quick Actions', style: NeyvoType.titleMedium),
              const SizedBox(height: NeyvoSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: NeyvoSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addPayment,
                      icon: const Icon(Icons.payment),
                      label: const Text('Add Payment'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NeyvoSpacing.xl),
              
              // Edit Form
              Text('Contact information', style: NeyvoType.titleMedium),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _studentId, decoration: const InputDecoration(labelText: 'Student ID (school internal)', hintText: 'Optional')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _balance, decoration: const InputDecoration(labelText: 'Balance')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _dueDate, decoration: const InputDecoration(labelText: 'Due date')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _lateFee, decoration: const InputDecoration(labelText: 'Late fee')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: NeyvoSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Save Changes'),
              ),
            ],
          ),
          
          // Payments Tab
          _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment_outlined, size: 64, color: NeyvoColors.textMuted),
                      const SizedBox(height: NeyvoSpacing.md),
                      Text('No payments yet', style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textMuted)),
                      const SizedBox(height: NeyvoSpacing.lg),
                      FilledButton.icon(
                        onPressed: _addPayment,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Payment'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(NeyvoSpacing.lg),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment History', style: NeyvoType.titleLarge),
                        FilledButton.icon(
                          onPressed: _addPayment,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Payment'),
                        ),
                      ],
                    ),
                    const SizedBox(height: NeyvoSpacing.md),
                    ..._payments.map((p) {
                      final amount = p['amount']?.toString() ?? '—';
                      final method = p['method']?.toString() ?? '';
                      final date = p['created_at']?.toString() ?? p['date']?.toString() ?? '';
                      final note = p['note']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: NeyvoColors.success.withOpacity(0.1),
                            child: Icon(Icons.payment, color: NeyvoColors.success),
                          ),
                          title: Text(amount, style: NeyvoType.titleMedium.copyWith(color: NeyvoColors.success)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (method.isNotEmpty) Text('Method: $method'),
                              if (date.isNotEmpty) Text('Date: $date'),
                              if (note.isNotEmpty) Text(note, style: NeyvoType.bodySmall),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
          
          // Calls Tab (Call History + Past Calls Summary)
          ListView(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Call History', style: NeyvoType.titleLarge),
                  FilledButton.icon(
                    onPressed: _call,
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('New Call'),
                  ),
                ],
              ),
              const SizedBox(height: NeyvoSpacing.md),
              if (_calls.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_outlined, size: 64, color: NeyvoColors.textMuted),
                        const SizedBox(height: NeyvoSpacing.md),
                        Text('No calls yet', style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textMuted)),
                        const SizedBox(height: NeyvoSpacing.lg),
                        FilledButton.icon(
                          onPressed: _call,
                          icon: const Icon(Icons.phone),
                          label: const Text('Start Call'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._calls.map((c) {
                  final status = c['status']?.toString() ?? c['outcome']?.toString() ?? 'unknown';
                  final date = c['date']?.toString() ?? c['created_at']?.toString() ?? '';
                  final duration = c['duration_seconds']?.toString() ?? c['duration']?.toString() ?? '';
                  final outcome = c['outcome']?.toString() ?? status;
                  final agentName = c['agent_name']?.toString() ?? '';
                  final credits = c['credits_charged']?.toString() ?? '';
                  final transcript = c['transcript']?.toString() ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(outcome).withOpacity(0.1),
                        child: Icon(Icons.phone, color: _getStatusColor(outcome)),
                      ),
                      title: Text(outcome.isNotEmpty ? outcome : 'Call', style: NeyvoType.titleMedium),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (date.isNotEmpty) Text('Date: $date'),
                          if (duration.isNotEmpty) Text('Duration: ${duration}s'),
                          if (agentName.isNotEmpty) Text('Agent: $agentName'),
                          if (credits.isNotEmpty) Text('Credits: $credits'),
                        ],
                      ),
                      children: [
                        if (transcript.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(NeyvoSpacing.md),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(NeyvoSpacing.md),
                              decoration: BoxDecoration(
                                color: NeyvoColors.bgRaised,
                                borderRadius: BorderRadius.circular(NeyvoRadius.sm),
                              ),
                              child: Text(transcript, style: NeyvoType.bodySmall),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: NeyvoSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(NeyvoSpacing.md),
                decoration: BoxDecoration(
                  color: NeyvoColors.bgRaised,
                  border: Border.all(color: NeyvoColors.borderDefault),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Past Calls Summary (injected into next call):',
                      style: NeyvoType.labelSmall.copyWith(color: NeyvoColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _pastCallsSummary.isEmpty
                          ? 'No previous calls yet. This will fill after the first call.'
                          : _pastCallsSummary,
                      style: NeyvoType.bodySmall.copyWith(
                        color: NeyvoColors.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return NeyvoColors.success;
      case 'failed':
      case 'error':
        return NeyvoColors.error;
      case 'pending':
        return NeyvoColors.warning;
      default:
        return NeyvoColors.textMuted;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textSecondary)),
          Text(value, style: NeyvoType.titleMedium.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
