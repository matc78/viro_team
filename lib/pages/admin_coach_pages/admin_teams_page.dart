import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import 'admin_teams_detail_page.dart';

class AdminTeamsPage extends StatefulWidget {
  final String clubId;
  const AdminTeamsPage({super.key, required this.clubId});

  @override
  State<AdminTeamsPage> createState() => _AdminTeamsPageState();
}

class _AdminTeamsPageState extends State<AdminTeamsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _clubSport;
  String? _clubLogoUrl;

  @override
  void initState() {
    super.initState();
    _loadClubInfo();
  }

  Future<void> _loadClubInfo() async {
    final doc = await _db.collection('clubs').doc(widget.clubId).get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _clubSport = (data['sport'] as String?) ?? "";
      _clubLogoUrl = data['logoUrl'] as String?;
    });
  }

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    final categories = getCategoriesBySport(_clubSport ?? "");
    String category = categories.isNotEmpty ? categories.first : "Sénior";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Nouvelle Équipe"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Nom de l'équipe",
                hintText: "ex: Équipe A",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(
                labelText: "Catégorie",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => category = val!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ViroColors.primary,
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _db
                    .collection('clubs')
                    .doc(widget.clubId)
                    .collection('teams')
                    .add({
                      'name': nameController.text.trim(),
                      'category': category,
                      'playerIds': [],
                      'coachIds': [],
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("CRÉER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _fetchCoachNames(List<String> coachIds) async {
    if (coachIds.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: coachIds)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      final first = (data['firstName'] as String? ?? "").trim();
      final last = (data['lastName'] as String? ?? "").trim().toUpperCase();
      final name = [first, last].where((e) => e.isNotEmpty).join(" ");
      return name.isEmpty ? "Coach" : name;
    }).toList();
  }

  static List<String> getCategoriesBySport(String sportName) {
    final sport = sportName.toLowerCase().trim().replaceAll('-', '');
    switch (sport) {
      case 'football':
        return [
          'U7',
          'U8',
          'U9',
          'U10',
          'U11',
          'U12',
          'U13',
          'U14',
          'U15',
          'U16',
          'U17',
          'U18',
          'U19',
          'Sénior',
          'Vétéran',
          'Féminines',
          'Loisir',
        ];
      case 'basketball':
        return [
          'U7',
          'U9',
          'U11',
          'U13',
          'U15',
          'U17',
          'U18',
          'U20',
          'Sénior',
          'Sénior +',
          'Loisir',
        ];
      case 'volleyball':
        return [
          'M7',
          'M9',
          'M11',
          'M13',
          'M15',
          'M18',
          'M21',
          'Sénior',
          'Loisir',
          'Soft',
        ];
      case 'handball':
        return [
          '-9',
          '-11',
          '-13',
          '-15',
          '-18',
          'Sénior',
          'Féminines',
          'Loisir',
        ];
      case 'rugby':
        return [
          'M6',
          'M8',
          'M10',
          'M12',
          'M14',
          'M16',
          'M19',
          'Sénior',
          'Vétéran (+35)',
          'Loisir',
        ];
      case 'tennis':
        return [
          'Galaxie Rouge',
          'Galaxie Orange',
          'Galaxie Vert',
          '11/12 ans',
          '13/14 ans',
          '15/16 ans',
          '17/18 ans',
          'Sénior',
          'Sénior +',
          'Loisir',
        ];
      case 'judo':
        return [
          'Éveil',
          'Mini-poussin',
          'Poussin',
          'Benjamin',
          'Minime',
          'Cadet',
          'Junior',
          'Sénior',
          'Vétéran',
        ];
      case 'natation':
        return [
          'Avenirs',
          'Benjamins',
          'Juniors 1',
          'Juniors 2',
          'Juniors 3',
          'Juniors 4',
          'Séniors',
          'Masters',
        ];
      default:
        return ['U13', 'U15', 'U17', 'Sénior', 'Loisir'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Équipes"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('clubs')
            .doc(widget.clubId)
            .collection('teams')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("Une erreur est survenue"));
          if (!snapshot.hasData)
            return const Center(child: ViroLoader(size: 50));

          final teams = snapshot.data!.docs;

          if (teams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    "Aucune équipe pour le moment",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              final data = team.data() as Map<String, dynamic>;
              final coachIds = List<String>.from(data['coachIds'] ?? []);
              final playerIds = List<String>.from(data['playerIds'] ?? []);
              final playerCount = playerIds.length;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: ViroColors.borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading:
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: _db
                            .collection('clubs')
                            .doc(widget.clubId)
                            .get(),
                        builder: (context, clubSnap) {
                          final logoUrl =
                              _clubLogoUrl ??
                              (clubSnap.data?.data()?['logoUrl'] as String? ??
                                  "");
                          return CircleAvatar(
                            backgroundColor: ViroColors.primary.withOpacity(
                              0.1,
                            ),
                            backgroundImage: logoUrl.isNotEmpty
                                ? NetworkImage(logoUrl)
                                : null,
                            child: logoUrl.isEmpty
                                ? const Icon(
                                    Icons.groups_rounded,
                                    color: ViroColors.primary,
                                  )
                                : null,
                          );
                        },
                      ),
                  title: Text(
                    data['name'] ?? "Sans nom",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Catégorie : ${data['category']}"),
                      if (playerCount > 0)
                        Text(
                          "$playerCount joueur${playerCount > 1 ? 's' : ''}",
                        ),
                      FutureBuilder<List<String>>(
                        future: _fetchCoachNames(coachIds),
                        builder: (context, snapshot) {
                          final coaches = snapshot.data ?? [];
                          if (coaches.isEmpty) {
                            return const Text("Coach(s) : non renseigné");
                          }
                          return Text("Coach(s) : ${coaches.join(', ')}");
                        },
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: ViroColors.borderColor,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamDetailsPage(
                          clubId: widget.clubId,
                          teamDoc: team,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTeamDialog,
        backgroundColor: ViroColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
