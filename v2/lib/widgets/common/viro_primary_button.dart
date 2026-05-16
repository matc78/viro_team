import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';

class ViroPrimaryButton extends StatelessWidget {
  const ViroPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: ViroSpacing.buttonHeightLarge,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: ViroSpacing.buttonHeightLarge,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}
