import 'package:flutter/material.dart';

import '../../../theme/viro_theme.dart';

/// Bouton flottant "Accueil" réutilisable dans les pages cotisations.
class FeeHomeFab extends StatelessWidget {
  const FeeHomeFab({super.key});

  static void goHome(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: null,
      tooltip: 'Accueil',
      onPressed: () => goHome(context),
      backgroundColor: ViroColors.primary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.home_rounded),
    );
  }
}
