import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Approved final artifact's control/raised radii — 12 for controls,
  // inputs, chips and tiles; 20 for raised cards/sheets (applied per
  // component, not globally, since it depends on which plane a surface
  // sits on).
  static const double controlRadius = 12;

  static ThemeData get lightTheme {
    // Barlow carries every structural surface — labels, buttons, nav,
    // controls, metadata — per the final artifact's two-voice type system.
    // Newsreader (already wired via AppTextStyles.display) stays reserved
    // for names, counts, headlines and stories, so it is deliberately left
    // out of this default text theme.
    final barlowTextTheme = GoogleFonts.barlowTextTheme(
      const TextTheme(
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pageBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.surface,
        onPrimary: AppColors.whiteTextOnPrimary,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
      ),

      // Default Icon Style
      iconTheme: const IconThemeData(
        size: 16,
        color: AppColors.textSecondary,
      ),

      textTheme: barlowTextTheme,

      // Outlined and ElevatedButton themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.whiteTextOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          textStyle: GoogleFonts.barlow(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 13),
          textStyle: GoogleFonts.barlow(fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.red700,
          textStyle: GoogleFonts.barlow(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        labelStyle: GoogleFonts.barlow(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        hintStyle: GoogleFonts.barlow(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
