import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/voice_studio_provider.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class VoiceStudioPage extends ConsumerStatefulWidget {
  const VoiceStudioPage({super.key});

  @override
  ConsumerState<VoiceStudioPage> createState() => _VoiceStudioPageState();
}

class _VoiceStudioPageState extends ConsumerState<VoiceStudioPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceStudioCtrlProvider.notifier).load();
    });
  }

  Future<void> _playSample(Map<String, dynamic> voice) async {
    try {
      await ref.read(voiceStudioCtrlProvider.notifier).playSample(voice);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playing sample…')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview unavailable for this voice. Try another.')),
      );
    }
  }

  String _tierLabel(String tier) {
    switch (tier.toLowerCase()) {
      case 'neutral':
        return 'Neutral Human';
      case 'natural':
        return 'Natural Human';
      case 'ultra':
        return 'Ultra Real Human';
      default:
        return tier;
    }
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'neutral':
        return NeyvoTheme.teal;
      case 'natural':
        return NeyvoTheme.coral;
      case 'ultra':
        return NeyvoTheme.warning;
      default:
        return NeyvoTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(voiceStudioCtrlProvider);
    final voices = s.filteredVoices;
    final n = ref.read(voiceStudioCtrlProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeyvoGlassPanel(
                  glowing: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 72),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Studio',
                              style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Browse every OpenAI and ElevenLabs voice available on your plan. Listen to samples, then pick the perfect personality for your operators.',
                              style: NeyvoTextStyles.body,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Search voices',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: n.setSearchTerm,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All tiers')),
                        ButtonSegment(value: 'neutral', label: Text('Neutral')),
                        ButtonSegment(value: 'natural', label: Text('Natural')),
                        ButtonSegment(value: 'ultra', label: Text('Ultra')),
                      ],
                      selected: {s.filterTier},
                      onSelectionChanged: (sel) {
                        if (sel.isNotEmpty) {
                          n.setFilterTier(sel.first);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (s.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoTheme.teal),
                    ),
                  )
                else if (s.error != null)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Voice catalog is unavailable right now.',
                          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.error!,
                          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => n.load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (voices.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No voices found for this filter.',
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                      ),
                    ),
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: GridView.builder(
                      key: ValueKey('${s.filterTier}-${s.searchTerm}'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: voices.length,
                      itemBuilder: (context, index) {
                        final v = voices[index];
                        final name = (v['name'] ?? '').toString().isNotEmpty
                            ? (v['name'] ?? '').toString()
                            : (v['voice_id'] ?? '').toString();
                        final tier = (v['tier'] ?? 'natural').toString();
                        final provider = (v['provider'] ?? '').toString().toLowerCase();
                        final tags = (v['tags'] is List ? v['tags'] as List : const [])
                            .whereType<String>()
                            .toList();
                        final isPlaying = s.playingVoiceId == (v['voice_id'] ?? '').toString();

                        return _VoiceCard(
                          name: name,
                          tierLabel: _tierLabel(tier),
                          tierColor: _tierColor(tier),
                          provider: provider,
                          description: (v['description'] ?? '').toString(),
                          tags: tags,
                          isPlaying: isPlaying,
                          onPlay: () => _playSample(v),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceCard extends StatefulWidget {
  final String name;
  final String tierLabel;
  final Color tierColor;
  final String provider;
  final String description;
  final List<String> tags;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _VoiceCard({
    required this.name,
    required this.tierLabel,
    required this.tierColor,
    required this.provider,
    required this.description,
    required this.tags,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  State<_VoiceCard> createState() => _VoiceCardState();
}

class _VoiceCardState extends State<_VoiceCard> with SingleTickerProviderStateMixin {
  // riverpod-migration-allowed: ephemeral hover / scale feedback only.
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: NeyvoGlassPanel(
          glowing: _hovering,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NeyvoAIOrb(
                      state: widget.isPlaying ? NeyvoAIOrbState.speaking : NeyvoAIOrbState.idle,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeyvoTextStyles.bodyPrimary,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.tierColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  widget.tierLabel,
                                  style: NeyvoTextStyles.micro.copyWith(color: widget.tierColor),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.provider == 'openai' ? 'OpenAI' : 'ElevenLabs',
                                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.description.isNotEmpty)
                  Text(
                    widget.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                  ),
                const Spacer(),
                if (widget.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: widget.tags.take(4).map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: NeyvoColors.bgRaised,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t,
                          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: widget.isPlaying ? null : widget.onPlay,
                      icon: widget.isPlaying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_circle_outline),
                      label: const Text('Play'),
                    ),
                    Text(
                      'Apply in operator Voice tab',
                      style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

