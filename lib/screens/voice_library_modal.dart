// lib/screens/voice_library_modal.dart
// Voice Library: filter by tier, play sample via /api/voices/preview, select and return profile.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

class VoiceLibraryModal extends StatefulWidget {
  const VoiceLibraryModal({
    super.key,
    required this.currentTier,
    this.currentVoiceId,
    this.currentProvider,
    required this.unlockedTiers,
  });

  final String currentTier;
  final String? currentVoiceId;
  final String? currentProvider;
  final List<String> unlockedTiers;

  @override
  State<VoiceLibraryModal> createState() => _VoiceLibraryModalState();
}

class _VoiceLibraryModalState extends State<VoiceLibraryModal> {
  List<dynamic> _voices = [];
  bool _loading = true;
  String _filterTier = 'all';
  String? _playingId;
  String? _selectedId;
  Map<String, dynamic>? _selectedProfile;

  @override
  void initState() {
    super.initState();
    _filterTier = widget.currentTier;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await NeyvoPulseApi.getVoices(tier: _filterTier);
      List<dynamic> list = [];
      if (res is List) {
        list = List<dynamic>.from(res);
      } else if (res is Map && res['voices'] is List) {
        list = List<dynamic>.from(res['voices'] as List);
      } else if (res is Map && res['neutral'] is List) {
        list = [
          ...(res['neutral'] as List),
          ...(res['natural'] as List? ?? []),
          ...(res['ultra'] as List? ?? []),
        ];
      }
      if (mounted) setState(() {
        _voices = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _voices = [];
        _loading = false;
      });
    }
  }

  void _onFilterChanged(String? tier) {
    if (tier == null) return;
    setState(() {
      _filterTier = tier;
      _loading = true;
    });
    _load();
  }

  Future<void> _playSample(Map<String, dynamic> profile) async {
    final voiceId = profile['voice_id'] as String?;
    final provider = profile['provider'] as String?;
    if (voiceId == null || provider == null) return;
    setState(() => _playingId = voiceId);
    try {
      final res = await NeyvoPulseApi.postVoicePreview(
        voiceId: voiceId,
        provider: provider,
        text: profile['sample_text'] as String?,
      );
      if (!mounted) return;
      final url = res['audio_url'] as String?;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening sample…')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _playingId = null);
    }
  }

  void _select(Map<String, dynamic> profile) {
    setState(() {
      _selectedId = profile['voice_id'] as String?;
      _selectedProfile = profile;
    });
  }

  void _confirm() {
    if (_selectedProfile != null) {
      final p = _selectedProfile!;
      Navigator.pop(context, {
        'id': p['id'],
        'tier': p['tier'] as String? ?? 'neutral',
        'provider': p['provider'] as String? ?? 'openai',
        'voice_id': p['voice_id'],
      });
    }
  }

  String _tierDisplay(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'neutral': return 'Neutral Human';
      case 'natural': return 'Natural Human';
      case 'ultra': return 'Ultra Real Human';
      default: return tier ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Row(
              children: [
                Text(
                  'Voice Library',
                  style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg),
            child: DropdownButtonFormField<String>(
              value: _filterTier,
              decoration: const InputDecoration(
                labelText: 'Tier',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All tiers')),
                if (widget.unlockedTiers.contains('neutral'))
                  const DropdownMenuItem(value: 'neutral', child: Text('Neutral Human')),
                if (widget.unlockedTiers.contains('natural'))
                  const DropdownMenuItem(value: 'natural', child: Text('Natural Human')),
                if (widget.unlockedTiers.contains('ultra'))
                  const DropdownMenuItem(value: 'ultra', child: Text('Ultra Real Human')),
              ],
              onChanged: _onFilterChanged,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _voices.isEmpty
                    ? Center(
                        child: Text(
                          'No voices found. Try another tier.',
                          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg),
                        itemCount: _voices.length,
                        itemBuilder: (_, i) {
                          final p = _voices[i] as Map<String, dynamic>;
                          final voiceId = p['voice_id'] as String? ?? '';
                          final name = p['name'] as String? ?? p['voice_id']?.toString() ?? '—';
                          final tier = (p['tier'] as String?)?.toLowerCase() ?? 'neutral';
                          final isSelected = _selectedId == voiceId;
                          final isLocked = !widget.unlockedTiers.contains(tier);
                          return Card(
                            color: isSelected
                                ? NeyvoTheme.teal.withOpacity(0.15)
                                : NeyvoTheme.bgCard,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                isSelected ? Icons.check_circle : Icons.record_voice_over_outlined,
                                color: isSelected ? NeyvoTheme.teal : NeyvoTheme.textSecondary,
                              ),
                              title: Text(
                                name,
                                style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                              ),
                              subtitle: Text(
                                _tierDisplay(tier),
                                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isLocked)
                                    IconButton(
                                      icon: _playingId == voiceId
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.play_circle_outline),
                                      onPressed: () => _playSample(p),
                                    ),
                                  if (!isLocked)
                                    FilledButton.tonal(
                                      onPressed: () => _select(p),
                                      child: Text(isSelected ? 'Selected' : 'Select'),
                                    ),
                                  if (isLocked)
                                    Text(
                                      'Upgrade to unlock',
                                      style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textTertiary),
                                    ),
                                ],
                              ),
                              onTap: isLocked ? null : () => _select(p),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: FilledButton(
              onPressed: _selectedProfile != null ? _confirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: NeyvoTheme.teal,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Use this voice'),
            ),
          ),
        ],
      ),
    );
  }
}
