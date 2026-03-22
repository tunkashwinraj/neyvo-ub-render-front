import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/backend_urls.dart';
import '../../../core/providers/backup_rollback_provider.dart';
import '../../../theme/neyvo_theme.dart';

class BackupRollbackPage extends ConsumerStatefulWidget {
  const BackupRollbackPage({super.key});

  @override
  ConsumerState<BackupRollbackPage> createState() => _BackupRollbackPageState();
}

class _BackupRollbackPageState extends ConsumerState<BackupRollbackPage> {
  static const _frontRepo = 'tunkashwinraj/Goodwin_Neyvo_Front';
  static const _backRepo = 'tunkashwinraj/Goodwin_Neyvo_Back';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backupRollbackProvider.notifier).load();
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(backupRollbackProvider.notifier);
    if (!notifier.isAuthorized) {
      return Scaffold(
        backgroundColor: NeyvoTheme.bgPrimary,
        appBar: AppBar(
          backgroundColor: NeyvoTheme.bgSurface,
          title: Text('Page not found', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        ),
        body: Center(
          child: Text(
            'Not available.',
            style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textMuted),
          ),
        ),
      );
    }
    final ui = ref.watch(backupRollbackProvider);
    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: NeyvoTheme.bgSurface,
        title: Text('Backups & rollbacks (internal)', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(backupRollbackProvider.notifier).load(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _infoPanel(
            title: 'What “production-level rollback” still needs',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You already have 12-hour snapshot releases + a frontend build artifact. To roll back “exactly how it was”, you must also snapshot backend env vars (encrypted) for each backup window.',
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                _bullet('Ensure `ops/secrets/render-prod.env.enc` exists and is updated whenever env vars change.'),
                _bullet('Keep `age.key` offline. Without it, you cannot restore encrypted env snapshots.'),
                _bullet('Run a quarterly fire-drill: rollback frontend + backend to a backup and verify /health + login.'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Snapshot releases'),
          const SizedBox(height: 10),
          if (ui.loading) ...[
            const Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
            const SizedBox(height: 12),
          ],
          if (ui.error != null) ...[
            Text(ui.error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.warning)),
            const SizedBox(height: 12),
          ],
          _repoCard(
            title: 'Frontend snapshots',
            subtitle: _frontRepo,
            releases: ui.front,
            onOpenReleases: () => _openUrl('https://github.com/$_frontRepo/releases'),
          ),
          const SizedBox(height: 14),
          _repoCard(
            title: 'Backend snapshots',
            subtitle: _backRepo,
            releases: ui.back,
            onOpenReleases: () => _openUrl('https://github.com/$_backRepo/releases'),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Rollback shortcuts'),
          const SizedBox(height: 10),
          _infoPanel(
            title: 'Frontend (Firebase Hosting)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mono('firebase hosting:rollback goodwin-neyvo'),
                const SizedBox(height: 10),
                Text('Or deploy a backup artifact from the matching GitHub Release (frontend-build-web.zip).', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openUrl('https://console.firebase.google.com/project/goodwin-neyvo/hosting/sites'),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open Firebase Hosting console'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _infoPanel(
            title: 'Backend (Render)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rollback via Render → Deploys → pick prior deploy.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: 10),
                Text('If behavior differs after rollback, restore env vars from the encrypted snapshot for that backup window.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Verification'),
          const SizedBox(height: 10),
          _infoPanel(
            title: 'After rollback, verify these',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bullet('Frontend loads: https://goodwin-neyvo.web.app'),
                _bullet(
                  'Backend health: GET ${resolveNeyvoApiBaseUrl()}/api/pulse/health',
                ),
                _bullet('Slate config: GET /api/pulse/integrations/slate'),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w700));
  }

  Widget _infoPanel({required String title, required Widget child}) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: NeyvoTheme.textMuted)),
          Expanded(child: Text(text, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary))),
        ],
      ),
    );
  }

  Widget _mono(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeyvoTheme.bgHover,
        borderRadius: BorderRadius.circular(NeyvoRadius.md),
        border: Border.all(color: NeyvoTheme.borderSubtle),
      ),
      child: SelectableText(
        text,
        style: NeyvoType.bodySmall.copyWith(fontFamily: 'monospace', color: NeyvoTheme.textSecondary),
      ),
    );
  }

  Widget _repoCard({
    required String title,
    required String subtitle,
    required List<BackupRelease> releases,
    required VoidCallback onOpenReleases,
  }) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: const BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenReleases,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (releases.isEmpty)
              Text('No backup releases found yet (look for tags starting with backup-).', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted))
            else
              ...releases.take(20).map((r) => _releaseRow(r)),
          ],
        ),
      ),
    );
  }

  Widget _releaseRow(BackupRelease r) {
    final hasFrontendZip = r.assetNames.any((a) => a.toLowerCase().contains('frontend-build-web') || a.toLowerCase().endsWith('.zip'));
    final hasEnc = r.assetNames.any((a) => a.toLowerCase().endsWith('.enc'));
    return InkWell(
      onTap: () => _openUrl(r.htmlUrl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.tag, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    r.createdAt.isEmpty ? r.name : '${r.createdAt} · ${r.name}',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasFrontendZip)
              _chip('build.zip', NeyvoTheme.teal.withOpacity(0.12), NeyvoTheme.teal),
            if (hasEnc)
              _chip('.enc', NeyvoTheme.warning.withOpacity(0.12), NeyvoTheme.warning),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: NeyvoTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(text, style: NeyvoType.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}
