import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_logger.dart';

/// Déconnexion complète : Google Sign-In + Firebase Auth.
/// Nécessaire pour permettre une reconnexion Google propre (évite le blocage
/// sur la page de connexion après reconnexion).
Future<void> signOutCompletely() async {
  try {
    await GoogleSignIn().signOut();
  } catch (e) {
    // Ignorer les erreurs Google (ex. jamais connecté via Google)
    AppLogger.instance.error('GoogleSignIn.signOut failed', error: e);
  }
  await FirebaseAuth.instance.signOut();
}
