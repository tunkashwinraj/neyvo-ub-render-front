// lib/features/managed_profiles/profile_detail_page.dart
// Profile detail with tabs: Overview, Edit, AI Studio, Call Logs, Performance.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as ul;
import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import '../../pulse_route_names.dart';
import '../../theme/neyvo_theme.dart';
import '../../widgets/upgrade_nudge_widget.dart';
import '../../screens/plan_selector_page.dart';
import 'managed_profile_api_service.dart';

class ManagedProfileDetailPage extends StatefulWidget {
  const ManagedProfileDetailPage({
    super.key,
    required this.profileId,
    this.embedded = false,
  });

  final String profileId;
  final bool embedded;

  @override
  State<ManagedProfileDetailPage> createState() => _ManagedProfileDetailPageState();
}

class _ManagedProfileDetailPageState extends State<ManagedProfileDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  bool _callInitiating = false;
  SubscriptionPlan? _subscriptionPlan;
  bool _loadingPlan = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _load();
    _loadSubscription();
  }

  bool get _canMakeOutboundCalls {
    final plan = _subscriptionPlan;
    if (plan == null) return false;
    return plan.features.canMakeOutboundCalls;
  }

  void _showUpgradeForOutbound() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NeyvoColors.bgBase,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outbound calls are a Pro feature',
                style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
              ),
              const SizedBox(height: 12),
              UpgradeNudge(
                message: 'Upgrade to Pro or Business to place outbound calls from this voice profile.',
                ctaLabel: 'View plans',
                onUpgrade: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const PlanSelectorPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ManagedProfileApiService.getProfile(widget.profileId);
      setState(() { _profile = res; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadSubscription() async {
    setState(() => _loadingPlan = true);
    try {
      final plan = await SubscriptionService.getCurrentPlan();
      if (!mounted) return;
      setState(() {
        _subscriptionPlan = plan;
        _loadingPlan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator(color: NeyvoColors.teal))
        : _error != null
            ? Center(child: Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)))
            : Column(
                children: [
                  if ((_profile?['status'] as String? ?? 'active') == 'active')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _canMakeOutboundCalls
                                  ? _onMakeOutboundCall
                                  : _showUpgradeForOutbound,
                              icon: Icon(
                                _canMakeOutboundCalls ? Icons.call : Icons.lock,
                                size: 16,
                              ),
                              label: Text(
                                _canMakeOutboundCalls
                                    ? 'Make Outbound Call'
                                    : 'Upgrade to enable outbound calls',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _onTestCall,
                              icon: const Icon(Icons.headset, size: 16),
                              label: const Text('Test Call'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _OverviewTab(profileId: widget.profileId, profile: _profile!, onRefresh: _load),
                        _EditTab(profileId: widget.profileId, profile: _profile!, onSaved: _load),
                        _AIStudioTab(
                          profileId: widget.profileId,
                          subscriptionPlan: _subscriptionPlan,
                          loadingPlan: _loadingPlan,
                        ),
                        _CallLogsTab(profileId: widget.profileId),
                        _PerformanceTab(profileId: widget.profileId),
                      ],
                    ),
                  ),
                ],
              );

    if (widget.embedded) {
      // Embedded inside split-view; no own Scaffold or back button.
      return Container(
        color: NeyvoColors.bgVoid,
        child: Column(
          children: [
            Container(
              color: NeyvoColors.bgBase,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TabBar(
                controller: _tabController,
                labelColor: NeyvoColors.teal,
                unselectedLabelColor: NeyvoColors.textSecondary,
                indicatorColor: NeyvoColors.teal,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Edit'),
                  Tab(text: 'AI Studio'),
                  Tab(text: 'Calls'),
                  Tab(text: 'Performance'),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      appBar: AppBar(
        backgroundColor: NeyvoColors.bgBase,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeyvoColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _profile?['profile_name'] as String? ?? 'Voice Profile',
          style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: NeyvoColors.teal,
          unselectedLabelColor: NeyvoColors.textSecondary,
          indicatorColor: NeyvoColors.teal,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Edit'),
            Tab(text: 'AI Studio'),
            Tab(text: 'Calls'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: content,
    );
  }

  Future<void> _onMakeOutboundCall() async {
    final profile = _profile ?? {};
    final attachedNumber = profile['attached_phone_number'] as String?;
    final vapiNumberId = profile['attached_vapi_phone_number_id'] as String?;
    final industryId = profile['industry_id'] as String? ?? '';
    if (attachedNumber == null || attachedNumber.isEmpty || vapiNumberId == null || vapiNumberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attach a phone number to this profile before making calls.')),
      );
      return;
    }
    final phoneController = TextEditingController();
    final nameController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: NeyvoColors.bgBase,
      isScrollControlled: true,
      builder: (ctx) {
        final label = industryId == 'school_financial_aid' ? 'Student name (optional)' : 'Client name (optional)';
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setInnerState) {
              bool isValid(String input) {
                final trimmed = input.trim();
                final e164 = RegExp(r'^\+[0-9]{8,15}$');
                return e164.hasMatch(trimmed);
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Make Outbound Call', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('From: $attachedNumber', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                  Text(
                    'Using profile: ${profile['profile_name'] ?? ''}',
                    style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number to call',
                      hintText: '+12035551234',
                      border: OutlineInputBorder(),
                    ),
                    style: NeyvoTextStyles.bodyPrimary,
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use full international format (E.164), for example +12035551234.',
                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: label,
                      helperText: industryId == 'school_financial_aid'
                          ? 'Used only to greet the student by name; not stored permanently.'
                          : 'Used only for a warmer greeting; not stored permanently.',
                      border: const OutlineInputBorder(),
                    ),
                    style: NeyvoTextStyles.bodyPrimary,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _callInitiating || !isValid(phoneController.text)
                            ? null
                            : () async {
                                final to = phoneController.text.trim();
                            final overrides = <String, dynamic>{};
                            final name = nameController.text.trim();
                            if (name.isNotEmpty) {
                              if (industryId == 'school_financial_aid') {
                                overrides['studentName'] = name;
                              } else {
                                overrides['clientName'] = name;
                              }
                            }
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            setState(() => _callInitiating = true);
                            try {
                              await ManagedProfileApiService.makeOutboundCall(
                                profileId: widget.profileId,
                                customerPhone: to,
                                overrides: overrides,
                              );
                              if (!mounted) return;
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(content: Text('Call initiated to $to')),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              final msg = e.toString();
                              if (msg.contains('402') || msg.toLowerCase().contains('insufficient')) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Insufficient credits — top up your wallet to make calls.')),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed to start call: $e')),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _callInitiating = false);
                              }
                            }
                          },
                        style: ElevatedButton.styleFrom(backgroundColor: NeyvoColors.teal),
                        child: _callInitiating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Call Now'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onTestCall() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await ManagedProfileApiService.getWebCallToken(widget.profileId);
      final assistantId = token['assistant_id'] as String? ?? '';
      final publicKey = token['public_key'] as String? ?? '';
      final profileName = token['profile_name'] as String? ?? 'Voice Profile';
      if (assistantId.isEmpty || publicKey.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Test call is not available for this profile.')),
        );
        return;
      }
      final base = SpeariaApi.baseUrl;
      final webCallUrl = Uri.parse(
        '$base/api/managed-profiles/web-call-page'
        '?assistant_id=$assistantId'
        '&public_key=$publicKey'
        '&profile_name=${Uri.encodeComponent(profileName)}',
      );
      if (!await ul.launchUrl(webCallUrl, mode: ul.LaunchMode.inAppBrowserView)) {
        await ul.launchUrl(webCallUrl, mode: ul.LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to open test call: $e')),
      );
    }
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.profileId, required this.profile, required this.onRefresh});

  final String profileId;
  final Map<String, dynamic> profile;
  final VoidCallback onRefresh;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _toggling = false;

  Widget _buildConnectionsCard(Map<String, dynamic> businessContent) {
    final integration = businessContent['integration_selection'];
    final integrationMap = integration is Map ? Map<String, dynamic>.from(integration) : <String, dynamic>{};
    final schedulingProvider = (integrationMap['scheduling_provider'] ?? '').toString().trim().toLowerCase();
    final hasSchedulingSelected = schedulingProvider.isNotEmpty && schedulingProvider != 'none';
    final leadCaptureMode = !hasSchedulingSelected;

    final title = leadCaptureMode ? 'Lead capture mode' : 'Scheduling system selected';
    final statusText = leadCaptureMode
        ? 'Your voice profile will collect details and your team can confirm by text or call.'
        : 'Connection not verified yet. Connect to enable live booking actions.';

    final icon = leadCaptureMode ? Icons.info_outline : Icons.warning_amber_rounded;
    final iconColor = leadCaptureMode ? NeyvoColors.textMuted : NeyvoColors.warning;

    return NeyvoCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, size: 20, color: NeyvoColors.teal),
                const SizedBox(width: 8),
                Text('Connections', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeyvoColors.bgRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NeyvoColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(statusText, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!leadCaptureMode)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.integration),
                    style: ElevatedButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Connect now'),
                  ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.settings),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Open settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(String status) async {
    setState(() => _toggling = true);
    try {
      await ManagedProfileApiService.updateProfile(widget.profileId, {'status': status});
      if (mounted) widget.onRefresh();
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bc = widget.profile['business_content'] as Map<String, dynamic>? ?? {};
    final status = widget.profile['status'] as String? ?? 'active';
    final vapiId = widget.profile['vapi_assistant_id'] as String? ?? '';
    final attachedNumber = widget.profile['attached_phone_number'] as String?;
    final attachedNumberId = widget.profile['attached_phone_number_id'] as String?;
    final subscriptionTier = (widget.profile['subscription_tier'] as String?)?.toLowerCase();
    final voiceTier = (widget.profile['voice_tier'] as String?)?.toLowerCase();
    final installedCapabilities = (widget.profile['installed_capabilities'] as List?)?.cast<dynamic>() ?? const [];

    String tierLabel(String? t) {
      switch (t) {
        case 'business':
          return 'Business';
        case 'pro':
          return 'Pro';
        case 'free':
          return 'Free';
        default:
          return '';
      }
    }

    String voiceTierLabel(String? t) {
      switch (t) {
        case 'neutral':
          return 'Neutral Human';
        case 'natural':
          return 'Natural Human';
        case 'ultra':
          return 'Ultra Real Human';
        default:
          return '';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeyvoCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.profile['industry_id'] == 'school_financial_aid'
                            ? Icons.school
                            : Icons.content_cut,
                        size: 28,
                        color: NeyvoColors.teal,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.profile['profile_name'] as String? ?? '',
                          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'active' ? NeyvoColors.teal.withValues(alpha: 0.2) : NeyvoColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: NeyvoTextStyles.micro.copyWith(color: status == 'active' ? NeyvoColors.teal : NeyvoColors.warning),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Industry: ${widget.profile['industry_id'] == 'school_financial_aid' ? 'Education' : 'Salon & Spa'}',
                    style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                  ),
                  Text(
                    'Goal: ${bc['primary_goal'] ?? ''}',
                    style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                  ),
                  if (installedCapabilities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Capabilities:',
                      style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: installedCapabilities
                          .map((c) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: NeyvoColors.bgRaised,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: NeyvoColors.borderSubtle),
                                ),
                                child: Text(
                                  c.toString().replaceAll('Capability_v1', '').replaceAll('_', ' '),
                                  style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (subscriptionTier != null && subscriptionTier.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: NeyvoColors.bgRaised,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: NeyvoColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.workspace_premium_outlined, size: 14, color: NeyvoColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                tierLabel(subscriptionTier),
                                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (voiceTier != null && voiceTier.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: NeyvoColors.bgRaised,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: NeyvoColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.record_voice_over_outlined, size: 14, color: NeyvoColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                voiceTierLabel(voiceTier),
                                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_toggling)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.teal),
                        )
                      else if (status == 'active')
                        TextButton(onPressed: () => _setStatus('paused'), child: const Text('Pause'))
                      else
                        TextButton(onPressed: () => _setStatus('active'), child: const Text('Activate')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildConnectionsCard(bc),
          const SizedBox(height: 16),
          _buildPhoneNumberCard(attachedNumberId, attachedNumber ?? ''),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Profile ID: $vapiId',
                  style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (vapiId.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: NeyvoColors.textSecondary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: vapiId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Version: v${widget.profile['version'] ?? 1}', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
          Text('Created: ${widget.profile['created_at'] ?? ''}', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
          Text('Updated: ${widget.profile['updated_at'] ?? ''}', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _showArchiveConfirmation,
            icon: const Icon(Icons.archive_outlined, size: 16, color: Colors.red),
            label: const Text('Archive Profile', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showArchiveConfirmation() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Archive this profile?'),
          content: const Text(
            'The profile will be deactivated and its phone number detached. '
            'All call history is preserved. The profile becomes read-only.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _archiveProfile();
              },
              child: const Text('Archive', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _archiveProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ManagedProfileApiService.archiveProfile(widget.profileId);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile archived. Call history preserved.')),
      );
      navigator.pop(); // Back to profiles list
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Archive failed: $e')),
      );
    }
  }

  Widget _buildPhoneNumberCard(String? numberId, String numberE164) {
    final hasNumber = numberId != null && numberId.isNotEmpty && numberE164.isNotEmpty;
    if (!hasNumber) {
      return NeyvoCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_in_talk_outlined, size: 18, color: NeyvoColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('Phone Number', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              Text('No phone number attached', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                'Attach a number to enable inbound and outbound calls for this profile.',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _showAttachSheet,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Attach Number'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final displayNumber = numberE164;
    return NeyvoCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_in_talk, size: 18, color: NeyvoColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayNumber,
                    style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _confirmDetach,
                  child: const Text('Detach'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _pill('Inbound Active', NeyvoColors.teal),
                const SizedBox(width: 8),
                _pill('Outbound Active', NeyvoColors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: NeyvoTextStyles.micro.copyWith(color: color)),
    );
  }

  Future<void> _showAttachSheet() async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final res = await NeyvoPulseApi.listNumbers();
      final raw = res['numbers'] as List? ?? [];
      final numbers = raw.cast<Map<String, dynamic>>();
      if (!mounted) return;
      if (numbers.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text("You don't have any phone numbers yet. Go to Phone Numbers to buy one.")),
        );
        return;
      }
      await showModalBottomSheet(
        context: context,
        backgroundColor: NeyvoColors.bgBase,
        isScrollControlled: true,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Phone Number', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: numbers.length,
                      itemBuilder: (context, index) {
                        final n = numbers[index];
                        final id = (n['number_id'] ?? n['phone_number_id'])?.toString() ?? '';
                        final phone = (n['phone_number'] ?? '') as String? ?? '';
                        final friendly = (n['friendly_name'] ?? '') as String? ?? '';
                        final attachedName = n['attached_profile_name'] as String?;
                        return ListTile(
                          title: Text(phone.isNotEmpty ? phone : friendly),
                          subtitle: attachedName != null && attachedName.isNotEmpty
                              ? Text('Attached to: $attachedName', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.warning))
                              : null,
                          onTap: () async {
                            final messengerInner = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            try {
                              await ManagedProfileApiService.attachPhoneNumber(
                                profileId: widget.profileId,
                                phoneNumberId: id,
                                vapiPhoneNumberId: id,
                              );
                              if (!mounted) return;
                              navigator.pop();
                              messengerInner.showSnackBar(
                                SnackBar(content: Text('Number attached — inbound calls active on $phone')),
                              );
                              widget.onRefresh();
                            } catch (e) {
                              if (!mounted) return;
                              messengerInner.showSnackBar(
                                SnackBar(content: Text('Failed to attach number: $e')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text('Failed to load numbers: $e')));
    }
  }

  Future<void> _confirmDetach() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detach number'),
        content: const Text(
          'Detach this phone number from the profile? Inbound calls to this number will no longer reach this profile.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Detach')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ManagedProfileApiService.detachPhoneNumber(widget.profileId);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Number detached')),
      );
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to detach number: $e')),
      );
    }
  }
}

class _EditTab extends StatefulWidget {
  const _EditTab({required this.profileId, required this.profile, required this.onSaved});

  final String profileId;
  final Map<String, dynamic> profile;
  final VoidCallback onSaved;

  @override
  State<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<_EditTab> {
  final _businessName = TextEditingController();
  final _primaryGoal = TextEditingController();
  final _phoneNumber = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final bc = widget.profile['business_content'] as Map<String, dynamic>? ?? {};
    _businessName.text = bc['business_name'] as String? ?? '';
    _primaryGoal.text = bc['primary_goal'] as String? ?? '';
    _phoneNumber.text = bc['phone_number'] as String? ?? '';
  }

  @override
  void dispose() {
    _businessName.dispose();
    _primaryGoal.dispose();
    _phoneNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ManagedProfileApiService.updateProfile(widget.profileId, {
        'business_name': _businessName.text.trim(),
        'primary_goal': _primaryGoal.text.trim(),
        'phone_number': _phoneNumber.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated and synced'), backgroundColor: NeyvoColors.teal));
        widget.onSaved();
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
          const SizedBox(height: 8),
          TextField(controller: _businessName, decoration: const InputDecoration(labelText: 'Business name'), style: NeyvoTextStyles.bodyPrimary),
          TextField(controller: _primaryGoal, maxLines: 3, decoration: const InputDecoration(labelText: 'Primary goal'), style: NeyvoTextStyles.bodyPrimary),
          TextField(controller: _phoneNumber, decoration: const InputDecoration(labelText: 'Phone number'), style: NeyvoTextStyles.bodyPrimary, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: NeyvoColors.teal), child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes')),
        ],
      ),
    );
  }
}

class _AIStudioTab extends StatefulWidget {
  const _AIStudioTab({
    required this.profileId,
    required this.subscriptionPlan,
    required this.loadingPlan,
  });

  final String profileId;
  final SubscriptionPlan? subscriptionPlan;
  final bool loadingPlan;

  @override
  State<_AIStudioTab> createState() => _AIStudioTabState();
}

class _AIStudioTabState extends State<_AIStudioTab> {
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _chatHistory = [];
  Map<String, dynamic>? _suggestion;
  bool _loading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty || _loading) return;
    _messageController.clear();
    setState(() {
      _chatHistory.add({'role': 'user', 'content': msg});
      _loading = true;
      _suggestion = null;
    });
    try {
      final res = await ManagedProfileApiService.aiSuggest(widget.profileId, msg);
      final explanation = res['explanation'] as String? ?? '';
      final proposed = res['proposed_changes'] as Map<String, dynamic>? ?? {};
      final preview = res['preview_text'] as String? ?? '';
      if (mounted) {
        setState(() {
          _chatHistory.add({'role': 'assistant', 'content': explanation, 'proposed_changes': proposed, 'preview_text': preview});
          _suggestion = proposed.isNotEmpty ? res : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatHistory.add({'role': 'assistant', 'content': 'Sorry, something went wrong. Please try again.'});
          _loading = false;
        });
      }
    }
  }

  Future<void> _applyChanges() async {
    if (_suggestion == null || _suggestion!['proposed_changes'] == null) return;
    final changes = _suggestion!['proposed_changes'] as Map<String, dynamic>? ?? {};
    if (changes.isEmpty) return;
    try {
      await ManagedProfileApiService.updateProfile(widget.profileId, changes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
        setState(() => _suggestion = null);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.subscriptionPlan;
    final loadingPlan = widget.loadingPlan;
    final locked = !loadingPlan &&
        (plan == null || !plan.features.canUseAiStudio);

    if (locked) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Studio is a Pro feature',
              style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
            ),
            const SizedBox(height: 12),
            UpgradeNudge(
              message:
                  'Upgrade to Pro or Business to get AI-powered suggestions for this voice profile.',
              ctaLabel: 'View plans',
              onUpgrade: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PlanSelectorPage()),
                );
              },
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'AI suggestions use a small amount of studio credits, not your call minutes. Good for refining goal, wording, and business specifics.',
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
        );
        if (narrow) {
          return Column(
            children: [
              header,
              Expanded(child: _chatPanel()),
              if (_suggestion != null)
                _suggestionPanel(
                  onApply: _applyChanges,
                  onDismiss: () => setState(() => _suggestion = null),
                ),
            ],
          );
        }
        return Column(
          children: [
            header,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _chatPanel()),
                  const SizedBox(width: 16),
                  if (_suggestion != null)
                    Expanded(
                      flex: 4,
                      child: _suggestionPanel(
                        onApply: _applyChanges,
                        onDismiss: () => setState(() => _suggestion = null),
                      ),
                    )
                  else
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: Text(
                          'Describe what you want to change. Suggested changes will appear here.',
                          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chatPanel() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chatHistory.length + (_loading ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _chatHistory.length) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.teal)), const SizedBox(width: 8), Text('Thinking...', style: NeyvoTextStyles.body)]),
                );
              }
              final item = _chatHistory[i];
              final isUser = item['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? NeyvoColors.teal.withValues(alpha: 0.3) : NeyvoColors.bgRaised,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: BoxConstraints(maxWidth: 320),
                  child: Text(item['content'] as String? ?? '', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Describe what you want to change...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: NeyvoColors.bgRaised,
                  ),
                  style: NeyvoTextStyles.bodyPrimary,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _loading ? null : _send,
                icon: const Icon(Icons.send),
                style: IconButton.styleFrom(backgroundColor: NeyvoColors.teal),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _suggestionPanel({required VoidCallback onApply, required VoidCallback onDismiss}) {
    final proposed = _suggestion?['proposed_changes'] as Map<String, dynamic>? ?? {};
    final preview = _suggestion?['preview_text'] as String? ?? '';
    final isEmpty = proposed.isEmpty;
    return NeyvoCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suggested Changes', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
            const SizedBox(height: 12),
            if (isEmpty)
              Text(
                'Voice timing and conversation mechanics are managed automatically by Neyvo for the best quality. I can help you update the wording, goal, or specific instructions instead.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
              )
            else ...[
              ...proposed.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${_fieldLabel(e.key)} → ${e.value}', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('How it will sound:', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                const SizedBox(height: 4),
                Text(preview, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(onPressed: onApply, style: ElevatedButton.styleFrom(backgroundColor: NeyvoColors.teal), child: const Text('Apply Changes')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fieldLabel(String key) {
    if (key == 'primary_goal') return 'Primary goal';
    if (key == 'agent_persona_name') return 'Agent name';
    if (key == 'voicemail_enabled') return 'Voicemail';
    if (key == 'business_specifics') return 'Business specifics';
    return key.replaceAll('_', ' ').split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
  }
}

class _CallLogsTab extends StatefulWidget {
  const _CallLogsTab({required this.profileId});

  final String profileId;

  @override
  State<_CallLogsTab> createState() => _CallLogsTabState();
}

class _CallLogsTabState extends State<_CallLogsTab> {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ManagedProfileApiService.getProfileCalls(widget.profileId);
      final list = (res['calls'] as List?)?.cast<dynamic>() ?? [];
      if (mounted) {
        setState(() {
          _calls = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  static String _formatDuration(int sec) {
    if (sec < 60) return '${sec}s';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m}m ${s}s';
  }

  static Color _outcomeColor(String outcome) {
    if (outcome == 'completed_goal' || outcome == 'appointment_booked' || outcome == 'appointment_confirmed') return NeyvoColors.success;
    if (outcome == 'voicemail') return NeyvoColors.info;
    if (outcome == 'no_answer') return NeyvoColors.textMuted;
    return NeyvoColors.error;
  }

  static String _outcomeLabel(String outcome) {
    if (outcome.isEmpty) return '—';
    if (outcome == 'completed_goal' || outcome == 'appointment_booked' || outcome == 'appointment_confirmed') return 'Completed';
    if (outcome == 'voicemail') return 'Voicemail';
    if (outcome == 'no_answer') return 'No Answer';
    return outcome;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    if (_calls.isEmpty) {
      return Center(
        child: Text(
          'No calls made through this profile yet.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: DataTable(
          headingTextStyle: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textPrimary),
          dataTextStyle: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Duration')),
            DataColumn(label: Text('Outcome')),
            DataColumn(label: Text('Credits')),
          ],
          rows: _calls.map((c) {
            final created = c['created_at'] as String? ?? '';
            final phone = c['phone'] as String? ?? '';
            final dur = c['duration_seconds'] as int? ?? 0;
            final outcome = c['outcome'] as String? ?? '';
            final credits = c['credits_used'] as int? ?? 0;
            return DataRow(
              onSelectChanged: (_) => _openCallDetail(c),
              cells: [
              DataCell(Text(created.length > 16 ? created.substring(0, 16) : created)),
              DataCell(Text(phone)),
              DataCell(Text(_formatDuration(dur))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _outcomeColor(outcome).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(_outcomeLabel(outcome), style: NeyvoTextStyles.micro.copyWith(color: _outcomeColor(outcome))),
              )),
              DataCell(Text('$credits')),
            ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openCallDetail(Map<String, dynamic> call) {
    final transcript = call['transcript'] as String? ?? '';
    final structured = call['structured_data'] as Map<String, dynamic>? ?? {};
    showModalBottomSheet(
      context: context,
      backgroundColor: NeyvoColors.bgBase,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  Text('Call detail', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
                  const SizedBox(height: 12),
                  Text('Transcript', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                  const SizedBox(height: 6),
                  NeyvoCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        transcript.isEmpty ? 'No transcript available for this call.' : transcript,
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Structured data', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                  const SizedBox(height: 6),
                  NeyvoCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        structured.isEmpty ? 'No structured data extracted.' : structured.toString(),
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PerformanceTab extends StatefulWidget {
  const _PerformanceTab({required this.profileId});

  final String profileId;

  @override
  State<_PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<_PerformanceTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ManagedProfileApiService.getProfilePerformance(widget.profileId);
      if (mounted) setState(() { _stats = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    final total = _stats?['total_calls'] as int? ?? 0;
    if (total < 5) {
      return Center(
        child: Text(
          'Make more calls to see performance data.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
      );
    }
    final completed = _stats?['completed_calls'] as int? ?? 0;
    final rate = _stats?['completion_rate'] as num? ?? 0;
    final avgSec = _stats?['avg_duration_seconds'] as int? ?? 0;
    final credits = _stats?['total_credits_used'] as int? ?? 0;
    final avgMin = (avgSec / 60).toStringAsFixed(1);
    final daily = (_stats?['daily_last_30_days'] as List?)?.cast<dynamic>() ?? const [];
    final dailyCounts = daily.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCard('Total Calls', '$total'),
              const SizedBox(width: 16),
              _statCard('Completion Rate', '$rate%'),
              const SizedBox(width: 16),
              _statCard('Avg Duration', '${avgMin}m'),
              const SizedBox(width: 16),
              _statCard('Credits Used', '$credits'),
            ],
          ),
          if (dailyCounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            NeyvoCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Calls per day (last 30 days)', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                    const SizedBox(height: 10),
                    _DailyBarChart(dailyCounts: dailyCounts),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          NeyvoCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'This profile has completed $completed of $total calls successfully ($rate%). Average call length is $avgMin minutes.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: NeyvoCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
              const SizedBox(height: 4),
              Text(value, style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.dailyCounts});

  final List<Map<String, dynamic>> dailyCounts;

  @override
  Widget build(BuildContext context) {
    final counts = dailyCounts.map((e) => (e['count'] as int?) ?? 0).toList();
    final maxCount = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
    if (maxCount <= 0) {
      return Text('No calls in the last 30 days.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary));
    }
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final c in counts)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  height: 8 + (c / maxCount) * 100,
                  decoration: BoxDecoration(
                    color: NeyvoColors.teal.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
