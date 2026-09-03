import 'package:flutter/material.dart';
import 'plantfollow_colors.dart';

class PlantFollowSpacing {
  PlantFollowSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  static const double screen = 20;
  static const double card = 16;
  static const double section = 24;
}

class PlantFollowRadius {
  PlantFollowRadius._();

  static const double control = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;

  static BorderRadius get controlAll => BorderRadius.circular(control);
  static BorderRadius get cardAll => BorderRadius.circular(card);
  static BorderRadius get sheetTop =>
      const BorderRadius.vertical(top: Radius.circular(sheet));
}

class PlantFollowShadows {
  PlantFollowShadows._();

  static List<BoxShadow> get none => const [];

  static List<BoxShadow> get sheet => [
        BoxShadow(
          color: PlantFollowColors.textPrimary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, -4),
        ),
      ];

  static List<BoxShadow> get camera => [
        BoxShadow(
          color: PlantFollowColors.primary.withValues(alpha: 0.18),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}
