// lib/widgets/inactivity_detector.dart
// Wraps authenticated content and signs out after a period of user inactivity.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../api/spearia_api.dart';
import '../neyvo_pulse_api.dart';

/// Wraps [child] and signs out the user after [timeout] of no pointer or keyboard activity.
class InactivityDetector extends StatefulWidget {
  const InactivityDetector({
    super.key,
    required this.child,
    this.timeout = const Duration(hours: 1),
  });

  final Widget child;
  final Duration timeout;

  @override
  State<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends State<InactivityDetector> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _onTimeout);
  }

  void _onTimeout() {
    _timer?.cancel();
    _timer = null;
    FirebaseAuth.instance.signOut();
    SpeariaApi.setSessionToken(null);
    SpeariaApi.setUserId(null);
    NeyvoPulseApi.setDefaultAccountId(null);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _resetTimer();
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _resetTimer(),
        onPointerMove: (_) => _resetTimer(),
        onPointerSignal: (_) => _resetTimer(),
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}
