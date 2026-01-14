import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Gère les erreurs Firebase et retourne un message utilisateur approprié
class FirebaseErrorHandler {
  /// Retourne un message d'erreur utilisateur-friendly basé sur l'erreur Firebase
  static String getErrorMessage(Object? error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Vous n\'avez pas les permissions nécessaires pour cette action.';
        case 'unavailable':
          return 'Service temporairement indisponible. Veuillez réessayer plus tard.';
        case 'unauthenticated':
          return 'Vous devez être connecté pour effectuer cette action.';
        case 'not-found':
          return 'Ressource introuvable.';
        case 'already-exists':
          return 'Cette ressource existe déjà.';
        case 'deadline-exceeded':
          return 'La requête a pris trop de temps. Veuillez réessayer.';
        case 'resource-exhausted':
          return 'Limite de requêtes atteinte. Veuillez réessayer plus tard.';
        case 'failed-precondition':
          return 'Condition requise non remplie.';
        case 'aborted':
          return 'L\'opération a été annulée.';
        case 'out-of-range':
          return 'Valeur hors limites.';
        case 'unimplemented':
          return 'Cette fonctionnalité n\'est pas encore implémentée.';
        case 'internal':
          return 'Erreur interne du serveur. Veuillez réessayer.';
        case 'cancelled':
          return 'Opération annulée.';
        default:
          return error.message ?? 'Une erreur est survenue : ${error.code}';
      }
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Aucun utilisateur trouvé avec cet email.';
        case 'wrong-password':
          return 'Mot de passe incorrect.';
        case 'email-already-in-use':
          return 'Cet email est déjà utilisé.';
        case 'weak-password':
          return 'Le mot de passe est trop faible.';
        case 'invalid-email':
          return 'Adresse email invalide.';
        case 'user-disabled':
          return 'Ce compte a été désactivé.';
        case 'too-many-requests':
          return 'Trop de tentatives. Veuillez réessayer plus tard.';
        case 'operation-not-allowed':
          return 'Cette opération n\'est pas autorisée.';
        default:
          return error.message ?? 'Erreur d\'authentification : ${error.code}';
      }
    }
    return 'Une erreur inattendue est survenue.';
  }

  /// Affiche un SnackBar avec le message d'erreur
  static void showErrorSnackBar(BuildContext context, Object? error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getErrorMessage(error)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Retourne un widget d'erreur pour les StreamBuilder/FutureBuilder
  static Widget buildErrorWidget(
    BuildContext context,
    Object? error, {
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              getErrorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
