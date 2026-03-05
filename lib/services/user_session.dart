import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:viro_team/utils/firestore_instance.dart';
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
  bool _hasServerSnapshot = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  /// True après le premier snapshot venu du serveur (pas du cache).
  /// Évite de restaurer activeContext sur des données Firestore en cache obsolètes.
  bool get hasServerSnapshot => _hasServerSnapshot;

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
      final doc = await appFirestore
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
    _hasServerSnapshot = false;
    notifyListeners();

    _subscription = appFirestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
            try {
              if (!doc.metadata.isFromCache) _hasServerSnapshot = true;
              if (doc.exists) {
                _currentUser = UserModel.fromFirestore(doc);
                final u = _currentUser;
                if (u != null &&
                    !doc.metadata.isFromCache &&
                    u.hasAnyRole &&
                    !u.isActiveContextCoherent) {
                  restoreActiveContextIfNeeded();
                }
              } else {
                _currentUser = null;
              }
            } catch (e, st) {
              AppLogger.instance.error('Erreur parsing UserModel', error: e, stackTrace: st, context: {'userId': uid});
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
    _hasServerSnapshot = false;
    notifyListeners();
  }

  /// Annule uniquement l'abonnement Firestore sans effacer [currentUser].
  /// À utiliser pendant la suppression de compte pour éviter PERMISSION_DENIED
  /// et pour ne pas déclencher la redirection AuthPage via currentUser == null.
  void cancelListeningOnly() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Restaure activeContext si celui-ci est manquant, invalide, ou obsolète
  /// (l'utilisateur n'a plus le rôle/club indiqué).
  /// Priorité : admin_fondateur > admin > coach > player.
  /// À appeler après reconnexion pour éviter d'afficher la mauvaise home.
  Future<bool> restoreActiveContextIfNeeded() async {
    final u = _currentUser;
    if (u == null) return false;

    // Ne rien faire si le contexte actuel est valide ET correspond aux rôles réels
    if (u.isActiveContextCoherent) return false;

    String? role;
    String? clubId;
    if (u.roles.adminFondateur.isNotEmpty) {
      role = 'admin_fondateur';
      clubId = u.roles.adminFondateur.first;
    } else if (u.roles.admin.isNotEmpty) {
      role = 'admin';
      clubId = u.roles.admin.first;
    } else if (u.roles.coach.isNotEmpty) {
      role = 'coach';
      clubId = u.roles.coach.first.clubId;
    } else if (u.roles.player != null && u.roles.player!.clubs.isNotEmpty) {
      role = 'player';
      clubId = u.roles.player!.clubs.first.clubId;
    }
    if (role == null || clubId == null || clubId.isEmpty) return false;

    try {
      await appFirestore
          .collection(FirebaseCollections.users)
          .doc(u.uid)
          .update({
        'activeContext': {'role': role, 'clubId': clubId},
      });
      AppLogger.instance.info('Contexte actif restauré', {
        'userId': u.uid,
        'role': role,
        'clubId': clubId,
      });
      return true;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur restauration contexte actif',
        error: e,
        context: {'userId': u.uid},
      );
      return false;
    }
  }

  /// Change le contexte actif (role + clubId)
  /// Met à jour activeContext dans Firestore
  Future<bool> switchContext(String role, String clubId) async {
    final u = _currentUser;
    if (u == null) return false;

    try {
      await appFirestore
          .collection(FirebaseCollections.users)
          .doc(u.uid)
          .update({
            'activeContext': {'role': role, 'clubId': clubId},
          });

      // Le listener mettra à jour _currentUser automatiquement
      AppLogger.instance.info('Changement de contexte actif', {
        'userId': u.uid,
        'role': role,
        'clubId': clubId,
      });
      return true;
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors du changement de contexte',
        error: e,
        context: {'userId': u.uid, 'role': role, 'clubId': clubId},
      );
      return false;
    }
  }

  /// Vérifie si l'utilisateur peut changer vers un contexte spécifique
  bool canSwitchTo(String role, String clubId) {
    final u = _currentUser;
    if (u == null) return false;
    return u.hasRoleInClub(role, clubId);
  }

  /// Retourne tous les profils disponibles pour le switcher
  List<ProfileOption> getAvailableProfiles() {
    final u = _currentUser;
    if (u == null) return [];

    final List<ProfileOption> profiles = [];

    // Profil Player (peut avoir plusieurs clubs)
    final player = u.roles.player;
    if (player != null) {
      for (var club in player.clubs) {
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
    for (var coach in u.roles.coach) {
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
    for (var clubId in u.roles.adminFondateur) {
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
    final fondateurClubIds = u.roles.adminFondateur.toSet();
    for (var clubId in u.roles.admin) {
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
