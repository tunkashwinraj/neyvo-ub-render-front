// lib/screens/payments_page.dart
// Payments page with list, filters, analytics, and add payment functionality

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../utils/export_csv.dart';
import '../../theme/spearia_theme.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  List<dynamic> _allPayments = [];
  List<dynamic> _filteredPayments = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _filterMethod = 'all';

  double _totalAmount = 0.0;
  Map<String, int> _methodCounts = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterPayments);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NeyvoPulseApi.listPayments();
      final list = res['payments'] as List? ?? [];
      if (mounted) {
        setState(() {
          _allPayments = list;
          _filteredPayments = list;
          _loading = false;
        });
        _calculateStats();
        _filterPayments();
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _calculateStats() {
    double total = 0.0;
    final methodCounts = <String, int>{};
    
    for (final payment in _allPayments) {
      final amountStr = payment['amount']?.toString() ?? '';
      if (amountStr.isNotEmpty) {
        final amount = double.tryParse(amountStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        total += amount;
      }
      final method = payment['method']?.toString() ?? 'Unknown';
      methodCounts[method] = (methodCounts[method] ?? 0) + 1;
    }
    
    setState(() {
      _totalAmount = total;
      _methodCounts = methodCounts;
    });
  }

  void _filterPayments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPayments = _allPayments.where((p) {
        final studentName = (p['student_name']?.toString() ?? '').toLowerCase();
        final studentId = (p['student_id']?.toString() ?? '').toLowerCase();
        final method = (p['method']?.toString() ?? '').toLowerCase();
        final matchesSearch = query.isEmpty || 
            studentName.contains(query) || 
            studentId.contains(query) || 
            method.contains(query);
        
        if (!matchesSearch) return false;
        
        if (_filterMethod == 'all') return true;
        return method == _filterMethod.toLowerCase();
      }).toList();
    });
  }

  Future<void> _exportPaymentsCsv() async {
    final sb = StringBuffer();
    sb.writeln('Student Name,Student ID,Amount,Method,Date,Note');
    for (final p in _filteredPayments) {
      final name = (p['student_name']?.toString() ?? p['name']?.toString() ?? '').replaceAll(',', ';');
      final id = p['student_id']?.toString() ?? '';
      final amount = p['amount']?.toString() ?? '';
      final method = p['method']?.toString() ?? '';
      final date = p['created_at']?.toString() ?? p['date']?.toString() ?? '';
      final note = (p['note']?.toString() ?? '').replaceAll(RegExp(r'[\r\n]'), ' ');
      sb.writeln('"$name","$id","$amount","$method","$date","$note"');
    }
    final filename = 'payments_${DateTime.now().toIso8601String().split('T').first}.csv';
    await downloadCsv(filename, sb.toString(), context);
  }

  Future<void> _addPayment() async {
    List<dynamic> students = [];
    try {
      final res = await NeyvoPulseApi.listStudents();
      students = res['students'] as List? ?? [];
    } catch (_) {}
    
    final amountC = TextEditingController();
    final methodC = TextEditingController();
    final noteC = TextEditingController();
    String? selectedStudentId;
    
    final navigator = Navigator.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStudentId,
                    decoration: const InputDecoration(labelText: 'Student *'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select student')),
                      ...students.map((s) {
                        final id = s['id'] as String? ?? '';
                        final name = s['name'] as String? ?? id;
                        return DropdownMenuItem(value: id, child: Text(name));
                      }),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStudentId = v),
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  TextField(
                    controller: amountC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount *', hintText: '\$100.00'),
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  TextField(
                    controller: methodC,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      hintText: 'Credit Card, Cash, Check, etc.',
                    ),
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
                  if (selectedStudentId == null || selectedStudentId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a student')));
                    return;
                  }
                  if (amountC.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount required')));
                    return;
                  }
                  try {
                    await NeyvoPulseApi.addPayment(
                      studentId: selectedStudentId!,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payments')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error), textAlign: TextAlign.center),
                const SizedBox(height: SpeariaSpacing.lg),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _filteredPayments.isEmpty ? null : _exportPaymentsCsv,
            tooltip: 'Export payments CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            padding: const EdgeInsets.all(SpeariaSpacing.md),
            decoration: BoxDecoration(
              color: SpeariaAura.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Payments',
                    value: '\$${_totalAmount.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: SpeariaAura.success,
                  ),
                ),
                const SizedBox(width: SpeariaSpacing.md),
                Expanded(
                  child: _StatCard(
                    label: 'Count',
                    value: '${_allPayments.length}',
                    icon: Icons.receipt_outlined,
                    color: SpeariaAura.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(SpeariaSpacing.md),
            decoration: BoxDecoration(
              color: SpeariaAura.surface,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search payments...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Methods',
                        selected: _filterMethod == 'all',
                        onTap: () {
                          setState(() => _filterMethod = 'all');
                          _filterPayments();
                        },
                      ),
                      ..._methodCounts.keys.map((method) => Padding(
                        padding: const EdgeInsets.only(left: SpeariaSpacing.sm),
                        child: _FilterChip(
                          label: '$method (${_methodCounts[method]})',
                          selected: _filterMethod == method.toLowerCase(),
                          onTap: () {
                            setState(() => _filterMethod = method.toLowerCase());
                            _filterPayments();
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Payments List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _filteredPayments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment_outlined, size: 64, color: SpeariaAura.textMuted),
                          const SizedBox(height: SpeariaSpacing.md),
                          Text(
                            _allPayments.isEmpty ? 'No payments yet' : 'No payments found',
                            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted),
                          ),
                          if (_allPayments.isEmpty) ...[
                            const SizedBox(height: SpeariaSpacing.lg),
                            FilledButton.icon(
                              onPressed: _addPayment,
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Payment'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(SpeariaSpacing.md),
                      itemCount: _filteredPayments.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(SpeariaSpacing.md),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Payments (${_filteredPayments.length})',
                                  style: SpeariaType.headlineMedium,
                                ),
                                if (_filteredPayments.length != _allPayments.length)
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _filterMethod = 'all');
                                      _filterPayments();
                                    },
                                    child: const Text('Clear filters'),
                                  ),
                              ],
                            ),
                          );
                        }
                        final p = _filteredPayments[i - 1] as Map<String, dynamic>;
                        final amount = p['amount']?.toString() ?? '—';
                        final method = p['method']?.toString() ?? 'Unknown';
                        final date = p['created_at']?.toString() ?? p['date']?.toString() ?? '';
                        final studentName = p['student_name']?.toString() ?? p['student_id']?.toString() ?? 'Unknown';
                        final note = p['note']?.toString() ?? '';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: SpeariaAura.success.withOpacity(0.1),
                              child: Icon(Icons.payment, color: SpeariaAura.success),
                            ),
                            title: Text(amount, style: SpeariaType.titleMedium.copyWith(color: SpeariaAura.success, fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Student: $studentName'),
                                Text('Method: $method'),
                                if (date.isNotEmpty) Text('Date: $date', style: SpeariaType.bodySmall),
                                if (note.isNotEmpty) Text(note, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPayment,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpeariaSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(SpeariaRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: SpeariaSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: SpeariaType.labelSmall.copyWith(color: SpeariaAura.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpeariaSpacing.xs),
          Text(
            value,
            style: SpeariaType.titleMedium.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: SpeariaAura.primary.withOpacity(0.2),
      checkmarkColor: SpeariaAura.primary,
    );
  }
}
