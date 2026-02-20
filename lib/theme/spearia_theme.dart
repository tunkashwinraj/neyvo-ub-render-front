// lib/theme/spearia_theme.dart
// Spearia Aura Design System — Unique, warm, professional
// For business owners: approachable, easy to use, responsive
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SPEARIA AURA — Design Tokens
// ═══════════════════════════════════════════════════════════════════════════

/// Spearia Aura color palette.
/// Warm, professional, trustworthy — designed for business owners.
class SpeariaAura {
  // Primary — Deep teal (trust, calm)
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primaryDark = Color(0xFF0F766E);

  // Accent — Warm coral (energy, action)
  static const Color accent = Color(0xFFEA580C);
  static const Color accentLight = Color(0xFFF97316);
  static const Color accentDark = Color(0xFFC2410C);

  // Neutrals — Warm stone (not cold gray)
  static const Color bg = Color(0xFFFAFAF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE7E5E4);
  static const Color borderLight = Color(0xFFF5F5F4);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFE11D48);
  static const Color info = Color(0xFF0284C7);

  // Status colors (for bookings, calls, etc.)
  static const Color statusActive = Color(0xFF10B981);      // Green
  static const Color statusPending = Color(0xFFFBBF24);    // Yellow
  static const Color statusCancelled = Color(0xFFEF4444);  // Red
  static const Color statusCompleted = Color(0xFF6366F1);  // Indigo
  static const Color statusNoShow = Color(0xFF6B7280);   // Gray

  // Background variants
  static const Color bgDark = Color(0xFFF5F5F4);
  static const Color bgHover = Color(0xFFFAFAFA);

  // Icon colors
  static const Color iconPrimary = Color(0xFF0D9488);
  static const Color iconSecondary = Color(0xFF64748B);
  static const Color iconMuted = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0D9488),
      Color(0xFF14B8A6),
      Color(0xFF2DD4BF),
    ],
  );
}

/// Spacing scale (4px base).
class SpeariaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double section = 48;
  static const double screen = 64;

  /// Minimum touch target (44dp for accessibility).
  static const double touchTarget = 44;
}

/// Border radius scale.
class SpeariaRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
}

/// Typography — Plus Jakarta Sans (headings) + DM Sans (body).
class SpeariaType {
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: SpeariaAura.textSecondary,
      );

  static TextStyle get labelLarge => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: SpeariaAura.textPrimary,
      );

  static TextStyle get labelMedium => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: SpeariaAura.textSecondary,
      );

  static TextStyle get labelSmall => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: SpeariaAura.textMuted,
      );
}

/// Decorative utilities.
class SpeariaFX {
  /// Soft card with subtle shadow.
  static BoxDecoration card({double radius = SpeariaRadius.md}) {
    return BoxDecoration(
      color: SpeariaAura.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
      border: Border.all(color: SpeariaAura.borderLight, width: 1),
    );
  }

  /// Primary action card with teal glow.
  static BoxDecoration primaryCard({double radius = SpeariaRadius.md}) {
    return BoxDecoration(
      color: SpeariaAura.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: SpeariaAura.primary.withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: SpeariaAura.primary.withOpacity(0.2)),
    );
  }

  /// Shape for cards and dialogs.
  static ShapeBorder shape([double r = SpeariaRadius.md]) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  /// Stat card with left border accent.
  /// Note: Returns a BoxDecoration without borderRadius when accent border is used,
  /// as Flutter doesn't allow borderRadius with non-uniform border colors.
  /// Use a Stack with a colored left container for rounded corners.
  static BoxDecoration statCard({
    required Color accentColor,
    double radius = SpeariaRadius.md,
  }) {
    return BoxDecoration(
      color: SpeariaAura.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: SpeariaAura.borderLight, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Glass morphism effect.
  static BoxDecoration glassMorphism({double radius = SpeariaRadius.lg}) {
    return BoxDecoration(
      color: SpeariaAura.surface.withOpacity(0.7),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: SpeariaAura.border.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: SpeariaAura.primary.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  /// Elevated card (for important items).
  static BoxDecoration elevatedCard({double radius = SpeariaRadius.md}) {
    return BoxDecoration(
      color: SpeariaAura.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// THEME DATA
// ═══════════════════════════════════════════════════════════════════════════

class SpeariaTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SpeariaAura.bg,
      colorSchemeSeed: SpeariaAura.primary,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final colorScheme = ColorScheme.light(
      primary: SpeariaAura.primary,
      onPrimary: SpeariaAura.textOnPrimary,
      primaryContainer: SpeariaAura.primary.withOpacity(0.12),
      secondary: SpeariaAura.accent,
      onSecondary: SpeariaAura.textOnAccent,
      tertiary: SpeariaAura.primaryLight,
      surface: SpeariaAura.surface,
      onSurface: SpeariaAura.textPrimary,
      surfaceContainerHighest: SpeariaAura.bg,
      error: SpeariaAura.error,
      onError: Colors.white,
      outline: SpeariaAura.border,
    );

    final textTheme = TextTheme(
      displayLarge: SpeariaType.displayLarge,
      displayMedium: SpeariaType.displayMedium,
      headlineLarge: SpeariaType.headlineLarge,
      headlineMedium: SpeariaType.headlineMedium,
      titleLarge: SpeariaType.titleLarge,
      titleMedium: SpeariaType.titleMedium,
      bodyLarge: SpeariaType.bodyLarge,
      bodyMedium: SpeariaType.bodyMedium,
      bodySmall: SpeariaType.bodySmall,
      labelLarge: SpeariaType.labelLarge,
      labelMedium: SpeariaType.labelMedium,
      labelSmall: SpeariaType.labelSmall,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: SpeariaAura.surface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: SpeariaType.titleLarge.copyWith(color: SpeariaAura.textPrimary),
        iconTheme: const IconThemeData(color: SpeariaAura.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: SpeariaAura.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: SpeariaFX.shape(SpeariaRadius.md),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SpeariaAura.primary,
          foregroundColor: SpeariaAura.textOnPrimary,
          minimumSize: const Size(0, SpeariaSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: SpeariaSpacing.xl,
            vertical: SpeariaSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SpeariaRadius.md),
          ),
          textStyle: SpeariaType.labelLarge.copyWith(color: SpeariaAura.textOnPrimary),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpeariaAura.primary,
          side: const BorderSide(color: SpeariaAura.border),
          minimumSize: const Size(0, SpeariaSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: SpeariaSpacing.lg,
            vertical: SpeariaSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SpeariaRadius.md),
          ),
          textStyle: SpeariaType.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SpeariaAura.primary,
          minimumSize: const Size(0, SpeariaSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: SpeariaSpacing.md),
          textStyle: SpeariaType.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: SpeariaAura.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SpeariaSpacing.md,
          vertical: SpeariaSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpeariaRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpeariaRadius.md),
          borderSide: const BorderSide(color: SpeariaAura.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpeariaRadius.md),
          borderSide: const BorderSide(color: SpeariaAura.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpeariaRadius.md),
          borderSide: const BorderSide(color: SpeariaAura.error),
        ),
        labelStyle: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
        hintStyle: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted),
        floatingLabelStyle: SpeariaType.labelSmall.copyWith(color: SpeariaAura.primary),
      ),
    );
  }
}


