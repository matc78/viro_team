import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:intl/intl.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_helpers.dart';
import '../../utils/firebase_error_handler.dart';
import '../../widget/user_display_tile.dart';
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
  /// Par défaut : diffusion à tout le club (réservé aux admins — les coachs sont
  /// repassés sur « Équipes » une fois le rôle connu).
  String _selectedTargetType = 'Tous les membres';
  final List<String> _selectedIds = [];
  bool _scheduledCoachRecipientFallback = false;
  bool _isSending = false;
  int _durationDays = 7;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Simulation d'envoi (À lier plus tard à Firebase Messaging pour les notifications push)
  Future<void> _sendMessage() async {
    final isBroadcastToAll = _selectedTargetType == 'Tous les membres';
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir un message.")),
      );
      return;
    }
    if (!isBroadcastToAll && _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner au moins une cible."),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      String? senderFirstName;
      String? senderLastName;
      if (_currentUserId.isNotEmpty) {
        final userSnap = await appFirestore
            .collection(FirebaseCollections.users)
            .doc(_currentUserId)
            .get();
        final data = userSnap.data();
        senderFirstName = data?['firstName'] as String?;
        senderLastName = data?['lastName'] as String?;
      }

      // On enregistre l'annonce dans une sous-collection du club
      final targetType = _selectedTargetType == 'Tous les membres'
          ? 'Tous les membres'
          : _selectedTargetType;
      final targetIds = _selectedTargetType == 'Tous les membres'
          ? <String>[]
          : _selectedIds;

      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.announcements)
          .add({
            'senderId': _currentUserId.isNotEmpty ? _currentUserId : 'admin',
            'senderFirstName': senderFirstName,
            'senderLastName': senderLastName,
            'message': _messageController.text.trim(),
            'targetType': targetType,
            'targetIds': targetIds,
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
      ).showSnackBar(SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showEditAnnouncementDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final messageController = TextEditingController(
      text: data['message'] as String? ?? '',
    );
    int durationDays = data['durationDays'] as int? ?? 7;
    durationDays = durationDays.clamp(1, 30);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier l\'annonce'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Message',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Durée de visibilité : $durationDays jours',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      value: durationDays.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (v) {
                        setDialogState(() => durationDays = v.round());
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    final message = messageController.text.trim();
                    if (message.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez saisir un message.'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _updateAnnouncement(docId, message, durationDays);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Annonce modifiée.')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ViroColors.primary,
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
    messageController.dispose();
  }

  Future<void> _updateAnnouncement(
    String docId,
    String message,
    int durationDays,
  ) async {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.announcements)
        .doc(docId)
        .update({'message': message, 'durationDays': durationDays});
  }

  Future<void> _showDeleteAnnouncementConfirm(
    BuildContext context,
    String docId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'annonce'),
        content: const Text(
          'Cette annonce ne sera plus visible par les membres. Confirmer la suppression ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _deleteAnnouncement(docId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Annonce supprimée.')));
    }
  }

  Future<void> _deleteAnnouncement(String docId) async {
    await appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(widget.clubId)
        .collection(FirebaseCollections.announcements)
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text("Communication Club"),
        centerTitle: true,
        backgroundColor: ViroColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          _isSending
              ? const Center(child: ViroLoader())
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: appFirestore
                      .collection(FirebaseCollections.users)
                      .doc(_currentUserId)
                      .snapshots(),
                  builder: (context, userSnap) {
                    final hasUser =
                        userSnap.hasData && userSnap.data?.data() != null;
                    bool isAdmin = false;
                    if (hasUser) {
                      final roles = getAllUserRolesInClub(
                        userSnap.data!.data()!,
                        widget.clubId,
                      );
                      isAdmin = roles.any(
                        (r) => r == 'admin' || r == 'admin_fondateur',
                      );
                    }
                    if (hasUser &&
                        !isAdmin &&
                        _selectedTargetType == 'Tous les membres' &&
                        !_scheduledCoachRecipientFallback) {
                      _scheduledCoachRecipientFallback = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          _selectedTargetType = 'Équipes';
                          _selectedIds.clear();
                        });
                      });
                    }
                    return SingleChildScrollView(
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
                          _buildTargetToggle(isAdmin: isAdmin),
                          const SizedBox(height: 20),
                          if (_selectedTargetType != 'Tous les membres') ...[
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
                          ],
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
                              hintText:
                                  "Écrivez votre message important ici...",
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
                          const SizedBox(height: 40),
                          _buildActiveCommunicationsSection(isAdmin: isAdmin),
                        ],
                      ),
                    );
                  },
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

  Widget _buildActiveCommunicationsSection({required bool isAdmin}) {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.announcements)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;
        final active = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdTs = data['createdAt'] as Timestamp?;
          final durationDays = data['durationDays'] as int? ?? 7;
          if (createdTs == null) return false;
          final createdAt = createdTs.toDate();
          final expiresAt = createdAt.add(Duration(days: durationDays));
          return expiresAt.isAfter(now);
        }).toList();
        if (active.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "COMMUNICATIONS EN COURS",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ...active.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final message = data['message'] as String? ?? '';
              final targetType = data['targetType'] as String? ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final durationDays = data['durationDays'] as int? ?? 7;
              final expiresAt = createdAt?.add(Duration(days: durationDays));
              final senderFirst = data['senderFirstName'] as String? ?? '';
              final senderLast = data['senderLastName'] as String? ?? '';
              final docId = doc.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ViroColors.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.campaign_rounded,
                          size: 18,
                          color: ViroColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            targetType.isEmpty
                                ? 'Tous les membres'
                                : targetType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ViroColors.primary,
                            ),
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            DateFormat('dd/MM', 'fr_FR').format(createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        UserDisplayTile(
                          userId: data['senderId'] as String?,
                          firstName: senderFirst.isNotEmpty
                              ? senderFirst
                              : null,
                          lastName: senderLast.isNotEmpty ? senderLast : null,
                          compact: true,
                          fallback: 'Club',
                          textStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (expiresAt != null) ...[
                          const Spacer(),
                          Text(
                            "Visible jusqu'au ${DateFormat('dd/MM', 'fr_FR').format(expiresAt)}",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _showEditAnnouncementDialog(context, docId, data),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Modifier'),
                          style: TextButton.styleFrom(
                            foregroundColor: ViroColors.primary,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () =>
                                _showDeleteAnnouncementConfirm(context, docId),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red[700],
                            ),
                            label: Text(
                              'Supprimer',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildTargetToggle({bool isAdmin = false}) {
    final types = [
      'Équipes',
      'Catégories',
      'Joueurs',
      if (isAdmin) 'Tous les membres',
    ];
    return Row(
      children: types.map((type) {
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
    if (_selectedTargetType == 'Tous les membres') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: ViroColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ViroColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.campaign_rounded, color: ViroColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "L'annonce sera diffusée à tous les membres du club (joueurs, coachs, admins).",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_selectedTargetType == 'Équipes') {
      return StreamBuilder<QuerySnapshot>(
        stream: appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.teams)
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
                selectedColor: ViroColors.primary.withValues(alpha: 0.2),
              );
            }).toList(),
          );
        },
      );
    }

    if (_selectedTargetType == 'Catégories') {
      return StreamBuilder<QuerySnapshot>(
        stream: appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(widget.clubId)
            .collection(FirebaseCollections.teams)
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
                selectedColor: ViroColors.primary.withValues(alpha: 0.2),
              );
            }).toList(),
          );
        },
      );
    }

    // Joueurs
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore.collection(FirebaseCollections.users).snapshots(),
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
                    selectedColor: ViroColors.primary.withValues(alpha: 0.2),
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
                    selectedColor: ViroColors.primary.withValues(alpha: 0.2),
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
