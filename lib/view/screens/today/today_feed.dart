import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/today_priority.dart';

class TodayFeed extends StatelessWidget {
  final List<TodayAction> actions;
  final ValueChanged<TodayAction> onPrimaryAction;

  const TodayFeed({
    super.key,
    required this.actions,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const TodayEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          TodayActionCard(
            action: actions[i],
            onPressed: () => onPrimaryAction(actions[i]),
          ),
          if (i < actions.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class TodayEmptyState extends StatelessWidget {
  const TodayEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 40,
            color: const Color(0xFF2E7D32).withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            TodayPriorityResult.emptyTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TodayPriorityResult.emptySubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class TodayActionCard extends StatelessWidget {
  final TodayAction action;
  final VoidCallback onPressed;

  const TodayActionCard({
    super.key,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dominant = action.dominant;
    return Semantics(
      button: true,
      label: '${action.title}. ${action.ctaLabel}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(dominant ? 20 : 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: dominant
                    ? const Color(0xFF4CAF50).withOpacity(0.28)
                    : const Color(0xFF4CAF50).withOpacity(0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dominant ? 0.06 : 0.04),
                  blurRadius: dominant ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kindLabel(action.kind),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.title,
                  style: GoogleFonts.poppins(
                    fontSize: dominant ? 20 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      action.ctaLabel,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _kindLabel(TodayActionKind kind) {
    switch (kind) {
      case TodayActionKind.weather:
        return 'WEATHER';
      case TodayActionKind.recovery:
        return 'CHECK-IN';
      case TodayActionKind.care:
        return 'CARE';
      case TodayActionKind.milestone:
        return 'UPDATE';
      case TodayActionKind.grow:
        return 'GROW';
    }
  }
}
