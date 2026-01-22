import 'dart:async';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    // Attendre 2 secondes avant de naviguer vers l'écran principal
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.child),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
