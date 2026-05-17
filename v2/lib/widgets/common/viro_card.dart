import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_motion.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/widgets/common/viro_pressable.dart';

/// Carte flottante réutilisable (événements, stats, listes).
class ViroCard extends StatelessWidget {
  const ViroCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.accentColor,
    this.elevated = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ViroSpacing.cardRadius);
    final content = Container(
      margin: margin ?? const EdgeInsets.only(bottom: ViroSpacing.md),
      decoration: BoxDecoration(
        color: ViroColors.surfaceCard,
        borderRadius: radius,
        border: Border.all(
          color: ViroColors.primary100.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: ViroMotion.cardShadow(elevated: elevated),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentColor != null)
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor!,
                      accentColor!.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: padding ??
                  const EdgeInsets.all(ViroSpacing.cardPadding),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap == null && onLongPress == null) return content;

    return ViroPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      floating: elevated,
      borderRadius: radius,
      child: content,
    );
  }
}

/// Mini carte stats (grille 2×2 sur les homes).
class ViroStatsCard extends StatelessWidget {
  const ViroStatsCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ViroCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: ViroSpacing.md,
        vertical: ViroSpacing.sm + 2,
      ),
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: ViroColors.gray600,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ViroSpacing.xs),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: ViroColors.primary800,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: ViroColors.gray600,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
