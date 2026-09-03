import 'package:flutter/material.dart';

import '../../../navigation/v1_nav.dart';
import '../../../services/today_priority.dart';
import '../../../theme/plantfollow_colors.dart';
import '../../../theme/plantfollow_metrics.dart';
import '../../../theme/plantfollow_typography.dart';
import '../../../widgets/pf_components.dart';

class TodayFeed extends StatelessWidget {
  final List<TodayAction> actions;
  final ValueChanged<TodayAction> onPrimaryAction;
  final ValueChanged<TodayAction>? onSecondaryAction;

  const TodayFeed({
    super.key,
    required this.actions,
    required this.onPrimaryAction,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return TodayEmptyState(
        onViewPlants: () => V1Nav.onSelectTab?.call(V1Nav.plantsIndex),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          TodayActionCard(
            action: actions[i],
            onPressed: () => onPrimaryAction(actions[i]),
            onSecondaryPressed: onSecondaryAction == null
                ? null
                : () => onSecondaryAction!(actions[i]),
          ),
          if (i < actions.length - 1)
            const SizedBox(height: PlantFollowSpacing.sm),
        ],
      ],
    );
  }
}

class TodayEmptyState extends StatelessWidget {
  final VoidCallback? onViewPlants;

  const TodayEmptyState({super.key, this.onViewPlants});

  @override
  Widget build(BuildContext context) {
    return PfEmptyState(
      icon: Icons.check_circle_outline_rounded,
      title: TodayPriorityResult.emptyTitle,
      subtitle: TodayPriorityResult.emptySubtitle,
      actionLabel: onViewPlants == null ? null : 'View plants',
      onAction: onViewPlants,
    );
  }
}

class TodayActionCard extends StatelessWidget {
  final TodayAction action;
  final VoidCallback onPressed;
  final VoidCallback? onSecondaryPressed;

  const TodayActionCard({
    super.key,
    required this.action,
    required this.onPressed,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dominant = action.dominant;
    final hasSecondary = (action.secondaryCtaLabel ?? '').isNotEmpty;
    final accent = action.overdue
        ? PlantFollowColors.attention
        : PlantFollowColors.primary;
    return Semantics(
      button: !hasSecondary,
      label: hasSecondary
          ? '${action.title}. ${action.subtitle}. ${action.ctaLabel}. ${action.secondaryCtaLabel}.'
          : '${action.title}. ${action.ctaLabel}',
      child: PfCard(
        borderColor: accent.withValues(alpha: dominant ? 0.45 : 0.18),
        padding: const EdgeInsets.all(PlantFollowSpacing.md),
        onTap: hasSecondary ? null : onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _kindLabel(action.kind),
              style: PlantFollowTypography.micro(
                color: accent,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: PlantFollowSpacing.xs),
            Text(action.title, style: PlantFollowTypography.cardTitle()),
            const SizedBox(height: 4),
            Text(action.subtitle, style: PlantFollowTypography.secondary()),
            const SizedBox(height: PlantFollowSpacing.sm),
            if (hasSecondary)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondaryPressed,
                      child: Text(action.secondaryCtaLabel!),
                    ),
                  ),
                  const SizedBox(width: PlantFollowSpacing.xs),
                  Expanded(
                    child: FilledButton(
                      onPressed: onPressed,
                      child: Text(action.ctaLabel),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Text(
                    action.ctaLabel,
                    style: PlantFollowTypography.button(
                      color: PlantFollowColors.primary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: PlantFollowColors.inactive,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _kindLabel(TodayActionKind kind) {
    switch (kind) {
      case TodayActionKind.weather:
        return 'Weather';
      case TodayActionKind.recovery:
        return 'Recovery check-in';
      case TodayActionKind.care:
        return 'Care';
      case TodayActionKind.milestone:
        return 'Update';
      case TodayActionKind.grow:
        return 'Grow';
    }
  }
}
