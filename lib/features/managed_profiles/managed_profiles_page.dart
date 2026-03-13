// lib/features/managed_profiles/managed_profiles_page.dart
// Managed Voice Profiles — isolated feature; no changes to Agents page.

import 'package:flutter/material.dart';
import '../../theme/neyvo_theme.dart';
import '../../tenant/tenant_brand.dart';
import '../agents/create_agent_wizard.dart';
import 'managed_profile_api_service.dart';
import 'profile_detail_page.dart';

class ManagedProfilesPage extends StatefulWidget {
  const ManagedProfilesPage({super.key, this.onOpenProfileDetail});

  /// When set (e.g. by Pulse shell), opening a profile navigates to the detail page inside the shell instead of pushing a full-screen page.
  final void Function(String profileId)? onOpenProfileDetail;

  @override
  State<ManagedProfilesPage> createState() => ManagedProfilesPageState();
}

class ManagedProfilesPageState extends State<ManagedProfilesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _profiles = [];

  void refresh() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ManagedProfileApiService.listProfiles();
      final list = (res['profiles'] as List?)?.cast<dynamic>() ?? [];
      if (!mounted) return;
      setState(() {
        _profiles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreateAgent() async {
    // No business wizard gate — allow creating operators directly.
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => const CreateAgentWizard(),
    );
    if (created == true && mounted) {
      _load();
    }
  }

  void _openProfileDetail(String profileId) {
    // Always open detail on a separate page (inside Pulse shell when callback is set).
    final onOpen = widget.onOpenProfileDetail;
    if (onOpen != null) {
      onOpen(profileId);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManagedProfileDetailPage(profileId: profileId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = TenantBrand.primary(context);
    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Operators',
                  style: NeyvoTextStyles.title.copyWith(
                    fontWeight: FontWeight.w700,
                    color: NeyvoColors.textPrimary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openCreateAgent,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Operator'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: TenantBrand.primary(context)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.record_voice_over_outlined, size: 48, color: NeyvoColors.textMuted),
            const SizedBox(height: 16),
            Text('No operators yet', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Create your first operator in under 2 minutes.',
              style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreateAgent,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Operator'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TenantBrand.primary(context),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _profiles.length,
            itemBuilder: (context, i) {
              final p = _profiles[i];
              return _profileCard(p);
            },
          );
        },
      ),
    );
  }

  Widget _profileCard(Map<String, dynamic> p) {
    final name = p['profile_name'] as String? ?? 'Unnamed';
    final status = p['status'] as String? ?? 'active';
    final industryId = p['industry_id'] as String? ?? '';
    final voiceStyle = p['voice_style'] as String? ?? '';
    final version = p['version'] as int? ?? 1;
    final created = p['created_at'] as String? ?? '';
    String createdLabel = created;
    if (created.length >= 10) {
      try {
        final dt = DateTime.tryParse(created);
        if (dt != null) {
          final now = DateTime.now();
          final diff = now.difference(dt);
          if (diff.inDays > 0) {
            createdLabel = '${diff.inDays} days ago';
          } else if (diff.inHours > 0) {
            createdLabel = '${diff.inHours} hours ago';
          } else if (diff.inMinutes > 0) {
            createdLabel = '${diff.inMinutes} min ago';
          } else {
            createdLabel = 'Just now';
          }
        }
      } catch (_) {}
    }
    return Material(
      color: NeyvoColors.bgRaised,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openProfileDetail(p['profile_id'] as String? ?? ''),
        borderRadius: BorderRadius.circular(12),
        child: NeyvoCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      industryId == 'school_financial_aid' ? Icons.school : Icons.smart_toy_outlined,
                      size: 28,
                      color: TenantBrand.primary(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'active' ? TenantBrand.primary(context).withValues(alpha: 0.2) : NeyvoColors.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status, style: NeyvoTextStyles.micro.copyWith(color: status == 'active' ? TenantBrand.primary(context) : NeyvoColors.warning)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(_voiceLabel(voiceStyle), style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
                    const SizedBox(width: 8),
                    Text('v$version', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
                    const Spacer(),
                    Text(createdLabel, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _voiceLabel(String v) {
    if (v == 'warm_friendly') return 'Warm & Friendly';
    if (v == 'professional_clear') return 'Professional & Clear';
    if (v == 'calm_reassuring') return 'Calm & Reassuring';
    return v;
  }
}
