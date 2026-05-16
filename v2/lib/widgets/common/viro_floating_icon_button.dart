import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_motion.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/widgets/common/viro_pressable.dart';

/// Bouton icône flottant (menus, actions header, FAB secondaires).
class ViroFloatingIconButton extends StatelessWidget {
  const ViroFloatingIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ViroColors.white;
    final fg = foregroundColor ?? ViroColors.primary800;

    final button = ViroPressable(
      onTap: onPressed,
      enabled: onPressed != null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: ViroMotion.floatingShadow(opacity: 0.16, blur: 18, y: 5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: ViroIcon(icon, size: 22, color: fg),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// FAB principal — ombre prononcée, animation au appui via [ViroPressable].
class ViroFloatingActionButton extends StatelessWidget {
  const ViroFloatingActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ViroPressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: ViroColors.primary600,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? ViroSpacing.md : 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ViroColors.primary600, ViroColors.primary800],
            ),
            boxShadow: ViroMotion.floatingShadow(opacity: 0.22, blur: 20, y: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ViroIcon(icon, color: ViroColors.white, size: 24),
              if (label != null) ...[
                const SizedBox(width: ViroSpacing.sm),
                Text(
                  label!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ViroColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
