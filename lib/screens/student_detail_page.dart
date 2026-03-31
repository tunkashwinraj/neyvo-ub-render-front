// lib/screens/student_detail_page.dart
// Enhanced student detail page with payment history, call history, and quick actions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/student_detail_provider.dart';
import '../services/user_timezone_service.dart';
import '../../api/spearia_api.dart' show ApiException;
import '../theme/neyvo_theme.dart';
import '../utils/callback_date_format.dart';
import '../utils/phone_util.dart';
import 'call_detail_page.dart';

class StudentDetailPage extends ConsumerStatefulWidget {
  final String studentId;
  final VoidCallback? onUpdated;

  const StudentDetailPage({super.key, required this.studentId, this.onUpdated});

  @override
  ConsumerState<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends ConsumerState<StudentDetailPage> with SingleTickerProviderStateMixin {
  String? _syncSig;
  late TabController _tabController;
  
  final _name = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _advisorName = TextEditingController();
  final _bookingUrl = TextEditingController();
  final _balance = TextEditingController();
  final _dueDate = TextEditingController();
  final _lateFee = TextEditingController();
  final _studentId = TextEditingController();
  final _notes = TextEditingController();
  Map<String, TextEditingController> _customFieldControllers = {};
  final _newFieldKey = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _advisorName.dispose();
    _bookingUrl.dispose();
    _balance.dispose();
    _dueDate.dispose();
    _lateFee.dispose();
    _studentId.dispose();
    _notes.dispose();
    _newFieldKey.dispose();
    for (final c in _customFieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers(StudentDetailUiState ui) {
    final s = ui.student;
    if (s == null) return;
    final sig = '${s['updated_at'] ?? s['id'] ?? ''}|${(s['custom_fields'] as Map?)?.length ?? 0}';
    if (_syncSig == sig) return;
    _syncSig = sig;
    _name.text = s['name']?.toString() ?? '';
    _firstName.text = s['first_name']?.toString() ?? (_name.text);
    _lastName.text = s['last_name']?.toString() ?? '';
    _phone.text = s['phone']?.toString() ?? '';
    _email.text = s['email']?.toString() ?? '';
    _advisorName.text = s['advisor_name']?.toString() ?? '';
    _bookingUrl.text = s['booking_url']?.toString() ?? '';
    _balance.text = s['balance']?.toString() ?? '';
    _dueDate.text = s['due_date']?.toString() ?? '';
    _lateFee.text = s['late_fee']?.toString() ?? '';
    _studentId.text = s['student_id']?.toString() ?? '';
    _notes.text = s['notes']?.toString() ?? '';
    for (final c in _customFieldControllers.values) {
      c.dispose();
    }
    _customFieldControllers = {};
    final custom = (s['custom_fields'] as Map?)?.cast<String, dynamic>() ?? {};
    custom.forEach((key, value) {
      _customFieldControllers[key] = TextEditingController(text: value?.toString() ?? '');
    });
  }

  Future<void> _cancelCallbackIfAny() async {
    final ui = ref.read(studentDetailCtrlProvider(widget.studentId));
    if (ui.student == null) return;
    final status = (ui.student!['callback_status'] ?? '').toString().toLowerCase();
    if (status.isEmpty || status == 'canceled' || status == 'completed' || status == 'exhausted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active callback to cancel.')),
      );
      return;
    }
    try {
      await ref.read(studentDetailCtrlProvider(widget.studentId).notifier).cancelCallback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Callback cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {}
  }

  Future<void> _save() async {
    final ui = ref.read(studentDetailCtrlProvider(widget.studentId));
    if (ui.student == null) return;
    try {
      await ref.read(studentDetailCtrlProvider(widget.studentId).notifier).saveStudent(
        name: _name.text.trim(),
        firstName: _firstName.text.trim().isNotEmpty ? _firstName.text.trim() : null,
        lastName: _lastName.text.trim().isNotEmpty ? _lastName.text.trim() : null,
        phone: normalizePhoneInput(_phone.text.trim()),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        advisorName: _advisorName.text.trim().isEmpty ? null : _advisorName.text.trim(),
        bookingUrl: _bookingUrl.text.trim().isEmpty ? null : _bookingUrl.text.trim(),
        balance: _balance.text.trim().isEmpty ? null : _balance.text.trim(),
        dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
        lateFee: _lateFee.text.trim().isEmpty ? null : _lateFee.text.trim(),
        schoolStudentId: _studentId.text.trim().isEmpty ? null : _studentId.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        customFields: _buildCustomFieldsPayload(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Map<String, dynamic>? _buildCustomFieldsPayload() {
    final out = <String, String>{};
    _customFieldControllers.forEach((key, controller) {
      final k = key.trim();
      final v = controller.text.trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        out[k] = v;
      }
    });
    return out.isEmpty ? null : out;
  }

  Future<void> _call() async {
    final phone = normalizePhoneInput(_phone.text.trim());
    final effectiveFirst = _firstName.text.trim().isNotEmpty ? _firstName.text.trim() : _name.text.trim();
    final name = effectiveFirst;
    if (phone.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone and name required')));
      return;
    }

    final ui = ref.read(studentDetailCtrlProvider(widget.studentId));
    final agents = ui.agents;
    final agentId = (ui.selectedAgentId ?? (agents.isNotEmpty ? (agents.first['id'] ?? agents.first['agent_id'])?.toString() : null))?.trim();
    if (agentId == null || agentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create/select an agent before calling')));
      return;
    }
    try {
      final res = await ref.read(studentDetailCtrlProvider(widget.studentId).notifier).startCall(
        agentId: agentId,
        studentPhone: phone,
        studentName: name,
        balance: _balance.text.trim().isEmpty ? null : _balance.text.trim(),
        dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
        lateFee: _lateFee.text.trim().isEmpty ? null : _lateFee.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Call started')),
        );
        widget.onUpdated?.call();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _addCustomFieldRow() {
    final key = _newFieldKey.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a field name')));
      return;
    }
    if (_customFieldControllers.containsKey(key)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Field already exists')));
      return;
    }
    setState(() {
      _customFieldControllers[key] = TextEditingController();
      _newFieldKey.clear();
    });
  }

  Future<void> _confirmDeleteStudent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete student?'),
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
      await ref.read(studentDetailCtrlProvider(widget.studentId).notifier).deleteStudent();
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
                await ref.read(studentDetailCtrlProvider(widget.studentId).notifier).addPayment(
                  amount: amountC.text.trim(),
                  method: methodC.text.trim().isEmpty ? null : methodC.text.trim(),
                  note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
                );
                if (context.mounted) {
                  navigator.pop();
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
    final ui = ref.watch(studentDetailCtrlProvider(widget.studentId));
    _syncControllers(ui);
    if (ui.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (ui.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student profile')),
        body: Center(child: Text(ui.error!, style: TextStyle(color: NeyvoColors.error))),
      );
    }
    
    final balance = _balance.text.trim();
    final dueDate = _dueDate.text.trim();
    final callbackStatus = (ui.student?['callback_status'] ?? '').toString();
    final callbackAt = ui.student?['callback_at'];
    final callbackAttempts = ui.student?['callback_attempt_count'];
    final callbackMaxAttempts = ui.student?['callback_max_attempts'];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(ui.student?['name']?.toString() ?? 'Student profile'),
        actions: [
          IconButton(
            icon: ui.calling 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.phone),
            onPressed: ui.calling ? null : _call,
            tooltip: 'Reach out to contact',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') _confirmDeleteStudent();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete student'))),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.person_outline)),
            Tab(text: 'Payments', icon: Icon(Icons.payment_outlined)),
            Tab(text: 'Call Logs', icon: Icon(Icons.phone_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
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
              
              // Callback status (if any)
              if (callbackStatus.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(NeyvoSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Callback', style: NeyvoType.titleMedium),
                        const SizedBox(height: NeyvoSpacing.sm),
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                'Status: ${callbackStatus[0].toUpperCase()}${callbackStatus.substring(1)}',
                                style: NeyvoType.bodySmall,
                              ),
                            ),
                            const SizedBox(width: NeyvoSpacing.sm),
                            if (callbackAttempts != null && callbackMaxAttempts != null)
                              Chip(
                                label: Text(
                                  'Attempts: $callbackAttempts / $callbackMaxAttempts',
                                  style: NeyvoType.bodySmall,
                                ),
                              ),
                          ],
                        ),
                        if (callbackAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: NeyvoSpacing.sm),
                            child: Text(
                              'Next: ${formatCallbackTime12h(callbackAt)}',
                              style: NeyvoType.bodyMedium.copyWith(
                                color: NeyvoColors.tealLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: NeyvoSpacing.sm),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: ui.cancelingCallback ? null : _cancelCallbackIfAny,
                              child: ui.cancelingCallback
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Cancel callback'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
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
              TextField(controller: _firstName, decoration: const InputDecoration(labelText: 'First name')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _lastName, decoration: const InputDecoration(labelText: 'Last name')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name (legacy / optional)')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '123-456-7890 or (123) 456-7890',
                ),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: _advisorName,
                decoration: const InputDecoration(
                  labelText: 'Advisor name (optional)',
                  hintText: 'Used for {{advisor_name}}',
                ),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: _bookingUrl,
                decoration: const InputDecoration(
                  labelText: 'Booking URL (optional)',
                  hintText: 'Used for {{booking_url}}',
                ),
              ),
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

              // Custom flexible fields
              Text('Additional fields', style: NeyvoType.titleMedium),
              const SizedBox(height: NeyvoSpacing.sm),
              Text(
                'Use this section for any extra columns you imported (e.g. course, cohort, dorm). '
                'These fields are stored on the student record and can be referenced in prompts.',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              ..._customFieldControllers.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          e.key,
                          style: NeyvoType.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: NeyvoSpacing.sm),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: e.value,
                          decoration: const InputDecoration(
                            labelText: 'Value',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Remove field',
                        onPressed: () {
                          setState(() {
                            e.value.dispose();
                            _customFieldControllers.remove(e.key);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newFieldKey,
                      decoration: const InputDecoration(
                        labelText: 'Add field name (e.g. course)',
                      ),
                    ),
                  ),
                  const SizedBox(width: NeyvoSpacing.sm),
                  FilledButton.tonal(
                    onPressed: _addCustomFieldRow,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: NeyvoSpacing.xl),
              FilledButton(
                onPressed: ui.saving ? null : _save,
                child: ui.saving 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Save Changes'),
              ),
            ],
          ),
          
          // Payments Tab
          ui.payments.isEmpty
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
                ...ui.payments.map((p) {
                      final amount = p['amount']?.toString() ?? '—';
                      final method = p['method']?.toString() ?? '';
                      final dateRaw = p['created_at'] ?? p['date'];
                      final date = dateRaw != null ? UserTimezoneService.format(dateRaw) : '';
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
          
          // Call Logs Tab
          ListView(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Call Logs', style: NeyvoType.titleLarge),
                  FilledButton.icon(
                    onPressed: _call,
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('New Call'),
                  ),
                ],
              ),
              const SizedBox(height: NeyvoSpacing.md),
              if (ui.calls.isEmpty)
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
                ...ui.calls.map((c) {
                  final callMap = Map<String, dynamic>.from(c as Map);
                  final status = callMap['status']?.toString() ?? callMap['outcome']?.toString() ?? 'unknown';
                  final dateRaw = callMap['started_at'] ?? callMap['created_at'] ?? callMap['date'];
                  final date = dateRaw != null ? UserTimezoneService.formatShort(dateRaw) : '';
                  final durationSec = callMap['duration_seconds'] ?? callMap['duration_sec'] ?? callMap['duration'];
                  String duration = '';
                  if (durationSec != null) {
                    final s = durationSec is int ? durationSec : int.tryParse(durationSec.toString()) ?? 0;
                    if (s < 60) {
                      duration = '${s}s';
                    } else {
                      final m = s ~/ 60;
                      final r = s % 60;
                      duration = r > 0 ? '${m}m ${r}s' : '${m}m';
                    }
                  }
                  final outcome = callMap['outcome']?.toString() ?? status;
                  final agentName = callMap['agent_name']?.toString() ?? '';
                  final direction = (callMap['direction']?.toString() ?? '').toLowerCase();
                  final hasRecording = (callMap['recording_url']?.toString().isNotEmpty ?? false) ||
                      (callMap['recording']?.toString().isNotEmpty ?? false);
                  return Card(
                    margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallDetailPage(call: callMap),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(NeyvoRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(NeyvoSpacing.md),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _getStatusColor(outcome).withOpacity(0.1),
                              child: Icon(Icons.phone, color: _getStatusColor(outcome)),
                            ),
                            const SizedBox(width: NeyvoSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(outcome.isNotEmpty ? outcome : 'Call', style: NeyvoType.titleMedium),
                                  if (date.isNotEmpty) Text('$date', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary)),
                                  if (agentName.isNotEmpty) Text('Operator: $agentName', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textMuted)),
                                ],
                              ),
                            ),
                            if (duration.isNotEmpty)
                              Text('${duration}s', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary)),
                            if (direction.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Chip(
                                  label: Text(direction == 'inbound' ? 'In' : 'Out', style: NeyvoType.labelSmall),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            if (hasRecording)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.record_voice_over, size: 18, color: NeyvoColors.textMuted),
                              ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, color: NeyvoColors.textMuted),
                          ],
                        ),
                      ),
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
                      ui.pastCallsSummary.isEmpty
                          ? 'No previous calls yet. This will fill after the first call.'
                          : ui.pastCallsSummary,
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
