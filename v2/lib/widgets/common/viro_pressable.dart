import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_motion.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';

/// Enveloppe tactile : légère mise à l'échelle + ombre flottante au repos.
///
/// À utiliser pour boutons icône, tuiles, entrées de menu — pas pour les
/// [ElevatedButton] pleine largeur (déjà animés via le thème).
class ViroPressable extends StatefulWidget {
  const ViroPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.borderRadius,
    this.floating = true,
    this.minSize = ViroSpacing.minTouchTarget,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final BorderRadius? borderRadius;
  final bool floating;
  final double minSize;

  @override
  State<ViroPressable> createState() => _ViroPressableState();
}

class _ViroPressableState extends State<ViroPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ViroMotion.standard,
      reverseDuration: ViroMotion.fast,
    );
    _scale = Tween<double>(begin: 1, end: ViroMotion.pressScale).animate(
      CurvedAnimation(parent: _controller, curve: ViroMotion.enter),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.enabled) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.enabled) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.enabled) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ??
        BorderRadius.circular(ViroSpacing.buttonRadius);

    return Semantics(
      button: widget.onTap != null,
      enabled: widget.enabled,
      child: GestureDetector(
        onTapDown: widget.enabled ? _onTapDown : null,
        onTapUp: widget.enabled ? _onTapUp : null,
        onTapCancel: widget.enabled ? _onTapCancel : null,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: AnimatedContainer(
                duration: ViroMotion.standard,
                curve: ViroMotion.enter,
                constraints: BoxConstraints(
                  minWidth: widget.minSize,
                  minHeight: widget.minSize,
                ),
                decoration: widget.floating
                    ? BoxDecoration(
                        borderRadius: radius,
                        boxShadow: ViroMotion.floatingShadow(
                          opacity: _controller.value > 0 ? 0.05 : 0.08,
                        ),
                      )
                    : null,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
