import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/neyvo_theme.dart';

/// Single source of truth for app theme.
final appThemeProvider = Provider<ThemeData>((ref) {
  return NeyvoThemeData.light();
});

