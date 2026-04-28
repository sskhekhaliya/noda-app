import 'package:flutter/widgets.dart';

/// Responsive breakpoints for Noda's adaptive layout.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Layout mode enum for the responsive scaffold.
enum LayoutMode { mobile, tablet, desktop }

/// Extension on BuildContext for quick layout queries.
extension ResponsiveExtension on BuildContext {
  /// Get current layout mode based on screen width.
  LayoutMode get layoutMode {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= Breakpoints.desktop) return LayoutMode.desktop;
    if (width >= Breakpoints.tablet) return LayoutMode.tablet;
    return LayoutMode.mobile;
  }

  bool get isMobile => layoutMode == LayoutMode.mobile;
  bool get isTablet => layoutMode == LayoutMode.tablet;
  bool get isDesktop => layoutMode == LayoutMode.desktop;
  bool get isWideScreen => !isMobile;
}

