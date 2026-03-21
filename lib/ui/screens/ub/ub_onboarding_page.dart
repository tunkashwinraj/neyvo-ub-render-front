// UB-only onboarding: 3 slides, then initialize from UB website and go to UB Model Overview.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ub_onboarding_provider.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/backgrounds/neyvo_neural_background.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class UbOnboardingPage extends ConsumerStatefulWidget {
  const UbOnboardingPage({super.key});

  @override
  ConsumerState<UbOnboardingPage> createState() => _UbOnboardingPageState();
}

class _UbOnboardingPageState extends ConsumerState<UbOnboardingPage> {
  final PageController _pageController = PageController();
  final _websiteController = TextEditingController(text: 'https://www.bridgeport.edu');

  @override
  void dispose() {
    _pageController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    ref.read(ubOnboardingCtrlProvider.notifier).setPageIndex(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(ubOnboardingCtrlProvider);
    final msgIndex = ui.initStepIndex.clamp(0, UbOnboardingCtrl.initMessages.length - 1);

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
                        'University of Bridgeport Voice OS',
                        style: NeyvoTextStyles.title
                            .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Autonomous voice operators for UB departments.',
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
                                  onPageChanged: (i) => ref.read(ubOnboardingCtrlProvider.notifier).setPageIndex(i),
                                  children: [
                                    _buildSlideWelcome(),
                                    _buildSlideHowItWorks(),
                                    _buildSlideInitialize(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (i) {
                                  final selected = i == ui.pageIndex;
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
                                    onPressed: ui.pageIndex == 0 ? null : () => _goTo(ui.pageIndex - 1),
                                    child: const Text('Back'),
                                  ),
                                  FilledButton(
                                    onPressed: ui.initializing
                                        ? null
                                        : () {
                                            if (ui.pageIndex < 2) {
                                              _goTo(ui.pageIndex + 1);
                                            } else {
                                              ref
                                                  .read(ubOnboardingCtrlProvider.notifier)
                                                  .initializeAndGoToOverview(context, _websiteController.text);
                                            }
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: NeyvoColors.teal,
                                    ),
                                    child: Text(
                                      ui.pageIndex < 2 ? 'Continue' : 'Initialize UB Voice OS',
                                    ),
                                  ),
                                ],
                              ),
                              if (ui.error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  ui.error!,
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
          if (ui.initializing) Positioned.fill(child: _buildInitializationOverlay(msgIndex)),
        ],
      ),
    );
  }

  Widget _buildSlideWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to University of Bridgeport Voice OS.',
          style: NeyvoTextStyles.heading
              .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'Neyvo builds a University Model from your website and creates voice operators for each department — so callers get answers 24/7.',
          style: NeyvoTextStyles.body,
        ),
      ],
    );
  }

  Widget _buildSlideHowItWorks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How it Works at UB',
          style: NeyvoTextStyles.heading
              .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'Neyvo builds a University Model from bridgeport.edu, then creates Operators for each department. Operators connect to your lines and handle calls; you get insights and control.',
          style: NeyvoTextStyles.body,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _PillCard(label: 'University Model'),
            _PillCard(label: 'Operators'),
            _PillCard(label: 'Lines'),
            _PillCard(label: 'Calls'),
            _PillCard(label: 'Insights'),
          ],
        ),
      ],
    );
  }

  Widget _buildSlideInitialize() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Initialize from UB website',
          style: NeyvoTextStyles.heading
              .copyWith(fontSize: 18, color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'We will analyze the University of Bridgeport website to detect departments, contacts, and FAQs. You can re-run this later if needed.',
          style: NeyvoTextStyles.body,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _websiteController,
          decoration: InputDecoration(
            labelText: 'Website URL',
            hintText: 'https://www.bridgeport.edu',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
      ],
    );
  }

  Widget _buildInitializationOverlay(int msgIndex) {
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
                UbOnboardingCtrl.initMessages[msgIndex],
                style: NeyvoTextStyles.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This takes a few seconds.',
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
      child: Text(label, style: NeyvoTextStyles.micro),
    );
  }
}
