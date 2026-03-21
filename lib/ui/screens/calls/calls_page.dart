import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/calls_ui_provider.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import '../../../screens/call_history_page.dart';
import '../../../screens/callbacks_page.dart';
import 'calls_section.dart';
import 'dialer_page.dart';

class CallsPage extends ConsumerStatefulWidget {
  const CallsPage({super.key, this.initialSection = CallsSection.calls});

  final CallsSection initialSection;

  @override
  ConsumerState<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends ConsumerState<CallsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callsUiProvider.notifier).select(widget.initialSection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(callsUiProvider);
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
        Expanded(child: _body(section)),
      ],
    );
  }

  Widget _pill(String label, CallsSection target) {
    final section = ref.watch(callsUiProvider);
    final selected = section == target;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => ref.read(callsUiProvider.notifier).select(target),
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

  Widget _body(CallsSection section) {
    switch (section) {
      case CallsSection.calls:
        return const CallHistoryPage(initialDirection: 'all');
      case CallsSection.dialer:
        return const DialerPage();
      case CallsSection.callbacks:
        return const CallbacksPage();
    }
  }
}
