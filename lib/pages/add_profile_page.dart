import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../services/join_request_service.dart';
import '../theme/viro_theme.dart';
import '../widget/viro_loader.dart';
import '../widget/club_search_widget.dart';
import '../widget/pending_requests_widget.dart';
import '../utils/firebase_helpers.dart';
import '../utils/firebase_error_handler.dart';
import 'admin_coach_pages/create_club_page.dart';

/// Page pour ajouter un nouveau profil (pour utilisateurs qui en ont déjà)
/// Affiche les profils existants et permet d'ajouter un nouveau profil
class AddProfilePage extends StatelessWidget {
  const AddProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(title: const Text("Ajouter un profil"), elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
        stream: appFirestore
            .collection(FirebaseCollections.users)
            .doc(uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting &&
              !userSnapshot.hasData) {
            return const Center(child: ViroLoader());
          }

          if (userSnapshot.hasError) {
            return FirebaseErrorHandler.buildErrorWidget(
              context,
              userSnapshot.error,
            );
          }

          final userData =
              (userSnapshot.data?.data() as Map<String, dynamic>?) ??
              <String, dynamic>{};

          return _AddProfileFormBody(uid: uid, userData: userData);
        },
      ),
    );
  }
}

/// Corps du formulaire isolé dans son propre StatefulWidget.
/// Les interactions du formulaire (sélection de rôle, de club, filtre sport)
/// ne déclenchent un rebuild que de ce widget, pas de la page entière.
class _AddProfileFormBody extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const _AddProfileFormBody({required this.uid, required this.userData});

  @override
  State<_AddProfileFormBody> createState() => _AddProfileFormBodyState();
}

class _AddProfileFormBodyState extends State<_AddProfileFormBody> {
  bool _isUpdating = false;
  String? _selectedRole;
  String? _selectedClubId;
  String? _selectedClubName;
  String? _selectedClubSport;
  String? _sportFilter;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Envoie la demande d'adhésion via [JoinRequestService]
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
      final userDoc = await appFirestore
          .collection(FirebaseCollections.users)
          .doc(widget.uid)
          .get();
      final userData = userDoc.data() ?? {};

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

      await JoinRequestService.instance.sendRequest(
        userId: widget.uid,
        clubId: _selectedClubId!,
        clubName: _selectedClubName ?? '',
        role: _selectedRole!,
        message: _messageController.text.trim(),
        phone: userData['phone'] as String? ?? '',
        firstName: userData['firstName'] as String? ?? '',
        lastName: userData['lastName'] as String? ?? '',
        clubSport: _selectedClubSport,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Demande envoyée avec succès !")),
        );
        setState(() {
          _selectedRole = null;
          _selectedClubId = null;
          _selectedClubName = null;
          _selectedClubSport = null;
          _messageController.clear();
        });
      }
    } catch (e) {
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
  List<String> _getExcludedClubIds({String? role}) {
    final List<String> excluded = [];
    final summaries =
        (widget.userData['profileSummaries'] as List?)
            ?.whereType<Map>()
            .toList() ??
        [];
    if (role != null) {
      for (final e in summaries) {
        if (e['role'] == role) {
          final cid = e['clubId'] as String?;
          if (cid != null && cid.isNotEmpty) excluded.add(cid);
        }
      }
      return excluded;
    }
    for (final e in summaries) {
      final cid = e['clubId'] as String?;
      if (cid != null && cid.isNotEmpty) excluded.add(cid);
    }
    return excluded;
  }

  @override
  Widget build(BuildContext context) {
    if (_isUpdating) return const Center(child: ViroLoader(size: 80));

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PendingRequestsWidget(userId: widget.uid),
          const SizedBox(height: 30),

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
          ),

          // OPTION : REJOINDRE LICENCIÉ
          _roleOptionWithForm(
            title: "Je suis un Joueur",
            subtitle: "Rejoindre un nouveau club",
            icon: Icons.sports_soccer_rounded,
            roleValue: 'player',
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
  }) {
    final bool isSelected = _selectedRole == roleValue;
    final excludedClubIds = _getExcludedClubIds(role: roleValue);
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
            _selectedClubSport = null;
            _messageController.clear();
          }),
        ),
        if (isSelected) _buildJoinForm(excludedClubIds: excludedClubIds),
      ],
    );
  }

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
            onClubSelected: (clubId, clubName, clubSport) {
              setState(() {
                _selectedClubId = clubId;
                _selectedClubName = clubName;
                _selectedClubSport = clubSport;
              });
            },
            sportFilter: _sportFilter,
            onSportFilterChanged: (filter) {
              setState(() {
                _sportFilter = filter;
                _selectedClubId = null;
                _selectedClubName = null;
                _selectedClubSport = null;
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
              hintText:
                  "Ex: Bonjour, je souhaite rejoindre l'équipe Sénior...",
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

  Widget _roleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String roleValue,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _selectedRole == roleValue;

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
