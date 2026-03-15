import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/services/invite_apply_service.dart';
import 'package:viro_team/theme/viro_theme.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/widget/viro_loader.dart';

/// Page affichée lorsqu'un utilisateur déjà connecté ouvre un lien d'invitation.
/// L'invitation est acceptée automatiquement sans demander de confirmation.
class PlayerConfirmClubInvitationPage extends StatefulWidget {
  final String token;
  final String clubId;
  final String userId;
  final String userEmail;
  final VoidCallback onDone;

  const PlayerConfirmClubInvitationPage({
    super.key,
    required this.token,
    required this.clubId,
    required this.userId,
    required this.userEmail,
    required this.onDone,
  });

  @override
  State<PlayerConfirmClubInvitationPage> createState() =>
      _PlayerConfirmClubInvitationPageState();
}

class _PlayerConfirmClubInvitationPageState
    extends State<PlayerConfirmClubInvitationPage> {
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _loadAndAccept();
  }

  Future<void> _loadAndAccept() async {
    final emailNorm = widget.userEmail.trim().toLowerCase();
    if (emailNorm.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Email manquant.');
      return;
    }

    try {
      final inviteRef = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.inviteLinks)
          .doc(widget.token);
      final inviteSnap = await inviteRef.get();

      if (!inviteSnap.exists || inviteSnap.data() == null) {
        if (!mounted) return;
        setState(() => _error = 'Lien invalide.');
        return;
      }

      final data = inviteSnap.data()!;
      final usedAt = data['usedAt'] as Timestamp?;
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (usedAt != null) {
        if (!mounted) return;
        setState(() => _error = 'Ce lien a déjà été utilisé.');
        return;
      }
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        if (!mounted) return;
        setState(() => _error = 'Ce lien a expiré.');
        return;
      }

      final inviteEmail =
          (data['email'] as String? ?? '').trim().toLowerCase();
      if (inviteEmail != emailNorm) {
        if (!mounted) return;
        setState(() => _error =
            'Cette invitation est pour $inviteEmail. Vous êtes connecté avec un autre compte.');
        return;
      }

      final pendingMemberId = data['pendingMemberId'] as String? ?? '';
      if (pendingMemberId.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Lien invalide.');
        return;
      }

      // Acceptation automatique
      final result =
          await InviteApplyService.instance.applyInviteForLoggedInUser(
        userId: widget.userId,
        userEmail: widget.userEmail,
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      if (result != null) {
        setState(() => _error = result);
        return;
      }
      setState(() => _success = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Une erreur s\'est produite.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Invitation")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: ViroColors.error),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ViroColors.primary,
                  ),
                  child: const Text("OK"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_success) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: ViroColors.success),
                const SizedBox(height: 16),
                Text(
                  "Invitation acceptée",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ViroColors.success,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Vous avez rejoint le club et vos équipes.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ViroColors.primary,
                  ),
                  child: const Text("Aller à l'accueil"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Chargement / acceptation en cours
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ViroLoader(size: 50),
            SizedBox(height: 16),
            Text("Chargement de l'invitation..."),
          ],
        ),
      ),
    );
  }
}
