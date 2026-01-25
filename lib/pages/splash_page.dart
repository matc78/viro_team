import 'dart:async';
import 'package:flutter/material.dart';
import '../pages/no_internet_page.dart';
import '../utils/connectivity_checker.dart';
import '../widget/viro_loader.dart';

class SplashPage extends StatefulWidget {
  final Widget child;
  
  const SplashPage({
    super.key,
    required this.child,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _hasCheckedConnection = false;
  bool _hasInternet = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final hasConnection = await ConnectivityChecker.hasInternetConnection();
    
    if (mounted) {
      setState(() {
        _hasCheckedConnection = true;
        _hasInternet = hasConnection;
      });

      if (hasConnection) {
        // Attendre 2 secondes avant de naviguer vers l'écran principal
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => widget.child),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si pas de connexion, afficher la page "pas de connexion"
    if (_hasCheckedConnection && !_hasInternet) {
      return NoInternetPage(
        onConnectionRestored: () {
          // Quand la connexion est restaurée, on revient au splash et on continue
          _checkConnection();
        },
      );
    }

    // Sinon, afficher le splash screen normal
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo principal
            Image.asset(
              'assets/logo/logo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.sports_soccer,
                  size: 200,
                  color: Colors.blue,
                );
              },
            ),
            const SizedBox(height: 40),
            // ViroLoader
            const ViroLoader(size: 60),
          ],
        ),
      ),
    );
  }
}
