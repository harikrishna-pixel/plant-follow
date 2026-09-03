import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'plantfollow_colors.dart';
import 'plantfollow_metrics.dart';
import 'plantfollow_typography.dart';

class PlantFollowTheme {
  PlantFollowTheme._();

  static ThemeData get light {
    final textTheme = GoogleFonts.poppinsTextTheme().apply(
      bodyColor: PlantFollowColors.textPrimary,
      displayColor: PlantFollowColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: PlantFollowColors.background,
      colorScheme: const ColorScheme.light(
        primary: PlantFollowColors.primaryAction,
        onPrimary: Colors.white,
        secondary: PlantFollowColors.primary,
        onSecondary: Colors.white,
        surface: PlantFollowColors.surface,
        onSurface: PlantFollowColors.textPrimary,
        error: PlantFollowColors.danger,
        outline: PlantFollowColors.border,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: PlantFollowColors.surface,
        foregroundColor: PlantFollowColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: PlantFollowTypography.sectionTitle(),
        iconTheme: const IconThemeData(color: PlantFollowColors.textPrimary),
      ),
      dividerColor: PlantFollowColors.border,
      cardTheme: CardThemeData(
        color: PlantFollowColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: PlantFollowRadius.cardAll,
          side: const BorderSide(color: PlantFollowColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PlantFollowColors.primaryAction,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 48),
          textStyle: PlantFollowTypography.button(),
          shape: RoundedRectangleBorder(borderRadius: PlantFollowRadius.controlAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PlantFollowColors.primary,
          side: const BorderSide(color: PlantFollowColors.border),
          minimumSize: const Size(44, 48),
          textStyle: PlantFollowTypography.button(
            color: PlantFollowColors.textPrimary,
          ),
          shape: RoundedRectangleBorder(borderRadius: PlantFollowRadius.controlAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PlantFollowColors.primary,
          textStyle: PlantFollowTypography.button(
            color: PlantFollowColors.primary,
          ),
          minimumSize: const Size(44, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PlantFollowColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PlantFollowSpacing.md,
          vertical: PlantFollowSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: PlantFollowRadius.controlAll,
          borderSide: const BorderSide(color: PlantFollowColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PlantFollowRadius.controlAll,
          borderSide: const BorderSide(color: PlantFollowColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PlantFollowRadius.controlAll,
          borderSide: const BorderSide(color: PlantFollowColors.primaryAction, width: 1.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PlantFollowColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PlantFollowColors.textPrimary,
        contentTextStyle: PlantFollowTypography.secondary(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: PlantFollowRadius.controlAll),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PlantFollowColors.primaryAction,
      ),
    );
  }
}
