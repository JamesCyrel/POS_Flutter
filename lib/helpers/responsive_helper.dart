import 'package:flutter/material.dart';

/// Responsive Helper
/// Provides utilities for responsive design
class ResponsiveHelper {
  /// Check if device is a tablet (width >= 600)
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  /// Check if device is a phone (width < 600)
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Get responsive font size
  static double getFontSize(BuildContext context, {
    required double tabletSize,
    required double phoneSize,
  }) {
    return isTablet(context) ? tabletSize : phoneSize;
  }

  /// Get responsive padding
  static EdgeInsets getPadding(BuildContext context, {
    required EdgeInsets tabletPadding,
    required EdgeInsets phonePadding,
  }) {
    return isTablet(context) ? tabletPadding : phonePadding;
  }

  /// Get responsive grid cross axis count
  static int getGridCrossAxisCount(BuildContext context, {
    required int tabletCount,
    required int phoneCount,
  }) {
    return isTablet(context) ? tabletCount : phoneCount;
  }
}

