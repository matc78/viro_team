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
    final clubIds = profiles.map((p) => p.clubId).where((id) => id.isNotEmpty).toSet();
    
    final Map<String, String> names = {};
    for (final clubId in clubIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .get();
        if (doc.exists) {
          names[clubId] = doc.data()?['name'] as String? ?? clubId;
        }
      } catch (e) {
        names[clubId] = clubId;
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

    return AlertDialog(
      title: const Text('Changer de profil'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isSwitching
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                shrinkWrap: true,
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final isCurrent = profile.role == currentRole &&
                      profile.clubId == currentClubId;

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
                        _getRoleDisplayName(profile.role),
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(_getClubName(profile.clubId)),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: isCurrent
                          ? null
                          : () => _switchProfile(profile.role, profile.clubId),
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
