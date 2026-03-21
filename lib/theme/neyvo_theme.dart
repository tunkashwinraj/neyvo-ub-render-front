// lib/theme/neyvo_theme.dart
// Neyvo — Goodwin University style guide (April 2024).
// Working State 2 marker – Goodwin theme applied across the app.
// Colors: Dark Blue #005cb9 (Pantone 300), Light Blue #00a7e0 (Pantone 2995 C), Green #80bc00.
// Typography: Freight Sans Pro (preferred) → Roboto Slab (headings) + Open Sans (body) as web alternates.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════
// NEYVO COLORS — GOODWIN STYLE GUIDE
// ═══════════════════════════════════════════════════════════════════════════

class NeyvoColors {
  // Primary palette (single source of truth)
  // Goodwin style guide (digital RGB):
  // Dark blue #005CB9, light blue #00A7E0, green #80BC00.
  static const Color ubPurple = Color(0xFF005CB9); // primary dark blue
  static const Color ubLightBlue = Color(0xFF00A7E0); // secondary light blue
  static const Color white = Color(0xFFFFFFFF);

  // Backgrounds — white with subtle tints
  static const Color bgLight = white;
  static const Color surfaceLight = Color(0xFFFAFBFC);  // very subtle cool gray
  static const Color cardLight = white;
  static const Color bgVoid = white;
  static const Color bgBase = Color(0xFFFAFBFC);
  static const Color bgRaised = white;
  static const Color bgOverlay = Color(0xFFF5F6F8);
  static const Color bgHover = Color(0xFFF0F2F5);

  // Borders — derived from primary blue
  static const Color borderLight = Color(0x1A005CB9); // 10%
  static const Color borderSubtle = Color(0x0F005CB9); // 6%
  static const Color borderDefault = borderLight;
  static const Color borderStrong = Color(0x33005CB9); // 20%

  // Text — dark neutrals for readability on light UI
  static const Color textLightPrimary = Color(0xFF1A1D2E);  // dark for readability
  static const Color textLightSecondary = Color(0xFF4A4E6A);
  static const Color textLightMuted = Color(0xFF6B6F82);
  static const Color textPrimary = textLightPrimary;
  static const Color textSecondary = textLightSecondary;
  static const Color textMuted = textLightMuted;

  // Brand variants
  static const Color ubPurpleSoft = Color(0xFF2D7CC8);
  static const Color ubLightBlueSoft = Color(0xFF5FC6EA);
  static const Color teal = ubPurple;
  static const Color tealGlow = Color(0x1A005CB9);
  static const Color tealLight = ubPurpleSoft;
  static const Color coral = Color(0xFF80BC00);  // Goodwin green accent

  // Status — purple primary, light blue for info/success
  static const Color success = ubLightBlue;
  static const Color warning = Color(0xFFE6A800);  // amber tint, readable
  static const Color error = Color(0xFFD32F2F);   // red for errors
  static const Color info = ubLightBlue;

  // Sidebar — Goodwin dark blue with subtle elevation states
  static const Color sidebarBg = ubPurple;
  static const Color sidebarSelected = Color(0xFF0B73D1); // selected band
  static const Color sidebarHover = Color(0x33005CB9); // 20% primary overlay
  static const Color sidebarBgLight = ubPurple;
  static const Color sidebarSelectedLight = sidebarSelected;
  static const Color sidebarHoverLight = sidebarHover;
}

/// Typography scale — Roboto Slab (headings) + Open Sans (body) per UB style guide.
class NeyvoTextStyles {
  static TextStyle get display => GoogleFonts.robotoSlab(
    fontSize: 28, fontWeight: FontWeight.w700,
    letterSpacing: -0.5, color: NeyvoTheme.textPrimary,
  );
  static TextStyle get title => GoogleFonts.robotoSlab(
    fontSize: 20, fontWeight: FontWeight.w600,
    letterSpacing: -0.3, color: NeyvoTheme.textPrimary,
  );
  static TextStyle get heading => GoogleFonts.robotoSlab(
    fontSize: 16, fontWeight: FontWeight.w600,
    letterSpacing: -0.2, color: NeyvoTheme.textPrimary,
  );
  static TextStyle get body => GoogleFonts.openSans(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: NeyvoTheme.textSecondary,
  );
  static TextStyle get bodyPrimary => GoogleFonts.openSans(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: NeyvoTheme.textPrimary,
  );
  static TextStyle get label => GoogleFonts.openSans(
    fontSize: 12, fontWeight: FontWeight.w500,
    letterSpacing: 0.3, color: NeyvoTheme.textSecondary,
  );
  static TextStyle get micro => GoogleFonts.openSans(
    fontSize: 11, fontWeight: FontWeight.w500,
    letterSpacing: 0.5, color: NeyvoTheme.textMuted,
  );
}

/// Card with optional purple accent for active/AI elements.
class NeyvoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool glowing;

  const NeyvoCard({required this.child, this.padding, this.glowing = false, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeyvoTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: glowing ? NeyvoColors.ubPurple.withOpacity(0.35) : NeyvoTheme.border,
          width: 1,
        ),
        boxShadow: glowing ? [
          BoxShadow(
            color: NeyvoColors.tealGlow,
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEYVO THEME — Aliases
// ═══════════════════════════════════════════════════════════════════════════

class NeyvoTheme {
  static const Color bgPrimary = NeyvoColors.bgLight;
  static const Color bgSurface = NeyvoColors.surfaceLight;
  static const Color bgCard = NeyvoColors.cardLight;
  static const Color bgHover = NeyvoColors.sidebarHoverLight;

  static const Color border = NeyvoColors.borderLight;
  static const Color borderSubtle = NeyvoColors.borderLight;

  static const Color textPrimary = NeyvoColors.textLightPrimary;
  static const Color textSecondary = NeyvoColors.textLightSecondary;
  static const Color textTertiary = NeyvoColors.textLightMuted;
  static const Color textMuted = NeyvoColors.textLightMuted;

  static const Color teal = NeyvoColors.teal;
  static const Color tealLight = NeyvoColors.tealLight;
  static const Color coral = NeyvoColors.coral;

  static const Color success = NeyvoColors.success;
  static const Color warning = NeyvoColors.warning;
  static const Color error = NeyvoColors.error;
  static const Color info = NeyvoColors.info;

  static const Color sidebarBg = NeyvoColors.sidebarBgLight;
  static const Color sidebarSelected = NeyvoColors.sidebarSelectedLight;
  static const Color sidebarHover = NeyvoColors.sidebarHoverLight;

  static const Color primary = teal;
  static const Color accent = coral;
  static const Color surface = bgCard;
}

/// Spacing — 4px base.
class NeyvoSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 48;
  static const double touchTarget = 44;
}

class NeyvoRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
}

/// Typography — Roboto Slab (H1/H2) + Open Sans (body) per UB style guide.
class NeyvoType {
  static TextStyle get displayLarge => GoogleFonts.robotoSlab(
        fontSize: 32, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: NeyvoColors.textPrimary,
      );
  static TextStyle get headlineLarge => GoogleFonts.robotoSlab(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: NeyvoColors.textPrimary,
      );
  static TextStyle get headlineMedium => GoogleFonts.robotoSlab(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: NeyvoColors.textPrimary,
      );
  static TextStyle get titleLarge => GoogleFonts.robotoSlab(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: NeyvoColors.textPrimary,
      );
  static TextStyle get titleMedium => GoogleFonts.robotoSlab(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: NeyvoColors.textPrimary,
      );
  static TextStyle get bodyLarge => GoogleFonts.openSans(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: NeyvoColors.textPrimary,
      );
  static TextStyle get bodyMedium => GoogleFonts.openSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: NeyvoColors.textPrimary,
      );
  static TextStyle get bodySmall => GoogleFonts.openSans(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: NeyvoColors.textSecondary,
      );
  static TextStyle get labelLarge => GoogleFonts.openSans(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: NeyvoColors.textPrimary,
      );
  static TextStyle get labelSmall => GoogleFonts.openSans(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: NeyvoColors.textMuted,
      );

  // Light theme
  static TextStyle get displayLargeLight => GoogleFonts.robotoSlab(
        fontSize: 32, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: NeyvoColors.textLightPrimary,
      );
  static TextStyle get headlineLargeLight => GoogleFonts.robotoSlab(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: NeyvoColors.textLightPrimary,
      );
  static TextStyle get headlineMediumLight => GoogleFonts.robotoSlab(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: NeyvoColors.textLightPrimary,
      );
  static TextStyle get titleLargeLight => GoogleFonts.robotoSlab(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: NeyvoColors.textLightPrimary,
      );
  static TextStyle get titleMediumLight => GoogleFonts.robotoSlab(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: NeyvoColors.textLightPrimary,
      );
  static TextStyle get bodyLargeLight => GoogleFonts.openSans(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: NeyvoColors.textLightPrimary,
      );
  static TextStyle get bodyMediumLight => GoogleFonts.openSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: NeyvoColors.textLightPrimary,
      );
  static TextStyle get bodySmallLight => GoogleFonts.openSans(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: NeyvoColors.textLightSecondary,
      );
  static TextStyle get labelLargeLight => GoogleFonts.openSans(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: NeyvoColors.textLightPrimary,
      );
  static TextStyle get labelSmallLight => GoogleFonts.openSans(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: NeyvoColors.textLightMuted,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// THEME DATA — UB purple, light blue, white
// ═══════════════════════════════════════════════════════════════════════════

class NeyvoThemeData {
  /// Light theme — University of Bridgeport (purple primary, light blue secondary).
  static ThemeData light({
    Color? primaryColor,
    Color? secondaryColor,
    Color? accentColor,
  }) {
    final primary = primaryColor ?? NeyvoColors.ubPurple;
    final secondary = secondaryColor ?? NeyvoColors.ubLightBlue;
    final _ = accentColor; // kept for API compatibility
    final colorScheme = ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: NeyvoColors.surfaceLight,
      background: NeyvoColors.bgLight,
      error: NeyvoColors.error,
      onPrimary: NeyvoColors.white,
      onSecondary: NeyvoColors.white,
      onSurface: NeyvoColors.textLightPrimary,
      onBackground: NeyvoColors.textLightPrimary,
    );

    final textTheme = TextTheme(
      displayLarge: NeyvoType.displayLargeLight,
      headlineLarge: NeyvoType.headlineLargeLight,
      headlineMedium: NeyvoType.headlineMediumLight,
      titleLarge: NeyvoType.titleLargeLight,
      titleMedium: NeyvoType.titleMediumLight,
      bodyLarge: NeyvoType.bodyLargeLight,
      bodyMedium: NeyvoType.bodyMediumLight,
      bodySmall: NeyvoType.bodySmallLight,
      labelLarge: NeyvoType.labelLargeLight,
      labelSmall: NeyvoType.labelSmallLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: NeyvoColors.bgLight,
      colorScheme: colorScheme,
      fontFamily: 'Open Sans',
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: NeyvoColors.borderLight,
      cardTheme: CardThemeData(
        color: NeyvoColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeyvoRadius.lg),
          side: const BorderSide(color: NeyvoColors.borderLight, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: NeyvoColors.bgLight,
        foregroundColor: NeyvoColors.textLightPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: NeyvoType.titleLargeLight,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: NeyvoColors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.xl, vertical: NeyvoSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: NeyvoColors.borderLight),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: NeyvoSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, NeyvoSpacing.touchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NeyvoColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeyvoColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeyvoColors.ubPurple, width: 1.5),
        ),
        labelStyle: NeyvoType.bodyMediumLight.copyWith(color: NeyvoColors.textLightSecondary),
        hintStyle: NeyvoType.bodyMediumLight.copyWith(color: NeyvoColors.textLightMuted),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: NeyvoColors.sidebarSelectedLight,
        textColor: NeyvoColors.textLightPrimary,
        iconColor: NeyvoColors.textLightSecondary,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: NeyvoColors.ubPurple,
      secondary: NeyvoColors.ubLightBlue,
      surface: NeyvoColors.bgRaised,
      background: NeyvoColors.bgBase,
      error: NeyvoColors.error,
      onPrimary: NeyvoColors.white,
      onSurface: NeyvoColors.textPrimary,
    );

    final textTheme = TextTheme(
      displayLarge: NeyvoType.displayLarge,
      headlineLarge: NeyvoType.headlineLarge,
      headlineMedium: NeyvoType.headlineMedium,
      titleLarge: NeyvoType.titleLarge,
      titleMedium: NeyvoType.titleMedium,
      bodyLarge: NeyvoType.bodyLarge,
      bodyMedium: NeyvoType.bodyMedium,
      bodySmall: NeyvoType.bodySmall,
      labelLarge: NeyvoType.labelLarge,
      labelSmall: NeyvoType.labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NeyvoColors.bgVoid,
      colorScheme: colorScheme,
      fontFamily: 'Open Sans',
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: NeyvoColors.borderDefault,
      cardTheme: CardThemeData(
        color: NeyvoColors.bgRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeyvoRadius.lg),
          side: const BorderSide(color: NeyvoColors.borderDefault, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: NeyvoColors.bgBase,
        foregroundColor: NeyvoColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: NeyvoType.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NeyvoColors.ubPurple,
          foregroundColor: NeyvoColors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.xl, vertical: NeyvoSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NeyvoColors.ubPurple,
          side: const BorderSide(color: NeyvoColors.borderDefault),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: NeyvoSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NeyvoColors.ubPurple,
          minimumSize: const Size(0, NeyvoSpacing.touchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NeyvoColors.bgBase,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeyvoColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeyvoColors.ubPurple, width: 1.5),
        ),
        labelStyle: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textSecondary),
        hintStyle: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textMuted),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: NeyvoColors.sidebarSelected,
        textColor: NeyvoColors.textPrimary,
        iconColor: NeyvoColors.textSecondary,
      ),
    );
  }
}
