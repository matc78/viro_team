import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';

/// Bouton d'action RSVP (Présent / Absent) — fond coloré, texte blanc, ombre.
class RsvpChoiceButton extends StatelessWidget {
  const RsvpChoiceButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.height = ViroSpacing.buttonHeightMedium,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ViroSpacing.buttonRadius);

    return Material(
      color: color,
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.5),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: ViroColors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
