import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../widget/viro_loader.dart';

class AdminClubCommunicationPage extends StatefulWidget {
  final String clubId;
  const AdminClubCommunicationPage({super.key, required this.clubId});

  @override
  State<AdminClubCommunicationPage> createState() =>
      _AdminClubCommunicationPageState();
}

class _AdminClubCommunicationPageState
    extends State<AdminClubCommunicationPage> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedTargetType = 'Équipes'; // 'Équipes', 'Catégories', 'Joueurs'
  final List<String> _selectedIds = [];
  bool _isSending = false;
  int _durationDays = 7;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Simulation d'envoi (À lier plus tard à Firebase Messaging pour les notifications push)
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez saisir un message et sélectionner au moins une cible.",
          ),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      String? senderFirstName;
      String? senderLastName;
      if (_currentUserId.isNotEmpty) {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();
        final data = userSnap.data();
        senderFirstName = data?['firstName'] as String?;
        senderLastName = data?['lastName'] as String?;
      }

      // On enregistre l'annonce dans une sous-collection du club
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('announcements')
          .add({
            'senderId': _currentUserId.isNotEmpty ? _currentUserId : 'admin',
            'senderFirstName': senderFirstName,
            'senderLastName': senderLastName,
            'message': _messageController.text.trim(),
            'targetType': _selectedTargetType,
            'targetIds': _selectedIds,
            'createdAt': FieldValue.serverTimestamp(),
            'durationDays': _durationDays,
          });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Annonce envoyée aux membres !")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur lors de l'envoi : $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Communication Club"),
        backgroundColor: ViroColors.background,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _isSending
              ? const Center(child: ViroLoader())
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 140,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DESTINATAIRES",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Colors.grey,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTargetToggle(),
                      const SizedBox(height: 20),

                      const Text(
                        "SÉLECTIONNER",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Colors.grey,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPickerList(),
                      const SizedBox(height: 30),

                      const Text(
                        "DURÉE DE VISIBILITÉ",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Colors.grey,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _durationDays.toDouble(),
                              min: 1,
                              max: 30,
                              divisions: 29,
                              label: "$_durationDays jours",
                              onChanged: (v) {
                                setState(() {
                                  _durationDays = v.round();
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              "$_durationDays j",
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ViroColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      const Text(
                        "MESSAGE",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Colors.grey,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: "Écrivez votre message important ici...",
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.campaign_rounded),
                          label: const Text(
                            "DIFFUSER L'ANNONCE",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ViroColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildTargetToggle() {
    return Row(
      children: ['Équipes', 'Catégories', 'Joueurs'].map((type) {
        bool selected = _selectedTargetType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedTargetType = type;
              _selectedIds.clear();
            }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? ViroColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? ViroColors.primary : ViroColors.borderColor,
                ),
              ),
              child: Text(
                type,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPickerList() {
    if (_selectedTargetType == 'Équipes') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .collection('teams')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final docs = snapshot.data!.docs;
          return Wrap(
            spacing: 8,
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? "Équipe";
              final isSel = _selectedIds.contains(doc.id);
              return FilterChip(
                label: Text(name, style: const TextStyle(fontSize: 12)),
                selected: isSel,
                onSelected: (val) => setState(
                  () => val
                      ? _selectedIds.add(doc.id)
                      : _selectedIds.remove(doc.id),
                ),
                selectedColor: ViroColors.primary.withOpacity(0.2),
              );
            }).toList(),
          );
        },
      );
    }

    if (_selectedTargetType == 'Catégories') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .collection('teams')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final categories =
              snapshot.data!.docs
                  .map(
                    (d) =>
                        (d.data() as Map<String, dynamic>)['category']
                            as String?,
                  )
                  .whereType<String>()
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return Wrap(
            spacing: 8,
            children: categories.map((cat) {
              final isSel = _selectedIds.contains(cat);
              return FilterChip(
                label: Text(cat, style: const TextStyle(fontSize: 12)),
                selected: isSel,
                onSelected: (val) => setState(
                  () => val ? _selectedIds.add(cat) : _selectedIds.remove(cat),
                ),
                selectedColor: ViroColors.primary.withOpacity(0.2),
              );
            }).toList(),
          );
        },
      );
    }

    // Joueurs
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final allDocs = snapshot.data!.docs
            .cast<DocumentSnapshot<Map<String, dynamic>>>()
            .toList();
        // Filtrer les utilisateurs du club
        final clubDocs = filterUsersByClub(allDocs, widget.clubId);

        final users = clubDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final first = (data['firstName'] as String? ?? "").trim();
          final last = (data['lastName'] as String? ?? "").trim();
          // Utiliser la nouvelle fonction pour obtenir le rôle dans ce club
          final role = getUserRoleInClub(data, widget.clubId) ?? "";
          final fullName =
              "${first.isNotEmpty ? first[0].toUpperCase() + first.substring(1).toLowerCase() : ''} ${last.toUpperCase()}"
                  .trim();
          return {
            'id': doc.id,
            'name': fullName.isEmpty ? "Membre" : fullName,
            'role': role,
          };
        }).toList();
        final staff =
            users.where((u) {
              final r = u['role'] ?? '';
              return r == 'admin' || r == 'admin_fondateur' || r == 'coach';
            }).toList()..sort(
              (a, b) => (a['name'] as String).toLowerCase().compareTo(
                (b['name'] as String).toLowerCase(),
              ),
            );
        final players =
            users.where((u) {
              final r = u['role'] ?? '';
              return !(r == 'admin' || r == 'admin_fondateur' || r == 'coach');
            }).toList()..sort(
              (a, b) => (a['name'] as String).toLowerCase().compareTo(
                (b['name'] as String).toLowerCase(),
              ),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (staff.isNotEmpty) ...[
              const Text(
                "Staff / Coachs",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: staff.map((u) {
                  final isSel = _selectedIds.contains(u['id']);
                  return FilterChip(
                    label: Text(
                      u['name'] as String,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: isSel,
                    onSelected: (val) => setState(
                      () => val
                          ? _selectedIds.add(u['id'] as String)
                          : _selectedIds.remove(u['id'] as String),
                    ),
                    selectedColor: ViroColors.primary.withOpacity(0.2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (players.isNotEmpty) ...[
              const Text(
                "Joueurs",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: players.map((u) {
                  final isSel = _selectedIds.contains(u['id']);
                  return FilterChip(
                    label: Text(
                      u['name'] as String,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: isSel,
                    onSelected: (val) => setState(
                      () => val
                          ? _selectedIds.add(u['id'] as String)
                          : _selectedIds.remove(u['id'] as String),
                    ),
                    selectedColor: ViroColors.primary.withOpacity(0.2),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}
