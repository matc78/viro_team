import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../theme/viro_theme.dart';
import '../widget/viro_loader.dart';
import '../widget/club_search_widget.dart';
import 'player_pages/player_home_page.dart';
import 'admin_coach_pages/admin_home_page.dart';
import 'admin_coach_pages/create_club_page.dart';

/// Page d'onboarding pour les utilisateurs sans profil
/// Permet de créer un club ou de rejoindre un club comme player/coach
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _isUpdating = false;
  bool _initialCheckDone = false;
  String? _selectedRole; // 'player' ou 'coach'
  String? _selectedClubId;
  String? _selectedClubName;
  String? _sportFilter;

  // Contrôleurs
  final _messageController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
    _checkAndRedirect();
  }

  /// Si l'utilisateur a un activeContext → redirection vers la bonne home.
  /// S'il a au moins un club dans roles mais pas d'activeContext → créer activeContext sur le premier club puis rediriger.
  Future<void> _checkAndRedirect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _initialCheckDone = true);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection(FirebaseCollections.users)
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data == null || !mounted) return;

    final activeContext = data['activeContext'] as Map<String, dynamic>?;
    final activeRole = activeContext?['role'] as String?;
    final activeClubId = activeContext?['clubId'] as String?;

    // 1. ActiveContext valide → rediriger vers la bonne home
    if (activeContext != null &&
        activeRole != null &&
        activeRole.isNotEmpty &&
        activeClubId != null &&
        activeClubId.isNotEmpty) {
      if (!mounted) return;
      if (activeRole == 'admin' ||
          activeRole == 'coach' ||
          activeRole == 'admin_fondateur') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
        );
      } else if (activeRole == 'player') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlayerHomePage()),
        );
      } else {
        setState(() => _initialCheckDone = true);
      }
      return;
    }

    // 2. Pas d'activeContext mais au moins un club dans roles → créer activeContext sur le premier club
    final roles = data['roles'] as Map<String, dynamic>? ?? {};
    String? firstClubId;
    String? firstRole;

    final playerData = roles['player'] as Map<String, dynamic>?;
    if (playerData != null && playerData['clubs'] is List) {
      final clubs = (playerData['clubs'] as List).whereType<Map>().toList();
      if (clubs.isNotEmpty) {
        firstClubId = clubs.first['clubId'] as String?;
        firstRole = 'player';
      }
    }
    if (firstClubId == null && roles['coach'] is List) {
      final coaches = (roles['coach'] as List).whereType<Map>().toList();
      if (coaches.isNotEmpty) {
        firstClubId = coaches.first['clubId'] as String?;
        firstRole = 'coach';
      }
    }
    if (firstClubId == null && roles['admin'] is List) {
      final adminIds = (roles['admin'] as List).whereType<String>().toList();
      if (adminIds.isNotEmpty) {
        firstClubId = adminIds.first;
        firstRole = 'admin';
      }
    }

    if (firstClubId != null && firstRole != null) {
      final newActiveContext = <String, dynamic>{
        'role': firstRole,
        'clubId': firstClubId,
      };

      await FirebaseFirestore.instance.collection(FirebaseCollections.users).doc(user.uid).set({
        'activeContext': newActiveContext,
        'clubId': firstClubId,
      }, SetOptions(merge: true));

      if (!mounted) return;
      if (firstRole == 'admin' ||
          firstRole == 'coach' ||
          firstRole == 'admin_fondateur') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlayerHomePage()),
        );
      }
      return;
    }

    if (mounted) setState(() => _initialCheckDone = true);
  }

  Future<void> _loadUserPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection(FirebaseCollections.users)
        .doc(user.uid)
        .get();
    final raw = doc.data()?['phone'];
    final String? phone = raw is String
        ? raw
        : (raw is num ? raw.toString() : null);
    if (phone != null && phone.trim().isNotEmpty && mounted) {
      _phoneController.text = phone.trim();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
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
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user == null) throw Exception("Utilisateur non connecté");

      final requestsRef = FirebaseFirestore.instance.collection(
        'join_requests',
      );

      // Récupérer les infos utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection(FirebaseCollections.users)
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final firstName = userData['firstName'];
      final lastName = userData['lastName'];

      // Vérifier s'il existe déjà une demande en attente pour ce club/rôle
      final existing = await requestsRef
          .where('userId', isEqualTo: user.uid)
          .where('clubId', isEqualTo: _selectedClubId)
          .where('roleRequested', isEqualTo: _selectedRole)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      final requestData = {
        'userId': user.uid,
        'clubId': _selectedClubId,
        'clubName': _selectedClubName,
        'roleRequested': _selectedRole,
        'message': _messageController.text.trim(),
        'status': 'pending',
        'firstName': firstName,
        'lastName': lastName,
        if (_phoneController.text.trim().isNotEmpty)
          'phone': _phoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        // Mettre à jour la demande existante
        final oldData = existing.docs.first.data();
        final String oldMessage = oldData['message'] ?? "";
        final String newMessage = _messageController.text.trim();
        final String combinedMessage = oldMessage.isEmpty
            ? newMessage
            : "$oldMessage\n\n[Relance] : $newMessage";

        await existing.docs.first.reference.update({
          ...requestData,
          'message': combinedMessage,
        });
      } else {
        // Créer une nouvelle demande
        await requestsRef.add(requestData);
      }

      // Marquer la demande en attente et mettre à jour le téléphone au profil (y compris si modifié ou vidé)
      final userUpdateData = <String, dynamic>{
        'hasPendingRequest': true,
        'lastClubRequested': _selectedClubName,
        'phone': _phoneController.text.trim(),
      };
      await FirebaseFirestore.instance
          .collection(FirebaseCollections.users)
          .doc(user.uid)
          .set(userUpdateData, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlayerHomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone || _isUpdating) {
      return const Scaffold(body: ViroLoader(size: 80));
    }

    return Scaffold(
      backgroundColor: ViroColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "Bienvenue dans l'équipe !",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Text(
                "Quelle est votre mission au sein du club ?",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 30),

              // OPTION : CRÉER UN CLUB
              _roleCard(
                title: "Créer un Club",
                subtitle: "Je souhaite fonder mon club",
                icon: Icons.add_business_outlined,
                roleValue: 'admin',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateClubPage()),
                ),
              ),

              // OPTION : REJOINDRE COACH
              _roleOptionWithForm(
                title: "Rejoindre (Coach / Admin)",
                subtitle: "Gérer les entraînements",
                icon: Icons.psychology_outlined,
                roleValue: 'coach',
              ),

              // OPTION : REJOINDRE LICENCIÉ
              _roleOptionWithForm(
                title: "Rejoindre (Joueur)",
                subtitle: "Consulter mon calendrier d'entrainement",
                icon: Icons.sports_soccer_rounded,
                roleValue: 'player',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Le formulaire qui apparaît sous l'option sélectionnée
  Widget _buildJoinForm() {
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

          // Numéro de téléphone optionnel mais utile pour discuter par la suite d'un essai à un entraînement (Licencié et Coach/Entraîneur)
          if (_selectedRole == 'player' || _selectedRole == 'coach') ...[
            const SizedBox(height: 16),
            const Text(
              "Numéro de téléphone (optionnel mais utile pour discuter par la suite d'un essai à un entraînement)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "Ex: 06 12 34 56 78",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],

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
              "ENVOYER LA DEMANDE",
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
  }) {
    final bool isSelected = _selectedRole == roleValue;
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
            // Ne pas vider le téléphone : il est prérempli depuis le profil utilisateur
          }),
        ),
        if (isSelected) _buildJoinForm(),
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
              : const Icon(Icons.chevron_right, color: ViroColors.borderColor),
        ),
      ),
    );
  }
}
