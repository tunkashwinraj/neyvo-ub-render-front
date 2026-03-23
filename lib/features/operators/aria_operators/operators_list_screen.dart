import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pulse_route_names.dart';
import 'aria_operator_providers.dart';
import 'operators_create_screen.dart';

Color _industryColor(String industry) {
  final i = industry.toLowerCase();
  if (i.contains('health')) return const Color(0xFF3B82F6);
  if (i.contains('legal')) return const Color(0xFF7C3AED);
  if (i.contains('real')) return const Color(0xFF0EA5E9);
  if (i.contains('restaurant')) return const Color(0xFFEF4444);
  if (i.contains('finance')) return const Color(0xFF10B981);
  if (i.contains('education')) return const Color(0xFF8B5CF6);
  if (i.contains('ecommerce')) return const Color(0xFFF59E0B);
  return const Color(0xFF64748B);
}

class OperatorsListScreen extends ConsumerWidget {
  const OperatorsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(ariaOperatorsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operators'),
        actions: [
          TextButton.icon(
            onPressed: () => _openAriaCreatePopup(context),
            icon: const Icon(Icons.mic_external_on_outlined),
            label: const Text('Create Operator with ARIA'),
          ),
          IconButton(
            tooltip: 'Create ARIA operator (popup)',
            onPressed: () => _openAriaCreatePopup(context),
            icon: const Icon(Icons.mic_external_on_outlined),
          ),
          IconButton(
            tooltip: 'Create new operator',
            onPressed: () {
              Navigator.pushNamed(context, PulseRouteNames.operatorsNew);
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => _LoadingGrid(),
        error: (e, st) => Center(child: Text('Failed to load operators: $e')),
        data: (operators) {
          if (operators.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_none_rounded, size: 54, color: Colors.white70),
                    const SizedBox(height: 16),
                    const Text(
                      'No operators yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start a short voice conversation with ARIA to build your first operator.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, PulseRouteNames.operatorsNew);
                      },
                      child: const Text('Create new operator'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openAriaCreatePopup(context),
                      icon: const Icon(Icons.mic_external_on_outlined),
                      label: const Text('Create with ARIA (Popup)'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              itemCount: operators.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final op = operators[index];
                final color = _industryColor(op.industry);
                final status = op.status;
                final statusLabel = status == 'live'
                    ? 'Live'
                    : status == 'error'
                        ? 'Error'
                        : 'Building';
                final statusColor = status == 'live'
                    ? const Color(0xFF22C55E)
                    : status == 'error'
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF94A3B8);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pushNamed(context, '${PulseRouteNames.operatorsRoot}/${op.operatorId}');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                      color: const Color(0xFF0B1225),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: statusColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                op.personaName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: color.withOpacity(0.18),
                                border: Border.all(color: color.withOpacity(0.35)),
                              ),
                              child: Text(
                                op.industry.isEmpty ? 'Industry' : op.industry,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          op.operatorRole.isEmpty ? 'Operator' : op.operatorRole,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          op.operatorSummary.isEmpty ? '—' : op.operatorSummary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

void _openAriaCreatePopup(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: SizedBox(
          width: 1100,
          height: 760,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: const OperatorsCreateScreen(),
          ),
        ),
      );
    },
  );
}

class _LoadingGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

