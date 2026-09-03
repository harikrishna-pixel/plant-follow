import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'plantfollow_colors.dart';

/// Single type family: Poppins. Dark text by default; green is for actions.
class PlantFollowTypography {
  PlantFollowTypography._();

  static TextStyle _base({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = PlantFollowColors.textPrimary,
    double height = 1.35,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      fontStyle: fontStyle,
    );
  }

  static TextStyle screenTitle({Color? color}) => _base(
        size: 28,
        weight: FontWeight.w600,
        color: color ?? PlantFollowColors.textPrimary,
        height: 1.2,
      );

  static TextStyle sectionTitle({Color? color}) => _base(
        size: 20,
        weight: FontWeight.w600,
        color: color ?? PlantFollowColors.textPrimary,
      );

  static TextStyle cardTitle({Color? color}) => _base(
        size: 16,
        weight: FontWeight.w600,
        color: color ?? PlantFollowColors.textPrimary,
      );

  static TextStyle body({Color? color}) => _base(
        size: 15,
        color: color ?? PlantFollowColors.textPrimary,
      );

  static TextStyle secondary({Color? color}) => _base(
        size: 13,
        color: color ?? PlantFollowColors.textSecondary,
        height: 1.4,
      );

  static TextStyle micro({Color? color, FontWeight weight = FontWeight.w500}) =>
      _base(
        size: 12,
        weight: weight,
        color: color ?? PlantFollowColors.textSecondary,
      );

  static TextStyle button({Color? color}) => _base(
        size: 15,
        weight: FontWeight.w600,
        color: color ?? Colors.white,
      );

  static TextStyle scientific({Color? color}) => _base(
        size: 13,
        color: color ?? PlantFollowColors.textSecondary,
        fontStyle: FontStyle.italic,
      );
}
