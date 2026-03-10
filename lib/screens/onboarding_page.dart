// File: onboarding_page.dart
// Purpose: Neyvo unified onboarding wizard – surface choice, industry, first agent or project.
// Surface: both
// Connected to: GET/PATCH /api/pulse/account, templates, agents, studio

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/ai_orb/neyvo_ai_orb.dart';
import '../ui/components/backgrounds/neyvo_neural_background.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../ui/components/visualizer/neyvo_voice_wave.dart';
import '../ui/screens/business_interview/business_setup_interview_page.dart';
import 'pulse_shell.dart';

const String _kOnboardingCompletedKey = 'neyvo_pulse_onboarding_completed';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  bool _initializing = false;
  int _initStepIndex = 0;
  String? _error;

  static const List<String> _initMessages = [
    'Initializing Neyvo Voice OS…',
    'Loading voice engine…',
    'Preparing routing layer…',
    'Calibrating business intelligence…',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      final body = <String, dynamic>{
        'onboarding_completed': true,
        'active_surface': 'comms',
        'surfaces_enabled': ['comms'],
      };
      await NeyvoPulseApi.updateAccountInfo(body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboardingCompletedKey, true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PulseShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _startInitializationAndInterview() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _initStepIndex = 0;
      _error = null;
    });

    try {
      for (var i = 0; i < _initMessages.length; i++) {
        if (!mounted) return;
        setState(() {
          _initStepIndex = i;
        });
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const BusinessSetupInterviewPage(),
        ),
      );

      if (!mounted) return;
      await _completeOnboarding();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initializing = false;
      });
    }
  }

  void _goTo(int index) {
    setState(() {
      _pageIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: Stack(
        children: [
          const Positioned.fill(child: NeyvoNeuralBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const NeyvoAIOrb(
                        state: NeyvoAIOrbState.idle,
                        size: 140,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to Neyvo Voice OS',
                        style: NeyvoTextStyles.title
                            .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter a living, autonomous voice environment — not a dashboard.',
                        style: NeyvoTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: NeyvoGlassPanel(
                          glowing: true,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Expanded(
                                child: PageView(
                                  controller: _pageController,
                                  onPageChanged: (i) {
                                    setState(() {
                                      _pageIndex = i;
                                    });
                                  },
                                  children: [
                                    _buildSlideWelcome(),
                                    _buildSlideHowItWorks(),
                                    _buildSlideIntelligence(),
                                    _buildSlideWallet(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (i) {
                                  final selected = i == _pageIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: selected ? 18 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: selected
                                          ? NeyvoColors.teal
                                          : NeyvoColors.borderSubtle,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed:
                                        _pageIndex == 0 ? null : () => _goTo(_pageIndex - 1),
                                    child: const Text('Back'),
                                  ),
                                  FilledButton(
                                    onPressed: _initializing
                                        ? null
                                        : () {
                                            if (_pageIndex < 3) {
                                              _goTo(_pageIndex + 1);
                                            } else {
                                              _startInitializationAndInterview();
                                            }
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: NeyvoColors.teal,
                                    ),
                                    child: Text(
                                      _pageIndex < 3
                                          ? 'Continue'
                                          : 'Initialize My Voice OS',
                                    ),
                                  ),
                                ],
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: NeyvoTextStyles.body
                                      .copyWith(color: NeyvoColors.error),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_initializing) Positioned.fill(child: _buildInitializationOverlay()),
        ],
      ),
    );
  }

  Widget _buildSlideWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You are entering a Voice Operating System.',
          style: NeyvoTextStyles.heading
              .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Neyvo runs autonomous AI agents that answer, route, and operate for your business.',
          style: NeyvoTextStyles.body,
        ),
        const SizedBox(height: 20),
        const NeyvoVoiceWave(),
      ],
    );
  }

  Widget _buildSlideHowItWorks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How Neyvo works',
          style: NeyvoTextStyles.heading
              .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'We model your business once, then route every call through an AI agent that knows your services, policies, and priorities.',
          style: NeyvoTextStyles.body,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _PillCard(label: 'Business → Intelligence'),
            _PillCard(label: 'Intelligence → Agent'),
            _PillCard(label: 'Operator → Number'),
            _PillCard(label: 'Number → Live Calls'),
          ],
        ),
      ],
    );
  }

  Widget _buildSlideIntelligence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What Neyvo will do for you',
          style: NeyvoTextStyles.heading
              .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'During activation we will detect services, caller intents, and suggested agents from your business profile.',
          style: NeyvoTextStyles.body,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _Bullet(label: 'Detect your core services'),
            _Bullet(label: 'Infer common caller questions'),
            _Bullet(label: 'Propose initial AI agents'),
            _Bullet(label: 'Simulate safe call flows'),
          ],
        ),
      ],
    );
  }

  Widget _buildSlideWallet() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You stay in control',
          style: NeyvoTextStyles.heading
              .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'Credits, numbers, and routing are all transparent. You can start with low volume and scale once you trust the system.',
          style: NeyvoTextStyles.body,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _Bullet(label: 'Wallet-based credits'),
            _Bullet(label: 'Daily safety caps'),
            _Bullet(label: 'Training vs production numbers'),
            _Bullet(label: 'Live call and cost visibility'),
          ],
        ),
      ],
    );
  }

  Widget _buildInitializationOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.78),
      child: Center(
        child: NeyvoGlassPanel(
          glowing: true,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NeyvoAIOrb(
                state: NeyvoAIOrbState.processing,
                size: 96,
              ),
              const SizedBox(height: 16),
              Text(
                _initMessages[_initStepIndex],
                style: NeyvoTextStyles.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This takes a few seconds. We are not placing any calls yet.',
                style: NeyvoTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NeyvoColors.teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillCard extends StatelessWidget {
  final String label;

  const _PillCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: NeyvoColors.bgRaised.withOpacity(0.7),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Text(
        label,
        style: NeyvoTextStyles.micro,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String label;

  const _Bullet({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: NeyvoColors.teal,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: NeyvoTextStyles.body,
          ),
        ),
      ],
    );
  }
}

