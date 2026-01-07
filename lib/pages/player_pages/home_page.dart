import 'package:flutter/material.dart';
import 'profil_page.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Suppression de la logique de blocage _isLoading pour un affichage continu
  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfilPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("ViroTeam"),
            const SizedBox(width: 12),
            // AJOUT DU LOADER EN CONTINU ICI (Taille réduite pour l'AppBar)
            const ViroLoader(size: 60),
          ],
        ),
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
              "Bonjour, Alexandre 👋",
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontSize: 24),
            ),
            const Text(
              "Voici le résumé de ton activité au club.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            _buildSectionTitle("À NE PAS MANQUER"),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ViroColors.secondary,
                      child: Icon(
                        Icons.sports_volleyball,
                        color: ViroColors.primary,
                      ),
                    ),
                    title: Text("Match vs Les Titans"),
                    subtitle: Text("Samedi 10 Janvier • 18h00"),
                  ),
                  const Divider(height: 1, color: ViroColors.borderColor),
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
            ),

            const SizedBox(height: 30),

            _buildSectionTitle("MES SERVICES"),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.2,
              children: [
                _buildMenuCard(
                  context,
                  "Boutique",
                  Icons.shopping_bag_outlined,
                ),
                _buildMenuCard(context, "Cotisation", Icons.payments_outlined),
                _buildMenuCard(context, "Documents", Icons.folder_outlined),
                _buildMenuCard(
                  context,
                  "Chat Équipe",
                  Icons.chat_bubble_outline,
                ),
              ],
            ),

            // OPTIONNEL : Un loader plus grand en bas de page pour combler l'espace
            const SizedBox(height: 40),
            const Center(child: ViroLoader(size: 80)),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: ViroColors.borderColor, width: 1),
          ),
        ),
        child: BottomNavigationBar(
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

  Widget _buildMenuCard(BuildContext context, String title, IconData icon) {
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
}
