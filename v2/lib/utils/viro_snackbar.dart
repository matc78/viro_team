import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/project_config.dart';

/// Affiche un SnackBar avec la durée globale [ProjectConfig.snackBarDuration].
abstract final class ViroSnackBar {
  static void show(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: ProjectConfig.snackBarDuration,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }
}
