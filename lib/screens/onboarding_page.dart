// File: onboarding_page.dart
// Purpose: Neyvo unified onboarding wizard – surface choice, industry, first agent or project.
// Surface: both
// Connected to: GET/PATCH /api/pulse/account, templates, agents, studio

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import 'pulse_shell.dart';

const String _kOnboardingCompletedKey = 'neyvo_pulse_onboarding_completed';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  String? _surfaceChoice; // 'comms' | 'studio' | 'both'
  String? _industry;
  bool _loading = false;
  String? _error;
  static const int _totalSteps = 6;

  Future<void> _completeOnboarding() async {
    setState(() { _loading = true; _error = null; });
    try {
      final surfaces = _surfaceChoice == 'studio' ? ['studio'] : _surfaceChoice == 'both' ? ['comms', 'studio'] : ['comms'];
      final active = _surfaceChoice == 'studio' ? 'studio' : 'comms';
      final body = <String, dynamic>{
        'onboarding_completed': true,
        'active_surface': active,
        'surfaces_enabled': surfaces,
      };
      if (_industry != null && _industry!.isNotEmpty) body['primary_industry'] = _industry!.toLowerCase().replaceAll('/', '_').replaceAll(' ', '_');
      await NeyvoPulseApi.updateAccountInfo(body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboardingCompletedKey, true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PulseShell()),
      );
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, minHeight: 540),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: NeyvoColors.bgRaised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NeyvoColors.borderDefault),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _totalSteps,
                        minHeight: 4,
                        backgroundColor: NeyvoColors.borderSubtle,
                        valueColor: const AlwaysStoppedAnimation<Color>(NeyvoColors.teal),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_step == 0) _buildWelcome(),
                    if (_step == 1) _buildSurfaceChoice(),
                    if (_step == 2) _buildIndustryChoice(),
                    if (_step == 3) _buildFirstSetup(),
                    if (_step == 4) _buildTopUpOrStartFree(),
                    if (_step == 5) _buildComplete(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                      ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: _loading ? null : () => setState(() => _step--),
                            child: const Text('Back'),
                          )
                        else
                          const SizedBox.shrink(),
                        FilledButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  if (_step < _totalSteps - 1) {
                                    setState(() => _step++);
                                  } else {
                                    _completeOnboarding();
                                  }
                                },
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_step == _totalSteps - 1 ? 'Go to Dashboard →' : 'Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome to Neyvo', style: NeyvoTextStyles.title.copyWith(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          "Let's get your AI voice system ready. Takes about 2 minutes.",
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Text(
          'You can handle voice calls, create voice content, or both. We\'ll guide you through a few quick steps.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSurfaceChoice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What will you use Neyvo for?',
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 24),
        _surfaceCard(
          title: 'Handle calls',
          subtitle: 'Receive and make phone calls with AI',
          icon: Icons.phone_in_talk,
          value: 'comms',
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          title: 'Create voice content',
          subtitle: 'Text-to-speech, voiceovers, and more',
          icon: Icons.mic,
          value: 'studio',
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          title: 'Both',
          subtitle: 'Calls and voice content',
          icon: Icons.apps,
          value: 'both',
        ),
      ],
    );
  }

  Widget _surfaceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final selected = _surfaceChoice == value;
    return InkWell(
      onTap: () => setState(() => _surfaceChoice = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? NeyvoColors.teal.withValues(alpha: 0.08) : null,
          border: Border.all(
            color: selected ? NeyvoColors.teal : NeyvoColors.borderDefault,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: NeyvoColors.teal),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: NeyvoColors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustryChoice() {
    final industries = [
      'Healthcare',
      'Education',
      'Automotive',
      'Real Estate',
      'Finance/Banking',
      'Retail/E-commerce',
      'Sales/Lead Gen',
      'Recruitment/HR',
      'Logistics/Fleet',
      'Hospitality/Restaurant',
      'Insurance',
      'Government/Public Services',
      'Home Services',
      'Telecom',
      'Custom',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your industry?",
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: industries
              .map((e) => ChoiceChip(
                    label: Text(e, style: NeyvoTextStyles.label),
                    selected: _industry == e,
                    selectedColor: NeyvoColors.teal.withValues(alpha: 0.2),
                    onSelected: (v) => setState(() => _industry = v ? e : null),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildFirstSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create your first agent',
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'You can create your first agent or project from the dashboard after we finish. Use the Agents or Projects section to create from a template.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTopUpOrStartFree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add credits or start free',
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'Add credits now to start making calls or generating voice content, or skip and top up later from the Wallet page.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _step++),
          child: Text('Skip for now', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted, decoration: TextDecoration.underline)),
        ),
      ],
    );
  }

  Widget _buildComplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 48, color: NeyvoColors.success),
        const SizedBox(height: 16),
        Text("You're all set", style: NeyvoTextStyles.title.copyWith(fontSize: 22)),
        const SizedBox(height: 8),
        Text(
          'Your agent is active and ready to receive calls.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
        ),
      ],
    );
  }
}
