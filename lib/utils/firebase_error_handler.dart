import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

/// Gère les erreurs Firebase et retourne un message utilisateur approprié
class FirebaseErrorHandler {
  /// Retourne un message d'erreur utilisateur-friendly basé sur l'erreur Firebase
  static String getErrorMessage(Object? error, [StackTrace? stackTrace]) {
    // Enregistrer l'erreur dans Crashlytics (non-fatal)
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace ?? StackTrace.current,
      fatal: false,
    );
    // Gestion des erreurs réseau (connexion internet)
    if (error is SocketException) {
      return 'Problème de connexion internet. Vérifiez votre connexion réseau et réessayez.';
    }

    // Convertir l'erreur en string pour vérifier les patterns réseau
    final errorString = error.toString().toLowerCase();

    // Vérifier les erreurs de timeout via le message d'erreur
    if (errorString.contains('timeoutexception') ||
        errorString.contains('timeout exception')) {
      return 'La connexion a pris trop de temps. Vérifiez votre connexion internet et réessayez.';
    }

    // Gestion des erreurs Firebase
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Vous n\'avez pas les permissions nécessaires pour cette action.';
        case 'unavailable':
          return 'Service temporairement indisponible. Vérifiez votre connexion internet et réessayez.';
        case 'unauthenticated':
          return 'Vous devez être connecté pour effectuer cette action.';
        case 'not-found':
          return 'Ressource introuvable.';
        case 'already-exists':
          return 'Cette ressource existe déjà.';
        case 'deadline-exceeded':
          return 'La requête a pris trop de temps. Vérifiez votre connexion internet et réessayez.';
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
          // Vérifier si le message d'erreur contient des indices de problème réseau
          final errorMessage = error.message?.toLowerCase() ?? '';
          if (errorMessage.contains('network') ||
              errorMessage.contains('connection') ||
              errorMessage.contains('socket') ||
              errorMessage.contains('timeout') ||
              errorMessage.contains('unable to resolve host') ||
              errorMessage.contains('eai_nodata') ||
              errorMessage.contains('no address associated with hostname') ||
              errorMessage.contains('unknownhostexception')) {
            return 'Problème de connexion internet. Vérifiez votre connexion réseau et réessayez.';
          }
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
        case 'network-request-failed':
          return 'Erreur de connexion réseau. Vérifiez votre connexion internet.';
        default:
          return error.message ?? 'Erreur d\'authentification : ${error.code}';
      }
    }

    // Vérifier si l'erreur générique contient des indices de problème réseau
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('timeout') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no internet') ||
        errorString.contains('unable to resolve host') ||
        errorString.contains('eai_nodata') ||
        errorString.contains('no address associated with hostname') ||
        errorString.contains('unknownhostexception')) {
      return 'Problème de connexion internet. Vérifiez votre connexion réseau et réessayez.';
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
            Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
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
