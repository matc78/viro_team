import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import '../../constants/firebase_collections.dart';
import '../../services/join_request_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_error_handler.dart';
import '../../utils/avatar_moderation.dart';
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
    final doc = await appFirestore
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
            future: appFirestore
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
                      avatarUrl: effectiveAvatarUrl(data),
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
      if (accept) {
        await JoinRequestService.instance.acceptRequest(
          requestId: widget.requestId,
          userId: widget.userId!,
          clubId: widget.clubId ?? '',
          role: widget.roleRequested ?? 'player',
        );
      } else {
        await JoinRequestService.instance.refuseRequest(
          requestId: widget.requestId,
          userId: widget.userId!,
          clubId: widget.clubId,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
