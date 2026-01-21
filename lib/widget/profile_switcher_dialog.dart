import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/user_session.dart';
import '../theme/viro_theme.dart';
import '../pages/player_pages/player_home_page.dart';
import '../pages/admin_coach_pages/admin_home_page.dart';

/// Dialog pour changer de profil/contexte
class ProfileSwitcherDialog extends StatefulWidget {
  const ProfileSwitcherDialog({super.key});

  @override
  State<ProfileSwitcherDialog> createState() => _ProfileSwitcherDialogState();
}

class _ProfileSwitcherDialogState extends State<ProfileSwitcherDialog> {
  final UserSession _session = UserSession();
  bool _isSwitching = false;
  Map<String, String> _clubNamesCache = {};

  @override
  void initState() {
    super.initState();
    _loadClubNames();
  }

  Future<void> _loadClubNames() async {
    final profiles = _session.getAvailableProfiles();
    final clubIds = profiles
        .map((p) => p.clubId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (clubIds.isEmpty) return;

    final Map<String, String> names = {};
    
    // Charger par batch de 10 (limite Firestore whereIn)
    for (var i = 0; i < clubIds.length; i += 10) {
      final batch = clubIds.sublist(
        i,
        i + 10 > clubIds.length ? clubIds.length : i + 10,
      );
      
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('clubs')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        for (var doc in snapshot.docs) {
          names[doc.id] = doc.data()['name'] as String? ?? doc.id;
        }
      } catch (e) {
        // En cas d'erreur, utiliser l'ID comme nom
        for (var clubId in batch) {
          names[clubId] = clubId;
        }
      }
    }

    if (mounted) {
      setState(() {
        _clubNamesCache = names;
      });
    }
  }

  String _getClubName(String clubId) {
    return _clubNamesCache[clubId] ?? clubId;
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'player':
        return 'Joueur';
      case 'coach':
        return 'Coach';
      case 'admin':
        return 'Administrateur';
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'player':
        return Icons.sports_soccer;
      case 'coach':
        return Icons.psychology;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  Future<void> _switchProfile(String role, String clubId) async {
    setState(() => _isSwitching = true);

    final success = await _session.switchContext(role, clubId);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();

      // Rediriger vers la bonne page selon le nouveau rôle
      if (role == 'player') {
        // Rediriger vers PlayerHomePage
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PlayerHomePage()),
          (route) => false,
        );
      } else if (role == 'admin' || role == 'coach') {
        // Rediriger vers AdminHomePage
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
          (route) => false,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil changé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _isSwitching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors du changement de profil'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _session.getAvailableProfiles();
    final currentRole = _session.currentRole;
    final currentClubId = _session.currentClubId;

    if (profiles.isEmpty) {
      return AlertDialog(
        title: const Text('Aucun profil disponible'),
        content: const Text('Vous n\'avez pas encore de profil configuré.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    // Regrouper les profils player
    final playerProfiles = profiles.where((p) => p.role == 'player').toList();
    final otherProfiles = profiles.where((p) => p.role != 'player').toList();

    // Créer une liste de profils groupés
    final List<_GroupedProfile> groupedProfiles = [];

    // Ajouter le profil player groupé s'il y en a
    if (playerProfiles.isNotEmpty) {
      final isCurrentPlayer = currentRole == 'player';
      groupedProfiles.add(
        _GroupedProfile(
          role: 'player',
          displayName: playerProfiles.length > 1 ? 'Joueur' : 'Joueur',
          clubCount: playerProfiles.length,
          profiles: playerProfiles,
          isCurrent: isCurrentPlayer,
          currentClubId: currentClubId,
        ),
      );
    }

    // Ajouter les autres profils (coach, admin)
    for (final profile in otherProfiles) {
      final isCurrent =
          profile.role == currentRole && profile.clubId == currentClubId;
      groupedProfiles.add(
        _GroupedProfile(
          role: profile.role,
          displayName: _getRoleDisplayName(profile.role),
          clubCount: 1,
          profiles: [profile],
          isCurrent: isCurrent,
          currentClubId: currentClubId,
        ),
      );
    }

    return AlertDialog(
      title: const Text('Changer de profil'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isSwitching
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                shrinkWrap: true,
                itemCount: groupedProfiles.length,
                itemBuilder: (context, index) {
                  final grouped = groupedProfiles[index];

                  // Pour les players, utiliser le premier club disponible (ou le club actuel si déjà en mode player)
                  // car toutes les données sont mélangées dans les pages player
                  String targetClubId;
                  if (grouped.role == 'player') {
                    // Si déjà en mode player, garder le club actuel, sinon prendre le premier
                    if (grouped.isCurrent && currentClubId != null) {
                      targetClubId = currentClubId;
                    } else {
                      targetClubId = grouped.profiles.first.clubId;
                    }
                  } else {
                    targetClubId = grouped.profiles.first.clubId;
                  }

                  final profile = grouped.profiles.first;
                  final isCurrent = grouped.isCurrent;
                  
                  // Pour les players avec plusieurs clubs, afficher le nombre de clubs
                  String subtitle;
                  if (grouped.role == 'player' && grouped.clubCount > 1) {
                    subtitle = '${grouped.clubCount} clubs';
                  } else {
                    subtitle = _getClubName(targetClubId);
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isCurrent
                        ? ViroColors.primary.withOpacity(0.1)
                        : Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent
                            ? ViroColors.primary
                            : Colors.grey.shade300,
                        child: Icon(
                          _getRoleIcon(profile.role),
                          color: isCurrent ? Colors.white : Colors.grey,
                        ),
                      ),
                      title: Text(
                        grouped.displayName,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(subtitle),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: isCurrent
                          ? null
                          : () => _switchProfile(profile.role, targetClubId),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSwitching ? null : () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

/// Classe helper pour regrouper les profils
class _GroupedProfile {
  final String role;
  final String displayName;
  final int clubCount;
  final List<ProfileOption> profiles;
  final bool isCurrent;
  final String? currentClubId;

  _GroupedProfile({
    required this.role,
    required this.displayName,
    required this.clubCount,
    required this.profiles,
    required this.isCurrent,
    this.currentClubId,
  });
}
