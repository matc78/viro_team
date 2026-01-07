import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/viro_theme.dart';

class ViroLoader extends StatefulWidget {
  final double size;
  const ViroLoader({super.key, this.size = 100.0});

  @override
  State<ViroLoader> createState() => _ViroLoaderState();
}

class _ViroLoaderState extends State<ViroLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Un cycle complet en 2s
    )..repeat();

    // L'ajout du CurvedAnimation permet l'effet d'accélération/décélération
    _animation = CurvedAnimation(
      parent: _controller,
      curve:
          Curves.easeInOutCubic, // Accélération au début, décélération à la fin
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _animation.value * 2 * math.pi,
              child: child,
            );
          },
          child: Image.asset(
            'assets/logo/logo_seul.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.bolt,
                color: ViroColors.primary,
                size: widget.size,
              );
            },
          ),
        ),
      ),
    );
  }
}
