// lib/features/managed_profiles/create_profile_wizard.dart
// Multi-step modal: Industry → Business details → Voice → Create.

import 'package:flutter/material.dart';
import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';
import '../../theme/neyvo_theme.dart';
import 'managed_profile_api_service.dart';

class CreateProfileWizard extends StatefulWidget {
  const CreateProfileWizard({super.key});

  @override
  State<CreateProfileWizard> createState() => _CreateProfileWizardState();
}

class _CreateProfileWizardState extends State<CreateProfileWizard> {
  int _currentStep = 0;
  static const int _totalSteps = 5; // Industry, Business, Voice, Number, Review
  String? _selectedIndustryId;
  List<Map<String, dynamic>> _industries = [];
  bool _loadingIndustries = true;
  bool _saving = false;
  String? _error;

  // Form data
  final _profileName = TextEditingController();
  final _agentName = TextEditingController();
  final _businessName = TextEditingController();
  final _primaryGoal = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _officeHours = TextEditingController();
  final _portalSteps = TextEditingController();
  final _servicesOffered = TextEditingController();
  String _schedulingSystem = 'None yet';
  String _voiceStyle = 'warm_friendly';
  bool _voicemailEnabled = true;
  bool _allowCallbacks = true;
  bool _portalStepsYes = false;
  String _educationCallType = 'loan_acceptance';
  bool _requireIdentityVerification = false;
  bool _salonAllowUpsell = false;
  // Phone number selection (optional)
  String? _selectedPhoneNumberId;
  String? _selectedVapiPhoneNumberId;
  bool _loadingNumbers = false;
  List<Map<String, dynamic>> _numbers = [];

  @override
  void initState() {
    super.initState();
    _loadIndustries();
    _loadNumbers();
  }

  @override
  void dispose() {
    _profileName.dispose();
    _agentName.dispose();
    _businessName.dispose();
    _primaryGoal.dispose();
    _phoneNumber.dispose();
    _officeHours.dispose();
    _portalSteps.dispose();
    _servicesOffered.dispose();
    super.dispose();
  }

  Future<void> _loadIndustries() async {
    setState(() => _loadingIndustries = true);
    try {
      final res = await ManagedProfileApiService.getIndustries();
      final list = (res['industries'] as List?)?.cast<dynamic>() ?? [];
      setState(() {
        _industries = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingIndustries = false;
      });
    } catch (_) {
      setState(() => _loadingIndustries = false);
    }
  }

  Future<void> _loadNumbers() async {
    setState(() => _loadingNumbers = true);
    try {
      final res = await NeyvoPulseApi.listNumbers();
      final list = (res['numbers'] as List? ?? []).cast<dynamic>();
      setState(() {
        _numbers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingNumbers = false;
      });
    } catch (_) {
      setState(() => _loadingNumbers = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    final generatedProfileName = _businessName.text.trim().isEmpty
        ? 'Voice Profile'
        : '${_businessName.text.trim().split(RegExp(r'\s+')).first} · ${_selectedIndustryId == 'school_financial_aid' ? 'UB' : 'Profile'}';
    final profileName = _profileName.text.trim().isEmpty ? generatedProfileName : _profileName.text.trim();
    final businessSpecifics = <String, dynamic>{};
    if (_selectedIndustryId == 'school_financial_aid') {
      businessSpecifics['call_type'] = _educationCallType;
      if (_officeHours.text.trim().isNotEmpty) businessSpecifics['office_hours'] = _officeHours.text.trim();
      if (_portalStepsYes && _portalSteps.text.trim().isNotEmpty) {
        businessSpecifics['portal_steps'] = _portalSteps.text.trim();
      }
      businessSpecifics['require_identity_verification'] = _requireIdentityVerification;
    } else {
      if (_servicesOffered.text.trim().isNotEmpty) {
        businessSpecifics['services_offered'] = _servicesOffered.text.trim();
      }
      if (_officeHours.text.trim().isNotEmpty) {
        businessSpecifics['business_hours'] = _officeHours.text.trim();
      }
      if (_schedulingSystem.trim().isNotEmpty) {
        businessSpecifics['scheduling_system'] = _schedulingSystem.trim();
      }
      businessSpecifics['allow_upsell'] = _salonAllowUpsell;
    }
    final payload = {
      'industry_id': _selectedIndustryId!,
      'profile_name': profileName,
      'business_name': _businessName.text.trim(),
      'primary_goal': _primaryGoal.text.trim().length > 200 ? _primaryGoal.text.trim().substring(0, 200) : _primaryGoal.text.trim(),
      'phone_number': _phoneNumber.text.trim(),
      'callback_phone': _phoneNumber.text.trim(),
      'voice_style': _voiceStyle,
      'voicemail_enabled': _voicemailEnabled,
      'allow_callbacks': _allowCallbacks,
      'agent_persona_name': _agentName.text.trim().isEmpty ? 'Alex' : _agentName.text.trim(),
      'business_specifics': businessSpecifics,
    };
    if (_selectedPhoneNumberId != null && _selectedVapiPhoneNumberId != null) {
      payload['attached_phone_number_id'] = _selectedPhoneNumberId!;
      payload['attached_vapi_phone_number_id'] = _selectedVapiPhoneNumberId!;
    }
    return payload;
  }

  Future<void> _createProfile() async {
    if (_selectedIndustryId == null) return;
    if (_businessName.text.trim().isEmpty || _primaryGoal.text.trim().isEmpty || _phoneNumber.text.trim().isEmpty) {
      setState(() => _error = 'Please fill required fields.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final body = _buildPayload();
      final res = await ManagedProfileApiService.createProfile(body);
      if (res['profile_id'] != null && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${res['profile_name'] ?? 'Voice Profile'} is ready to use', style: const TextStyle(color: NeyvoColors.textPrimary)),
            backgroundColor: NeyvoColors.bgRaised,
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.pop(true);
      } else {
        setState(() {
          _error = res['error'] as String? ?? res['details'] as String? ?? 'Failed to create profile';
          _saving = false;
        });
      }
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      setState(() { _error = msg; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return Dialog(
      backgroundColor: NeyvoColors.bgBase,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: isNarrow ? double.infinity : 560,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  ...List.generate(_totalSteps, (i) {
                    final done = i < _currentStep;
                    final current = i == _currentStep;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done || current ? NeyvoColors.teal : NeyvoColors.textMuted,
                      ),
                    );
                  }),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: NeyvoColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _stepContent(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() { _currentStep--; _error = null; }),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(),
                  if (_currentStep < _totalSteps - 1)
                    ElevatedButton(
                      onPressed: _canProceed() && !_saving
                          ? () => setState(() {
                                if (_currentStep == 3) {
                                  final generatedProfileName = _businessName.text.trim().isEmpty
                                      ? 'Voice Profile'
                                      : '${_businessName.text.trim().split(RegExp(r'\s+')).first} · ${_selectedIndustryId == 'school_financial_aid' ? 'UB' : 'Profile'}';
                                  if (_profileName.text.trim().isEmpty) {
                                    _profileName.text = generatedProfileName;
                                  }
                                }
                                _currentStep++;
                                _error = null;
                              })
                          : null,
                      style: ElevatedButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _saving ? null : _createProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                      child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Profile'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedIndustryId != null;
      case 1:
        return _businessName.text.trim().isNotEmpty &&
            _primaryGoal.text.trim().isNotEmpty &&
            _phoneNumber.text.trim().isNotEmpty;
      case 2:
        return true;
      case 3:
        return true; // phone number is optional
      default:
        return true;
    }
  }

  Widget _stepContent() {
    switch (_currentStep) {
      case 0:
        return _buildIndustryStep();
      case 1:
        return _buildBusinessStep();
      case 2:
        return _buildVoiceStep();
      case 3:
        return _buildPhoneStep();
      case 4:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildIndustryStep() {
    if (_loadingIndustries) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: NeyvoColors.teal)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What kind of business is this?', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 20),
        ..._industries.map((ind) {
          final id = ind['id'] as String? ?? '';
          final name = ind['display_name'] as String? ?? id;
          final desc = ind['description'] as String? ?? '';
          final iconName = ind['icon'] as String? ?? 'tune';
          final selected = _selectedIndustryId == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: selected ? NeyvoColors.tealGlow : NeyvoColors.bgRaised,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => setState(() => _selectedIndustryId = id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? NeyvoColors.teal : NeyvoColors.borderDefault, width: selected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        iconName == 'school' ? Icons.school : Icons.content_cut,
                        size: 32,
                        color: selected ? NeyvoColors.teal : NeyvoColors.textSecondary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text(desc, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBusinessStep() {
    final isEducation = _selectedIndustryId == 'school_financial_aid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business details', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 20),
        _field('Agent name (what callers hear)', _agentName, hint: isEducation ? 'e.g. Maria, Alex, Jordan' : 'e.g. Mia, Alex, Jordan'),
        const SizedBox(height: 12),
        _field(
          isEducation ? 'Business / department name' : 'Salon / spa name',
          _businessName,
          hint: isEducation ? 'e.g. Student Financial Services — University of Bridgeport' : 'e.g. Downtown Salon & Spa',
        ),
        const SizedBox(height: 12),
        _field(
          'What is the goal of these calls?',
          _primaryGoal,
          lines: 3,
          maxLength: 200,
          hint: isEducation
              ? 'e.g. Remind students to accept or decline their federal student loans for this academic year'
              : 'e.g. Book and confirm hair appointments with existing clients',
        ),
        const SizedBox(height: 12),
        _field(
          isEducation ? 'Phone number students should call back' : 'Phone number clients should call',
          _phoneNumber,
          hint: 'e.g. 2035764568',
          keyboard: TextInputType.phone,
        ),
        if (isEducation) ...[
          const SizedBox(height: 12),
          Text('What type of calls is this profile making?', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, label) in const [
                ('loan_acceptance', 'Loan acceptance'),
                ('payment_reminder', 'Payment reminder'),
                ('portal_guidance', 'Portal guidance'),
                ('general_followup', 'General follow-up'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _educationCallType == id,
                  selectedColor: NeyvoColors.teal.withValues(alpha: 0.25),
                  backgroundColor: NeyvoColors.bgRaised,
                  labelStyle: NeyvoTextStyles.micro.copyWith(color: _educationCallType == id ? NeyvoColors.teal : NeyvoColors.textSecondary),
                  onSelected: (_) => setState(() => _educationCallType = id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: NeyvoColors.borderDefault),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _field('Office hours (optional)', _officeHours, hint: 'e.g. Monday–Friday, 9am–5pm'),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Any specific portal steps to mention?', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
              const SizedBox(width: 8),
              Switch(value: _portalStepsYes, onChanged: (v) => setState(() => _portalStepsYes = v), activeTrackColor: NeyvoColors.teal, activeThumbColor: NeyvoColors.teal),
            ],
          ),
          if (_portalStepsYes) _field('Portal steps', _portalSteps, lines: 2),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Confirm identity before discussing account', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
              const SizedBox(width: 8),
              Switch(
                value: _requireIdentityVerification,
                onChanged: (v) => setState(() => _requireIdentityVerification = v),
                activeTrackColor: NeyvoColors.teal,
                activeThumbColor: NeyvoColors.teal,
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          _field('Services offered (brief)', _servicesOffered, hint: 'e.g. Haircuts, color services, blowouts'),
          const SizedBox(height: 12),
          Text('Scheduling system', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in const ['Square', 'Fresha', 'Google Calendar', 'Calendly', 'None yet'])
                ChoiceChip(
                  label: Text(opt),
                  selected: _schedulingSystem == opt,
                  selectedColor: NeyvoColors.teal.withValues(alpha: 0.25),
                  backgroundColor: NeyvoColors.bgRaised,
                  labelStyle: NeyvoTextStyles.micro.copyWith(color: _schedulingSystem == opt ? NeyvoColors.teal : NeyvoColors.textSecondary),
                  onSelected: (_) => setState(() => _schedulingSystem = opt),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: NeyvoColors.borderDefault)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Leave voicemail if no answer', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
            const SizedBox(width: 8),
            Switch(value: _voicemailEnabled, onChanged: (v) => setState(() => _voicemailEnabled = v), activeTrackColor: NeyvoColors.teal, activeThumbColor: NeyvoColors.teal),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Allow callbacks from this profile', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
            const SizedBox(width: 8),
            Switch(
              value: _allowCallbacks,
              onChanged: (v) => setState(() => _allowCallbacks = v),
              activeTrackColor: NeyvoColors.teal,
              activeThumbColor: NeyvoColors.teal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, int lines = 1, int? maxLength, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: c,
          maxLines: lines,
          maxLength: maxLength,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: NeyvoColors.bgRaised,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NeyvoColors.borderDefault)),
          ),
          style: NeyvoTextStyles.bodyPrimary,
        ),
      ],
    );
  }

  Widget _buildVoiceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How should your agent sound?', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 8),
        Text('The conversation quality is managed by Neyvo — you\'re choosing the personality.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
        const SizedBox(height: 20),
        _voiceCard('warm_friendly', 'Warm & Friendly', 'Natural, warm female voice. Best for care-oriented calls.', '🎙'),
        _voiceCard('professional_clear', 'Professional & Clear', 'Confident male voice. Best for formal or business calls.', '💼'),
        _voiceCard('calm_reassuring', 'Calm & Reassuring', 'Gentle, measured voice. Best for sensitive conversations.', '🌊'),
      ],
    );
  }

  Widget _buildPhoneStep() {
    if (_loadingNumbers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: NeyvoColors.teal),
        ),
      );
    }
    if (_numbers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Which number should handle calls for this profile?', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any phone numbers yet. You can attach a number later from the profile page.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            'Go to Phone Numbers after setup to buy or link a number.',
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Which number should handle calls for this profile?', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'You can change this anytime after setup.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.builder(
            itemCount: _numbers.length,
            itemBuilder: (context, index) {
              final n = _numbers[index];
              final id = (n['number_id'] ?? n['phone_number_id'])?.toString() ?? '';
              final phone = (n['phone_number'] ?? '') as String? ?? '';
              final friendly = (n['friendly_name'] ?? '') as String? ?? '';
              final attachedName = n['attached_profile_name'] as String?;
              final selected = _selectedPhoneNumberId == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected ? NeyvoColors.tealGlow : NeyvoColors.bgRaised,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _selectedPhoneNumberId = id;
                        _selectedVapiPhoneNumberId = id;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? NeyvoColors.teal : NeyvoColors.borderDefault, width: selected ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 20, color: NeyvoColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  phone.isNotEmpty ? phone : friendly,
                                  style: NeyvoTextStyles.bodyPrimary,
                                ),
                                if (attachedName != null && attachedName.isNotEmpty)
                                  Text(
                                    'Used by: $attachedName',
                                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.warning),
                                  ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle, size: 18, color: NeyvoColors.teal),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedPhoneNumberId = null;
              _selectedVapiPhoneNumberId = null;
            });
          },
          child: const Text('Skip — attach a number later'),
        ),
      ],
    );
  }

  Widget _voiceCard(String value, String title, String subtitle, String emoji) {
    final selected = _voiceStyle == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? NeyvoColors.tealGlow : NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _voiceStyle = value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? NeyvoColors.teal : NeyvoColors.borderDefault, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                      Text(subtitle, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & create', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 20),
        Text('Profile name', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: _profileName,
          decoration: const InputDecoration(
            filled: true,
            fillColor: NeyvoColors.bgRaised,
            border: OutlineInputBorder(),
          ),
          style: NeyvoTextStyles.bodyPrimary,
        ),
        const SizedBox(height: 12),
        _reviewRow('Industry', _selectedIndustryId == 'school_financial_aid' ? 'Education — Student Financial Services' : 'Salon & Spa'),
        _reviewRow('Goal', _primaryGoal.text.trim().length > 80 ? '${_primaryGoal.text.trim().substring(0, 80)}...' : _primaryGoal.text.trim()),
        _reviewRow('Voice', _voiceStyle == 'warm_friendly' ? 'Warm & Friendly' : _voiceStyle == 'professional_clear' ? 'Professional & Clear' : 'Calm & Reassuring'),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted))),
          Expanded(child: Text(value, style: NeyvoTextStyles.bodyPrimary)),
        ],
      ),
    );
  }
}
