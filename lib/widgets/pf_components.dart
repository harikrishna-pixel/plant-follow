import 'package:flutter/material.dart';
import '../theme/plantfollow_colors.dart';
import '../theme/plantfollow_metrics.dart';
import '../theme/plantfollow_typography.dart';

class PfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const PfCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(PlantFollowSpacing.card),
      decoration: BoxDecoration(
        color: PlantFollowColors.surface,
        borderRadius: PlantFollowRadius.cardAll,
        border: Border.all(color: borderColor ?? PlantFollowColors.border),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: PlantFollowRadius.cardAll,
        child: content,
      ),
    );
  }
}

class PfEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return PfCard(
      padding: const EdgeInsets.symmetric(
        horizontal: PlantFollowSpacing.xl,
        vertical: PlantFollowSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: PlantFollowColors.primary),
          const SizedBox(height: PlantFollowSpacing.sm),
          Text(title, textAlign: TextAlign.center, style: PlantFollowTypography.cardTitle()),
          const SizedBox(height: PlantFollowSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: PlantFollowTypography.secondary(),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: PlantFollowSpacing.sm),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class PfPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  const PfPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(onPressed: onPressed, child: Text(label));
    if (!expand) return button;
    return SizedBox(width: double.infinity, height: 48, child: button);
  }
}

class PfSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  const PfSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(onPressed: onPressed, child: Text(label));
    if (!expand) return button;
    return SizedBox(width: double.infinity, height: 48, child: button);
  }
}

class PfSectionLabel extends StatelessWidget {
  final String text;
  const PfSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: PlantFollowTypography.cardTitle());
  }
}

class PfPlantRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? meta;
  final VoidCallback? onTap;

  const PfPlantRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.meta,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PfCard(
      onTap: onTap,
      padding: const EdgeInsets.all(PlantFollowSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PlantFollowRadius.control),
            child: SizedBox(width: 56, height: 56, child: leading),
          ),
          const SizedBox(width: PlantFollowSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PlantFollowTypography.cardTitle(),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlantFollowTypography.scientific(),
                  ),
                if (meta != null && meta!.trim().isNotEmpty)
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlantFollowTypography.micro(),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: PlantFollowColors.inactive),
        ],
      ),
    );
  }
}

class PfLoadingBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? photo;

  const PfLoadingBlock({
    super.key,
    required this.title,
    required this.subtitle,
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PlantFollowSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (photo != null) ...[
            ClipRRect(
              borderRadius: PlantFollowRadius.cardAll,
              child: SizedBox(width: 220, height: 220, child: photo),
            ),
            const SizedBox(height: PlantFollowSpacing.xl),
          ],
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: PlantFollowSpacing.md),
          Text(title, style: PlantFollowTypography.cardTitle()),
          const SizedBox(height: PlantFollowSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: PlantFollowTypography.secondary(),
          ),
        ],
      ),
    );
  }
}
