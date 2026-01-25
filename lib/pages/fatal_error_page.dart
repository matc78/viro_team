import 'package:flutter/material.dart';
import 'package:viro_team/theme/viro_theme.dart';

/// Page affichée en cas d'erreur fatale lors de l'initialisation de l'application
class FatalErrorPage extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const FatalErrorPage({
    super.key,
    required this.error,
    this.stackTrace,
  });

  String _getErrorMessage() {
    final errorString = error.toString().toLowerCase();
    
    // Erreurs Firebase
    if (errorString.contains('firebase') || errorString.contains('firestore')) {
      return 'Impossible d\'initialiser les services Firebase. '
          'Vérifiez votre connexion internet et réessayez.';
    }
    
    // Erreurs réseau
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('timeout')) {
      return 'Problème de connexion internet. '
          'Vérifiez votre connexion réseau et réessayez.';
    }
    
    // Erreur générique
    return 'Une erreur critique est survenue lors du démarrage de l\'application.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: ViroColors.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Erreur de démarrage',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _getErrorMessage(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    // Redémarrer l'application
                    // Note: En production, cela pourrait nécessiter un redémarrage complet
                    // Pour l'instant, on affiche juste un message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Veuillez redémarrer l\'application manuellement',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
                if (stackTrace != null) ...[
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text(
                      'Détails techniques',
                      style: TextStyle(fontSize: 12),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SelectableText(
                          'Erreur: $error\n\nStackTrace:\n$stackTrace',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
