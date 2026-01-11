import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../profil_display_page.dart';

class TeamDetailsPage extends StatefulWidget {
  final String clubId;
  final DocumentSnapshot teamDoc;

  const TeamDetailsPage({
    super.key,
    required this.clubId,
    required this.teamDoc,
  });

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  bool _isEditing = false;
  // Ouvre une liste de membres du club pour les ajouter à l'équipe
  void _showAddMemberSheet(String role) {
    final roles = role == 'coach' ? ['coach', 'admin_fondateur'] : ['player'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('clubId', isEqualTo: widget.clubId)
            .where('role', whereIn: roles)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: ViroLoader(size: 40));
          final existingCoachIds = (widget.teamDoc.data()
                  as Map<String, dynamic>)['coachIds'] as List<dynamic>? ??
              [];
          final existingPlayerIds = (widget.teamDoc.data()
                  as Map<String, dynamic>)['playerIds'] as List<dynamic>? ??
              [];
          final existingIds =
              role == 'coach' ? existingCoachIds : existingPlayerIds;

          final users = snapshot.data!.docs
              .where((doc) => !existingIds.contains(doc.id))
              .toList();

          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("Aucun membre trouvé avec ce rôle dans le club."),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  role == 'player' ? "Ajouter un Licencié" : "Ajouter un Coach / Admin",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                    final user = users[i].data() as Map<String, dynamic>;
                    final formattedName = _formatName(
                      user['firstName'],
                      user['lastName'],
                    );
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(formattedName),
                      trailing: const Icon(
                        Icons.add_circle_outline,
                        color: ViroColors.primary,
                      ),
                  onTap: () async {
                    String field = (role == 'player')
                        ? 'playerIds'
                        : 'coachIds';
                        await widget.teamDoc.reference.update({
                          field: FieldValue.arrayUnion([users[i].id]),
                        });
                        if (mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.teamDoc.reference.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(body: ViroLoader(size: 80));

        final teamData = snapshot.data!.data() as Map<String, dynamic>;
        final List coachIds = teamData['coachIds'] ?? [];
        final List playerIds = teamData['playerIds'] ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(teamData['name'] ?? "Détails"),
                Text(
                  teamData['category'] ?? "",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                onPressed: () => setState(() => _isEditing = !_isEditing),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildMemberSection("Coachs", coachIds, 'coach'),
              const Divider(height: 1, color: ViroColors.borderColor),
              _buildMemberSection("Effectif (Licenciés)", playerIds, 'player'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberSection(String title, List ids, String role) {
    final isCoach = role == 'coach';
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(
                Icons.add_circle_rounded,
                color: ViroColors.primary,
              ),
              onPressed: () => _showAddMemberSheet(role),
            ),
        ],
      ),
    );

    final listWidget = ids.isEmpty
        ? const Center(
            child: Text(
              "Aucun membre dans cette section",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ids.length,
            itemBuilder: (ctx, i) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(ids[i])
                  .get(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox();
                final userData = snap.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ViroColors.borderColor.withOpacity(0.5),
                    ),
                  ),
                  child: ListTile(
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.person_outline, size: 20),
                    title: Text(
                      _formatName(userData['firstName'], userData['lastName']),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: _isEditing
                        ? IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              String field =
                                  (role == 'player') ? 'playerIds' : 'coachIds';
                              await widget.teamDoc.reference.update({
                                field: FieldValue.arrayRemove([ids[i]]),
                              });
                            },
                          )
                        : null,
                    onTap: () {
                      final userId = snap.data!.id;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfilDisplayPage(userId: userId),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );

    if (isCoach) {
      final height =
          (ids.length * 68 + 120).clamp(160, 360).toDouble(); // responsive height
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: listWidget,
          ),
        ],
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Expanded(child: listWidget),
        ],
      ),
    );
  }

  String _formatName(dynamic firstName, dynamic lastName) {
    final fn = (firstName as String?)?.trim() ?? "";
    final ln = (lastName as String?)?.trim() ?? "";
    String cap(String v) =>
        v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();
    final first = cap(fn);
    final last = ln.toUpperCase();
    final full = [first, last].where((e) => e.isNotEmpty).join(" ").trim();
    return full.isEmpty ? "Membre" : full;
  }
}
