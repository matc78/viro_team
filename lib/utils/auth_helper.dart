import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Déconnexion complète : Google Sign-In + Firebase Auth.
/// Nécessaire pour permettre une reconnexion Google propre (évite le blocage
/// sur la page de connexion après reconnexion).
Future<void> signOutCompletely() async {
  try {
    await GoogleSignIn().signOut();
  } catch (_) {
    // Ignorer les erreurs Google (ex. jamais connecté via Google)
  }
  await FirebaseAuth.instance.signOut();
}
