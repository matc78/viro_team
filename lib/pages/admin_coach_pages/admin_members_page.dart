import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Membres • ${widget.clubName}")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Rechercher par nom ou email",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('clubId', isEqualTo: widget.clubId)
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

                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data();
                  final first = (data['firstName'] as String? ?? "").toLowerCase();
                  final last = (data['lastName'] as String? ?? "").toLowerCase();
                  final email = (data['email'] as String? ?? "").toLowerCase();
                  if (_search.isEmpty) return true;
                  return first.contains(_search) ||
                      last.contains(_search) ||
                      email.contains(_search);
                }).toList()
                  ..sort((a, b) {
                    final aLast = (a.data()['lastName'] as String? ?? "").toLowerCase();
                    final bLast = (b.data()['lastName'] as String? ?? "").toLowerCase();
                    return aLast.compareTo(bLast);
                  });

                if (filtered.isEmpty) {
                  return const Center(child: Text("Aucun membre trouvé."));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = filtered[index].data();
                    final firstName = data['firstName'] as String? ?? "";
                    final lastName = data['lastName'] as String? ?? "";
                    final email = data['email'] as String? ?? "";
                    final role = data['role'] as String? ?? "";
                    final name = _formatName(firstName, lastName);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ViroColors.primary.withOpacity(0.1),
                        child: const Icon(Icons.person, color: ViroColors.primary),
                      ),
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: Text(
                        role == 'admin_fondateur' || role == 'coach'
                            ? "Staff"
                            : "Licencié",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatName(String first, String last) {
    String cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();
    final f = cap(first);
    final l = last.toUpperCase();
    return [f, l].where((e) => e.isNotEmpty).join(" ").trim();
  }
}
