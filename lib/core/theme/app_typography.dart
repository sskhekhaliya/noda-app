import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography presets using Montserrat for headings and Inter for body text.
class AppTypography {
  AppTypography._();

  // ──────────────────────────────────────────
  // Heading Styles (Montserrat — matches logo geometry)
  // ──────────────────────────────────────────

  static TextStyle headingLarge({Color? color}) => GoogleFonts.manrope(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: color,
  );

  static TextStyle headingMedium({Color? color}) => GoogleFonts.manrope(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: color,
  );

  static TextStyle headingSmall({Color? color}) => GoogleFonts.manrope(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: color,
  );

  static TextStyle subtitle({Color? color}) => GoogleFonts.manrope(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: color,
  );

  // ──────────────────────────────────────────
  // Body Styles (Manrope — optimized for reading)
  // ──────────────────────────────────────────

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: color,
  );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color,
  );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: color,
  );

  // ──────────────────────────────────────────
  // Utility Styles
  // ──────────────────────────────────────────

  static TextStyle breadcrumb({Color? color}) => GoogleFonts.manrope(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: color ?? AppColors.lightTextSecondary,
  );

  static TextStyle chipLabel({Color? color}) => GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: color,
  );

  static TextStyle buttonText({Color? color}) => GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: color ?? Colors.white,
  );

  static TextStyle caption({Color? color}) => GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.lightTextSecondary,
  );

  static TextStyle noteTitle({Color? color}) => GoogleFonts.manrope(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.3,
    color: color,
  );
}

