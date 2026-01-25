import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/viro_theme.dart';

class ProfilRequestPage extends StatefulWidget {
  final String requestId;
  final String? userId;
  final String? clubId;
  final String? clubName;
  final String? roleRequested;
  final String? message;
  final String? firstName;
  final String? lastName;

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
  });

  @override
  State<ProfilRequestPage> createState() => _ProfilRequestPageState();
}

class _ProfilRequestPageState extends State<ProfilRequestPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final name = _formatName(
      widget.firstName,
      widget.lastName,
      fallback: widget.userId ?? "Membre",
    );
    return Scaffold(
      appBar: AppBar(title: const Text("Demande d'adhésion")),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
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
          final message = widget.message ?? "";

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
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
                ),
              ],
            ),
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
          .collection('join_requests')
          .doc(widget.requestId);

      if (accept) {
        await requestRef.update({
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .set({
              'clubId': widget.clubId,
              'clubName': widget.clubName,
              'hasPendingRequest': false,
              'role': widget.roleRequested ?? 'player',
            }, SetOptions(merge: true));
        if (widget.clubId != null) {
          final field =
              (widget.roleRequested == 'admin_fondateur' ||
                  widget.roleRequested == 'coach')
              ? 'coaches'
              : 'members';
          await FirebaseFirestore.instance
              .collection('clubs')
              .doc(widget.clubId)
              .update({
                field: FieldValue.arrayUnion([widget.userId]),
              });
        }
      } else {
        await requestRef.update({
          'status': 'refused',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .set({'hasPendingRequest': false}, SetOptions(merge: true));
      }

      await requestRef.delete();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Action impossible : $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatName(
    dynamic firstName,
    dynamic lastName, {
    String fallback = "Membre",
  }) {
    final fn = (firstName as String?)?.trim();
    final ln = (lastName as String?)?.trim();
    if ((fn == null || fn.isEmpty) && (ln == null || ln.isEmpty)) {
      return fallback;
    }
    String capitalize(String value) {
      if (value.isEmpty) return value;
      return value[0].toUpperCase() + value.substring(1).toLowerCase();
    }

    final first = fn != null ? capitalize(fn) : "";
    final last = ln != null ? ln.toUpperCase() : "";
    return [first, last].where((e) => e.isNotEmpty).join(" ");
  }
}
