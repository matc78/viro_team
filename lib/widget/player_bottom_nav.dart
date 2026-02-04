import 'package:flutter/material.dart';

import '../theme/viro_theme.dart';
import '../pages/player_pages/player_home_page.dart';
import '../pages/player_pages/player_planning_page.dart';
import '../pages/player_pages/player_infos_page.dart';
import '../pages/player_pages/player_loan_catalog_page.dart';

/// Barre de navigation du player : Accueil, Planning, Infos, Catalogue prêt.
/// Utilisée sur les pages d'accueil, planning, infos et catalogue prêt.
Widget playerBottomNav(
  BuildContext context, {
  required int currentIndex,
  required String clubId,
}) {
  return BottomNavigationBar(
    elevation: 0,
    backgroundColor: ViroColors.background,
    selectedItemColor: ViroColors.primary,
    unselectedItemColor: Colors.grey,
    type: BottomNavigationBarType.fixed,
    currentIndex: currentIndex,
    onTap: (index) {
      if (index == currentIndex) return;
      if (index == 0) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PlayerHomePage()),
          (route) => false,
        );
      }
      if (index == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerPlanningPage(clubId: clubId)),
        );
      }
      if (index == 2) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerInfosPage(clubId: clubId)),
        );
      }
      if (index == 3) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerLoanCatalogPage(clubId: clubId),
          ),
        );
      }
    },
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Accueil"),
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month),
        label: "Planning",
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.notifications_none),
        label: "Infos",
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined),
        label: "Catalogue prêt",
      ),
    ],
  );
}
