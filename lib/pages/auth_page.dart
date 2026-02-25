import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/pages/onboarding_page.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_home_page.dart';
import 'player_pages/player_home_page.dart';
import '../theme/viro_theme.dart';
import '../widget/viro_loader.dart';
import '../utils/app_logger.dart';
import '../utils/auth_helper.dart';
import '../utils/firebase_error_handler.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // 1. Nouveau contrôleur pour la confirmation
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  /// Valide le format de l'email
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Format d\'email invalide';
    }
    return null;
  }

  /// Valide la complexité du mot de passe
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas")),
      );
      return;
    }

    setState(() => _isLoading = true);
    bool authSuccess = false;

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = FirebaseAuth.instance.currentUser;
        AppLogger.instance.info(
          'Connexion réussie',
          {'userId': user?.uid, 'email': _emailController.text.trim()},
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = cred.user;
        if (user != null) {
          try {
            await appFirestore.collection(FirebaseCollections.users).doc(user.uid).set({
              'firstName': _firstNameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
              'email': user.email,
              'createdAt': FieldValue.serverTimestamp(),
              // On ne met pas de clubId ici, il sera ajouté lors de l'acceptation
            }, SetOptions(merge: true));
            AppLogger.instance.info(
              'Compte créé avec succès',
              {
                'userId': user.uid,
                'email': user.email,
                'firstName': _firstNameController.text.trim(),
                'lastName': _lastNameController.text.trim(),
              },
            );
          } catch (e) {
            AppLogger.instance.error(
              'Erreur lors de la création du document utilisateur',
              error: e,
              context: {'userId': user.uid, 'email': user.email},
            );
            FirebaseErrorHandler.showErrorSnackBar(context, e);
            // Déconnecter l'utilisateur si la création du document échoue
            await signOutCompletely();
            return;
          }
        }
      }
      authSuccess = true;
    } on FirebaseAuthException catch (e) {
      AppLogger.instance.error(
        _isLogin ? 'Erreur de connexion' : 'Erreur de création de compte',
        error: e,
        context: {
          'email': _emailController.text.trim(),
          'errorCode': e.code,
        },
      );
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    } catch (e) {
      AppLogger.instance.error(
        _isLogin ? 'Erreur inattendue lors de la connexion' : 'Erreur inattendue lors de la création de compte',
        error: e,
        context: {'email': _emailController.text.trim()},
      );
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }

    if (authSuccess) {
      TextInput.finishAutofillContext();
      await _handleNavigation();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Extrait prénom et nom depuis displayName (ex: "Jean Dupont" -> prénom="Jean", nom="Dupont")
  (String firstName, String lastName) _parseDisplayName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return ('', '');
    }
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final firstName = parts.firstOrNull ?? '';
    final lastName = parts.skip(1).join(' ');
    return (firstName, lastName);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Android : Web client ID (client_type 3) depuis google-services.json
      // iOS : utilise le client par défaut du GoogleService-Info.plist
      final serverClientId = defaultTargetPlatform == TargetPlatform.android
          ? '396501317680-afnku6clj84s00aa5f8ejcjm4oigphom.apps.googleusercontent.com'
          : null;
      final googleSignIn = GoogleSignIn(serverClientId: serverClientId);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final isNewUser = userCredential.additionalUserInfo?.isNewUser == true;

      if (isNewUser) {
        final (firstName, lastName) = _parseDisplayName(user.displayName);
        try {
          await appFirestore
              .collection(FirebaseCollections.users)
              .doc(user.uid)
              .set({
            'firstName': firstName,
            'lastName': lastName,
            'email': user.email,
            'avatarUrl': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'profileCompleted': false,
          }, SetOptions(merge: true));
          AppLogger.instance.info(
            'Compte Google créé',
            {
              'userId': user.uid,
              'email': user.email,
              'firstName': firstName,
              'lastName': lastName,
            },
          );
        } catch (e) {
          AppLogger.instance.error(
            'Erreur création document utilisateur Google',
            error: e,
            context: {'userId': user.uid},
          );
          FirebaseErrorHandler.showErrorSnackBar(context, e);
          await signOutCompletely();
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      } else {
        AppLogger.instance.info(
          'Connexion Google réussie',
          {'userId': user.uid, 'email': user.email},
        );
        // Navigation explicite pour éviter le blocage sur la page de connexion
        // (l'AuthGate peut avoir un délai/race avec UserSession)
        await _handleNavigation();
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.instance.error(
        'Erreur connexion Google',
        error: e,
        context: {'errorCode': e.code},
      );
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    } catch (e) {
      AppLogger.instance.error(
        'Erreur inattendue connexion Google',
        error: e,
      );
      FirebaseErrorHandler.showErrorSnackBar(context, e);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Redirection après connexion - utilise activeContext/roles pour éviter
  // d'afficher PlayerHomePage quand l'utilisateur est admin/coach.
  Future<void> _handleNavigation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await appFirestore
        .collection(FirebaseCollections.users)
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final data = userDoc.data() ?? {};
    final activeContext = data['activeContext'] as Map<String, dynamic>?;
    final activeRole = activeContext?['role'] as String?;
    final hasPendingRequest = data['hasPendingRequest'] == true;
    final roles = data['roles'] as Map<String, dynamic>? ?? {};
    final hasAdminOrCoach = _hasRoleIn(roles, 'admin_fondateur') ||
        _hasRoleIn(roles, 'admin') ||
        _hasRoleIn(roles, 'coach');
    final hasPlayer = roles['player'] != null;

    if (hasPendingRequest) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PlayerHomePage()),
      );
      return;
    }
    if (activeRole == 'admin_fondateur' ||
        activeRole == 'admin' ||
        activeRole == 'coach') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminHomePage()),
      );
      return;
    }
    if (activeRole == 'player' || (hasPlayer && !hasAdminOrCoach)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PlayerHomePage()),
      );
      return;
    }
    if (hasAdminOrCoach) {
      // Rôle admin/coach mais pas d'activeContext : AuthGate gérera la restauration
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingPage()),
    );
  }

  bool _hasRoleIn(Map<String, dynamic> roles, String roleKey) {
    final val = roles[roleKey] ??
        (roleKey == 'admin_fondateur' ? roles['adminFondateur'] : null);
    if (val == null) return false;
    if (val is List) return val.isNotEmpty;
    if (val is Map) return val.isNotEmpty;
    if (val is String) return val.isNotEmpty;
    return false;
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Utilisation du logo JPG selon tes assets
                Image.asset('assets/logo/logo.png', height: 150),
                const SizedBox(height: 40),

                Text(
                  _isLogin ? "Bon retour !" : "Rejoins ViroTeam",
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 30),

                if (!_isLogin) ...[
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: "Prénom",
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le prénom est requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: "Nom",
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom est requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints:
                      _isLogin ? [AutofillHints.password] : [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: "Mot de passe",
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: _isLogin ? null : _validatePassword,
                ),

                // 3. Affichage conditionnel du champ de confirmation
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: "Confirmer le mot de passe",
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez confirmer le mot de passe';
                      }
                      if (value != _passwordController.text) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const ViroLoader(size: 30)
                        : Text(_isLogin ? "SE CONNECTER" : "CRÉER UN COMPTE"),
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "ou",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                    label: const Text("Continuer avec Google"),
                  ),
                ),

                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? "Pas encore de compte ? Inscris-toi"
                        : "Déjà un compte ? Connecte-toi",
                    style: const TextStyle(color: ViroColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
