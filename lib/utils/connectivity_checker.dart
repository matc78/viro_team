import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Utilitaire pour vérifier la connexion internet
class ConnectivityChecker {
  /// Vérifie si l'appareil a une connexion internet active
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      // Si pas de connexion réseau du tout
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // Vérifier si on peut vraiment accéder à internet en faisant un lookup DNS
      // On essaie de résoudre un domaine fiable (Google DNS)
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
