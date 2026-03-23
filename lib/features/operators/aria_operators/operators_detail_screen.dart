import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/email_models.dart';
import '../../../models/sms_models.dart';
import '../../../neyvo_pulse_api.dart';
import '../../../providers/sendgrid_providers.dart';
import '../../../providers/sms_providers.dart';
import '../../../services/sms_api.dart';
import '../../../pulse_route_names.dart';
import '../../../services/email_templates_api.dart';
import 'aria_operator_api_service.dart';
import 'aria_operator_providers.dart';
import 'aria_vapi_iframe.dart';
import 'operators_create_screen.dart';
import 'vapi_public_key_guard.dart';

// Screen: /operators/{operator_id}
class OperatorsDetailScreen extends ConsumerStatefulWidget {
  final String operatorId;
  const OperatorsDetailScreen({required this.operatorId, super.key});

  @override
  ConsumerState<OperatorsDetailScreen> createState() => _OperatorsDetailScreenState();
}

class _OperatorsDetailScreenState extends ConsumerState<OperatorsDetailScreen> {
  StreamSubscription? _callMessageSub;

  @override
  void dispose() {
    _callMessageSub?.cancel();
    _callMessageSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(ariaOperatorDetailProvider(widget.operatorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Operator')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTemplateSheet(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Email template'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Failed to load operator: $e')),
        data: (doc) {
          final op = doc;
          final personaName = (op['persona_name'] ?? '').toString();
          final industry = (op['industry'] ?? '').toString();
          final operatorRole = (op['operator_role'] ?? '').toString();
          final summary = (op['operator_summary'] ?? '').toString();
          final status = (op['status'] ?? 'building').toString();
          final assistantId = (op['vapi_assistant_id'] ?? '').toString();
          final vapiPublicKey = (op['vapi_public_key'] ?? '').toString();

          final toneProfile = op['tone_profile'];
          final descriptors = (toneProfile is Map)
              ? (toneProfile['descriptors'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[]
              : const <String>[];

          final ariaExtractedProfile = op['aria_extracted_profile'];
          final operatorRoleDetail =
              (ariaExtractedProfile is Map && ariaExtractedProfile['operator_role_detail'] != null)
                  ? ariaExtractedProfile['operator_role_detail'].toString()
                  : '';

          final systemPromptFinal = (op['system_prompt_final'] ?? '').toString();

          final statusColor = status == 'live'
              ? const Color(0xFF22C55E)
              : status == 'error'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF94A3B8);

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Integrations'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                Row(
                  children: [
                    CircleAvatar(radius: 10, backgroundColor: statusColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        personaName.isEmpty ? 'Operator' : personaName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12),
                        color: Colors.white.withOpacity(0.04),
                      ),
                      child: Text(industry.isEmpty ? 'Industry' : industry),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Text(
                  operatorRole.isEmpty ? operatorRoleDetail : operatorRole,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Card(
                  color: const Color(0xFF0B1225),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      summary.isEmpty ? '—' : summary,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call_rounded),
                        onPressed: status == 'live' &&
                                assistantId.isNotEmpty &&
                                vapiPublicKey.isNotEmpty &&
                                !isPlaceholderVapiPublicKey(vapiPublicKey)
                            ? () => _startOperatorCall(
                                  context: context,
                                  assistantId: assistantId,
                                  vapiPublicKey: vapiPublicKey,
                                )
                            : null,
                        label: const Text('Call this operator'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit flow coming soon')),
                        );
                      },
                      child: const Text('Edit'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: status == 'live'
                          ? () {
                              Navigator.of(context).pushNamed(
                                PulseRouteNames.operatorsOptimization(widget.operatorId),
                              );
                            }
                          : null,
                      child: const Text('Optimization'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openAriaCreatePopup(context),
                      icon: const Icon(Icons.mic_external_on_outlined),
                      label: const Text('Create ARIA (Popup)'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete operator?'),
                            content: const Text('This permanently removes the operator assistant and its configuration.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await AriaOperatorApiService.deleteOperator(widget.operatorId);
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, PulseRouteNames.operatorsRoot);
                          }
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF0B1225),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        const Text('Tone profile', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: descriptors.isEmpty
                              ? const [Text('—')]
                              : descriptors.map((d) => Chip(label: Text(d))).toList(),
                        ),
                        const SizedBox(height: 14),
                        const Text('Primary role', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text(operatorRole.isEmpty ? '—' : operatorRole),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Card(
                  color: const Color(0xFF0B1225),
                  child: ExpansionTile(
                    title: const Text('System prompt (advanced)'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          systemPromptFinal.isEmpty ? '—' : systemPromptFinal,
                          style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                _EmailTemplatesSection(
                  operatorId: widget.operatorId,
                  onAdd: () => _openTemplateSheet(context, ref, null),
                  onEditTemplate: (t) => _openTemplateSheet(context, ref, t),
                ),
                const SizedBox(height: 14),
                _SmsTemplatesSection(
                  operatorId: widget.operatorId,
                  onAdd: () => _openSmsTemplateSheet(context, ref, null),
                  onEditTemplate: (t) => _openSmsTemplateSheet(context, ref, t),
                ),
                        ],
                      ),
                      _OperatorIntegrationsSection(operatorId: widget.operatorId),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openSmsTemplateSheet(BuildContext context, WidgetRef ref, SmsTemplate? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1225),
      builder: (ctx) => CreateEditSmsTemplateSheet(
        operatorId: widget.operatorId,
        existing: existing,
        onSaved: () {
          ref.invalidate(smsTemplatesForOperatorProvider(widget.operatorId));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _openTemplateSheet(BuildContext context, WidgetRef ref, EmailTemplate? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1225),
      builder: (ctx) => CreateEditEmailTemplateSheet(
        operatorId: widget.operatorId,
        existing: existing,
        onSaved: () {
          ref.invalidate(emailTemplatesForOperatorProvider(widget.operatorId));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _startOperatorCall({
    required BuildContext context,
    required String assistantId,
    required String vapiPublicKey,
  }) async {
    if (isPlaceholderVapiPublicKey(vapiPublicKey)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vapi public key is invalid (placeholder). Fix businesses/{account}/operators/aria_operator_creator → vapi_public_key in Firestore.',
            ),
          ),
        );
      }
      return;
    }
    final sessionId = AriaVapiSessionIframe.createSessionId();
    final viewType = 'operator-iframe-$sessionId';

    final htmlSrcDoc = AriaVapiSessionIframe.operatorCallHtml(
      sessionId: sessionId,
      operatorAssistantId: assistantId,
      publicKey: vapiPublicKey,
      accountId: NeyvoPulseApi.defaultAccountId,
      operatorId: widget.operatorId,
    );

    _callMessageSub?.cancel();
    // ignore: avoid_web_libraries_in_flutter
    final htmlWindow = (html.window);
    _callMessageSub = htmlWindow.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map) return;
      final type = data['type']?.toString() ?? '';
      final msgSessionId = data['session_id']?.toString() ?? '';
      if (msgSessionId != sessionId) return;
      if (type == 'aria_call_end') {
        _callMessageSub?.cancel();
        _callMessageSub = null;
        if (context.mounted) Navigator.of(context).pop();
      }
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          child: SizedBox(
            width: 900,
            height: 620,
            child: AriaIframeView(htmlSrcDoc: htmlSrcDoc, viewType: viewType),
          ),
        );
      },
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

class _OperatorIntegrationsSection extends ConsumerStatefulWidget {
  final String operatorId;
  const _OperatorIntegrationsSection({required this.operatorId});

  @override
  ConsumerState<_OperatorIntegrationsSection> createState() => _OperatorIntegrationsSectionState();
}

class _OperatorIntegrationsSectionState extends ConsumerState<_OperatorIntegrationsSection> {
  final _sendgridApiKey = TextEditingController();
  final _sendgridFromEmail = TextEditingController();
  final _sendgridFromName = TextEditingController();
  final _twilioSid = TextEditingController();
  final _twilioToken = TextEditingController();
  final _twilioFrom = TextEditingController();
  final _emailTo = TextEditingController();
  final _emailSubject = TextEditingController();
  final _emailBody = TextEditingController();
  final _emailHtml = TextEditingController();
  final _emailFromName = TextEditingController();
  final _smsTo = TextEditingController();
  final _smsBody = TextEditingController();

  bool _loaded = false;
  bool _loadingOperatorIntegrations = true;
  bool _savingSendgrid = false;
  bool _savingTwilio = false;
  SendgridConfig? _sendgridConfig;
  SmsConfig? _twilioConfig;
  bool _savingEmail = false;
  bool _savingSms = false;
  String? _error;

  @override
  void dispose() {
    _sendgridApiKey.dispose();
    _sendgridFromEmail.dispose();
    _sendgridFromName.dispose();
    _twilioSid.dispose();
    _twilioToken.dispose();
    _twilioFrom.dispose();
    _emailTo.dispose();
    _emailSubject.dispose();
    _emailBody.dispose();
    _emailHtml.dispose();
    _emailFromName.dispose();
    _smsTo.dispose();
    _smsBody.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadOperatorIntegrations();
  }

  Future<void> _loadOperatorIntegrations() async {
    setState(() {
      _loadingOperatorIntegrations = true;
      _error = null;
    });
    try {
      final sendgrid = await AriaOperatorApiService.getOperatorSendgridConfig(widget.operatorId);
      final twilio = await AriaOperatorApiService.getOperatorTwilioConfig(widget.operatorId);
      if (!mounted) return;
      setState(() {
        _sendgridConfig = sendgrid;
        _twilioConfig = twilio;
        if ((sendgrid.fromEmail ?? '').trim().isNotEmpty) {
          _sendgridFromEmail.text = (sendgrid.fromEmail ?? '').trim();
        }
        if ((sendgrid.fromName ?? '').trim().isNotEmpty) {
          _sendgridFromName.text = (sendgrid.fromName ?? '').trim();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingOperatorIntegrations = false);
    }
  }

  Future<void> _saveOperatorSendgrid() async {
    setState(() {
      _savingSendgrid = true;
      _error = null;
    });
    try {
      await AriaOperatorApiService.connectOperatorSendgrid(
        widget.operatorId,
        apiKey: _sendgridApiKey.text,
        fromEmail: _sendgridFromEmail.text,
      );
      if (_sendgridFromName.text.trim().isNotEmpty) {
        await AriaOperatorApiService.verifyOperatorSendgridSender(
          widget.operatorId,
          fromEmail: _sendgridFromEmail.text,
          fromName: _sendgridFromName.text,
        );
      }
      await _loadOperatorIntegrations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operator SendGrid saved')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingSendgrid = false);
    }
  }

  Future<void> _saveOperatorTwilio() async {
    setState(() {
      _savingTwilio = true;
      _error = null;
    });
    try {
      final cfg = await AriaOperatorApiService.saveOperatorTwilioConfig(
        widget.operatorId,
        accountSid: _twilioSid.text,
        authToken: _twilioToken.text,
        fromNumber: _twilioFrom.text,
      );
      if (!mounted) return;
      setState(() => _twilioConfig = cfg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operator Twilio saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingTwilio = false);
    }
  }

  void _applyDefaults(Map<String, dynamic> data) {
    final email = data['email'] is Map ? Map<String, dynamic>.from(data['email'] as Map) : const <String, dynamic>{};
    final sms = data['sms'] is Map ? Map<String, dynamic>.from(data['sms'] as Map) : const <String, dynamic>{};
    _emailTo.text = (email['to'] ?? '').toString();
    _emailSubject.text = (email['subject'] ?? '').toString();
    _emailBody.text = (email['body'] ?? '').toString();
    _emailHtml.text = (email['html_body'] ?? '').toString();
    _emailFromName.text = (email['from_name'] ?? '').toString();
    _smsTo.text = (sms['to'] ?? '').toString();
    _smsBody.text = (sms['body'] ?? '').toString();
  }

  Future<void> _saveEmail() async {
    setState(() {
      _savingEmail = true;
      _error = null;
    });
    try {
      await AriaOperatorApiService.saveEmailDefaults(
        widget.operatorId,
        email: {
          'to': _emailTo.text.trim(),
          'subject': _emailSubject.text,
          'body': _emailBody.text,
          'html_body': _emailHtml.text,
          'from_name': _emailFromName.text.trim(),
        },
      );
      ref.invalidate(operatorMessagingDefaultsProvider(widget.operatorId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email defaults saved')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _saveSms() async {
    setState(() {
      _savingSms = true;
      _error = null;
    });
    try {
      await AriaOperatorApiService.saveSmsDefaults(
        widget.operatorId,
        sms: {
          'to': _smsTo.text.trim(),
          'body': _smsBody.text,
        },
      );
      ref.invalidate(operatorMessagingDefaultsProvider(widget.operatorId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS defaults saved')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingSms = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(operatorMessagingDefaultsProvider(widget.operatorId));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF0B1225),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Integrations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text(
                  'Configure operator-scoped SendGrid/Twilio credentials and defaults used by sendEmail/sendSMS for this operator only.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (_loadingOperatorIntegrations)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  Text(
                    'SendGrid: ${_sendgridConfig?.connected == true ? 'Connected' : 'Not connected'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  Text(
                    'Twilio: ${_twilioConfig?.configured == true ? 'Configured' : 'Not configured'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                ],
                async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) => Text('Could not load defaults: $e', style: const TextStyle(color: Color(0xFFF59E0B))),
                  data: (data) {
                    if (!_loaded) {
                      _applyDefaults(data);
                      _loaded = true;
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF0B1225),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Operator SendGrid', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _sendgridApiKey,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API key'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sendgridFromEmail,
                  decoration: const InputDecoration(labelText: 'From email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sendgridFromName,
                  decoration: const InputDecoration(labelText: 'From name (optional verify)'),
                ),
                const SizedBox(height: 8),
                if ((_sendgridConfig?.fromEmail ?? '').isNotEmpty)
                  Text(
                    'Current from: ${_sendgridConfig?.fromEmail}${(_sendgridConfig?.senderStatus ?? '').isNotEmpty ? ' (${_sendgridConfig?.senderStatus})' : ''}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _savingSendgrid ? null : _saveOperatorSendgrid,
                    child: _savingSendgrid
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Operator SendGrid'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF0B1225),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Operator Twilio', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _twilioSid,
                  decoration: const InputDecoration(labelText: 'Account SID'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _twilioToken,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Auth token'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _twilioFrom,
                  decoration: const InputDecoration(labelText: 'From number (+1555...)'),
                ),
                const SizedBox(height: 8),
                if ((_twilioConfig?.fromMasked ?? '').isNotEmpty)
                  Text(
                    'Current from: ${_twilioConfig?.fromMasked}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _savingTwilio ? null : _saveOperatorTwilio,
                    child: _savingTwilio
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Operator Twilio'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF0B1225),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Email defaults (SendGrid)', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(controller: _emailTo, decoration: const InputDecoration(labelText: 'Default to')),
                const SizedBox(height: 8),
                TextField(controller: _emailFromName, decoration: const InputDecoration(labelText: 'From name helper (optional)')),
                const SizedBox(height: 8),
                TextField(controller: _emailSubject, decoration: const InputDecoration(labelText: 'Default subject')),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailBody,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Default body', alignLabelWithHint: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailHtml,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Default html_body (optional)', alignLabelWithHint: true),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _savingEmail ? null : _saveEmail,
                    child: _savingEmail
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Email Defaults'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF0B1225),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SMS defaults (Twilio)', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(controller: _smsTo, decoration: const InputDecoration(labelText: 'Default to')),
                const SizedBox(height: 8),
                TextField(
                  controller: _smsBody,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Default body', alignLabelWithHint: true),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can use variables like {{name}}, {{date}}, {{time}}. They are filled from tool call `variables`.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _savingSms ? null : _saveSms,
                    child: _savingSms
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save SMS Defaults'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Color(0xFFF59E0B))),
        ],
      ],
    );
  }
}

class _EmailTemplatesSection extends ConsumerWidget {
  final String operatorId;
  final VoidCallback onAdd;
  final void Function(EmailTemplate t) onEditTemplate;

  const _EmailTemplatesSection({
    required this.operatorId,
    required this.onAdd,
    required this.onEditTemplate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(emailTemplatesForOperatorProvider(operatorId));

    return Card(
      color: const Color(0xFF0B1225),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Email Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
              ],
            ),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text(
                'Could not load templates: $e',
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Text(
                    'No templates yet. Use Add or the floating button to create one.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  );
                }
                return Column(
                  children: list.map((t) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: const Color(0xFF111827),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.name.isEmpty ? '(unnamed)' : t.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => onEditTemplate(t),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete template?'),
                                        content: Text('Delete "${t.name}"?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (ok == true && context.mounted) {
                                      try {
                                        await EmailTemplatesApi.deleteTemplate(
                                          operatorId: operatorId,
                                          templateId: t.id,
                                        );
                                        ref.invalidate(emailTemplatesForOperatorProvider(operatorId));
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                            ),
                            if (t.variables.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: t.variables
                                    .map(
                                      (v) => Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text('{{$v}}', style: const TextStyle(fontSize: 11)),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Create or update an operator email template; debounced variable detection for `{{var}}`.
class CreateEditEmailTemplateSheet extends StatefulWidget {
  final String operatorId;
  final EmailTemplate? existing;
  final VoidCallback onSaved;

  const CreateEditEmailTemplateSheet({
    super.key,
    required this.operatorId,
    this.existing,
    required this.onSaved,
  });

  @override
  State<CreateEditEmailTemplateSheet> createState() => _CreateEditEmailTemplateSheetState();
}

class _CreateEditEmailTemplateSheetState extends State<CreateEditEmailTemplateSheet> {
  late final TextEditingController _name;
  late final TextEditingController _subject;
  late final TextEditingController _body;
  late final TextEditingController _html;
  Timer? _debounce;
  List<String> _detected = [];
  bool _htmlOpen = false;
  bool _saving = false;
  String? _error;

  static final _varRe = RegExp(r'\{\{(\w+)\}\}');

  static List<String> _extractVars(String a, String b, String c) {
    final seen = <String>{};
    final out = <String>[];
    for (final m in _varRe.allMatches('$a\n$b\n$c')) {
      final n = m.group(1)!;
      if (seen.add(n)) out.add(n);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _subject = TextEditingController(text: e?.subject ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _html = TextEditingController(text: e?.htmlBody ?? '');
    _detected = _extractVars(_name.text, _subject.text, '${_body.text}\n${_html.text}');
    for (final c in [_name, _subject, _body, _html]) {
      c.addListener(_scheduleDetect);
    }
  }

  void _scheduleDetect() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _detected = _extractVars(_name.text, _subject.text, '${_body.text}\n${_html.text}');
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _subject.dispose();
    _body.dispose();
    _html.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final name = _name.text.trim();
    final subject = _subject.text;
    final body = _body.text;
    final html = _html.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Template name is required.');
      return;
    }
    setState(() => _saving = true);
    try {
      final ex = widget.existing;
      if (ex == null) {
        await EmailTemplatesApi.createTemplate(
          operatorId: widget.operatorId,
          name: name,
          subject: subject,
          body: body,
          htmlBody: html.isEmpty ? null : html,
        );
      } else {
        await EmailTemplatesApi.updateTemplate(
          operatorId: widget.operatorId,
          templateId: ex.id,
          name: name,
          subject: subject,
          body: body,
          htmlBody: html,
        );
      }
      if (!mounted) return;
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.existing == null ? 'New email template' : 'Edit template';
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Template name')),
            const SizedBox(height: 10),
            TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Body',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('HTML body (optional)'),
              initiallyExpanded: _htmlOpen,
              onExpansionChanged: (v) => setState(() => _htmlOpen = v),
              children: [
                TextField(
                  controller: _html,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Optional HTML version',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Detected variables', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            if (_detected.isEmpty)
              const Text('None yet — use {{name}} style placeholders.', style: TextStyle(color: Colors.white38, fontSize: 12))
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _detected.map((v) => Chip(label: Text('{{$v}}', style: const TextStyle(fontSize: 11)))).toList(),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFF59E0B))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save template'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsTemplatesSection extends ConsumerWidget {
  final String operatorId;
  final VoidCallback onAdd;
  final void Function(SmsTemplate t) onEditTemplate;

  const _SmsTemplatesSection({
    required this.operatorId,
    required this.onAdd,
    required this.onEditTemplate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(smsTemplatesForOperatorProvider(operatorId));

    return Card(
      color: const Color(0xFF0B1225),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('SMS Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
              ],
            ),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text(
                'Could not load SMS templates: $e',
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Text(
                    'No SMS templates yet. Add one for the sendSMS tool (Twilio).',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  );
                }
                return Column(
                  children: list.map((t) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: const Color(0xFF111827),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.name.isEmpty ? '(unnamed)' : t.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => onEditTemplate(t),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete SMS template?'),
                                        content: Text('Delete "${t.name}"?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (ok == true && context.mounted) {
                                      try {
                                        await SmsApi.deleteTemplate(
                                          operatorId: operatorId,
                                          templateId: t.id,
                                        );
                                        ref.invalidate(smsTemplatesForOperatorProvider(operatorId));
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '~${t.charCount} chars · ${t.segments} segment(s)',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            if (t.variables.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: t.variables
                                    .map(
                                      (v) => Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text('{{$v}}', style: const TextStyle(fontSize: 11)),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

int _smsEstimatedLen(String body) {
  return body.replaceAllMapped(RegExp(r'\{\{\w+\}\}'), (_) => 'X' * 10).length;
}

int _smsEstimatedSegments(String body) {
  final n = _smsEstimatedLen(body);
  if (n <= 160) return 1;
  return (n + 152) ~/ 153;
}

/// Create or update an operator SMS template; live segment meter + debounced {{var}} detection.
class CreateEditSmsTemplateSheet extends StatefulWidget {
  final String operatorId;
  final SmsTemplate? existing;
  final VoidCallback onSaved;

  const CreateEditSmsTemplateSheet({
    super.key,
    required this.operatorId,
    this.existing,
    required this.onSaved,
  });

  @override
  State<CreateEditSmsTemplateSheet> createState() => _CreateEditSmsTemplateSheetState();
}

class _CreateEditSmsTemplateSheetState extends State<CreateEditSmsTemplateSheet> {
  late final TextEditingController _name;
  late final TextEditingController _body;
  Timer? _debounce;
  List<String> _detected = [];
  bool _saving = false;
  String? _error;

  static final _varRe = RegExp(r'\{\{(\w+)\}\}');

  static List<String> _extractVars(String name, String body) {
    final seen = <String>{};
    final out = <String>[];
    for (final m in _varRe.allMatches('$name\n$body')) {
      final n = m.group(1)!;
      if (seen.add(n)) out.add(n);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _detected = _extractVars(_name.text, _body.text);
    _name.addListener(_scheduleDetect);
    _body.addListener(_scheduleDetect);
    _body.addListener(() => setState(() {}));
  }

  void _scheduleDetect() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _detected = _extractVars(_name.text, _body.text);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final name = _name.text.trim();
    final body = _body.text;
    if (name.isEmpty) {
      setState(() => _error = 'Template name is required.');
      return;
    }
    if (body.trim().isEmpty) {
      setState(() => _error = 'Message body is required.');
      return;
    }
    setState(() => _saving = true);
    try {
      final ex = widget.existing;
      if (ex == null) {
        await SmsApi.createTemplate(
          operatorId: widget.operatorId,
          name: name,
          body: body,
        );
      } else {
        await SmsApi.updateTemplate(
          operatorId: widget.operatorId,
          templateId: ex.id,
          name: name,
          body: body,
        );
      }
      if (!mounted) return;
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.existing == null ? 'New SMS template' : 'Edit SMS template';
    final estLen = _smsEstimatedLen(_body.text);
    final segs = _smsEstimatedSegments(_body.text);
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Template name')),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Message body',
                alignLabelWithHint: true,
                hintText: 'Hi {{name}}, thanks for calling…',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '~$estLen characters · $segs SMS segment(s) (estimated after filling {{variables}})',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tip: recipients can reply STOP to opt out of SMS; keep messages concise and include your business name when appropriate.',
              style: TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 10),
            const Text('Detected variables', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            if (_detected.isEmpty)
              const Text('None yet — use {{name}} style placeholders.', style: TextStyle(color: Colors.white38, fontSize: 12))
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _detected.map((v) => Chip(label: Text('{{$v}}', style: const TextStyle(fontSize: 11)))).toList(),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFF59E0B))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save SMS template'),
            ),
          ],
        ),
      ),
    );
  }
}

