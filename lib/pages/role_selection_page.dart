import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/viro_theme.dart';
import '../widget/viro_loader.dart';
import 'player_pages/player_home_page.dart';
import 'admin_coach_pages/create_club_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _isUpdating = false;
  String? _selectedRole;
  String _searchTerm = "";
  String _sportFilter = "Tous";

  // Contrôleurs
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();

  String? _selectedClubId;
  String? _selectedClubName;

  static const List<String> _sports = [
    "Tous",
    "Football",
    "Basketball",
    "Volleyball",
    "Handball",
    "Rugby",
    "Tennis",
    "Judo",
    "Autre",
  ];

  /// Envoie la demande d'adhésion à Firestore
  Future<void> _sendJoinRequest() async {
    if (_selectedClubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner un club dans la liste"),
        ),
      );
      return;
    }
    if (_selectedClubName == null || _selectedClubName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Merci de choisir un club valide dans la liste"),
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

      // Récupérer les infos utilisateur pour stocker prénom/nom dans la demande
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final firstName = userData['firstName'];
      final lastName = userData['lastName'];

      // 1. Vérifier s'il existe déjà une demande en attente pour cet utilisateur
      final existing = await requestsRef
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      final requestData = {
        'userId': user.uid,
        'clubId': _selectedClubId,
        'clubName': _selectedClubName,
        'roleRequested': _selectedRole, // 'player' ou 'coach'
        'message': _messageController.text.trim(),
        'status': 'pending',
        'firstName': firstName,
        'lastName': lastName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        // 1. Récupérer l'ancien message
        final oldData = existing.docs.first.data();
        final String oldMessage = oldData['message'] ?? "";
        final String newMessage = _messageController.text.trim();

        // 2. Concaténer (si le nouveau message n'est pas vide)
        String combinedMessage = oldMessage;
        if (newMessage.isNotEmpty) {
          // On ajoute un séparateur clair avec la date ou un "+"
          combinedMessage = oldMessage.isEmpty
              ? newMessage
              : "$oldMessage\n\n[Relance] : $newMessage";
        }

        // 3. Mettre à jour avec le message combiné
        await existing.docs.first.reference.set({
          ...requestData,
          'message': combinedMessage, // Utilisation du message concaténé
          'createdAt': oldData['createdAt'] ?? FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Créer une nouvelle demande
        await requestsRef.add({
          ...requestData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Mise à jour du profil utilisateur (marquer la demande en attente)
      // On ne modifie PAS la structure roles ici, c'est l'admin qui le fera lors de l'acceptation
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'hasPendingRequest': true,
        'lastClubRequested': _selectedClubName,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlayerHomePage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUpdating) return const Scaffold(body: ViroLoader(size: 80));

    return Scaffold(
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
                roleValue: 'admin_fondateur',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateClubPage()),
                ),
              ),

              // OPTION : REJOINDRE COACH
              _roleOptionWithForm(
                title: "Rejoindre (Entraîneur / Admin)",
                subtitle: "Gérer les entraînements",
                icon: Icons.admin_panel_settings_outlined,
                roleValue: 'coach',
              ),

              // OPTION : REJOINDRE LICENCIÉ
              _roleOptionWithForm(
                title: "Rejoindre (Licencié)",
                subtitle: "Consulter mon calendrier",
                icon: Icons.sports_volleyball_outlined,
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
        border: Border.all(color: ViroColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Filtrer par sport",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _sportFilter,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _sports
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _sportFilter = val;
                  _selectedClubId = null;
                  _selectedClubName = null;
                });
              }
            },
          ),

          const SizedBox(height: 20),
          const Text(
            "Rechercher votre club",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Nom du club ou ville...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) => setState(() => _searchTerm = val.trim()),
          ),

          const SizedBox(height: 12),
          _buildClubDropdown(),

          if (_selectedClubName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ViroColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: ViroColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Club sélectionné : $_selectedClubName",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ViroColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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

  /// Liste dynamique des clubs filtrés
  Widget _buildClubDropdown() {
    Query query = FirebaseFirestore.instance.collection('clubs');
    if (_sportFilter != 'Tous') {
      query = query.where('sport', isEqualTo: _sportFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Erreur de chargement");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final city = (data['city'] ?? '').toString().toLowerCase();
          return name.contains(_searchTerm.toLowerCase()) ||
              city.contains(_searchTerm.toLowerCase());
        }).toList();

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Aucun club trouvé.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          );
        }

        return Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final club = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                visualDensity: VisualDensity.compact,
                title: Text(
                  club['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  "${club['city']} - ${club['sport']}",
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  setState(() {
                    _selectedClubId = docs[index].id;
                    _selectedClubName = club['name'];
                  });
                },
              );
            },
          ),
        );
      },
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
              ? ViroColors.primary.withOpacity(0.05)
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
