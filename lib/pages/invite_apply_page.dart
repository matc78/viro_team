import 'package:flutter/material.dart';
import 'package:viro_team/services/invite_apply_service.dart';
import 'package:viro_team/theme/viro_theme.dart';
import 'package:viro_team/widget/viro_loader.dart';

/// Page affichée lorsqu'un utilisateur déjà connecté ouvre un lien d'invitation.
/// Applique l'invite (club, équipes, events, suppression pending) puis redirige.
class InviteApplyPage extends StatefulWidget {
  final String token;
  final String clubId;
  final String userId;
  final String userEmail;
  final VoidCallback onDone;

  const InviteApplyPage({
    super.key,
    required this.token,
    required this.clubId,
    required this.userId,
    required this.userEmail,
    required this.onDone,
  });

  @override
  State<InviteApplyPage> createState() => _InviteApplyPageState();
}

class _InviteApplyPageState extends State<InviteApplyPage> {
  bool _loading = true;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _applyInvite();
  }

  Future<void> _applyInvite() async {
    final result = await InviteApplyService.instance.applyInviteForLoggedInUser(
      userId: widget.userId,
      userEmail: widget.userEmail,
      token: widget.token,
      clubId: widget.clubId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result;
      _success = result == null;
    });
    if (_success) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) widget.onDone();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ViroLoader(size: 50),
              SizedBox(height: 16),
              Text("Traitement de l'invitation..."),
            ],
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
                _error ?? "Une erreur s'est produite.",
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
}
