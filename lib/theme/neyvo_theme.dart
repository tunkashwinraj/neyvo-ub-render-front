// lib/theme/neyvo_theme.dart
// Neyvo enterprise dark theme — "Ambient Intelligence" (Linear + Vapi + Vercel).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════
// NEYVO COLORS — Enterprise design system (exact values)
// ═══════════════════════════════════════════════════════════════════════════

class NeyvoColors {
  // Backgrounds
  static const Color bgVoid = Color(0xFF050508);
  static const Color bgBase = Color(0xFF0A0A0F);
  static const Color bgRaised = Color(0xFF0F0F17);
  static const Color bgOverlay = Color(0xFF151520);
  static const Color bgHover = Color(0xFF1A1A28);

  // Borders
  static const Color borderSubtle = Color(0x0FFFFFFF);  // 6%
  static const Color borderDefault = Color(0x1AFFFFFF); // 10%
  static const Color borderStrong = Color(0x29FFFFFF);  // 16%

  // Brand
  static const Color teal = Color(0xFF0D9488);
  static const Color tealGlow = Color(0x260D9488);  // 15% opacity
  static const Color tealLight = Color(0xFF14B8A6);
  static const Color coral = Color(0xFFEA580C);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8B8BA8);
  static const Color textMuted = Color(0xFF4A4A6A);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Sidebar
  static const Color sidebarBg = Color(0xFF080810);
  static const Color sidebarSelected = Color(0xFF111122);
  static const Color sidebarHover = Color(0xFF0D0D1A);
}

/// Typography scale — Inter, precise weights.
class NeyvoTextStyles {
  static TextStyle get display => GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w700,
    letterSpacing: -0.5, color: NeyvoColors.textPrimary,
  );
  static TextStyle get title => GoogleFonts.inter(
    fontSize: 20, fontWeight: FontWeight.w600,
    letterSpacing: -0.3, color: NeyvoColors.textPrimary,
  );
  static TextStyle get heading => GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600,
    letterSpacing: -0.2, color: NeyvoColors.textPrimary,
  );
  static TextStyle get body => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: NeyvoColors.textSecondary,
  );
  static TextStyle get bodyPrimary => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: NeyvoColors.textPrimary,
  );
  static TextStyle get label => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w500,
    letterSpacing: 0.3, color: NeyvoColors.textSecondary,
  );
  static TextStyle get micro => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500,
    letterSpacing: 0.5, color: NeyvoColors.textMuted,
  );
}

/// Card with optional teal glow for active/AI elements.
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
        color: NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: glowing ? NeyvoColors.teal.withOpacity(0.3) : NeyvoColors.borderDefault,
          width: 1,
        ),
        boxShadow: glowing ? [
          BoxShadow(
            color: NeyvoColors.tealGlow,
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ] : null,
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEYVO THEME — Aliases for backward compatibility (maps to NeyvoColors)
// ═══════════════════════════════════════════════════════════════════════════

class NeyvoTheme {
  static const Color bgPrimary = NeyvoColors.bgVoid;
  static const Color bgSurface = NeyvoColors.bgBase;
  static const Color bgCard = NeyvoColors.bgRaised;
  static const Color bgHover = NeyvoColors.bgHover;

  static const Color border = NeyvoColors.borderDefault;
  static const Color borderSubtle = NeyvoColors.borderSubtle;

  static const Color textPrimary = NeyvoColors.textPrimary;
  static const Color textSecondary = NeyvoColors.textSecondary;
  static const Color textTertiary = NeyvoColors.textMuted;
  static const Color textMuted = NeyvoColors.textMuted;

  static const Color teal = NeyvoColors.teal;
  static const Color tealLight = NeyvoColors.tealLight;
  static const Color coral = NeyvoColors.coral;

  static const Color success = NeyvoColors.success;
  static const Color warning = NeyvoColors.warning;
  static const Color error = NeyvoColors.error;
  static const Color info = NeyvoColors.info;

  static const Color sidebarBg = NeyvoColors.sidebarBg;
  static const Color sidebarSelected = NeyvoColors.sidebarSelected;
  static const Color sidebarHover = NeyvoColors.sidebarHover;

  static const Color primary = teal;
  static const Color accent = coral;
  static const Color surface = bgCard;
}

/// Spacing (reuse from spec — 4px base).
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

/// Border radius.
class NeyvoRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
}

/// Typography — Inter.
class NeyvoType {
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: NeyvoTheme.textPrimary,
      );
  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: NeyvoTheme.textPrimary,
      );
  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: NeyvoTheme.textPrimary,
      );
  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: NeyvoTheme.textPrimary,
      );
  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: NeyvoTheme.textPrimary,
      );
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: NeyvoTheme.textPrimary,
      );
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: NeyvoTheme.textPrimary,
      );
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: NeyvoTheme.textSecondary,
      );
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: NeyvoTheme.textPrimary,
      );
  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: NeyvoTheme.textTertiary,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// THEME DATA (dark)
// ═══════════════════════════════════════════════════════════════════════════

class NeyvoThemeData {
  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: NeyvoColors.teal,
      secondary: NeyvoColors.coral,
      surface: NeyvoColors.bgRaised,
      background: NeyvoColors.bgBase,
      error: NeyvoColors.error,
      onPrimary: Colors.white,
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
      fontFamily: 'Inter',
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: NeyvoColors.borderDefault,
      cardTheme: CardThemeData(
        color: NeyvoColors.bgRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeyvoRadius.md),
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
          backgroundColor: NeyvoColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.xl, vertical: NeyvoSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NeyvoColors.teal,
          side: const BorderSide(color: NeyvoColors.borderDefault),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: NeyvoSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NeyvoColors.teal,
          minimumSize: const Size(0, NeyvoSpacing.touchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NeyvoColors.bgBase,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: NeyvoColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: NeyvoColors.teal, width: 1),
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
