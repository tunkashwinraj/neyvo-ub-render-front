import 'package:flutter/material.dart';

import '../../../theme/neyvo_theme.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import '../../../screens/call_history_page.dart';
import '../../../screens/callbacks_page.dart';
import 'dialer_page.dart';

enum CallsSection { inbound, outbound, dialer, callbacks }

class CallsPage extends StatefulWidget {
  const CallsPage({super.key, this.initialSection = CallsSection.inbound});

  final CallsSection initialSection;

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
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
                _pill('Inbound', CallsSection.inbound),
                const SizedBox(width: 8),
                _pill('Outbound', CallsSection.outbound),
                const SizedBox(width: 8),
                _pill('Dialer', CallsSection.dialer),
                const SizedBox(width: 8),
                _pill('Callbacks', CallsSection.callbacks),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _pill(String label, CallsSection section) {
    final selected = _section == section;
    return InkWell(
      onTap: () => setState(() => _section = section),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? NeyvoColors.teal.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? NeyvoColors.teal.withOpacity(0.5) : NeyvoColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: NeyvoTextStyles.label.copyWith(
            color: selected ? NeyvoColors.teal : NeyvoColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_section) {
      case CallsSection.inbound:
        return const CallHistoryPage(initialDirection: 'inbound');
      case CallsSection.outbound:
        return const CallHistoryPage(initialDirection: 'outbound');
      case CallsSection.dialer:
        return const DialerPage();
      case CallsSection.callbacks:
        return const CallbacksPage();
    }
  }
}

