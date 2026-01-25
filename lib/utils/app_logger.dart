import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logger/logger.dart';

/// Service de logging centralisé pour l'application ViroTeam
/// 
/// Fournit des méthodes de logging avec différents niveaux :
/// - [debug] : Informations de développement (uniquement en mode debug)
/// - [info] : Actions utilisateur normales
/// - [warning] : Situations suspectes mais non critiques
/// - [error] : Erreurs nécessitant une attention
/// 
/// Exemple d'utilisation :
/// ```dart
/// AppLogger.instance.info('Utilisateur connecté', {'userId': userId});
/// AppLogger.instance.error('Erreur Firebase', error: e, stackTrace: st);
/// ```
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static AppLogger get instance => _instance;

  late final Logger _logger;

  /// Initialise le logger avec la configuration appropriée selon l'environnement
  void init() {
    _logger = Logger(
      printer: kDebugMode ? PrettyPrinter() : SimplePrinter(),
      level: kDebugMode ? Level.debug : Level.info,
      output: _MultiOutput([
        ConsoleOutput(),
        if (!kDebugMode) _CrashlyticsOutput(),
      ]),
    );
  }

  /// Log de niveau debug (uniquement en mode debug)
  /// 
  /// Utilisé pour les informations de développement détaillées
  void debug(String message, [Map<String, dynamic>? context]) {
    if (kDebugMode) {
      _logger.d(_formatMessage(message, context));
    }
  }

  /// Log de niveau info
  /// 
  /// Utilisé pour les actions utilisateur normales (connexion, création, etc.)
  void info(String message, [Map<String, dynamic>? context]) {
    _logger.i(_formatMessage(message, context));
  }

  /// Log de niveau warning
  /// 
  /// Utilisé pour les situations suspectes mais non critiques
  void warning(String message, [Map<String, dynamic>? context]) {
    _logger.w(_formatMessage(message, context));
  }

  /// Log de niveau error
  /// 
  /// Utilisé pour les erreurs nécessitant une attention
  /// En production, envoie également l'erreur à Crashlytics
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final formattedMessage = _formatMessage(message, context);
    _logger.e(formattedMessage, error: error, stackTrace: stackTrace);

    // Envoyer à Crashlytics en production
    if (!kDebugMode && error != null) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace ?? StackTrace.current,
        fatal: false,
        reason: formattedMessage,
      );
    }
  }

  /// Formate le message avec le contexte
  String _formatMessage(String message, Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) {
      return message;
    }
    final contextStr = context.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    return '$message | $contextStr';
  }
}

/// Output personnalisé pour envoyer les erreurs à Crashlytics
class _CrashlyticsOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Seulement envoyer les erreurs à Crashlytics
    if (event.level == Level.error) {
      for (final line in event.lines) {
        FirebaseCrashlytics.instance.log(line);
      }
    }
  }
}

/// Output qui combine plusieurs outputs
class _MultiOutput extends LogOutput {
  final List<LogOutput> outputs;

  _MultiOutput(this.outputs);

  @override
  void output(OutputEvent event) {
    for (final output in outputs) {
      output.output(event);
    }
  }
}
