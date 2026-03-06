import 'package:flutter/material.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class VoiceStudioPage extends StatefulWidget {
  const VoiceStudioPage({super.key});

  @override
  State<VoiceStudioPage> createState() => _VoiceStudioPageState();
}

class _VoiceStudioPageState extends State<VoiceStudioPage> {
  bool _loading = true;
  String? _error;

  // Grouped voices from /api/voices?tier=all => { neutral: [...], natural: [...], ultra: [...] }.
  List<Map<String, dynamic>> _neutralVoices = const [];
  List<Map<String, dynamic>> _naturalVoices = const [];
  List<Map<String, dynamic>> _ultraVoices = const [];

  String _filterTier = 'all'; // all | neutral | natural | ultra
  String _searchTerm = '';

  String? _playingVoiceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NeyvoPulseApi.getVoices(tier: 'all');
      if (!mounted) return;

      List<Map<String, dynamic>> neutral = const [];
      List<Map<String, dynamic>> natural = const [];
      List<Map<String, dynamic>> ultra = const [];

      if (res is Map) {
        neutral = _extractList(res['neutral']);
        natural = _extractList(res['natural']);
        ultra = _extractList(res['ultra']);
      } else if (res is List) {
        final all = _extractList(res);
        neutral = all.where((v) => (v['tier'] ?? '').toString().toLowerCase() == 'neutral').toList();
        natural = all.where((v) => (v['tier'] ?? '').toString().toLowerCase() == 'natural').toList();
        ultra = all.where((v) => (v['tier'] ?? '').toString().toLowerCase() == 'ultra').toList();
      }

      setState(() {
        _neutralVoices = neutral;
        _naturalVoices = natural;
        _ultraVoices = ultra;
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

  List<Map<String, dynamic>> _extractList(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> get _filteredVoices {
    List<Map<String, dynamic>> base;
    switch (_filterTier) {
      case 'neutral':
        base = _neutralVoices;
        break;
      case 'natural':
        base = _naturalVoices;
        break;
      case 'ultra':
        base = _ultraVoices;
        break;
      default:
        base = [..._neutralVoices, ..._naturalVoices, ..._ultraVoices];
    }
    final term = _searchTerm.trim().toLowerCase();
    if (term.isEmpty) return base;
    return base.where((v) {
      final name = (v['name'] ?? '').toString().toLowerCase();
      final id = (v['voice_id'] ?? '').toString().toLowerCase();
      final desc = (v['description'] ?? '').toString().toLowerCase();
      return name.contains(term) || id.contains(term) || desc.contains(term);
    }).toList();
  }

  Future<void> _playSample(Map<String, dynamic> voice) async {
    final voiceId = (voice['voice_id'] ?? '').toString();
    final provider = (voice['provider'] ?? '').toString();
    if (voiceId.isEmpty || provider.isEmpty) return;
    setState(() => _playingVoiceId = voiceId);
    try {
      final res = await NeyvoPulseApi.postVoicePreview(
        voiceId: voiceId,
        provider: provider,
        text: (voice['sample_text'] ?? '').toString().trim().isEmpty
            ? null
            : (voice['sample_text'] ?? '').toString(),
      );
      if (!mounted) return;
      final url = (res['audio_url'] ?? '').toString();
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        // We intentionally let the browser handle playback via new tab.
        // This keeps the implementation simple and consistent with other surfaces.
        // ignore: deprecated_member_use
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening sample…')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _playingVoiceId = null);
      }
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
    final voices = _filteredVoices;

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
                        onChanged: (v) => setState(() => _searchTerm = v),
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
                      selected: {_filterTier},
                      onSelectionChanged: (s) {
                        if (s.isNotEmpty) {
                          setState(() => _filterTier = s.first);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoTheme.teal),
                    ),
                  )
                else if (_error != null)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Voice catalog is unavailable right now.',
                          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _error!,
                          style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _load,
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
                      key: ValueKey('${_filterTier}-${_searchTerm}'),
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
                        final isPlaying = _playingVoiceId == (v['voice_id'] ?? '').toString();

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
                      state: widget.isPlaying ? NeyvoAIOrbState.talking : NeyvoAIOrbState.idle,
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

