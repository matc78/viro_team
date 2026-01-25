import 'package:flutter/material.dart';
import '../utils/connectivity_checker.dart';
import '../theme/viro_theme.dart';

class NoInternetPage extends StatefulWidget {
  final VoidCallback? onConnectionRestored;
  
  const NoInternetPage({
    super.key,
    this.onConnectionRestored,
  });

  @override
  State<NoInternetPage> createState() => _NoInternetPageState();
}

class _NoInternetPageState extends State<NoInternetPage> {
  bool _isChecking = false;

  Future<void> _checkConnection() async {
    setState(() {
      _isChecking = true;
    });

    final hasConnection = await ConnectivityChecker.hasInternetConnection();

    if (hasConnection && mounted) {
      if (widget.onConnectionRestored != null) {
        widget.onConnectionRestored!();
      } else {
        // Si pas de callback, on peut juste reconstruire
        Navigator.of(context).pop();
      }
    } else if (mounted) {
      setState(() {
        _isChecking = false;
      });
      // Afficher un message que la connexion n'est toujours pas disponible
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune connexion internet détectée. Veuillez vérifier votre connexion.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 100,
                color: ViroColors.error,
              ),
              const SizedBox(height: 32),
              Text(
                'Pas de connexion internet',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Veuillez vous connecter à internet pour utiliser l\'application.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkConnection,
                icon: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isChecking ? 'Vérification...' : 'Actualiser'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
