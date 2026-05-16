import 'package:flutter/foundation.dart';

/// Notifie [GoRouter] lors d'un changement d'état auth/session.
class RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
