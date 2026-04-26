import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Complete ThemeData for light and dark modes, derived from Theme.md.
class AppTheme {
  AppTheme._();

  // ──────────────────────────────────────────
  // Light Theme
  // ──────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.lightPrimaryAction,
      secondary: AppColors.lightSecondaryAction,
      surface: AppColors.lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
      outline: AppColors.lightDivider,
      surfaceContainerLowest: AppColors.lightSurfaceCard,
      surfaceContainerLow: AppColors.lightSurfaceAlt,
      surfaceContainer: AppColors.lightSurfaceContainer,
      surfaceContainerHigh: AppColors.lightSurfaceContainerHigh,
      surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,
    ),
    textTheme: _buildTextTheme(Brightness.light),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.lightSurfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide.none,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Colors.transparent, // No-Line rule
      thickness: 0,
      space: 12, // Default vertical spacing
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.lightPrimaryAction,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.lightFocusRing, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightSurfaceAlt,
      selectedColor: AppColors.lightSecondaryAction.withValues(alpha: 0.15),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.lightTextSecondary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.lightIconInactive,
      size: 22,
    ),
    extensions: <ThemeExtension<dynamic>>[
      NodaThemeExtension(
        surfaceAlt: AppColors.lightSurfaceAlt,
        brandGradient: AppColors.brandGradient,
        textSecondary: AppColors.lightTextSecondary,
        iconActive: AppColors.lightIconActive,
        iconInactive: AppColors.lightIconInactive,
        focusRing: AppColors.lightFocusRing,
        glassBackground: Colors.white.withValues(alpha: 0.8),
        glassBlur: 24,
      ),
    ],
  );

  // ──────────────────────────────────────────
  // Dark Theme
  // ──────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkPrimaryAction,
      secondary: AppColors.darkSecondaryAction,
      surface: AppColors.darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
      outline: AppColors.darkDivider,
      surfaceContainerLowest: AppColors.darkSurfaceCard,
      surfaceContainerLow: AppColors.darkSurfaceAlt,
      surfaceContainer: AppColors.darkSurfaceContainer,
      surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
      surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
    ),
    textTheme: _buildTextTheme(Brightness.dark),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.darkSurfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide.none,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Colors.transparent,
      thickness: 0,
      space: 12,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkPrimaryAction,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkFocusRing, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSurfaceAlt,
      selectedColor: AppColors.darkSecondaryAction.withValues(alpha: 0.15),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.darkTextSecondary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.darkIconInactive,
      size: 22,
    ),
    extensions: <ThemeExtension<dynamic>>[
      NodaThemeExtension(
        surfaceAlt: AppColors.darkSurfaceAlt,
        brandGradient: AppColors.darkBrandGradient,
        textSecondary: AppColors.darkTextSecondary,
        iconActive: AppColors.darkIconActive,
        iconInactive: AppColors.darkIconInactive,
        focusRing: AppColors.darkFocusRing,
        glassBackground: const Color(0xFF1E293B).withValues(alpha: 0.7),
        glassBlur: 24,
      ),
    ],
  );

  // ──────────────────────────────────────────
  // Shared TextTheme
  // ──────────────────────────────────────────
  static TextTheme _buildTextTheme(Brightness brightness) {
    final Color primary = brightness == Brightness.light
        ? AppColors.lightTextPrimary
        : AppColors.darkTextPrimary;
    final Color secondary = brightness == Brightness.light
        ? AppColors.lightTextSecondary
        : AppColors.darkTextSecondary;

    return TextTheme(
      headlineLarge: GoogleFonts.manrope(
        fontSize: 32, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.8,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 24, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.5,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 20, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 18, fontWeight: FontWeight.w600, color: primary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w500, color: primary,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w500, color: secondary,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w400, color: primary, height: 1.6,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w400, color: primary, height: 1.5,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w400, color: secondary, height: 1.4,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w600, color: primary, letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.1,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11, fontWeight: FontWeight.w400, color: secondary,
      ),
    );
  }
}

/// Custom theme extension for Noda-specific properties not covered by Material.
@immutable
class NodaThemeExtension extends ThemeExtension<NodaThemeExtension> {
  const NodaThemeExtension({
    required this.surfaceAlt,
    required this.brandGradient,
    required this.textSecondary,
    required this.iconActive,
    required this.iconInactive,
    required this.focusRing,
    required this.glassBackground,
    required this.glassBlur,
  });

  final Color surfaceAlt;
  final LinearGradient brandGradient;
  final Color textSecondary;
  final Color iconActive;
  final Color iconInactive;
  final Color focusRing;
  final Color glassBackground;
  final double glassBlur;

  @override
  NodaThemeExtension copyWith({
    Color? surfaceAlt,
    LinearGradient? brandGradient,
    Color? textSecondary,
    Color? iconActive,
    Color? iconInactive,
    Color? focusRing,
    Color? glassBackground,
    double? glassBlur,
  }) {
    return NodaThemeExtension(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      brandGradient: brandGradient ?? this.brandGradient,
      textSecondary: textSecondary ?? this.textSecondary,
      iconActive: iconActive ?? this.iconActive,
      iconInactive: iconInactive ?? this.iconInactive,
      focusRing: focusRing ?? this.focusRing,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBlur: glassBlur ?? this.glassBlur,
    );
  }

  @override
  NodaThemeExtension lerp(covariant NodaThemeExtension? other, double t) {
    if (other == null) return this;
    return NodaThemeExtension(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      brandGradient: LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      iconActive: Color.lerp(iconActive, other.iconActive, t)!,
      iconInactive: Color.lerp(iconInactive, other.iconInactive, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t)!,
    );
  }
}

double? lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}
