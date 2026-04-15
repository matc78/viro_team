import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'safe_navigation.dart';
import '../pages/admin_coach_pages/admin_shell.dart';
import '../pages/player_pages/player_shell.dart';
import '../services/user_session.dart';

String roleDisplayName(String role) {
  switch (role) {
    case 'player':
      return 'Joueur';
    case 'coach':
      return 'Coach';
    case 'admin':
      return 'Administrateur';
    case 'admin_fondateur':
      return 'Administrateur fondateur';
    default:
      return role;
  }
}

IconData roleIcon(String role) {
  switch (role) {
    case 'player':
      return Icons.sports_soccer;
    case 'coach':
      return Icons.psychology;
    case 'admin':
    case 'admin_fondateur':
      return Icons.admin_panel_settings;
    default:
      return Icons.person;
  }
}

bool usesPlayerShell(String role) => role == 'player';

ProfileSummary? preferredProfileSummary(Iterable<ProfileSummary> summaries) {
  ProfileSummary? firstWhereRole(String role) {
    for (final summary in summaries) {
      if (summary.role == role && summary.clubId.isNotEmpty) return summary;
    }
    return null;
  }

  return firstWhereRole('admin_fondateur') ??
      firstWhereRole('admin') ??
      firstWhereRole('coach') ??
      firstWhereRole('player');
}

Map<String, String>? preferredActiveContextFromSummaries(
  Iterable<ProfileSummary> summaries,
) {
  final preferred = preferredProfileSummary(summaries);
  if (preferred == null) return null;
  return {
    'role': preferred.role,
    'clubId': preferred.clubId,
  };
}

/// Rôle admin/coach pour un club (priorité fondateur > admin > coach), ex. ouverture depuis une notif.
String? adminSideRoleForClub(UserProfile user, String clubId) {
  if (clubId.isEmpty) return null;
  if (user.hasRoleInClub('admin_fondateur', clubId)) return 'admin_fondateur';
  if (user.hasRoleInClub('admin', clubId)) return 'admin';
  if (user.hasRoleInClub('coach', clubId)) return 'coach';
  return null;
}

Future<bool> switchProfileAndNavigate({
  required BuildContext context,
  required UserSession session,
  required String role,
  required String clubId,
  required VoidCallback closeCurrentSurface,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final success = await session.switchContext(role, clubId);
  if (!context.mounted) return false;

  if (!success) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Erreur lors du changement de profil'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }

  closeCurrentSurface();
  scheduleDeferredNavigation(() {
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => usesPlayerShell(role)
            ? const PlayerShell()
            : const AdminShell(),
      ),
      (route) => false,
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Profil changé avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  });
  return true;
}
