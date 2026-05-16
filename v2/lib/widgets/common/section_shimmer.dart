import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';

/// Placeholder animé pendant le chargement des sections.
class SectionShimmer extends StatefulWidget {
  const SectionShimmer({super.key, this.itemCount = 2});

  final int itemCount;

  @override
  State<SectionShimmer> createState() => _SectionShimmerState();
}

class _SectionShimmerState extends State<SectionShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          children: List.generate(widget.itemCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: ViroSpacing.md),
              child: _ShimmerCard(opacity: 0.4 + (_controller.value * 0.3)),
            );
          }),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: ViroColors.gray200.withValues(alpha: opacity.clamp(0.0, 1.0)),
        borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
      ),
    );
  }
}
