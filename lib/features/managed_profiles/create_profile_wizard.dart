// lib/features/managed_profiles/create_profile_wizard.dart
// 4-step wizard: Industry → Identity+Voice → Packs → Connect & Rules → Preview & Create.

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
  static const int _totalSteps = 5; // Industry, Identity+Voice, Packs, Connect, Preview
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
  // Wizard v2: packs and structured data
  String? _selectedPack;
  List<String> _enabledCapabilities = [];
  bool _customizeExpanded = false;
  String _schedulingProvider = 'none';
  String _businessHoursDisplay = 'Mon–Fri 9:00 AM–5:00 PM';
  bool _identityVerificationRequired = false;
  String _identityVerificationMethod = 'student_id';
  bool _depositRequired = false;
  String _depositType = 'fixed';
  String _depositAmount = '';
  final _knowledgeSnippet = TextEditingController();
  List<String> _servicesChips = [];
  Map<String, dynamic>? _previewData;
  bool _loadingPreview = false;
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
    _knowledgeSnippet.dispose();
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
    final bn = _businessName.text.trim();
    final generatedProfileName = bn.isEmpty
        ? 'Voice Profile'
        : '${bn.split(RegExp(r'\s+')).first} · ${_selectedIndustryId == 'school_financial_aid' ? 'UB' : 'Profile'}';
    final profileName = _profileName.text.trim().isEmpty ? generatedProfileName : _profileName.text.trim();
    final businessSpecifics = <String, dynamic>{};
    if (_selectedIndustryId == 'school_financial_aid') {
      final packToCallType = {'financial_aid': 'loan_acceptance', 'billing_fees': 'payment_reminder', 'front_desk': 'general_followup'};
      businessSpecifics['call_type'] = packToCallType[_selectedPack] ?? _educationCallType;
      businessSpecifics['office_hours'] = _businessHoursDisplay;
      if (_portalStepsYes && _portalSteps.text.trim().isNotEmpty) {
        businessSpecifics['portal_steps'] = _portalSteps.text.trim();
      }
      businessSpecifics['require_identity_verification'] = _identityVerificationRequired;
      if (_identityVerificationRequired) {
        businessSpecifics['identity_verification_method'] = _identityVerificationMethod;
      }
    } else {
      if (_servicesOffered.text.trim().isNotEmpty) {
        businessSpecifics['services_offered'] = _servicesOffered.text.trim();
      }
      if (_servicesChips.isNotEmpty) {
        businessSpecifics['services_offered'] = _servicesChips.join(', ');
      }
      businessSpecifics['business_hours'] = _businessHoursDisplay;
      final sched = _schedulingProvider == 'none' ? 'None yet' : _schedulingProvider;
      businessSpecifics['scheduling_system'] = sched;
      businessSpecifics['allow_upsell'] = _salonAllowUpsell;
    }
    final primaryGoal = _primaryGoal.text.trim().length > 200
        ? _primaryGoal.text.trim().substring(0, 200)
        : _primaryGoal.text.trim();
    final payload = {
      'industry_id': _selectedIndustryId!,
      'profile_name': profileName,
      'business_name': bn.isEmpty ? 'My Business' : bn,
      'primary_goal': primaryGoal.isEmpty ? _defaultPrimaryGoal() : primaryGoal,
      'phone_number': _phoneNumber.text.trim(),
      'callback_phone': _phoneNumber.text.trim(),
      'voice_style': _voiceStyle,
      'voicemail_enabled': _voicemailEnabled,
      'allow_callbacks': true,
      'agent_persona_name': _agentName.text.trim().isEmpty ? 'Alex' : _agentName.text.trim(),
      'business_specifics': businessSpecifics,
    };
    if (_selectedPack != null && _selectedPack!.isNotEmpty) {
      payload['selected_pack'] = _selectedPack!;
      payload['enabled_capabilities'] = _enabledCapabilities.isNotEmpty
          ? _enabledCapabilities
          : _capabilitiesForPack(_selectedPack!);
    }
    payload['integration_selection'] = {
      'scheduling_provider': _schedulingProvider,
      'calendar_provider': 'neyvo_scheduler',
      'payments_provider': 'none',
    };
    payload['policies'] = {
      'identity_verification_required': _identityVerificationRequired,
      'identity_verification_method': _identityVerificationMethod,
      'business_hours': _businessHoursDisplay,
      'deposit_required': _depositRequired,
      'deposit_amount': _depositAmount,
      'deposit_type': _depositType,
    };
    final know = _knowledgeSnippet.text.trim();
    if (know.isNotEmpty) {
      final snippet = know.length > 280 ? know.substring(0, 280) : know;
      payload['knowledge_snippet'] = snippet;
      payload['must_know_note'] = snippet;
    }
    if (_servicesChips.isNotEmpty) payload['services'] = _servicesChips;
    if (_selectedPhoneNumberId != null && _selectedVapiPhoneNumberId != null) {
      payload['attached_phone_number_id'] = _selectedPhoneNumberId!;
      payload['attached_vapi_phone_number_id'] = _selectedVapiPhoneNumberId!;
    }
    return payload;
  }

  String _defaultPrimaryGoal() {
    const map = {
      'financial_aid': 'Remind students about loan acceptance and financial aid; guide portal steps; schedule callbacks.',
      'billing_fees': 'Follow up on payments and balances; set payment plans; schedule callbacks.',
      'front_desk': 'Answer policy questions; route inquiries; schedule callbacks.',
      'receptionist': 'Book, confirm, and reschedule appointments; send SMS confirmations.',
      'reminders': 'Confirm appointments and send reminders.',
      'promotions': 'Promote offers, rebook, and capture leads.',
    };
    return map[_selectedPack] ?? 'Help callers with the main services your business provides.';
  }

  List<String> _capabilitiesForPack(String pack) {
    if (_selectedIndustryId == 'school_financial_aid') {
      return ['EducationFollowupCapability_v1'];
    }
    return ['SalonSchedulingCapability_v1'];
  }

  Future<void> _createProfile() async {
    if (_selectedIndustryId == null) return;
    if (_businessName.text.trim().isEmpty || _phoneNumber.text.trim().isEmpty) {
      setState(() => _error = 'Please fill business name and callback number.');
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
                                if (_currentStep == 1 && _selectedPack == null) {
                                  _selectedPack = _selectedIndustryId == 'school_financial_aid' ? 'financial_aid' : 'receptionist';
                                  _enabledCapabilities = _capabilitiesForPack(_selectedPack!);
                                }
                                if (_currentStep == 3) {
                                  final bn = _businessName.text.trim();
                                  final generated = bn.isEmpty ? 'Voice Profile' : '${bn.split(RegExp(r'\s+')).first} · ${_selectedIndustryId == 'school_financial_aid' ? 'UB' : 'Profile'}';
                                  if (_profileName.text.trim().isEmpty) _profileName.text = generated;
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
                      child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create My Voice Profile'),
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
        return _businessName.text.trim().isNotEmpty && _phoneNumber.text.trim().isNotEmpty;
      case 2:
        return _selectedPack != null && _selectedPack!.isNotEmpty;
      case 3:
        return true;
      case 4:
        return true;
      default:
        return true;
    }
  }

  Widget _stepContent() {
    switch (_currentStep) {
      case 0:
        return _buildIndustryStep();
      case 1:
        return _buildIdentityVoiceStep();
      case 2:
        return _buildPacksStep();
      case 3:
        return _buildConnectStep();
      case 4:
        return _buildPreviewStep();
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

  Widget _buildIdentityVoiceStep() {
    final isEducation = _selectedIndustryId == 'school_financial_aid';
    final agentChips = isEducation
        ? const ['Ms. Patel', 'Mr. Rodriguez', 'Alex', 'Emma', 'Maria']
        : const ['Mia', 'Sophia', 'Alex', 'Emma', 'Jordan'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Let's set up your ${isEducation ? 'school' : 'salon'} voice profile",
          style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Takes about 2 minutes. You can refine details anytime.',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _field(
          isEducation ? 'School / Department name' : 'Salon name',
          _businessName,
          hint: isEducation ? 'Student Financial Services — University of Bridgeport' : 'Downtown Salon & Spa',
        ),
        const SizedBox(height: 12),
        Text('What should the agent introduce itself as?', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...agentChips.map((name) => ChoiceChip(
                  label: Text(name),
                  selected: _agentName.text.trim() == name,
                  selectedColor: NeyvoColors.teal.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _agentName.text = name),
                )),
            ActionChip(
              label: const Text('Custom'),
              onPressed: () => setState(() => _agentName.text = ''),
            ),
          ],
        ),
        if (_agentName.text.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _field('Agent name', _agentName, hint: 'e.g. Alex'),
          ),
        const SizedBox(height: 12),
        _field(
          'Callback phone number',
          _phoneNumber,
          hint: '(203) 576-4568',
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        Text('Voice style', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
        const SizedBox(height: 8),
        _voiceCard('warm_friendly', 'Warm & Friendly', 'Best for students and parents. Friendly, supportive.', '🎙', showPlaySample: true),
        _voiceCard('professional_clear', 'Professional & Clear', 'More formal. Great for official communications.', '💼', showPlaySample: true),
        _voiceCard('calm_reassuring', 'Calm & Reassuring', 'Gentle and patient. Best for sensitive topics.', '🌊', showPlaySample: true),
      ],
    );
  }

  Widget _buildPacksStep() {
    final isEducation = _selectedIndustryId == 'school_financial_aid';
    if (isEducation) {
      final packs = [
        ('financial_aid', 'Financial Aid & Loan Support', 'Loan reminders, portal guidance, callbacks', true),
        ('billing_fees', 'Payment & Balance Follow-up', 'Payment reminders, payment plans, callbacks', false),
        ('front_desk', 'General Student Support', 'Answer policy questions, route inquiries, callbacks', false),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What should your agent help with most?', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Choose one pack to start. You can customize after.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
          const SizedBox(height: 16),
          ...packs.map((p) => _packCard(p.$1, p.$2, p.$3, recommended: p.$4)),
          const SizedBox(height: 12),
          _buildCustomizeDrawer(isEducation: true),
        ],
      );
    }
    final packs = [
      ('receptionist', 'Full Receptionist Pack', 'Book, confirm, reschedule, SMS confirmations', true),
      ('reminders', 'Reminders Pack', 'Confirm appointments, send reminders, SMS', false),
      ('promotions', 'Promotions & Rebooking Pack', 'Promote offers, rebook, capture leads', false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What should your agent handle?', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Pick one pack. You can customize if needed.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
        const SizedBox(height: 16),
        ...packs.map((p) => _packCard(p.$1, p.$2, p.$3, recommended: p.$4)),
        const SizedBox(height: 12),
        _buildCustomizeDrawer(isEducation: false),
      ],
    );
  }

  Widget _buildCustomizeDrawer({required bool isEducation}) {
    final caps = _selectedPack != null ? _capabilitiesForPack(_selectedPack!) : <String>[];
    final labels = isEducation
        ? {'EducationFollowupCapability_v1': 'Loan reminders, portal guidance, schedule callbacks, create case, send SMS'}
        : {'SalonSchedulingCapability_v1': 'Book, confirm, reschedule, cancel, send SMS confirmation'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _customizeExpanded = !_customizeExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text('Customize', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal)),
                const SizedBox(width: 4),
                Icon(_customizeExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: NeyvoColors.teal),
              ],
            ),
          ),
        ),
        if (_customizeExpanded && caps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Don\'t worry — if you skip anything, Neyvo will still create a working profile.', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted)),
          const SizedBox(height: 8),
          ...caps.map((capKey) {
            final isOn = _enabledCapabilities.contains(capKey);
            final label = labels[capKey] ?? capKey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: isOn,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        if (!_enabledCapabilities.contains(capKey)) _enabledCapabilities = [..._enabledCapabilities, capKey];
                      } else {
                        _enabledCapabilities = _enabledCapabilities.where((c) => c != capKey).toList();
                      }
                    }),
                    activeColor: NeyvoColors.teal,
                  ),
                  Expanded(child: Text(label, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary))),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _packCard(String id, String title, String subtitle, {bool recommended = false}) {
    final selected = _selectedPack == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? NeyvoColors.tealGlow : NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() {
            _selectedPack = id;
            _enabledCapabilities = _capabilitiesForPack(id);
          }),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? NeyvoColors.teal : NeyvoColors.borderDefault, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(selected ? Icons.check_circle : Icons.radio_button_off, color: selected ? NeyvoColors.teal : NeyvoColors.textMuted, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                          if (recommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: NeyvoColors.teal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text('Recommended', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.teal)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
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

  static const List<String> _businessHoursPresets = [
    'Mon–Fri 9:00 AM–5:00 PM',
    'Tue–Sat 10:00 AM–7:00 PM',
    'Mon–Sat 9:00 AM–6:00 PM',
    '24/7',
  ];

  Widget _buildConnectStep() {
    final isEducation = _selectedIndustryId == 'school_financial_aid';
    final isLeadCapture = !isEducation && _schedulingProvider == 'none';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect your systems + set key rules', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Connecting systems enables real actions. You can connect later.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
          const SizedBox(height: 20),
          if (!isEducation) ...[
            Text('Scheduling system', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in const ['square', 'fresha', 'google_calendar', 'calendly', 'none'])
                  ChoiceChip(
                    label: Text(opt == 'none' ? 'None — collect details manually' : opt.replaceAll('_', ' ').toUpperCase()),
                    selected: _schedulingProvider == opt,
                    selectedColor: NeyvoColors.teal.withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _schedulingProvider = opt),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: NeyvoColors.bgRaised, borderRadius: BorderRadius.circular(8), border: Border.all(color: NeyvoColors.borderSubtle)),
              child: Row(
                children: [
                  Icon(_schedulingProvider != 'none' ? Icons.check_circle : Icons.info_outline, size: 20, color: _schedulingProvider != 'none' ? NeyvoColors.success : NeyvoColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isLeadCapture
                          ? 'Lead capture mode — your agent will collect details and your team can confirm by text or call.'
                          : 'Connect your scheduling system in Settings to enable live booking.',
                      style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Business hours', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
          const SizedBox(height: 6),
          InputDecorator(
            decoration: const InputDecoration(filled: true, fillColor: NeyvoColors.bgRaised, border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _businessHoursPresets.contains(_businessHoursDisplay) ? _businessHoursDisplay : _businessHoursPresets.first,
                isExpanded: true,
                dropdownColor: NeyvoColors.bgRaised,
                items: _businessHoursPresets.map((s) => DropdownMenuItem(value: s, child: Text(s, style: NeyvoTextStyles.bodyPrimary))).toList(),
                onChanged: (v) => setState(() => _businessHoursDisplay = v ?? _businessHoursPresets.first),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isEducation) ...[
            Row(
              children: [
                Text('Verify identity before sharing student info?', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                const SizedBox(width: 8),
                Switch(
                  value: _identityVerificationRequired,
                  onChanged: (v) => setState(() => _identityVerificationRequired = v),
                  activeTrackColor: NeyvoColors.teal,
                ),
              ],
            ),
            if (_identityVerificationRequired) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Student ID'),
                    selected: _identityVerificationMethod == 'student_id',
                    selectedColor: NeyvoColors.teal.withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _identityVerificationMethod = 'student_id'),
                  ),
                  ChoiceChip(
                    label: const Text('Last name + DOB'),
                    selected: _identityVerificationMethod == 'last_name_dob',
                    selectedColor: NeyvoColors.teal.withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _identityVerificationMethod = 'last_name_dob'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (!isEducation && _selectedPack != null) ...[
            Row(
              children: [
                Text('Require deposit?', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                const SizedBox(width: 8),
                Switch(value: _depositRequired, onChanged: (v) => setState(() => _depositRequired = v), activeTrackColor: NeyvoColors.teal),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (!isEducation) ...[
            Text('Services offered (optional)', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in const ['Haircut', 'Color', 'Blowout', 'Highlights', 'Styling', 'Extensions'])
                  FilterChip(
                    label: Text(s),
                    selected: _servicesChips.contains(s),
                    selectedColor: NeyvoColors.teal.withValues(alpha: 0.25),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _servicesChips = [..._servicesChips, s];
                      } else {
                        _servicesChips = _servicesChips.where((e) => e != s).toList();
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Text('Leave voicemail when no answer', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
              const SizedBox(width: 8),
              Switch(value: _voicemailEnabled, onChanged: (v) => setState(() => _voicemailEnabled = v), activeTrackColor: NeyvoColors.teal),
            ],
          ),
          const SizedBox(height: 16),
          _field(
            'Anything your agent must know? (optional, 280 chars)',
            _knowledgeSnippet,
            lines: 2,
            maxLength: 280,
            hint: isEducation ? 'Only discuss aid with the student. Explain portal steps slowly.' : "We don't do color on Sundays.",
          ),
        ],
      ),
    );
  }

  Future<void> _loadPreview() async {
    setState(() { _loadingPreview = true; _previewData = null; });
    try {
      final payload = _buildPayload();
      final res = await ManagedProfileApiService.previewProfile(payload);
      if (mounted) setState(() { _previewData = res; _loadingPreview = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingPreview = false; });
    }
  }

  Widget _buildPreviewStep() {
    if (_previewData == null && !_loadingPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: NeyvoColors.teal)));
    }
    if (_loadingPreview) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: NeyvoColors.teal)));
    }
    if (_previewData == null) {
      return Column(
        children: [
          const SizedBox(height: 24),
          Center(child: Text('Preview could not be loaded.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary))),
          const SizedBox(height: 16),
          TextButton.icon(onPressed: _loadPreview, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      );
    }
    final happy = _previewData!['happy_preview_text'] as String? ?? '';
    final fallback = _previewData!['fallback_preview_text'] as String? ?? '';
    final summary = _previewData!['preview_summary'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview your agent before you launch', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Hear how it handles success and when systems are unavailable.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
          const SizedBox(height: 20),
          NeyvoCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Happy path — successful call', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal)),
                  const SizedBox(height: 8),
                  Text(happy, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          NeyvoCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fallback — when systems are slow', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                  const SizedBox(height: 8),
                  Text(fallback, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          NeyvoCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                  const SizedBox(height: 8),
                  if (summary['pack'] != null) Text('Pack: ${summary['pack']}', style: NeyvoTextStyles.bodyPrimary),
                  if (summary['voice_style'] != null) Text('Voice: ${summary['voice_style']}', style: NeyvoTextStyles.bodyPrimary),
                  if (summary['mode'] != null) Text('Mode: ${summary['mode']}', style: NeyvoTextStyles.bodyPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
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

  Widget _voiceCard(String value, String title, String subtitle, String emoji, {bool showPlaySample = false}) {
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
                if (showPlaySample)
                  TextButton.icon(
                    icon: const Icon(Icons.play_circle_outline, size: 18, color: NeyvoColors.teal),
                    label: const Text('Play sample'),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voice sample coming soon'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
