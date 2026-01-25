import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/pages/onboarding_page.dart';
import 'player_pages/player_home_page.dart';
import '../theme/viro_theme.dart';
import '../widget/viro_loader.dart';
import '../utils/app_logger.dart';
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
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
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
            await FirebaseAuth.instance.signOut();
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
      await _handleNavigation();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Nouvelle logique de redirection
  Future<void> _handleNavigation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Récupération des données utilisateur
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final data = userDoc.data();
    final hasPendingRequest = data?['hasPendingRequest'] == true;
    final hasClub = data?['clubId'] != null;

    if (hasPendingRequest || hasClub) {
      // Soit déjà membre, soit en attente : on atterrit sur HomePage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PlayerHomePage()),
      );
    } else {
      // Pas de club ni de demande en cours : sélection de rôle
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
      );
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
    );
  }
}
