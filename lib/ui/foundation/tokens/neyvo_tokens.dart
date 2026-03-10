import 'package:flutter/material.dart';
import '../../../theme/neyvo_theme.dart';

/// Neyvo 2.0 design tokens – layered, spatial, audio-first.
///
/// These sit on top of the existing `NeyvoColors` / `NeyvoTheme` so that
/// older screens keep working, while new Voice OS surfaces use tokens only.

/// Layer tokens – background depth hierarchy.
class NeyvoLayer {
  /// Deep space background (app root).
  static const Color voidLayer = NeyvoColors.bgVoid;

  /// Primary surface – main app shell background.
  static const Color depth1 = NeyvoColors.bgBase;

  /// Raised cards / panels.
  static const Color depth2 = NeyvoColors.bgRaised;

  /// Overlays, modals, glass panels.
  static const Color depth3 = NeyvoColors.bgOverlay;

  /// Glass layer used for translucent panels.
  static Color get glass =>
      NeyvoColors.bgOverlay.withOpacity(0.7); // tuned per-screen if needed
}

/// Border tokens – consistent borders for all components.
class NeyvoBorderTokens {
  static const BorderSide subtle =
      BorderSide(color: NeyvoColors.borderSubtle, width: 1);

  static const BorderSide normal =
      BorderSide(color: NeyvoColors.borderDefault, width: 1);

  static const BorderSide focus =
      BorderSide(color: NeyvoColors.tealLight, width: 1.2);

  static const BorderSide active =
      BorderSide(color: NeyvoColors.teal, width: 1.4);

  static const BorderSide glow =
      BorderSide(color: NeyvoColors.tealGlow, width: 1.2);
}

/// Accent tokens – brand and semantic accents.
class NeyvoAccent {
  static const Color primary = NeyvoColors.teal;
  static Color get primarySoft => NeyvoColors.teal.withOpacity(0.12);
  static Color get primaryGlow => NeyvoColors.tealGlow;

  /// Used for async / processing states.
  static const Color processing = NeyvoColors.info;

  static const Color warning = NeyvoColors.warning;
  static const Color error = NeyvoColors.error;
}

