import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/pages/role_selection_page.dart';
import 'player_profil_page.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isManualRefreshing = false;
  Map<String, dynamic>? _manualUserData;

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlayerProfilPage()));
  }

  Future<void> _refreshUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isManualRefreshing = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server)); // force serveur
      if (!mounted) return;
      _manualUserData = snap.data();
    } finally {
      if (mounted) setState(() => _isManualRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Scaffold(
            body: Center(child: Text("Erreur de chargement")),
          );
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Scaffold(body: ViroLoader(size: 80));

        final userData =
            _manualUserData ?? snapshot.data?.data() as Map<String, dynamic>?;
        final bool hasPendingRequest = userData?['hasPendingRequest'] ?? false;
        final String? clubId =
            userData?['clubId']; // ID du club si déjà accepté
        final String firstName = userData?['firstName'] ?? "Sportif";

        // Cas 1 : Demande en attente
        if (hasPendingRequest) {
          return _buildPendingRequestView(
            userData?['lastClubRequested'] ?? "ton club",
          );
        }

        // Cas 2 : Utilisateur dans un club
        if (clubId != null) {
          return _buildClubMemberView(
            firstName,
            userData?['clubName'] ?? "Mon Club",
          );
        }

        // Cas 3 : Ni club, ni demande (cas par défaut/erreur)
        return _buildNoClubView(firstName);
      },
    );
  }

  // --- VUE 1 : DEMANDE EN ATTENTE ---
  Widget _buildPendingRequestView(String clubName) {
    return Scaffold(
      appBar: AppBar(title: const Text("Demande envoyée")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.send_rounded,
                size: 80,
                color: ViroColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "Message envoyé !",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Ta demande pour rejoindre le club \"$clubName\" est en cours d'examen par l'administrateur.",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const ViroLoader(size: 50),
              const SizedBox(height: 20),
              const Text(
                "On te prévient dès que c'est validé !",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isManualRefreshing ? null : _refreshUserStatus,
                icon: _isManualRefreshing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: ViroLoader(size: 18),
                      )
                    : const Icon(Icons.refresh),
                label: const Text("Rafraîchir"),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _isManualRefreshing
                    ? null
                    : () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .set({
                                'hasPendingRequest': false,
                                'clubId': null,
                              }, SetOptions(merge: true));
                        }
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const RoleSelectionPage(),
                          ),
                          (route) => false,
                        );
                      },
                icon: const Icon(Icons.repeat),
                label: const Text("Faire une nouvelle demande"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- VUE 2 : HOME PAGE NORMALE (MEMBRE D'UN CLUB) ---
  Widget _buildClubMemberView(String name, String clubName) {
    return Scaffold(
      appBar: AppBar(
        title: Text(clubName), // On affiche le nom du club dans l'appbar
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _openProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bonjour, $name 👋",
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontSize: 24),
            ),
            const Text(
              "Voici ton activité au sein du club.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            _buildSectionTitle("À NE PAS MANQUER"),
            _buildNextMatchCard(), // Ton widget de match actuel

            const SizedBox(height: 30),
            _buildSectionTitle("MES SERVICES"),
            _buildGridMenu(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- VUE 3 : AUCUN CLUB (REDIRIGER VERS SELECTION DE ROLE SI BESOIN) ---
  Widget _buildNoClubView(String name) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Bonjour $name, tu n'as pas encore de club."),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text("Se déconnecter"),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.redo),
              label: const Text("Faire une nouvelle demande"),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPOSANTS UI RÉUTILISABLES ---

  Widget _buildNextMatchCard() {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: CircleAvatar(
              backgroundColor: ViroColors.secondary,
              child: Icon(Icons.sports_volleyball, color: ViroColors.primary),
            ),
            title: Text("Match vs Les Titans"),
            subtitle: Text("Samedi 10 Janvier • 18h00"),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text("ABSENT"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text("PRÉSENT"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMenu() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.2,
      children: [
        _buildMenuCard("Boutique", Icons.shopping_bag_outlined),
        _buildMenuCard("Cotisation", Icons.payments_outlined),
        _buildMenuCard("Documents", Icons.folder_outlined),
        _buildMenuCard("Chat Équipe", Icons.chat_bubble_outline),
      ],
    );
  }

  Widget _buildMenuCard(String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ViroColors.borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ViroColors.primary, size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      elevation: 0,
      backgroundColor: ViroColors.background,
      selectedItemColor: ViroColors.primary,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 3) _openProfile();
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: "Calendrier",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mail_outline),
          label: "Messages",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: "Profil",
        ),
      ],
    );
  }
}
