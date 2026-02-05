import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/app_logger.dart';
import '../../widget/user_display_tile.dart';

class ProfilRequestPage extends StatefulWidget {
  final String requestId;
  final String? userId;
  final String? clubId;
  final String? clubName;
  final String? roleRequested;
  final String? message;
  final String? firstName;
  final String? lastName;
  /// False pour coach ou admin non fondateur (demande coach/admin) : masque Accepter/Refuser.
  final bool canRespond;

  const ProfilRequestPage({
    super.key,
    required this.requestId,
    required this.userId,
    this.clubId,
    this.clubName,
    this.roleRequested,
    this.message,
    this.firstName,
    this.lastName,
    this.canRespond = true,
  });

  @override
  State<ProfilRequestPage> createState() => _ProfilRequestPageState();
}

class _ProfilRequestPageState extends State<ProfilRequestPage> {
  bool _isProcessing = false;

  /// Charge le message depuis Firestore si absent (ex. ouverture depuis une notif).
  Future<String> _loadMessageIfNeeded() async {
    if (widget.message != null && widget.message!.isNotEmpty) {
      return widget.message!;
    }
    if (widget.requestId.isEmpty) return "";
    final doc = await FirebaseFirestore.instance
        .collection(FirebaseCollections.joinRequests)
        .doc(widget.requestId)
        .get();
    final data = doc.data();
    return (data?['message'] as String?) ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Demande d'adhésion")),
      body: FutureBuilder<String>(
        future: _loadMessageIfNeeded(),
        builder: (context, messageSnap) {
          if (messageSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final message = messageSnap.data ?? widget.message ?? "";

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection(FirebaseCollections.users)
                .doc(widget.userId)
                .get(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data?.data() ?? {};
              final email = data['email'] as String? ?? "";
              final phone = data['phone'] as String? ?? "";
              final role = widget.roleRequested ?? "player";

              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserDisplayTile(
                      userId: widget.userId,
                      firstName: widget.firstName,
                      lastName: widget.lastName,
                      avatarUrl: data['avatarUrl'] as String?,
                      fallback: widget.userId ?? "Membre",
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role == 'coach' ? "Entraîneur" : "Membre",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    _infoTile(Icons.email, email.isEmpty ? "Email inconnu" : email),
                    _infoTile(
                      Icons.phone,
                      phone.isEmpty ? "Téléphone inconnu" : phone,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Message",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ViroColors.borderColor),
                      ),
                      child: Text(message.isEmpty ? "Aucun message" : message),
                    ),
                    const Spacer(),
                    if (widget.canRespond)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isProcessing
                                  ? null
                                  : () => _handleRequest(false),
                              child: const Text("Refuser"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isProcessing
                                  ? null
                                  : () => _handleRequest(true),
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text("Accepter"),
                            ),
                          ),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Seul un administrateur (ou l'administrateur fondateur pour coach/admin) peut traiter cette demande.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
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

  Widget _infoTile(IconData icon, String text) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: ViroColors.primary),
      title: Text(text),
    );
  }

  Future<void> _handleRequest(bool accept) async {
    if (widget.userId == null) return;
    setState(() => _isProcessing = true);
    try {
      final requestRef = FirebaseFirestore.instance
          .collection(FirebaseCollections.joinRequests)
          .doc(widget.requestId);

      if (accept) {
        await requestRef.update({
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });

        final userId = widget.userId!;
        final clubId = widget.clubId;
        final roleRequested = widget.roleRequested ?? 'player';

        final userDoc = await FirebaseFirestore.instance
            .collection(FirebaseCollections.users)
            .doc(userId)
            .get();
        final userData = userDoc.data() ?? {};
        final roles = userData['roles'] as Map<String, dynamic>? ?? {};

        final normalizedRole = (roleRequested == 'admin_fondateur')
            ? 'admin'
            : roleRequested;

        final Map<String, dynamic> updatedRoles =
            Map<String, dynamic>.from(roles);

        if (normalizedRole == 'player') {
          final existingPlayer = roles['player'] as Map<String, dynamic>?;
          if (existingPlayer == null) {
            final requestData =
                (await requestRef.get()).data() ?? {};
            final license = requestData['license'] as String?;
            updatedRoles['player'] = {
              'clubs': [
                {
                  'clubId': clubId,
                  'teamIds': [],
                  if (license != null && license.isNotEmpty) 'license': license,
                },
              ],
            };
          } else {
            List<Map<String, dynamic>> clubsList;
            if (existingPlayer['clubs'] is List) {
              clubsList = (existingPlayer['clubs'] as List)
                  .map((e) => e as Map<String, dynamic>)
                  .toList();
            } else if (existingPlayer['clubId'] != null) {
              clubsList = [
                {
                  'clubId': existingPlayer['clubId'],
                  'teamIds': existingPlayer['teamIds'] ?? [],
                  if (existingPlayer['license'] != null)
                    'license': existingPlayer['license'],
                },
              ];
            } else {
              clubsList = [];
            }
            if (!clubsList.any((c) => c['clubId'] == clubId)) {
              final requestData =
                  (await requestRef.get()).data() ?? {};
              final license = requestData['license'] as String?;
              clubsList.add({
                'clubId': clubId,
                'teamIds': [],
                if (license != null && license.isNotEmpty) 'license': license,
              });
            }
            updatedRoles['player'] = {...existingPlayer, 'clubs': clubsList};
          }
        } else if (normalizedRole == 'coach') {
          final existingCoaches =
              (roles['coach'] as List?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          if (!existingCoaches.any((c) => c['clubId'] == clubId)) {
            existingCoaches.add({'clubId': clubId, 'teams': []});
            updatedRoles['coach'] = existingCoaches;
          }
        } else if (normalizedRole == 'admin') {
          final existingAdmins =
              (roles['admin'] as List?)?.whereType<String>().toList() ?? [];
          if (clubId != null && !existingAdmins.contains(clubId)) {
            existingAdmins.add(clubId);
            updatedRoles['admin'] = existingAdmins;
          }
        }

        // Toujours définir activeContext sur le club et le rôle acceptés
        final newActiveContext = <String, dynamic>{
          'role': normalizedRole,
          'clubId': clubId,
        };

        await FirebaseFirestore.instance.collection(FirebaseCollections.users).doc(userId).set({
          'hasPendingRequest': false,
          'roles': updatedRoles,
          'activeContext': newActiveContext,
          if (clubId != null) 'clubId': clubId,
          if (widget.clubName != null) 'clubName': widget.clubName,
        }, SetOptions(merge: true));

        if (clubId != null) {
          final String field = normalizedRole == 'admin'
              ? 'admins'
              : normalizedRole == 'coach'
                  ? 'coaches'
                  : 'members';
          await FirebaseFirestore.instance
              .collection(FirebaseCollections.clubs)
              .doc(clubId)
              .update({
            field: FieldValue.arrayUnion([userId]),
          });
        }
      } else {
        await requestRef.update({
          'status': 'refused',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection(FirebaseCollections.users)
            .doc(widget.userId)
            .set({'hasPendingRequest': false}, SetOptions(merge: true));
      }

      await requestRef.delete();
      AppLogger.instance.info(
        accept ? 'Demande de profil acceptée' : 'Demande de profil refusée',
        {
          'requestId': widget.requestId,
          'userId': widget.userId,
          'clubId': widget.clubId,
          'roleRequested': widget.roleRequested,
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors du traitement de la demande de profil',
        error: e,
        context: {
          'requestId': widget.requestId,
          'userId': widget.userId,
          'clubId': widget.clubId,
          'action': accept ? 'accept' : 'refuse',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Action impossible : $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
