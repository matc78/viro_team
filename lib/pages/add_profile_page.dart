import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../theme/viro_theme.dart';
import '../widget/viro_loader.dart';
import '../widget/club_search_widget.dart';
import '../widget/pending_requests_widget.dart';
import '../utils/app_logger.dart';
import '../utils/firebase_helpers.dart';
import '../utils/firebase_error_handler.dart';
import 'admin_coach_pages/create_club_page.dart';

/// Page pour ajouter un nouveau profil (pour utilisateurs qui en ont déjà)
/// Affiche les profils existants et permet d'ajouter un nouveau profil
class AddProfilePage extends StatefulWidget {
  const AddProfilePage({super.key});

  @override
  State<AddProfilePage> createState() => _AddProfilePageState();
}

class _AddProfilePageState extends State<AddProfilePage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isUpdating = false;
  String? _selectedRole; // 'player' ou 'coach'
  String? _selectedClubId;
  String? _selectedClubName;
  String? _sportFilter;

  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Envoie la demande d'adhésion à Firestore
  Future<void> _sendJoinRequest() async {
    if (_selectedClubId == null || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner un club et un rôle"),
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(FirebaseCollections.users)
          .doc(_uid)
          .get();
      final userData = userDoc.data() ?? {};
      final firstName = userData['firstName'];
      final lastName = userData['lastName'];

      // Vérifier si l'utilisateur a déjà ce rôle dans ce club
      final currentRole = getUserRoleInClub(userData, _selectedClubId!);
      if (currentRole == _selectedRole) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Vous avez déjà ce rôle dans ce club."),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isUpdating = false);
        }
        return;
      }

      final requestsRef = FirebaseFirestore.instance.collection(
        'join_requests',
      );

      // Vérifier s'il existe déjà une demande en attente pour ce club/rôle
      final existing = await requestsRef
          .where('userId', isEqualTo: _uid)
          .where('clubId', isEqualTo: _selectedClubId)
          .where('roleRequested', isEqualTo: _selectedRole)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      final requestData = {
        'userId': _uid,
        'clubId': _selectedClubId,
        'clubName': _selectedClubName,
        'roleRequested': _selectedRole,
        'message': _messageController.text.trim(),
        'status': 'pending',
        'firstName': firstName,
        'lastName': lastName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String? requestId;
      if (existing.docs.isNotEmpty) {
        // Mettre à jour la demande existante
        final oldData = existing.docs.first.data();
        final String oldMessage = oldData['message'] ?? "";
        final String newMessage = _messageController.text.trim();
        final String combinedMessage = oldMessage.isEmpty
            ? newMessage
            : "$oldMessage\n\n[Relance] : $newMessage";

        requestId = existing.docs.first.id;
        await existing.docs.first.reference.update({
          ...requestData,
          'message': combinedMessage,
        });
        AppLogger.instance.info(
          'Demande de profil relancée',
          {
            'requestId': requestId,
            'userId': _uid,
            'clubId': _selectedClubId,
            'roleRequested': _selectedRole,
          },
        );
      } else {
        // Créer une nouvelle demande
        final ref = await requestsRef.add(requestData);
        requestId = ref.id;
        AppLogger.instance.info(
          'Demande de profil créée',
          {
            'requestId': requestId,
            'userId': _uid,
            'clubId': _selectedClubId,
            'clubName': _selectedClubName,
            'roleRequested': _selectedRole,
          },
        );
      }

      // Marquer la demande en attente
      await FirebaseFirestore.instance.collection(FirebaseCollections.users).doc(_uid).set({
        'hasPendingRequest': true,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Demande envoyée avec succès !")),
        );
        // Réinitialiser le formulaire
        setState(() {
          _selectedRole = null;
          _selectedClubId = null;
          _selectedClubName = null;
          _messageController.clear();
        });
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors de la création de la demande de profil',
        error: e,
        context: {
          'userId': _uid,
          'clubId': _selectedClubId,
          'roleRequested': _selectedRole,
        },
      );
      if (mounted) {
        FirebaseErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Récupère les clubIds à exclure pour le rôle demandé.
  /// On n'exclut que les clubs où l'utilisateur a DÉJÀ ce rôle,
  /// pour permettre d'être coach ET joueur dans le même club.
  List<String> _getExcludedClubIds(
    Map<String, dynamic> userData, {
    String? role,
  }) {
    final List<String> excluded = [];
    final roles = userData['roles'] as Map<String, dynamic>? ?? {};

    // Ne exclure que les clubs pour le rôle sélectionné
    if (role == 'player') {
      if (roles['player'] is Map) {
        final playerData = roles['player'] as Map;
        if (playerData['clubs'] is List) {
          final clubs = (playerData['clubs'] as List).whereType<Map>();
          excluded.addAll(
            clubs
                .map((c) => c['clubId'] as String? ?? '')
                .where((id) => id.isNotEmpty),
          );
        }
      }
      return excluded;
    }

    if (role == 'coach') {
      if (roles['coach'] is List) {
        final coaches = (roles['coach'] as List).whereType<Map>();
        excluded.addAll(
          coaches
              .map((c) => c['clubId'] as String? ?? '')
              .where((id) => id.isNotEmpty),
        );
      }
      return excluded;
    }

    if (role == 'admin') {
      if (roles['admin'] is List) {
        excluded.addAll((roles['admin'] as List).whereType<String>());
      }
      return excluded;
    }

    // Pas de rôle sélectionné : exclure tous les clubs (comportement par défaut)
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      if (playerData['clubs'] is List) {
        final clubs = (playerData['clubs'] as List).whereType<Map>();
        excluded.addAll(
          clubs
              .map((c) => c['clubId'] as String? ?? '')
              .where((id) => id.isNotEmpty),
        );
      }
    }
    if (roles['coach'] is List) {
      final coaches = (roles['coach'] as List).whereType<Map>();
      excluded.addAll(
        coaches
            .map((c) => c['clubId'] as String? ?? '')
            .where((id) => id.isNotEmpty),
      );
    }
    if (roles['admin'] is List) {
      excluded.addAll((roles['admin'] as List).whereType<String>());
    }
    return excluded;
  }

  @override
  Widget build(BuildContext context) {
    if (_isUpdating) return const Scaffold(body: ViroLoader(size: 80));

    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(title: const Text("Ajouter un profil"), elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirebaseCollections.users)
            .doc(_uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader());
          }

          if (userSnapshot.hasError) {
            return FirebaseErrorHandler.buildErrorWidget(
              context,
              userSnapshot.error,
              onRetry: () {
                // Le StreamBuilder se reconnectera automatiquement
                setState(() {});
              },
            );
          }

          if (!userSnapshot.hasData) {
            return const Center(child: ViroLoader());
          }

          final userData =
              (userSnapshot.data!.data() as Map<String, dynamic>?) ??
              <String, dynamic>{};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section : Demandes en attente
                PendingRequestsWidget(userId: _uid),
                if (userSnapshot.hasData) const SizedBox(height: 30),

                // Section : Nouvelle activité
                const Text(
                  "NOUVELLE ACTIVITÉ",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 15),

                // OPTION : CRÉER UN CLUB
                _roleCard(
                  title: "Créer un Club",
                  subtitle: "Devenir administrateur fondateur",
                  icon: Icons.add_business_outlined,
                  roleValue: 'admin',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateClubPage()),
                  ),
                ),

                // OPTION : REJOINDRE COACH
                _roleOptionWithForm(
                  title: "Je suis un Coach",
                  subtitle: "Postuler dans un club",
                  icon: Icons.psychology_outlined,
                  roleValue: 'coach',
                  userData: userData,
                ),

                // OPTION : REJOINDRE LICENCIÉ
                _roleOptionWithForm(
                  title: "Je suis un Joueur",
                  subtitle: "Rejoindre un nouveau club",
                  icon: Icons.sports_soccer_rounded,
                  roleValue: 'player',
                  userData: userData,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Le formulaire qui apparaît sous l'option sélectionnée
  Widget _buildJoinForm({required List<String> excludedClubIds}) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ViroColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClubSearchWidget(
            selectedClubId: _selectedClubId,
            selectedClubName: _selectedClubName,
            onClubSelected: (clubId, clubName) {
              setState(() {
                _selectedClubId = clubId;
                _selectedClubName = clubName;
              });
            },
            sportFilter: _sportFilter,
            onSportFilterChanged: (filter) {
              setState(() {
                _sportFilter = filter;
                _selectedClubId = null;
                _selectedClubName = null;
              });
            },
            excludedClubIds: excludedClubIds,
          ),

          const SizedBox(height: 20),
          const Text(
            "Message pour l'administrateur",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Ex: Bonjour, je souhaite rejoindre l'équipe Sénior...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sendJoinRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: ViroColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "POSTULER",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleOptionWithForm({
    required String title,
    required String subtitle,
    required IconData icon,
    required String roleValue,
    required Map<String, dynamic> userData,
  }) {
    final bool isSelected = _selectedRole == roleValue;
    final excludedClubIds = _getExcludedClubIds(userData, role: roleValue);
    return Column(
      children: [
        _roleCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          roleValue: roleValue,
          onTap: () => setState(() {
            _selectedRole = roleValue;
            _selectedClubId = null;
            _selectedClubName = null;
            _messageController.clear();
          }),
        ),
        if (isSelected) _buildJoinForm(excludedClubIds: excludedClubIds),
      ],
    );
  }

  Widget _roleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String roleValue,
    required VoidCallback onTap,
  }) {
    bool isSelected = _selectedRole == roleValue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? ViroColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? ViroColors.primary : ViroColors.borderColor,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Icon(
            icon,
            color: isSelected ? ViroColors.primary : Colors.grey,
            size: 32,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? ViroColors.primary : Colors.black,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: ViroColors.primary)
              : const Icon(Icons.add_circle_outline),
        ),
      ),
    );
  }
}
