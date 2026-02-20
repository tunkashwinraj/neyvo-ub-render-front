// lib/screens/outbound_calls_page.dart
// Enhanced outbound calls page with student selector, templates, and pre-filled data

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../../api/spearia_api.dart';
import '../../theme/spearia_theme.dart';

class OutboundCallsPage extends StatefulWidget {
  final Map<String, dynamic>? prefillStudent;

  const OutboundCallsPage({super.key, this.prefillStudent});

  @override
  State<OutboundCallsPage> createState() => _OutboundCallsPageState();
}

class _OutboundCallsPageState extends State<OutboundCallsPage> {
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _selectedStudent;
  final _studentSearchController = TextEditingController();
  final _phoneNumberId = TextEditingController();
  final _balance = TextEditingController();
  final _dueDate = TextEditingController();
  final _lateFee = TextEditingController();
  final _schoolName = TextEditingController();
  String _callTemplate = 'balance_reminder';

  bool _loading = false;
  bool _loadingStudents = false;
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    if (widget.prefillStudent != null) {
      _selectedStudent = widget.prefillStudent;
      _fillFromStudent();
    }
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _phoneNumberId.dispose();
    _balance.dispose();
    _dueDate.dispose();
    _lateFee.dispose();
    _schoolName.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loadingStudents = true);
    try {
      final res = await NeyvoPulseApi.listStudents();
      if (mounted) {
        setState(() {
          final studentsList = res['students'] as List? ?? [];
          _students = studentsList.cast<Map<String, dynamic>>();
          _loadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  void _fillFromStudent() {
    if (_selectedStudent == null) return;
    setState(() {
      _balance.text = _selectedStudent!['balance']?.toString() ?? '';
      _dueDate.text = _selectedStudent!['due_date']?.toString() ?? '';
      _lateFee.text = _selectedStudent!['late_fee']?.toString() ?? '';
    });
  }

  void _selectStudent(Map<String, dynamic> student) {
    setState(() {
      _selectedStudent = student;
      _studentSearchController.text = student['name']?.toString() ?? '';
    });
    _fillFromStudent();
  }

  List<Map<String, dynamic>> _getFilteredStudents(String query) {
    if (query.isEmpty) return _students;
    final queryLower = query.toLowerCase();
    return _students.where((s) {
      final name = (s['name']?.toString() ?? '').toLowerCase();
      final phone = (s['phone']?.toString() ?? '').toLowerCase();
      return name.contains(queryLower) || phone.contains(queryLower);
    }).toList();
  }

  Future<void> _startCall() async {
    final phone = _selectedStudent?['phone']?.toString() ?? '';
    final name = _selectedStudent?['name']?.toString() ?? '';
    
    if (phone.isEmpty || name.isEmpty) {
      setState(() {
        _message = 'Please select a student.';
        _success = false;
      });
      return;
    }
    
    setState(() {
      _loading = true;
      _message = null;
    });
    
    try {
      final result = await NeyvoPulseApi.startOutboundCall(
        studentPhone: phone,
        studentName: name,
        studentId: _selectedStudent?['id']?.toString(),
        phoneNumberId: _phoneNumberId.text.trim().isEmpty ? null : _phoneNumberId.text.trim(),
        balance: _balance.text.trim().isEmpty ? null : _balance.text.trim(),
        dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
        lateFee: _lateFee.text.trim().isEmpty ? null : _lateFee.text.trim(),
        schoolName: _schoolName.text.trim().isEmpty ? null : _schoolName.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = result['ok'] == true || result['call_id'] != null;
        _message = result['message']?.toString() ?? (result['call_id'] != null ? 'Call started successfully' : 'Done');
      });
      
      // Clear form after successful call
      if (_success) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _selectedStudent = null;
              _studentSearchController.clear();
              _balance.clear();
              _dueDate.clear();
              _lateFee.clear();
              _message = null;
            });
          }
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = false;
        _message = e.payload is Map ? (e.payload['error']?.toString() ?? e.message) : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = false;
        _message = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeariaAura.bg,
      appBar: AppBar(
        title: const Text('Outbound Calls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).pushNamed(PulseRouteNames.callHistory);
            },
            tooltip: 'Call History',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        children: [
          Text(
            'Call a Student',
            style: SpeariaType.headlineLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'The AI will deliver the balance reminder and answer their questions.',
            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
          ),
          const SizedBox(height: SpeariaSpacing.xl),
          
          // Student Selector
          Text('Student', style: SpeariaType.titleMedium),
          const SizedBox(height: SpeariaSpacing.sm),
          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text;
              _studentSearchController.text = query;
              return _getFilteredStudents(query);
            },
            displayStringForOption: (option) => 
                '${option['name'] ?? ''} - ${option['phone'] ?? ''}',
            onSelected: _selectStudent,
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // Sync the controller text with our search controller for filtering
              controller.addListener(() {
                if (_studentSearchController.text != controller.text) {
                  _studentSearchController.text = controller.text;
                }
              });
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Search and select student',
                  hintText: 'Type student name or phone...',
                  prefixIcon: const Icon(Icons.person),
                  suffixIcon: _selectedStudent != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedStudent = null;
                              controller.clear();
                            });
                          },
                        )
                      : null,
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(SpeariaRadius.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final student = options.elementAt(index);
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (student['name']?.toString() ?? '?')[0].toUpperCase(),
                            ),
                          ),
                          title: Text(student['name']?.toString() ?? ''),
                          subtitle: Text(student['phone']?.toString() ?? ''),
                          onTap: () => onSelected(student),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          
          if (_selectedStudent != null) ...[
            const SizedBox(height: SpeariaSpacing.md),
            Card(
              color: SpeariaAura.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: SpeariaAura.primary),
                    const SizedBox(width: SpeariaSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedStudent!['name']?.toString() ?? '',
                            style: SpeariaType.titleMedium,
                          ),
                          Text(
                            _selectedStudent!['phone']?.toString() ?? '',
                            style: SpeariaType.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: SpeariaSpacing.lg),
          
          // Call Template
          Text('Call Type', style: SpeariaType.titleMedium),
          const SizedBox(height: SpeariaSpacing.sm),
          DropdownButtonFormField<String>(
            value: _callTemplate,
            decoration: const InputDecoration(
              labelText: 'Call Template',
              hintText: 'Select call type',
            ),
            items: const [
              DropdownMenuItem(value: 'balance_reminder', child: Text('Balance Reminder')),
              DropdownMenuItem(value: 'payment_inquiry', child: Text('Payment Inquiry')),
              DropdownMenuItem(value: 'due_date_reminder', child: Text('Due Date Reminder')),
              DropdownMenuItem(value: 'general', child: Text('General Call')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _callTemplate = value);
            },
          ),
          
          const SizedBox(height: SpeariaSpacing.lg),
          
          // Financial Information
          Text('Financial Information (Optional)', style: SpeariaType.titleMedium),
          const SizedBox(height: SpeariaSpacing.sm),
          TextField(
            controller: _balance,
            decoration: const InputDecoration(
              labelText: 'Balance',
              hintText: '\$1,000',
              prefixIcon: Icon(Icons.account_balance_wallet),
            ),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          TextField(
            controller: _dueDate,
            decoration: const InputDecoration(
              labelText: 'Due Date',
              hintText: 'February 25, 2026',
              prefixIcon: Icon(Icons.calendar_today),
            ),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          TextField(
            controller: _lateFee,
            decoration: const InputDecoration(
              labelText: 'Late Fee',
              hintText: '\$75',
              prefixIcon: Icon(Icons.warning),
            ),
          ),
          
          const SizedBox(height: SpeariaSpacing.lg),
          
          // Advanced Options
          ExpansionTile(
            title: Text('Advanced Options', style: SpeariaType.titleMedium),
            children: [
              TextField(
                controller: _phoneNumberId,
                decoration: const InputDecoration(
                  labelText: 'VAPI Phone Number ID',
                  hintText: 'Caller ID for outbound',
                ),
              ),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(
                controller: _schoolName,
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  hintText: 'University of Example',
                ),
              ),
            ],
          ),
          
          if (_message != null) ...[
            const SizedBox(height: SpeariaSpacing.lg),
            Container(
              padding: const EdgeInsets.all(SpeariaSpacing.md),
              decoration: BoxDecoration(
                color: _success
                    ? SpeariaAura.success.withOpacity(0.1)
                    : SpeariaAura.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(SpeariaRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    _success ? Icons.check_circle : Icons.error,
                    color: _success ? SpeariaAura.success : SpeariaAura.error,
                  ),
                  const SizedBox(width: SpeariaSpacing.sm),
                  Expanded(
                    child: Text(
                      _message!,
                      style: SpeariaType.bodyMedium.copyWith(
                        color: _success ? SpeariaAura.success : SpeariaAura.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: SpeariaSpacing.xl),
          
          FilledButton.icon(
            onPressed: (_loading || _selectedStudent == null) ? null : _startCall,
            icon: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.phone),
            label: Text(_loading ? 'Starting Call...' : 'Start Call'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: SpeariaSpacing.md),
            ),
          ),
        ],
      ),
    );
  }
}
