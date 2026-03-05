import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/services/invite_apply_service.dart';
import 'package:viro_team/theme/viro_theme.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/widget/viro_loader.dart';

/// Page affichée lorsqu'un utilisateur déjà connecté ouvre un lien d'invitation.
/// Affiche une confirmation (Accepter / Refuser) avant d'appliquer ou de refuser l'invite.
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
  bool _loading = true;
  String? _error;
  String? _clubName;
  String? _pendingMemberId;
  Map<String, dynamic>? _inviteData;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _loadInviteAndClub();
  }

  Future<void> _loadInviteAndClub() async {
    final emailNorm = widget.userEmail.trim().toLowerCase();
    if (emailNorm.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Email manquant.';
      });
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
        setState(() {
          _loading = false;
          _error = 'Lien invalide.';
        });
        return;
      }

      final data = inviteSnap.data()!;
      final usedAt = data['usedAt'] as Timestamp?;
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (usedAt != null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Ce lien a déjà été utilisé.';
        });
        return;
      }
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Ce lien a expiré.';
        });
        return;
      }

      final inviteEmail =
          (data['email'] as String? ?? '').trim().toLowerCase();
      if (inviteEmail != emailNorm) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              'Cette invitation est pour $inviteEmail. Vous êtes connecté avec un autre compte.';
        });
        return;
      }

      final pendingMemberId = data['pendingMemberId'] as String? ?? '';
      if (pendingMemberId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Lien invalide.';
        });
        return;
      }

      final clubSnap = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .get();
      final clubName = clubSnap.exists && clubSnap.data() != null
          ? (clubSnap.data()!['name'] as String? ?? widget.clubId)
          : widget.clubId;

      if (!mounted) return;
      setState(() {
        _loading = false;
        _clubName = clubName;
        _pendingMemberId = pendingMemberId;
        _inviteData = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Une erreur s\'est produite.';
      });
    }
  }

  Future<void> _accept() async {
    if (_inviteData == null || _pendingMemberId == null) return;
    setState(() => _loading = true);
    final result = await InviteApplyService.instance.applyInviteForLoggedInUser(
      userId: widget.userId,
      userEmail: widget.userEmail,
      token: widget.token,
      clubId: widget.clubId,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _loading = false;
        _error = result;
      });
      return;
    }
    setState(() {
      _loading = false;
      _success = true;
    });
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) widget.onDone();
    }
  }

  Future<void> _decline() async {
    if (_pendingMemberId == null) return;
    setState(() => _loading = true);
    try {
      final pendingRef = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.pendingMembers)
          .doc(_pendingMemberId);
      await pendingRef.update({
        'invitationStatus': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      final inviteRef = appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.inviteLinks)
          .doc(widget.token);
      await inviteRef.update({'usedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Ignorer erreur : on appelle onDone quand même
    }
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _clubName == null && _error == null) {
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

    if (_error != null && _clubName == null) {
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

    // Confirmation : Accepter / Refuser
    final clubName = _clubName ?? 'ce club';
    final isApplying = _loading;

    return Scaffold(
      appBar: AppBar(title: const Text("Invitation club")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_add,
                size: 64,
                color: ViroColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "Rejoindre le club $clubName ?",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                "Vous avez été invité à rejoindre ce club et ses équipes.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 32),
              if (isApplying)
                const ViroLoader(size: 40)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _decline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ViroColors.error,
                        side: const BorderSide(color: ViroColors.error),
                      ),
                      child: const Text("Refuser"),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _accept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ViroColors.primary,
                      ),
                      child: const Text("Accepter"),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
