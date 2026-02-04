import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../models/user_model.dart';
import '../utils/app_logger.dart';

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
          .collection(FirebaseCollections.users)
          .doc(uid)
          .get();

      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors du chargement de l\'utilisateur',
        error: e,
        context: {'userId': uid},
      );
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
        .collection(FirebaseCollections.users)
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists) {
              _currentUser = UserModel.fromFirestore(doc);
            } else {
              _currentUser = null;
            }
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            AppLogger.instance.error(
              'Erreur lors de l\'écoute utilisateur',
              error: error,
              context: {'userId': uid},
            );
            _isLoading = false;
            notifyListeners();
          },
        );
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
          .collection(FirebaseCollections.users)
          .doc(_currentUser!.uid)
          .update({
            'activeContext': {'role': role, 'clubId': clubId},
          });

      // Le listener mettra à jour _currentUser automatiquement
      AppLogger.instance.info('Changement de contexte actif', {
        'userId': _currentUser!.uid,
        'role': role,
        'clubId': clubId,
      });
      return true;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors du changement de contexte',
        error: e,
        context: {'userId': _currentUser!.uid, 'role': role, 'clubId': clubId},
      );
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
        profiles.add(
          ProfileOption(
            role: 'player',
            clubId: club.clubId ?? '',
            clubName: null, // Sera chargé depuis Firestore si nécessaire
            displayName: 'Joueur',
          ),
        );
      }
    }

    // Profils Coach
    for (var coach in _currentUser!.roles.coach) {
      profiles.add(
        ProfileOption(
          role: 'coach',
          clubId: coach.clubId ?? '',
          clubName: null,
          displayName: 'Coach',
        ),
      );
    }

    // Profils Admin fondateur (priorité : afficher "Administrateur fondateur" pour les clubs fondés)
    for (var clubId in _currentUser!.roles.adminFondateur) {
      profiles.add(
        ProfileOption(
          role: 'admin_fondateur',
          clubId: clubId,
          clubName: null,
          displayName: 'Administrateur fondateur',
        ),
      );
    }

    // Profils Admin (uniquement les clubs où il n'est pas fondateur, pour éviter doublons)
    final fondateurClubIds = _currentUser!.roles.adminFondateur.toSet();
    for (var clubId in _currentUser!.roles.admin) {
      if (fondateurClubIds.contains(clubId)) continue;
      profiles.add(
        ProfileOption(
          role: 'admin',
          clubId: clubId,
          clubName: null,
          displayName: 'Administrateur',
        ),
      );
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
