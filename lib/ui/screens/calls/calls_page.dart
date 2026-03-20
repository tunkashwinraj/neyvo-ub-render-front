import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/calls_provider.dart';
import '../../../theme/neyvo_theme.dart';
import '../../../tenant/tenant_brand.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import '../../../screens/call_history_page.dart';
import '../../../screens/callbacks_page.dart';
import 'dialer_page.dart';

enum CallsSection { calls, callbacks, dialer }

class CallsPage extends ConsumerStatefulWidget {
  const CallsPage({super.key, this.initialSection = CallsSection.calls});

  final CallsSection initialSection;

  @override
  ConsumerState<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends ConsumerState<CallsPage> {
  late CallsSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: NeyvoGlassPanel(
            child: Row(
              children: [
                _pill('Calls', CallsSection.calls),
                const SizedBox(width: 8),
                _pill('Callbacks', CallsSection.callbacks),
                const SizedBox(width: 8),
                _pill('Dialer', CallsSection.dialer),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ref.watch(callsNotifierProvider).when(
                data: (_) => _body(),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
        ),
      ],
    );
  }

  Widget _pill(String label, CallsSection section) {
    final selected = _section == section;
    final primary = TenantBrand.primary(context);
    return InkWell(
      onTap: () => setState(() => _section = section),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? primary.withOpacity(0.5) : NeyvoColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: NeyvoTextStyles.label.copyWith(
            color: selected ? primary : NeyvoColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_section) {
      case CallsSection.calls:
        return const CallHistoryPage(initialDirection: 'all');
      case CallsSection.dialer:
        return const DialerPage();
      case CallsSection.callbacks:
        return const CallbacksPage();
    }
  }
}

