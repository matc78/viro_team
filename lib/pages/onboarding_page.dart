import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/utils/firebase_error_handler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../services/join_request_service.dart';
import '../services/user_session.dart';
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
  String? _selectedClubSport;
  String? _sportFilter;

  // Contrôleurs
  final _messageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _scrollController = ScrollController();

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
    final doc = await appFirestore
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

    // 2. Pas d'activeContext mais au moins un club dans profileSummaries → créer activeContext sur le premier club
    final summaries = (data['profileSummaries'] as List?)?.whereType<Map>().toList() ?? [];
    String? firstClubId;
    String? firstRole;
    for (final e in summaries) {
      final cid = e['clubId'] as String?;
      final role = e['role'] as String?;
      if (cid != null && cid.isNotEmpty && role != null) {
        firstClubId = cid;
        firstRole = role;
        break;
      }
    }

    if (firstClubId != null && firstRole != null) {
      final newActiveContext = <String, dynamic>{
        'role': firstRole,
        'clubId': firstClubId,
      };

      await appFirestore.collection(FirebaseCollections.users).doc(user.uid).set({
        'activeContext': newActiveContext,
      }, SetOptions(merge: true));

      if (!mounted) return;
      await context.read<UserSession>().loadUser(user.uid);

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
    final doc = await appFirestore
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
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user == null) throw Exception("Utilisateur non connecté");

      final userDoc = await appFirestore
          .collection(FirebaseCollections.users)
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      await JoinRequestService.instance.sendRequest(
        userId: user.uid,
        clubId: _selectedClubId!,
        clubName: _selectedClubName ?? '',
        role: _selectedRole!,
        message: _messageController.text.trim(),
        phone: _phoneController.text.trim(),
        firstName: userData['firstName'] as String? ?? '',
        lastName: userData['lastName'] as String? ?? '',
        clubSport: _selectedClubSport,
      );

      if (mounted) {
        await context.read<UserSession>().loadUser(user.uid);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlayerHomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))));
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
          controller: _scrollController,
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
            _selectedClubSport = null;
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
