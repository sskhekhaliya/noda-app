import 'package:flutter/material.dart';

/// Core color palette extracted from the Noda logo and Theme.md specification.
class AppColors {
  AppColors._();

  // ──────────────────────────────────────────
  // Brand Colors (from logo gradient)
  // ──────────────────────────────────────────
  static const Color brandOcean = Color(0xFF004F56);
  static const Color brandTeal = Color(0xFF14B8A6);
  static const Color brandBlue = Color(0xFF38BDF8);

  // 135-degree brand gradient (Primary Ocean to Teal)
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF004F56), Color(0xFF14B8A6)],
  );

  // 135-degree brand immersion gradient (Primary Teal to Blue)
  static const LinearGradient brandBlueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D9488), Color(0xFF0369A1)],
  );

  // ──────────────────────────────────────────
  // Light Theme
  // ──────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF6FAFE);
  static const Color lightSurface = Color(0xFFF6FAFE);
  static const Color lightSurfaceAlt = Color(0xFFF0F4F8); // surface-container-low
  static const Color lightSurfaceCard = Color(0xFFFFFFFF); // surface-container-lowest
  static const Color lightSurfaceContainer = Color(0xFFEAEEF2); // surface-container
  static const Color lightSurfaceContainerHigh = Color(0xFFE4E9ED); // surface-container-high
  static const Color lightSurfaceContainerHighest = Color(0xFFDFE3E7); // surface-container-highest

  static const Color lightTextPrimary = Color(0xFF171C1F);
  static const Color lightTextSecondary = Color(0xFF3F494A); // on-surface-variant

  static const Color lightIconActive = Color(0xFF004F56);
  static const Color lightIconInactive = Color(0xFFBEC8CA);

  static const Color lightPrimaryAction = Color(0xFF004F56);
  static const Color lightSecondaryAction = Color(0xFF35637F);
  static const Color lightFocusRing = Color(0xFF85D3DD);
  static const Color lightDivider = Color(0xFF6F797A); // outline

  // ──────────────────────────────────────────
  // Dark Theme
  // ──────────────────────────────────────────
  static const Color darkBackground = Color(0xFF020617); // Slate 950
  static const Color darkSurface = Color(0xFF020617);
  static const Color darkSurfaceAlt = Color(0xFF1E293B); // Slate 800
  static const Color darkSurfaceCard = Color(0xFF0F172A); // Slate 900
  static const Color darkSurfaceContainer = Color(0xFF1E293B);
  static const Color darkSurfaceContainerHigh = Color(0xFF334155);
  static const Color darkSurfaceContainerHighest = Color(0xFF475569);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static const Color darkIconActive = Color(0xFF14B8A6);
  static const Color darkIconInactive = Color(0xFF475569);

  static const Color darkPrimaryAction = Color(0xFF14B8A6);
  static const Color darkSecondaryAction = Color(0xFF38BDF8);
  static const Color darkFocusRing = Color(0xFF5EEAD4);
  static const Color darkDivider = Color(0xFF475569);

  // Dark Brand Gradient (Ocean-to-Teal immersion)
  static const LinearGradient darkBrandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D9488), Color(0xFF0369A1)],
  );
}
