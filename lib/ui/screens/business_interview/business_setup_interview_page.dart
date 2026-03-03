import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../features/business_intelligence/bi_wizard_api_service.dart';
import '../../../theme/neyvo_theme.dart';
import '../../../screens/business_setup_page.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class BusinessSetupInterviewPage extends StatefulWidget {
  const BusinessSetupInterviewPage({super.key});

  @override
  State<BusinessSetupInterviewPage> createState() =>
      _BusinessSetupInterviewPageState();
}

class _BusinessSetupInterviewPageState
    extends State<BusinessSetupInterviewPage> {
  bool _loading = true;
  String? _error;
  String _status = 'missing';

  String _description = '';
  String _website = '';

  Map<String, dynamic>? _extractResult;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await BiWizardApiService.getStatus();
      if (res['ok'] == true && res['status'] is String) {
        _status = res['status'] as String;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _extractModel() async {
    setState(() {
      _error = null;
      _extractResult = null;
      _loading = true;
    });
    try {
      final res = await BiWizardApiService.extractModel(
        description: _description,
        website: _website,
      );
      if (!mounted) return;
      setState(() {
        _extractResult = res;
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

  NeyvoAIOrbState get _orbState {
    if (_loading) return NeyvoAIOrbState.processing;
    if (_status == 'ready') return NeyvoAIOrbState.idle;
    if (_extractResult != null) return NeyvoAIOrbState.listening;
    return NeyvoAIOrbState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final extractBi = _extractResult != null && _extractResult!['bi'] is Map
        ? Map<String, dynamic>.from(_extractResult!['bi'] as Map)
        : null;
    List<Map<String, dynamic>>? extractServices;
    if (_extractResult != null &&
        _extractResult!['suggestions'] is Map &&
        (_extractResult!['suggestions'] as Map)['services'] is List) {
      final rawList =
          (_extractResult!['suggestions'] as Map)['services'] as List<dynamic>;
      extractServices = rawList
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: SafeArea(
        child: Row(
          children: [
            // Left: Orb + high-level status + extraction prompt.
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(NeyvoSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: NeyvoSpacing.lg),
                    Center(
                      child: NeyvoAIOrb(
                        state: _orbState,
                        size: 160,
                      ),
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    Text(
                      'Business Modeling Interview',
                      style: NeyvoTextStyles.heading
                          .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell Neyvo what your business does. I will propose services, intents, and agent roles for you.',
                      style: NeyvoTextStyles.body,
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'One-line description',
                        hintText: 'e.g. A dental clinic focusing on family care',
                      ),
                      onChanged: (v) => _description = v,
                    ),
                    const SizedBox(height: NeyvoSpacing.md),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Website (optional)',
                        hintText: 'https://yourbusiness.com',
                      ),
                      onChanged: (v) => _website = v,
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    FilledButton(
                      onPressed: _loading ? null : _extractModel,
                      style: FilledButton.styleFrom(
                        backgroundColor: NeyvoColors.teal,
                      ),
                      child: Text(
                        _extractResult == null
                            ? 'Let Neyvo analyze'
                            : 'Re-run analysis',
                      ),
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    _buildStatusSummary(),
                    if (extractServices != null && extractServices.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: NeyvoSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detected services',
                              style: NeyvoTextStyles.label,
                            ),
                            const SizedBox(height: NeyvoSpacing.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                  extractServices.length, (index) {
                                final s = extractServices![index];
                                final name =
                                    (s['name'] ?? '').toString().trim();
                                if (name.isEmpty) return const SizedBox();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(999),
                                    color: NeyvoColors.bgRaised
                                        .withOpacity(0.7),
                                    border: Border.all(
                                        color: NeyvoColors.borderSubtle),
                                  ),
                                  child: Text(
                                    name,
                                    style: NeyvoTextStyles.micro,
                                  ),
                                )
                                    .animate()
                                    .fadeIn(
                                        duration: 250.ms,
                                        delay: (index * 70).ms)
                                    .slideY(
                                        begin: 0.1,
                                        curve: Curves.easeOut);
                              }),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Right: Floating console with structured editor (existing wizard).
            Expanded(
              flex: 7,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  NeyvoSpacing.xl,
                  NeyvoSpacing.xl,
                  NeyvoSpacing.xl,
                  NeyvoSpacing.xl,
                ),
                child: NeyvoGlassPanel(
                  glowing: _status != 'ready',
                  padding: const EdgeInsets.all(NeyvoSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.smart_toy_outlined,
                              color: NeyvoColors.teal),
                          const SizedBox(width: NeyvoSpacing.sm),
                          Text(
                            'Structured business profile',
                            style: NeyvoTextStyles.heading,
                          ),
                        ],
                      ),
                      const SizedBox(height: NeyvoSpacing.md),
                      Text(
                        'Review and refine the structured profile that powers every voice agent. Changes here affect all agents.',
                        style: NeyvoTextStyles.body,
                      ),
                      const SizedBox(height: NeyvoSpacing.lg),
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(NeyvoRadius.md),
                          child: BusinessSetupPage(
                            initialBi: extractBi,
                            initialSuggestions: extractServices,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSummary() {
    final statusLabel = switch (_status) {
      'ready' => 'Business model: Ready',
      'partial' => 'Business model: Partial',
      _ => 'Business model: Not set up',
    };
    final statusColor = switch (_status) {
      'ready' => NeyvoColors.success,
      'partial' => NeyvoColors.warning,
      _ => NeyvoColors.textMuted,
    };

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        const SizedBox(width: NeyvoSpacing.sm),
        Expanded(
          child: Text(
            statusLabel,
            style: NeyvoTextStyles.body.copyWith(color: statusColor),
          ),
        ),
      ],
    );
  }
}

