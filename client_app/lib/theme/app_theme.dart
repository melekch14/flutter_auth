import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0E1118);
  static const surface = Color(0xFF161B25);
  static const surfaceElevated = Color(0xFF1E2432);
  static const fieldFill = Color(0xFF111621);
  static const accent = Color(0xFF2EE59D);
  static const accentSoft = Color(0xFF68F0BA);
  static const textPrimary = Color(0xFFF3F7FF);
  static const textMuted = Color(0xFF9AA4B8);
  static const stroke = Color(0xFF2A3245);
}

ThemeData buildAppTheme() {
  final colorScheme = const ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.accentSoft,
    surface: AppColors.surface,
    error: Color(0xFFFF5C5C),
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onSurface: AppColors.textPrimary,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    visualDensity: VisualDensity.compact,
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.fieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.8)),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIconColor: AppColors.textMuted,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.stroke.withOpacity(0.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF5C5C), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF5C5C), width: 1.4),
      ),
    ),
  );
}
