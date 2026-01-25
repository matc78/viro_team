import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service de retry avec backoff exponentiel pour les opérations réseau
class RetryService {
  RetryService._(); // Constructeur privé pour empêcher l'instanciation

  /// Nombre maximum de tentatives
  static const int maxRetries = 3;

  /// Délai initial en millisecondes
  static const int initialDelayMs = 500;

  /// Multiplicateur pour le backoff exponentiel
  static const double backoffMultiplier = 2.0;

  /// Vérifie si une erreur est récupérable (réseau temporaire, timeout, etc.)
  static bool isRetryableError(Object error) {
    // Erreurs réseau récupérables
    if (error is SocketException) {
      return true;
    }

    // Erreurs d'authentification récupérables (vérifier avant FirebaseException,
    // car FirebaseAuthException étend FirebaseException)
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
          return true;
        default:
          return false;
      }
    }

    // Erreurs Firebase récupérables
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
        case 'resource-exhausted':
        case 'internal':
          return true;
        default:
          return false;
      }
    }

    // Vérifier les messages d'erreur pour les problèmes réseau
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return true;
    }

    return false;
  }

  /// Calcule le délai avant la prochaine tentative (backoff exponentiel)
  static Duration _calculateDelay(int attempt) {
    final delayMs = (initialDelayMs * 
        (backoffMultiplier * attempt)).round();
    return Duration(milliseconds: delayMs);
  }

  /// Exécute une fonction avec retry automatique
  /// 
  /// [operation] : La fonction à exécuter
  /// [maxRetries] : Nombre maximum de tentatives (par défaut 3)
  /// [onRetry] : Callback appelé avant chaque retry (optionnel)
  /// 
  /// Retourne le résultat de l'opération ou lance l'erreur si toutes les tentatives échouent
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = RetryService.maxRetries,
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (error) {
        attempt++;
        
        // Si ce n'est pas une erreur récupérable ou qu'on a atteint le max, lancer l'erreur
        if (!isRetryableError(error) || attempt >= maxRetries) {
          rethrow;
        }
        
        // Calculer le délai avant le prochain retry
        final delay = _calculateDelay(attempt);
        
        // Appeler le callback si fourni
        if (onRetry != null) {
          onRetry(attempt, delay);
        }
        
        // Attendre avant de réessayer
        await Future.delayed(delay);
      }
    }
    
    // Ne devrait jamais arriver ici, mais au cas où
    throw Exception('Retry épuisé après $maxRetries tentatives');
  }

  /// Exécute une opération Firestore avec retry
  static Future<T> executeFirestoreWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = RetryService.maxRetries,
    void Function(int attempt, Duration delay)? onRetry,
  }) {
    return executeWithRetry<T>(
      operation: operation,
      maxRetries: maxRetries,
      onRetry: onRetry,
    );
  }

  /// Exécute une opération Firebase Auth avec retry
  static Future<T> executeAuthWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = RetryService.maxRetries,
    void Function(int attempt, Duration delay)? onRetry,
  }) {
    return executeWithRetry<T>(
      operation: operation,
      maxRetries: maxRetries,
      onRetry: onRetry,
    );
  }
}
