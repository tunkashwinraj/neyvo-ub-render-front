// lib/ui/activation/activation_service.dart
// Single frontend controller for org activation state (Activation Mode).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../neyvo_pulse_api.dart';

enum ActivationStage { intro, business, agents, numbers, testCall, live }

class ActivationNextAction {
  final String label;
  final String route;
  final Map<String, dynamic> context;

  const ActivationNextAction({
    required this.label,
    required this.route,
    required this.context,
  });

  factory ActivationNextAction.fromJson(Map<String, dynamic> json) {
    return ActivationNextAction(
      label: (json['label'] ?? '').toString(),
      route: (json['route'] ?? '').toString(),
      context: Map<String, dynamic>.from(json['context'] as Map? ?? const {}),
    );
  }
}

class ActivationStatus {
  final ActivationStage stage;
  final Map<String, bool> checklist;
  final Map<String, int> counts;
  final ActivationNextAction nextAction;

  const ActivationStatus({
    required this.stage,
    required this.checklist,
    required this.counts,
    required this.nextAction,
  });

  bool get introSeen => checklist['introSeen'] == true;
  bool get businessModelStarted => checklist['businessModelStarted'] == true;
  bool get businessModelReady => checklist['businessModelReady'] == true;
  bool get agentsCreated => checklist['agentsCreated'] == true;
  bool get numberConnected => checklist['numberConnected'] == true;
  bool get firstCallCompleted => checklist['firstCallCompleted'] == true;

  factory ActivationStatus.fromJson(Map<String, dynamic> json) {
    final stageStr = (json['stage'] ?? '').toString().toUpperCase();
    final stage = switch (stageStr) {
      'INTRO' => ActivationStage.intro,
      'BUSINESS' => ActivationStage.business,
      'AGENTS' => ActivationStage.agents,
      'NUMBERS' => ActivationStage.numbers,
      'TEST_CALL' => ActivationStage.testCall,
      'LIVE' => ActivationStage.live,
      _ => ActivationStage.intro,
    };
    final rawChecklist = Map<String, dynamic>.from(json['checklist'] as Map? ?? const {});
    final checklist = <String, bool>{
      'introSeen': rawChecklist['introSeen'] == true,
      'businessModelStarted': rawChecklist['businessModelStarted'] == true,
      'businessModelReady': rawChecklist['businessModelReady'] == true,
      'agentsCreated': rawChecklist['agentsCreated'] == true,
      'numberConnected': rawChecklist['numberConnected'] == true,
      'firstCallCompleted': rawChecklist['firstCallCompleted'] == true,
    };
    final rawCounts = Map<String, dynamic>.from(json['counts'] as Map? ?? const {});
    final counts = <String, int>{
      'agents': (rawCounts['agents'] as num?)?.toInt() ?? 0,
      'numbers': (rawCounts['numbers'] as num?)?.toInt() ?? 0,
      'completedCalls': (rawCounts['completedCalls'] as num?)?.toInt() ?? 0,
    };
    final nextActionJson = Map<String, dynamic>.from(json['nextAction'] as Map? ?? const {});
    return ActivationStatus(
      stage: stage,
      checklist: checklist,
      counts: counts,
      nextAction: ActivationNextAction.fromJson(nextActionJson),
    );
  }
}

class ActivationService extends ChangeNotifier {
  ActivationStatus? _status;
  bool _loading = false;
  bool _collapsed = false;
  bool _prefsLoaded = false;

  ActivationStatus? get status => _status;
  bool get isLoading => _loading;
  bool get isLive => _status?.stage == ActivationStage.live;
  bool get isCollapsed => _collapsed;

  double get progress01 {
    final s = _status;
    if (s == null) return 0.0;
    // Main four activation steps: business ready, agents, number, first call.
    final steps = [
      s.businessModelReady,
      s.agentsCreated,
      s.numberConnected,
      s.firstCallCompleted,
    ];
    final completed = steps.where((b) => b).length;
    return completed / steps.length;
  }

  ActivationStage get stage => _status?.stage ?? ActivationStage.intro;

  ActivationNextAction? get nextAction => _status?.nextAction;

  Future<void> _ensurePrefsLoaded() async {
    if (_prefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _collapsed = prefs.getBool('activation_dock_collapsed') ?? false;
    } catch (_) {
      _collapsed = false;
    }
    _prefsLoaded = true;
  }

  Future<void> setCollapsed(bool value) async {
    await _ensurePrefsLoaded();
    _collapsed = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('activation_dock_collapsed', value);
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> refresh() async {
    await _ensurePrefsLoaded();
    _loading = true;
    notifyListeners();
    try {
      final res = await NeyvoPulseApi.getActivationStatus();
      if (res['ok'] == true) {
        _status = ActivationStatus.fromJson(res);
      }
    } catch (_) {
      // Non-fatal; keep last known status.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

// Global singleton-style instance for now. In future, can be wired via Provider.
final ActivationService activationService = ActivationService();

