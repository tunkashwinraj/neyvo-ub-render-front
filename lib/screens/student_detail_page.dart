// lib/screens/student_detail_page.dart
// Enhanced student detail page with payment history, call history, and quick actions

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../../api/spearia_api.dart' show ApiException;
import '../../theme/spearia_theme.dart';

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
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _balance = TextEditingController();
  final _dueDate = TextEditingController();
  final _lateFee = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  bool _calling = false;

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
      
      final s = studentRes['student'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _student = s;
          _payments = paymentsRes['payments'] as List? ?? [];
          _calls = callsRes['calls'] as List? ?? [];
          _loading = false;
          _name.text = s['name']?.toString() ?? '';
          _phone.text = s['phone']?.toString() ?? '';
          _email.text = s['email']?.toString() ?? '';
          _balance.text = s['balance']?.toString() ?? '';
          _dueDate.text = s['due_date']?.toString() ?? '';
          _lateFee.text = s['late_fee']?.toString() ?? '';
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
    setState(() => _calling = true);
    try {
      final res = await NeyvoPulseApi.startOutboundCall(
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
              const SizedBox(height: SpeariaSpacing.md),
              TextField(
                controller: methodC,
                decoration: const InputDecoration(labelText: 'Payment Method', hintText: 'Credit Card, Cash, etc.'),
              ),
              const SizedBox(height: SpeariaSpacing.md),
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
        appBar: AppBar(title: const Text('Student')),
        body: Center(child: Text(_error!, style: TextStyle(color: SpeariaAura.error))),
      );
    }
    
    final balance = _balance.text.trim();
    final dueDate = _dueDate.text.trim();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_student?['name']?.toString() ?? 'Student'),
        actions: [
          IconButton(
            icon: _calling 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.phone),
            onPressed: _calling ? null : _call,
            tooltip: 'Call Student',
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
            padding: const EdgeInsets.all(SpeariaSpacing.lg),
            children: [
              // Financial Summary Card
              if (balance.isNotEmpty || dueDate.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(SpeariaSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Financial Summary', style: SpeariaType.titleLarge),
                        const SizedBox(height: SpeariaSpacing.md),
                        if (balance.isNotEmpty)
                          _InfoRow(label: 'Balance', value: balance, color: SpeariaAura.accent),
                        if (dueDate.isNotEmpty)
                          _InfoRow(label: 'Due Date', value: dueDate, color: SpeariaAura.info),
                        if (_lateFee.text.trim().isNotEmpty)
                          _InfoRow(label: 'Late Fee', value: _lateFee.text.trim(), color: SpeariaAura.warning),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: SpeariaSpacing.lg),
              
              // Quick Actions
              Text('Quick Actions', style: SpeariaType.titleMedium),
              const SizedBox(height: SpeariaSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: SpeariaSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addPayment,
                      icon: const Icon(Icons.payment),
                      label: const Text('Add Payment'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpeariaSpacing.xl),
              
              // Edit Form
              Text('Student Information', style: SpeariaType.titleMedium),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: _balance, decoration: const InputDecoration(labelText: 'Balance')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: _dueDate, decoration: const InputDecoration(labelText: 'Due date')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: _lateFee, decoration: const InputDecoration(labelText: 'Late fee')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: SpeariaSpacing.xl),
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
                      Icon(Icons.payment_outlined, size: 64, color: SpeariaAura.textMuted),
                      const SizedBox(height: SpeariaSpacing.md),
                      Text('No payments yet', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
                      const SizedBox(height: SpeariaSpacing.lg),
                      FilledButton.icon(
                        onPressed: _addPayment,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Payment'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(SpeariaSpacing.lg),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment History', style: SpeariaType.titleLarge),
                        FilledButton.icon(
                          onPressed: _addPayment,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Payment'),
                        ),
                      ],
                    ),
                    const SizedBox(height: SpeariaSpacing.md),
                    ..._payments.map((p) {
                      final amount = p['amount']?.toString() ?? '—';
                      final method = p['method']?.toString() ?? '';
                      final date = p['created_at']?.toString() ?? p['date']?.toString() ?? '';
                      final note = p['note']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: SpeariaAura.success.withOpacity(0.1),
                            child: Icon(Icons.payment, color: SpeariaAura.success),
                          ),
                          title: Text(amount, style: SpeariaType.titleMedium.copyWith(color: SpeariaAura.success)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (method.isNotEmpty) Text('Method: $method'),
                              if (date.isNotEmpty) Text('Date: $date'),
                              if (note.isNotEmpty) Text(note, style: SpeariaType.bodySmall),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
          
          // Calls Tab
          _calls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_outlined, size: 64, color: SpeariaAura.textMuted),
                      const SizedBox(height: SpeariaSpacing.md),
                      Text('No calls yet', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
                      const SizedBox(height: SpeariaSpacing.lg),
                      FilledButton.icon(
                        onPressed: _call,
                        icon: const Icon(Icons.phone),
                        label: const Text('Start Call'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(SpeariaSpacing.lg),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Call History', style: SpeariaType.titleLarge),
                        FilledButton.icon(
                          onPressed: _call,
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('New Call'),
                        ),
                      ],
                    ),
                    const SizedBox(height: SpeariaSpacing.md),
                    ..._calls.map((c) {
                      final status = c['status']?.toString() ?? 'unknown';
                      final date = c['created_at']?.toString() ?? c['date']?.toString() ?? '';
                      final duration = c['duration']?.toString() ?? '';
                      final transcript = c['transcript']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(status).withOpacity(0.1),
                            child: Icon(Icons.phone, color: _getStatusColor(status)),
                          ),
                          title: Text('Call ${status}', style: SpeariaType.titleMedium),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (date.isNotEmpty) Text('Date: $date'),
                              if (duration.isNotEmpty) Text('Duration: $duration'),
                            ],
                          ),
                          children: [
                            if (transcript.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(SpeariaSpacing.md),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(SpeariaSpacing.md),
                                  decoration: BoxDecoration(
                                    color: SpeariaAura.bgDark,
                                    borderRadius: BorderRadius.circular(SpeariaRadius.sm),
                                  ),
                                  child: Text(
                                    transcript,
                                    style: SpeariaType.bodySmall,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
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
        return SpeariaAura.success;
      case 'failed':
      case 'error':
        return SpeariaAura.error;
      case 'pending':
        return SpeariaAura.warning;
      default:
        return SpeariaAura.textMuted;
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
      padding: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary)),
          Text(value, style: SpeariaType.titleMedium.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
