import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';

class ProfilDisplayPage extends StatelessWidget {
  final String userId;

  const ProfilDisplayPage({super.key, required this.userId});

  // Vérifie si l'utilisateur actuel a le droit de voir les infos privées
  Future<Map<String, dynamic>> _viewerInfo() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return {'hasAccess': false, 'role': null};
    if (currentUid == userId) {
      return {'hasAccess': true, 'role': null};
    }

    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    final role = currentUserDoc.data()?['role'];
    // Seuls les admins et coachs ont accès aux coordonnées
    final hasAccess = role == 'admin_fondateur' || role == 'coach';
    return {'hasAccess': hasAccess, 'role': role};
  }

  Future<void> _editLicense(
    BuildContext context,
    String? currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue ?? "");
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier le numéro de licence"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Numéro de licence"),
            inputFormatters: [
              TextInputFormatter.withFunction(
                (oldValue, newValue) => newValue.copyWith(
                  text: newValue.text.toUpperCase(),
                  selection: newValue.selection,
                ),
              ),
            ],
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return "Champ requis";
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final newVal = controller.text.trim();
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({'licenseNumber': newVal});
                if (context.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Licence mise à jour")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur : $e")),
                  );
                }
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Profil"),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader(size: 60));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Utilisateur introuvable"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String firstName = data['firstName'] ?? "";
          final String lastName = data['lastName'] ?? "";
          final String formattedName = _formatName(firstName, lastName);
          final String role = data['role'] ?? "Membre";
          final String? clubId = data['clubId'] as String?;

          return FutureBuilder<bool>(
            future: _viewerInfo().then((v) => v['hasAccess'] as bool),
            builder: (context, accessSnapshot) {
              final bool hasAccess = accessSnapshot.data ?? false;
              final Future<Map<String, dynamic>> viewerInfoFuture =
                  _viewerInfo();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // --- HEADER : AVATAR ET NOM ---
                    FutureBuilder<List<String>>(
                      future: _fetchClubLogos(data),
                      builder: (context, logosSnap) {
                        final logos = logosSnap.data ?? [];
                        return Center(
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor:
                                        ViroColors.primary.withOpacity(0.1),
                                    backgroundImage: (data['avatarUrl'] != null &&
                                            (data['avatarUrl'] as String).isNotEmpty)
                                        ? NetworkImage(data['avatarUrl'])
                                        : null,
                                    child: (data['avatarUrl'] == null ||
                                            (data['avatarUrl'] as String).isEmpty)
                                        ? const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: ViroColors.primary,
                                          )
                                        : null,
                                  ),
                                  for (int i = 0; i < logos.length; i++)
                                    Positioned(
                                      top: -6,
                                      right: -6.0 - (i * 26),
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.white,
                                        child: CircleAvatar(
                                          radius: 15,
                                          backgroundColor: Colors.white,
                                          backgroundImage:
                                              NetworkImage(logos[i]),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                formattedName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ViroColors.secondary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: const TextStyle(
                                    color: ViroColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),

                    // --- SECTION : INFOS GÉNÉRALES ---
                    _buildSectionTitle("INFORMATIONS"),
                    _buildInfoTile(Icons.badge_outlined, "Rôle au club", role),
                    FutureBuilder<Map<String, dynamic>>(
                      future: viewerInfoFuture,
                      builder: (context, viewerSnap) {
                        final viewerRole = viewerSnap.data?['role'] as String?;
                        final isAdminOrCoach = viewerRole == 'admin_fondateur' ||
                            viewerRole == 'coach';
                        final license = data['licenseNumber'] as String?;
                        return _buildInfoTile(
                          Icons.credit_card,
                          "Numéro de licence",
                          license?.isNotEmpty == true
                              ? license!
                              : "Non renseigné",
                          trailing: isAdminOrCoach
                              ? IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _editLicense(context, license),
                                )
                              : null,
                        );
                      },
                    ),
                    if (clubId != null)
                      FutureBuilder<List<String>>(
                        future: _fetchTeams(clubId, userId),
                        builder: (context, teamSnap) {
                          if (teamSnap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: ViroLoader(size: 30),
                            );
                          }
                          final teams = teamSnap.data ?? [];
                          if (teams.isEmpty) return const SizedBox.shrink();
                          return _buildInfoTile(
                            Icons.group,
                            "Équipe(s)",
                            teams.join(", "),
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    // --- SECTION : COORDONNÉES (CONDITIONNEL) ---
                    _buildSectionTitle("COORDONNÉES"),
                    if (hasAccess) ...[
                      _buildInfoTile(
                        Icons.email_outlined,
                        "Email",
                        data['email'] ?? "Non renseigné",
                      ),
                      _buildInfoTile(
                        Icons.phone_android_outlined,
                        "Téléphone",
                        data['phone'] ?? "Non renseigné",
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ViroColors.borderColor),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: Colors.grey,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Les coordonnées sont visibles uniquement par les coachs et l'administration.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ViroColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: ViroColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}

String _formatName(String first, String last) {
  String cap(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();
  final f = cap(first);
  final l = last.toUpperCase();
  return [f, l].where((e) => e.isNotEmpty).join(" ").trim();
}

Future<List<String>> _fetchClubLogos(Map<String, dynamic> data) async {
  final logos = <String>[];
  final ids = <String>{};
  if (data['clubIds'] is List) {
    ids.addAll((data['clubIds'] as List).whereType<String>());
  }
  if (data['clubId'] is String) ids.add(data['clubId']);

  for (final id in ids) {
    final doc =
        await FirebaseFirestore.instance.collection('clubs').doc(id).get();
    final url = doc.data()?['logoUrl'] as String?;
    if (url != null && url.isNotEmpty) logos.add(url);
  }
  return logos;
}

Future<List<String>> _fetchTeams(String clubId, String uid) async {
  final db = FirebaseFirestore.instance;
  final playerTeams = await db
      .collection('clubs')
      .doc(clubId)
      .collection('teams')
      .where('playerIds', arrayContains: uid)
      .get();
  final coachTeams = await db
      .collection('clubs')
      .doc(clubId)
      .collection('teams')
      .where('coachIds', arrayContains: uid)
      .get();

  final names = <String>{};
  for (final doc in [...playerTeams.docs, ...coachTeams.docs]) {
    final data = doc.data();
    final name = data['name'] as String? ?? "Équipe";
    names.add(name);
  }
  return names.toList();
}
