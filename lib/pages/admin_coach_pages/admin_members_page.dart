import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../profil_display_page.dart';

class AdminMembersPage extends StatefulWidget {
  final String clubId;
  final String clubName;
  const AdminMembersPage({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<AdminMembersPage> createState() => _AdminMembersPageState();
}

class _AdminMembersPageState extends State<AdminMembersPage> {
  String _search = "";
  String? _selectedCategory;
  String? _selectedTeam;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFilters =
        _selectedCategory != null ||
        _selectedTeam != null ||
        _search.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text("Membres • ${widget.clubName}")),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Rechercher par nom ou email",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) =>
                      setState(() => _search = val.trim().toLowerCase()),
                ),
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(widget.clubId)
                    .collection('teams')
                    .snapshots(),
                builder: (context, snapshot) {
                  final categories = <String>{};
                  final teams = <String>{};
                  if (snapshot.hasData) {
                    for (final doc in snapshot.data!.docs) {
                      final data = doc.data();
                      final cat = data['category'] as String?;
                      final team = data['name'] as String?;
                      if (cat != null && cat.isNotEmpty) categories.add(cat);
                      if (team != null && team.isNotEmpty) teams.add(team);
                    }
                  }
                  final catList = categories.toList()..sort();
                  final teamList = teams.toList()..sort();
                  if (_selectedCategory != null &&
                      !catList.contains(_selectedCategory)) {
                    _selectedCategory = null;
                  }
                  if (_selectedTeam != null &&
                      !teamList.contains(_selectedTeam)) {
                    _selectedTeam = null;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: "Catégorie",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            hint: const Text("Catégorie"),
                            items:
                                catList
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList()
                                  ..insert(
                                    0,
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text("Catégorie"),
                                    ),
                                  ),
                            onChanged: (val) =>
                                setState(() => _selectedCategory = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedTeam,
                            decoration: const InputDecoration(
                              labelText: "Équipe",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            hint: const Text("Équipe"),
                            items:
                                teamList
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList()
                                  ..insert(
                                    0,
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text("Équipe"),
                                    ),
                                  ),
                            onChanged: (val) =>
                                setState(() => _selectedTeam = val),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  // Récupérer tous les utilisateurs et filtrer côté client
                  // car la nouvelle structure utilise roles/activeContext
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text("Erreur de chargement des membres."),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    // Filtrer les utilisateurs qui appartiennent au club
                    final clubMembers = filterUsersByClub(
                      allDocs,
                      widget.clubId,
                    );

                    // Créer une liste d'entrées avec doc et role pour gérer les utilisateurs multi-rôles
                    final entries = <Map<String, dynamic>>[];

                    for (final doc in clubMembers) {
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) continue;

                      // Obtenir tous les rôles de cet utilisateur dans ce club
                      final roles = getAllUserRolesInClub(data, widget.clubId);

                      // Si l'utilisateur est joueur ET admin/coach, créer deux entrées
                      // Sinon, créer une entrée par rôle
                      for (final role in roles) {
                        entries.add({'doc': doc, 'role': role});
                      }
                    }

                    // Filtrer les entrées selon les critères de recherche
                    final filtered =
                        entries.where((entry) {
                          final doc = entry['doc'] as DocumentSnapshot;
                          final role = entry['role'] as String;
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) return false;

                          final first = (data['firstName'] as String? ?? "")
                              .toLowerCase();
                          final last = (data['lastName'] as String? ?? "")
                              .toLowerCase();
                          final email = (data['email'] as String? ?? "")
                              .toLowerCase();
                          final userCat = data['category'] as String? ?? "";
                          final userCats =
                              (data['categories'] as List?)
                                  ?.whereType<String>()
                                  .toList() ??
                              [];
                          final userTeams =
                              (data['teamNames'] as List?)
                                  ?.whereType<String>()
                                  .toList() ??
                              [];
                          final userTeam = data['teamName'] as String?;

                          // Pour les filtres de catégorie et équipe, on ne filtre que les joueurs
                          // Les admins/coachs ne sont pas filtrés par catégorie/équipe
                          final isPlayer = role == 'player';
                          final catOk =
                              !isPlayer ||
                              _selectedCategory == null ||
                              _normalize(userCat) ==
                                  _normalize(_selectedCategory!) ||
                              userCats.any(
                                (c) =>
                                    _normalize(c) ==
                                    _normalize(_selectedCategory!),
                              );
                          final teamOk =
                              !isPlayer ||
                              _selectedTeam == null ||
                              _normalize(userTeam ?? "") ==
                                  _normalize(_selectedTeam!) ||
                              userTeams.any(
                                (t) =>
                                    _normalize(t) == _normalize(_selectedTeam!),
                              );

                          final matchesSearch =
                              _search.isEmpty ||
                              first.contains(_search) ||
                              last.contains(_search) ||
                              email.contains(_search);
                          return matchesSearch && catOk && teamOk;
                        }).toList()..sort((a, b) {
                          final aDoc = a['doc'] as DocumentSnapshot;
                          final bDoc = b['doc'] as DocumentSnapshot;
                          final aRole = a['role'] as String;
                          final bRole = b['role'] as String;
                          final aData = aDoc.data() as Map<String, dynamic>?;
                          final bData = bDoc.data() as Map<String, dynamic>?;

                          // Déterminer si ce sont des staff (admin/coach) ou des players (licenciés)
                          final aIsStaff =
                              aRole == 'admin_fondateur' ||
                              aRole == 'coach' ||
                              aRole == 'admin';
                          final bIsStaff =
                              bRole == 'admin_fondateur' ||
                              bRole == 'coach' ||
                              bRole == 'admin';

                          // D'abord, séparer les staff (en haut) des players (en bas)
                          if (aIsStaff && !bIsStaff)
                            return -1; // a est staff, b est player -> a en premier
                          if (!aIsStaff && bIsStaff)
                            return 1; // a est player, b est staff -> b en premier

                          // Si même type (tous les deux staff ou tous les deux players), trier par prénom
                          final aFirst = (aData?['firstName'] as String? ?? "")
                              .toLowerCase();
                          final bFirst = (bData?['firstName'] as String? ?? "")
                              .toLowerCase();
                          return aFirst.compareTo(bFirst);
                        });

                    if (filtered.isEmpty) {
                      return const Center(child: Text("Aucun membre trouvé."));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 140),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) {
                        // Afficher un séparateur uniquement à la transition entre staff et players
                        if (index < filtered.length - 1) {
                          final currentEntry = filtered[index];
                          final nextEntry = filtered[index + 1];
                          final currentRole = currentEntry['role'] as String;
                          final nextRole = nextEntry['role'] as String;

                          final currentIsStaff =
                              currentRole == 'admin_fondateur' ||
                              currentRole == 'coach' ||
                              currentRole == 'admin';
                          final nextIsPlayer = nextRole == 'player';

                          // Si l'élément actuel est staff et le suivant est player, afficher le séparateur
                          if (currentIsStaff && nextIsPlayer) {
                            return const Divider(
                              height: 1,
                              color: Colors.black,
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final doc = entry['doc'] as DocumentSnapshot;
                        final role = entry['role'] as String;
                        final rawData = doc.data();
                        final data = rawData as Map<String, dynamic>?;
                        if (data == null) return const SizedBox.shrink();

                        final userId = doc.id;
                        final firstName = data['firstName'] as String? ?? "";
                        final lastName = data['lastName'] as String? ?? "";
                        final name = _formatName(firstName, lastName);

                        // Pour les joueurs, afficher la catégorie
                        // Pour les admins/coachs, ne pas afficher de catégorie
                        final isPlayer = role == 'player';
                        final categories =
                            (data['categories'] as List?)
                                ?.whereType<String>()
                                .toList() ??
                            [];
                        final category = isPlayer
                            ? (categories.isNotEmpty
                                  ? categories.join(", ")
                                  : (data['category'] as String? ?? ""))
                            : "";

                        // Déterminer le label du rôle à afficher
                        final isStaff =
                            role == 'admin_fondateur' ||
                            role == 'coach' ||
                            role == 'admin';
                        final roleLabel = role
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map((word) {
                              if (word.isEmpty) return word;
                              return word[0].toUpperCase() + word.substring(1);
                            })
                            .join(' ');

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ViroColors.primary.withOpacity(
                              0.1,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: ViroColors.primary,
                            ),
                          ),
                          title: Text(name),
                          subtitle: isPlayer
                              ? Text(
                                  category.isNotEmpty
                                      ? category
                                      : "Sans catégorie",
                                  style: const TextStyle(color: Colors.grey),
                                )
                              : null,
                          trailing: isStaff
                              ? Text(
                                  roleLabel,
                                  style: const TextStyle(color: Colors.grey),
                                )
                              : const Text(
                                  "Licencié",
                                  style: TextStyle(color: Colors.grey),
                                ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfilDisplayPage(userId: userId),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: hasFilters
                    ? SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                foregroundColor: Colors.black87,
                                side: const BorderSide(
                                  color: ViroColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => setState(() {
                                _selectedCategory = null;
                                _selectedTeam = null;
                                _search = "";
                                _searchController.clear();
                              }),
                              child: const Text("Enlever les filtres"),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          // Logo en footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Opacity(
                    opacity: 0.12,
                    child: Image.asset(
                      'assets/logo/logo_long.png',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatName(String first, String last) {
    String cap(String v) =>
        v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();
    final f = cap(first);
    final l = last.toUpperCase();
    return [f, l].where((e) => e.isNotEmpty).join(" ").trim();
  }

  String _normalize(String input) {
    final lower = input.toLowerCase();
    return lower
        .replaceAll(RegExp('[àâä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[îï]'), 'i')
        .replaceAll(RegExp('[ôö]'), 'o')
        .replaceAll(RegExp('[ûü]'), 'u')
        .replaceAll(RegExp('[ç]'), 'c')
        .trim();
  }
}
