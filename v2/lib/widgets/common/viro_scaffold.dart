import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';

/// Scaffold avec fond en dégradé et halos discrets (pas de bleu opaque).
class ViroScaffold extends StatelessWidget {
  const ViroScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.scaffoldHighlight,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: ViroColors.scaffoldGradient)),
          Positioned(
            top: -80,
            right: -60,
            child: _AmbientOrb(
              diameter: 220,
              color: ViroColors.primary100.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: _AmbientOrb(
              diameter: 160,
              color: ViroColors.primary50.withValues(alpha: 0.5),
            ),
          ),
          body,
        ],
      ),
    );
  }
}

/// AppBar légère — fond dégradé clair, texte bleu foncé.
class ViroAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ViroAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.onTitleTap,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;

  /// Tap sur le titre (ex. « ViroTeam » → retour à la home globale).
  final VoidCallback? onTitleTap;

  @override
  Size get preferredSize => const Size.fromHeight(ViroSpacing.topBarHeight);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: ViroColors.scaffoldHighlight,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ViroColors.primary800,
      leading: leading,
      actions: actions,
      title: title == null
          ? null
          : onTitleTap == null
              ? title
              : InkWell(
                  onTap: onTitleTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: DefaultTextStyle(
                      style: textTheme.titleMedium!.copyWith(
                        color: ViroColors.primary800,
                      ),
                      child: title!,
                    ),
                  ),
                ),
      titleTextStyle: textTheme.titleMedium?.copyWith(color: ViroColors.primary800),
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ViroColors.headerGradient,
          border: Border(
            bottom: BorderSide(
              color: ViroColors.primary200.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
