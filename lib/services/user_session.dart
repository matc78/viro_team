import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Service de gestion de la session utilisateur
/// Gère le contexte actif et les changements de profil
class UserSession extends ChangeNotifier {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  
  /// Rôle actuel basé sur activeContext
  String? get currentRole => _currentUser?.activeContext?.role;
  
  /// Club actuel basé sur activeContext
  String? get currentClubId => _currentUser?.activeContext?.clubId;
  
  /// Vérifie si le contexte actif est valide
  bool get hasValidContext => _currentUser?.activeContext?.isValid ?? false;

  /// Charge l'utilisateur depuis Firestore
  Future<void> loadUser(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'utilisateur: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Écoute les changements du document utilisateur en temps réel
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  /// Démarre l'écoute en temps réel des changements utilisateur
  void startListening(String uid) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
      } else {
        _currentUser = null;
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Erreur lors de l\'écoute utilisateur: $error');
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Arrête l'écoute
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _currentUser = null;
    notifyListeners();
  }

  /// Change le contexte actif (role + clubId)
  /// Met à jour activeContext dans Firestore
  Future<bool> switchContext(String role, String clubId) async {
    if (_currentUser == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'activeContext': {
          'role': role,
          'clubId': clubId,
        },
      });

      // Le listener mettra à jour _currentUser automatiquement
      return true;
    } catch (e) {
      debugPrint('Erreur lors du changement de contexte: $e');
      return false;
    }
  }

  /// Vérifie si l'utilisateur peut changer vers un contexte spécifique
  bool canSwitchTo(String role, String clubId) {
    if (_currentUser == null) return false;
    return _currentUser!.hasRoleInClub(role, clubId);
  }

  /// Retourne tous les profils disponibles pour le switcher
  List<ProfileOption> getAvailableProfiles() {
    if (_currentUser == null) return [];

    final List<ProfileOption> profiles = [];

    // Profil Player (peut avoir plusieurs clubs)
    if (_currentUser!.roles.player != null) {
      for (var club in _currentUser!.roles.player!.clubs) {
        profiles.add(ProfileOption(
          role: 'player',
          clubId: club.clubId ?? '',
          clubName: null, // Sera chargé depuis Firestore si nécessaire
          displayName: 'Joueur',
        ));
      }
    }

    // Profils Coach
    for (var coach in _currentUser!.roles.coach) {
      profiles.add(ProfileOption(
        role: 'coach',
        clubId: coach.clubId ?? '',
        clubName: null,
        displayName: 'Coach',
      ));
    }

    // Profils Admin
    for (var clubId in _currentUser!.roles.admin) {
      profiles.add(ProfileOption(
        role: 'admin',
        clubId: clubId,
        clubName: null,
        displayName: 'Administrateur',
      ));
    }

    return profiles;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

/// Option de profil pour le switcher
class ProfileOption {
  final String role;
  final String clubId;
  final String? clubName;
  final String displayName;

  ProfileOption({
    required this.role,
    required this.clubId,
    this.clubName,
    required this.displayName,
  });
}
