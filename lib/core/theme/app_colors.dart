import 'package:flutter/material.dart';

/// Brand palette (dark cinema theme).
abstract class AppColors {
  AppColors._();

  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceHigh = Color(0xFF262626);
  static const Color border = Color(0xFF3A3A3A);
  static const Color primary = Color(0xFFE31B23);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF7A7A7A);
  static const Color pillLight = Color(0xFFEDEDED);
}

/// Spacing and radii.
abstract class AppDimens {
  AppDimens._();

  static const double gutter = 20;
  static const double controlHeight = 52;
  static const double buttonHeight = controlHeight;
  static const double radiusCard = 28;
  static const double radiusControl = 8;
  static const double radiusSheet = 28;
}
