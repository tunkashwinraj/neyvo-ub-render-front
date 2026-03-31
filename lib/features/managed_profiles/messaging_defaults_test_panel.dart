import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/neyvo_theme.dart';
import '../../ui/components/glass/neyvo_glass_panel.dart';
import 'messaging_defaults_test_provider.dart';

/// Test send for Additional settings: same templates and placeholder resolution as production.
class MessagingDefaultsTestPanel extends ConsumerStatefulWidget {
  const MessagingDefaultsTestPanel({
    super.key,
    required this.operatorId,
    this.variableDefaults = const {},
  });

  final String operatorId;
  final Map<String, String> variableDefaults;

  @override
  ConsumerState<MessagingDefaultsTestPanel> createState() => _MessagingDefaultsTestPanelState();
}

class _MessagingDefaultsTestPanelState extends ConsumerState<MessagingDefaultsTestPanel> {
  late final TextEditingController _emailToTest;
  late final TextEditingController _smsToTest;
  late final TextEditingController _memberUid;
  late final TextEditingController _staffId;
  late final TextEditingController _studentId;

  @override
  void initState() {
    super.initState();
    _emailToTest = TextEditingController();
    _smsToTest = TextEditingController();
    _memberUid = TextEditingController();
    _staffId = TextEditingController();
    _studentId = TextEditingController();
  }

  @override
  void dispose() {
    _emailToTest.dispose();
    _smsToTest.dispose();
    _memberUid.dispose();
    _staffId.dispose();
    _studentId.dispose();
    super.dispose();
  }

  Map<String, dynamic> _mergedVariables() {
    final m = <String, dynamic>{};
    for (final e in widget.variableDefaults.entries) {
      if (e.key.trim().isNotEmpty) m[e.key] = e.value;
    }
    return m;
  }

  Future<void> _sendEmail() async {
    final ctrl = ref.read(messagingDefaultsTestCtrlProvider(widget.operatorId).notifier);
    await ctrl.sendTestEmail(
      to: _emailToTest.text.trim(),
      variables: _mergedVariables().isEmpty ? null : _mergedVariables(),
      memberUserId: _memberUid.text.trim().isEmpty ? null : _memberUid.text.trim(),
      staffId: _staffId.text.trim().isEmpty ? null : _staffId.text.trim(),
      studentId: _studentId.text.trim().isEmpty ? null : _studentId.text.trim(),
    );
    if (!mounted) return;
    final st = ref.read(messagingDefaultsTestCtrlProvider(widget.operatorId));
    if (st.lastError == null && st.lastEmailMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.lastEmailMessage!)),
      );
    } else if (st.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.lastError!)),
      );
    }
  }

  Future<void> _sendSms() async {
    final ctrl = ref.read(messagingDefaultsTestCtrlProvider(widget.operatorId).notifier);
    await ctrl.sendTestSms(
      to: _smsToTest.text.trim(),
      variables: _mergedVariables().isEmpty ? null : _mergedVariables(),
      memberUserId: _memberUid.text.trim().isEmpty ? null : _memberUid.text.trim(),
      staffId: _staffId.text.trim().isEmpty ? null : _staffId.text.trim(),
      studentId: _studentId.text.trim().isEmpty ? null : _studentId.text.trim(),
    );
    if (!mounted) return;
    final st = ref.read(messagingDefaultsTestCtrlProvider(widget.operatorId));
    if (st.lastError == null && st.lastSmsMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.lastSmsMessage!)),
      );
    } else if (st.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.lastError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final st = ref.watch(messagingDefaultsTestCtrlProvider(widget.operatorId));

    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send test messages', style: NeyvoTextStyles.heading),
          const SizedBox(height: 8),
          Text(
            'Sends one email or SMS using the saved templates above, with the same placeholders as live sends '
            '(student fields, {{booking_url}} / {{advisor_name}} when member_user_id or staff_id is set). '
            'Enter a recipient you control.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text('Optional routing (Team member)', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _memberUid,
            decoration: const InputDecoration(
              labelText: 'member_user_id (Firebase UID)',
              hintText: 'For {{booking_url}} / {{advisor_name}}',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _staffId,
            decoration: const InputDecoration(
              labelText: 'staff_id (alternative)',
              hintText: 'Match Staff ID on Team profile',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _studentId,
            decoration: const InputDecoration(
              labelText: 'student_id (optional)',
              hintText: 'Resolve student for {{student_name}} etc.',
            ),
          ),
          const SizedBox(height: 16),
          Text('Test email', style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _emailToTest,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Send test to (email)',
              hintText: 'you@example.com',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: st.emailSending ? null : _sendEmail,
              style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: NeyvoColors.white),
              child: st.emailSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white))
                  : const Text('Send test email'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Test SMS', style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _smsToTest,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Send test to (E.164)',
              hintText: '+12035551234',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: st.smsSending ? null : _sendSms,
              style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: NeyvoColors.white),
              child: st.smsSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white))
                  : const Text('Send test SMS'),
            ),
          ),
          if (st.lastError != null && !st.emailSending && !st.smsSending) ...[
            const SizedBox(height: 8),
            Text(st.lastError!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.warning)),
          ],
        ],
      ),
    );
  }
}
