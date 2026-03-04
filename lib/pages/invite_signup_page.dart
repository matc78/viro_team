import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/services/pending_member_merge_service.dart';
import 'package:viro_team/services/user_session.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/utils/firebase_error_handler.dart';
import '../theme/viro_theme.dart';
import '../widget/viro_loader.dart';

/// Page d'inscription via lien d'invite : formulaire pré-rempli (nom, prénom, email)
/// + mot de passe ; création du compte puis redirection vers PlayerHomePage.
class InviteSignUpPage extends StatefulWidget {
  final String token;
  final String clubId;
  /// Appelé après inscription réussie pour que l'app efface le lien invite et redirige correctement.
  final VoidCallback? onSignUpSuccess;

  const InviteSignUpPage({
    super.key,
    required this.token,
    required this.clubId,
    this.onSignUpSuccess,
  });

  @override
  State<InviteSignUpPage> createState() => _InviteSignUpPageState();
}

class _InviteSignUpPageState extends State<InviteSignUpPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _initialLoadDone = false;
  String? _loadError;
  Map<String, dynamic>? _inviteData;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    try {
      final doc = await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.inviteLinks)
          .doc(widget.token)
          .get();

      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _initialLoadDone = true;
          _loadError = 'Lien invalide.';
        });
        return;
      }

      final data = doc.data()!;
      final usedAt = data['usedAt'] as Timestamp?;
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (usedAt != null) {
        setState(() {
          _initialLoadDone = true;
          _loadError = 'Ce lien a déjà été utilisé.';
        });
        return;
      }
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        setState(() {
          _initialLoadDone = true;
          _loadError = 'Ce lien a expiré.';
        });
        return;
      }

      _inviteData = data;
      _firstNameController.text = (data['firstName'] as String? ?? '').trim();
      _lastNameController.text = (data['lastName'] as String? ?? '').trim();
      _emailController.text = (data['email'] as String? ?? '').trim();
      setState(() => _initialLoadDone = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialLoadDone = true;
          _loadError = FirebaseErrorHandler.getErrorMessage(e);
        });
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Le mot de passe est requis';
    if (value.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Le mot de passe doit contenir au moins une majuscule';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Le mot de passe doit contenir au moins un chiffre';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas")),
      );
      return;
    }
    if (_inviteData == null) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final pendingMemberId = _inviteData!['pendingMemberId'] as String? ?? '';
    final teamsRaw = _inviteData!['teams'] as List? ?? [];
    final teams = teamsRaw
        .map((e) => e is Map<String, dynamic> ? e : (e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
        .toList();

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final clubId = widget.clubId;
      final teamIds = teams.map((t) => t['teamId'] as String? ?? '').where((s) => s.isNotEmpty).toList();
      final teamNames = teams.map((t) => t['teamName'] as String? ?? '').where((s) => s.isNotEmpty).toList();
      final categories = teams.map((t) => t['category'] as String? ?? '').where((s) => s.isNotEmpty).toList();

      final playerClubEntry = <String, dynamic>{
        'clubId': clubId,
        'teamIds': teamIds,
        'teamNames': teamNames,
        'categories': categories,
      };

      await appFirestore.collection(FirebaseCollections.users).doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'profileCompleted': true,
        'roles': {
          'player': {
            'clubs': [playerClubEntry],
          },
        },
        'activeContext': {
          'role': 'player',
          'clubId': clubId,
        },
      }, SetOptions(merge: true));

      context.read<UserSession>().startListening(uid);

      await appFirestore.collection(FirebaseCollections.clubs).doc(clubId).update({
        'members': FieldValue.arrayUnion([uid]),
      });

      final hasPendingId = pendingMemberId.trim().isNotEmpty;

      for (final t in teams) {
        final teamId = t['teamId'] as String?;
        if (teamId == null || teamId.isEmpty) continue;
        final teamRef = appFirestore
            .collection(FirebaseCollections.clubs)
            .doc(clubId)
            .collection(FirebaseCollections.teams)
            .doc(teamId);
        final updateData = <String, dynamic>{
          'playerIds': FieldValue.arrayUnion([uid]),
          'teamMemberIds': FieldValue.arrayUnion([uid]),
        };
        if (hasPendingId) {
          updateData['pendingPlayerIds'] = FieldValue.arrayRemove([pendingMemberId]);
        }
        await teamRef.update(updateData);
      }

      if (hasPendingId) {
        try {
          final pendingRef = appFirestore
              .collection(FirebaseCollections.clubs)
              .doc(clubId)
              .collection(FirebaseCollections.pendingMembers)
              .doc(pendingMemberId);
          await pendingRef.delete();
        } catch (_) {
          // Doc déjà supprimé ou erreur permission : on continue pour ne pas bloquer l'utilisateur
        }
      }

      await appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.inviteLinks)
          .doc(widget.token)
          .update({'usedAt': FieldValue.serverTimestamp()});

      // Fusionner les autres pending_members (même email) dans d'autres clubs
      try {
        await PendingMemberMergeService.instance.mergePendingMembersForUser(uid, email);
      } catch (_) {}

      if (mounted) widget.onSignUpSuccess?.call();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use' && mounted) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Connexion réussie. Application de l'invitation...",
                ),
                backgroundColor: ViroColors.success,
              ),
            );
          }
          // L'auth a changé : main.dart affichera InviteApplyPage (user connecté + lien invite)
        } on FirebaseAuthException catch (signInError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  signInError.code == 'wrong-password'
                      ? "Un compte existe déjà pour cet email. Mot de passe incorrect. Connectez-vous puis rouvrez le lien d'invitation."
                      : FirebaseErrorHandler.getErrorMessage(signInError),
                ),
                backgroundColor: ViroColors.error,
              ),
            );
          }
        }
      } else if (mounted) {
        FirebaseErrorHandler.showErrorSnackBar(context, e);
      }
    } catch (e) {
      if (mounted) {
        FirebaseErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialLoadDone) {
      return const Scaffold(
        body: Center(child: ViroLoader(size: 50)),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Lien d'invitation")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Retour"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Créer votre compte"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: "Prénom",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Saisissez le prénom.";
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: "Nom",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Saisissez le nom.";
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Mot de passe",
                  border: OutlineInputBorder(),
                ),
                validator: _validatePassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirmer le mot de passe",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Confirmez le mot de passe.";
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: ViroColors.primary,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Créer mon compte"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
