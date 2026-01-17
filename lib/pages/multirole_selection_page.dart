import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../../utils/firebase_helpers.dart';

class MultiRoleSelectionPage extends StatefulWidget {
  const MultiRoleSelectionPage({super.key});

  @override
  State<MultiRoleSelectionPage> createState() => _MultiRoleSelectionPageState();
}

class _MultiRoleSelectionPageState extends State<MultiRoleSelectionPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "";
  String? _activeView; // null, 'search_club', 'create_club'
  String? _selectedRole; // 'player' ou 'coach'

  // Pour la recherche
  String _searchTerm = "";
  final TextEditingController _searchController = TextEditingController();

  bool _isUpdating = false;

  // Controllers pour la création de club (persistants)
  final GlobalKey<FormState> _createClubFormKey = GlobalKey<FormState>();
  final TextEditingController _clubNameController = TextEditingController();
  final TextEditingController _clubCityController = TextEditingController();
  final TextEditingController _clubAddressController = TextEditingController();
  final TextEditingController _clubEmailController = TextEditingController();
  final TextEditingController _clubPhoneController = TextEditingController();
  final TextEditingController _clubDescriptionController = TextEditingController();
  String? _selectedSport;
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _clubNameController.dispose();
    _clubCityController.dispose();
    _clubAddressController.dispose();
    _clubEmailController.dispose();
    _clubPhoneController.dispose();
    _clubDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(title: const Text("Ajouter un profil"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1 : DEMANDES EN COURS ---
            _buildPendingRequestsSection(),
            const SizedBox(height: 30),

            // --- SECTION 2 : CHOIX DU RÔLE ---
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

            if (_activeView == null) ...[
              _roleCard(
                "Je suis un Joueur",
                "Rejoindre un nouveau club",
                Icons.sports_soccer_rounded,
                Colors.blue,
                () {
                  setState(() {
                    _activeView = 'search_club';
                    _selectedRole = 'player';
                  });
                },
              ),
              _roleCard(
                "Je suis un Coach",
                "Postuler dans un club",
                Icons.psychology_outlined,
                Colors.orange,
                () {
                  setState(() {
                    _activeView = 'search_club';
                    _selectedRole = 'coach';
                  });
                },
              ),
              _roleCard(
                "Créer un Club",
                "Devenir administrateur fondateur",
                Icons.add_business_outlined,
                Colors.green,
                () {
                  setState(() {
                    _activeView = 'create_club';
                  });
                },
              ),
            ],

            // --- SECTION 3 : VUES DYNAMIQUES (Recherche ou Création) ---
            if (_activeView == 'search_club') _buildClubSearchSection(),
            if (_activeView == 'create_club') _buildCreateClubSection(),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE LA PAGE ---

  Widget _buildPendingRequestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('join_requests')
          .where('userId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox();

        final pendingRequests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).toList();

        final processedRequests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'accepted' || data['status'] == 'refused';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingRequests.isNotEmpty) ...[
              const Text(
                "MES DEMANDES EN ATTENTE",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ...pendingRequests.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ViroColors.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        data['roleRequested'] == 'player'
                            ? Icons.sports_soccer
                            : Icons.psychology,
                        color: ViroColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Demande ${data['roleRequested'] == 'player' ? 'joueur' : 'coach'} chez ${data['clubName']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Badge(
                        label: Text("En attente"),
                        backgroundColor: Colors.orange,
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (processedRequests.isNotEmpty) ...[
              if (pendingRequests.isNotEmpty) const SizedBox(height: 20),
              const Text(
                "DEMANDES TRAITÉES",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ...processedRequests.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isAccepted = data['status'] == 'accepted';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAccepted ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAccepted ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAccepted ? Icons.check_circle : Icons.cancel,
                        color: isAccepted ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "${isAccepted ? 'Accepté' : 'Refusé'} : ${data['roleRequested'] == 'player' ? 'joueur' : 'coach'} chez ${data['clubName']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isAccepted ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildClubSearchSection() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _activeView = null),
              icon: const Icon(Icons.arrow_back),
            ),
            Text(
              "Rechercher un club (${_selectedRole == 'player' ? 'Joueur' : 'Coach'})",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Nom du club...",
            prefixIcon: const Icon(Icons.search),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) => setState(() => _searchTerm = val.toLowerCase()),
        ),
        const SizedBox(height: 15),
        // Ici, on remet ton StreamBuilder de recherche de clubs (celui de RoleSelectionPage)
        _buildSearchResults(),
      ],
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: ViroLoader());
        
        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: ViroLoader());

            // Filtrage local pour la recherche par nom ET exclusion des clubs où l'utilisateur a déjà le rôle
            final clubs = snapshot.data!.docs.where((doc) {
              final name = doc['name'].toString().toLowerCase();
              final clubId = doc.id;
              
              // Vérifier si le nom correspond à la recherche
              if (!name.contains(_searchTerm)) return false;
              
              // Vérifier si l'utilisateur a déjà le rôle demandé dans ce club
              if (_selectedRole != null) {
                final currentRole = getUserRoleInClub(userData, clubId);
                // Exclure le club si l'utilisateur a déjà le rôle demandé
                if (currentRole == _selectedRole) return false;
              }
              
              return true;
            }).toList();

            if (clubs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Aucun club trouvé avec ce nom.",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clubs.length,
              itemBuilder: (context, index) {
                final club = clubs[index];
                final data = club.data() as Map<String, dynamic>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ViroColors.borderColor),
                  ),
                  child: ListTile(
                    title: Text(
                      data['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${data['city'] ?? 'Ville non précisée'} • ${data['sport'] ?? ''}",
                    ),
                    trailing: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ViroColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () =>
                                _promptMessageAndSubmit(club.id, data['name']),
                            child: const Text(
                              "Postuler",
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _promptMessageAndSubmit(String clubId, String clubName) {
    final TextEditingController messageController = TextEditingController(
      text:
          "Bonjour, je souhaite rejoindre le club en tant que ${_selectedRole == 'player' ? 'joueur' : 'coach'}.",
    );
    final TextEditingController licenseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Rejoindre $clubName"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Ajoutez un message pour l'administrateur :",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Votre message...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (_selectedRole == 'player') ...[
                const SizedBox(height: 16),
                const Text(
                  "Numéro de licence (optionnel) :",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: licenseController,
                  decoration: InputDecoration(
                    hintText: "Ex: 123456",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ViroColors.primary,
            ),
            onPressed: () {
              Navigator.pop(context);
              _submitRequest(
                clubId,
                clubName,
                messageController.text.trim(),
                licenseController.text.trim(),
              );
            },
            child: const Text("Envoyer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest(
    String clubId,
    String clubName,
    String message,
    String license,
  ) async {
    setState(() => _isUpdating = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final userData = userDoc.data() ?? {};
      final firstName = userData['firstName'] ?? "";
      final lastName = userData['lastName'] ?? "";
      final email = userData['email'] ?? "";

      // VÉRIFICATION : Si demande player, vérifier qu'il n'est pas déjà player dans ce club
      if (_selectedRole == 'player') {
        final roles = userData['roles'] as Map<String, dynamic>? ?? {};
        final playerData = roles['player'];
        
        if (playerData != null) {
          // Nouvelle structure : liste de clubs
          if (playerData is Map) {
            // Vérifier si c'est la nouvelle structure avec "clubs" (liste)
            if (playerData['clubs'] is List) {
              final clubs = (playerData['clubs'] as List).whereType<Map>();
              final isAlreadyInClub = clubs.any((club) => club['clubId'] == clubId);
              if (isAlreadyInClub) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Vous êtes déjà joueur dans ce club.",
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  setState(() => _isUpdating = false);
                }
                return;
              }
            } 
            // Ancienne structure : clubId direct
            else if (playerData['clubId'] == clubId) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Vous êtes déjà joueur dans ce club.",
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                setState(() => _isUpdating = false);
              }
              return;
            }
          }
        }
      }

      final reqRef = FirebaseFirestore.instance.collection('requests');
      final existing = await reqRef
          .where('userId', isEqualTo: _uid)
          .where('clubId', isEqualTo: clubId)
          .where('role', isEqualTo: _selectedRole)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final prev = (doc.data()['message'] as String?) ?? "";
        final merged = prev.isEmpty ? message : "$prev\n\n---\n$message";
        await doc.reference.update({
          'message': merged,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await reqRef.add({
          'userId': _uid,
          'userFirstName': firstName,
          'userLastName': lastName,
          'userEmail': email,
          'clubId': clubId,
          'clubName': clubName,
          'role': _selectedRole,
          'message': message,
          'status': 'pending',
          if (license.isNotEmpty && _selectedRole == 'player') 'license': license,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Alimente aussi join_requests pour l'affichage admin
      final joinRef = FirebaseFirestore.instance.collection('join_requests');
      final existingJoin = await joinRef
          .where('userId', isEqualTo: _uid)
          .where('clubId', isEqualTo: clubId)
          .where('roleRequested', isEqualTo: _selectedRole)
          .limit(1)
          .get();

      if (existingJoin.docs.isNotEmpty) {
        final doc = existingJoin.docs.first;
        final prev = (doc.data()['message'] as String?) ?? "";
        final merged = prev.isEmpty ? message : "$prev\n\n---\n$message";
        await doc.reference.update({
          'message': merged,
          'updatedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      } else {
        await joinRef.add({
          'userId': _uid,
          'clubId': clubId,
          'clubName': clubName,
          'roleRequested': _selectedRole ?? 'player',
          'status': 'pending',
          'message': message,
          'firstName': firstName,
          'lastName': lastName,
          if (license.isNotEmpty && _selectedRole == 'player') 'license': license,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Marquer la demande en attente (sans modifier la structure roles)
      await FirebaseFirestore.instance.collection('users').doc(_uid).set({
        'hasPendingRequest': true,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _activeView = null;
          _isUpdating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Demande envoyée avec succès !")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    }
  }

  Widget _roleCard(
    String title,
    String sub,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.add_circle_outline),
      ),
    );
  }

  Widget _buildCreateClubSection() {
    final List<String> _sports = [
      'Football',
      'Basketball',
      'Tennis',
      'Volleyball',
      'Handball',
      'Rugby',
      'Judo',
      'Natation',
      'Autre',
    ];

    Future<void> _createClub() async {
      if (!_createClubFormKey.currentState!.validate()) return;
      if (_selectedSport == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez sélectionner un sport")),
        );
        return;
      }

      setState(() => _isCreating = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Création du document Club
        DocumentReference clubRef = await FirebaseFirestore.instance
            .collection('clubs')
            .add({
              'name': _clubNameController.text.trim(),
              'city': _clubCityController.text.trim(),
              'address': _clubAddressController.text.trim(),
              'sport': _selectedSport,
              'contactEmail': _clubEmailController.text.trim(),
              'phone': _clubPhoneController.text.trim(),
              'description': _clubDescriptionController.text.trim(),
              'adminId': user.uid,
              'admins': [user.uid],
              'createdAt': FieldValue.serverTimestamp(),
              'memberCount': 1,
            });

        // Mise à jour de l'utilisateur avec la nouvelle structure multi-tenant
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final existingData = userDoc.data() ?? {};
        final existingRoles = existingData['roles'] as Map<String, dynamic>? ?? {};
        
        final existingAdmins = (existingRoles['admin'] as List?)?.whereType<String>().toList() ?? [];
        if (!existingAdmins.contains(clubRef.id)) {
          existingAdmins.add(clubRef.id);
        }
        
        final updatedRoles = {
          ...existingRoles,
          'admin': existingAdmins,
        };
        
        final activeContext = existingData['activeContext'] as Map<String, dynamic>?;
        final Map<String, dynamic> newActiveContext;
        if (activeContext == null || activeContext.isEmpty) {
          newActiveContext = {
            'role': 'admin',
            'clubId': clubRef.id,
          };
        } else {
          newActiveContext = Map<String, dynamic>.from(activeContext);
        }
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'roles': updatedRoles,
          'activeContext': newActiveContext,
          'clubId': clubRef.id,
          'clubName': _clubNameController.text.trim(),
        }, SetOptions(merge: true));

        // Réinitialiser les champs après création réussie
        _clubNameController.clear();
        _clubCityController.clear();
        _clubAddressController.clear();
        _clubEmailController.clear();
        _clubPhoneController.clear();
        _clubDescriptionController.clear();
        _selectedSport = null;

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MultiRoleSelectionPage()),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Club créé avec succès !")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur lors de la création : $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _isCreating = false);
      }
    }

    Widget _buildTextField({
      required TextEditingController controller,
      required String label,
      required String hint,
      required IconData icon,
      int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: ViroColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ViroColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ViroColors.borderColor),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          validator: (val) =>
              val == null || val.isEmpty ? "Champ obligatoire" : null,
        ),
      );
    }

    return SingleChildScrollView(
      child: Form(
        key: _createClubFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _activeView = null;
                      // Réinitialiser les champs si on quitte la vue
                      _clubNameController.clear();
                      _clubCityController.clear();
                      _clubAddressController.clear();
                      _clubEmailController.clear();
                      _clubPhoneController.clear();
                      _clubDescriptionController.clear();
                      _selectedSport = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                const Text(
                  "Créer mon club",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Informations générales",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _clubNameController,
              label: "Nom du club",
              hint: "ex: Viroflay FC",
              icon: Icons.business,
            ),
            DropdownButtonFormField<String>(
              value: _selectedSport,
              decoration: InputDecoration(
                labelText: "Sport principal",
                prefixIcon: const Icon(Icons.sports_soccer, color: ViroColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ViroColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ViroColors.borderColor),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
              items: _sports
                  .map((sport) => DropdownMenuItem(value: sport, child: Text(sport)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSport = val),
              validator: (val) => val == null ? "Champ requis" : null,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _clubCityController,
              label: "Ville",
              hint: "ex: Viroflay",
              icon: Icons.location_city,
            ),
            _buildTextField(
              controller: _clubAddressController,
              label: "Adresse du siège / terrain",
              hint: "12 rue des sports",
              icon: Icons.map,
            ),
            const Divider(height: 40),
            Text(
              "Contact & Détails",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _clubEmailController,
              label: "Email de contact",
              hint: "contact@club.com",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            _buildTextField(
              controller: _clubPhoneController,
              label: "Téléphone",
              hint: "06 00 00 00 00",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              controller: _clubDescriptionController,
              label: "Description du club",
              hint: "Parlez-nous de l'histoire du club...",
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isCreating ? null : _createClub,
              style: ElevatedButton.styleFrom(
                backgroundColor: ViroColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "CRÉER LE CLUB",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
