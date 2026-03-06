import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../models/user_model.dart';
import '../utils/app_logger.dart';

/// Service de gestion de la session utilisateur
/// Gère le contexte actif et les changements de profil
/// Utilise UserProfile (profileSummaries) et fusionne avatar_moderation depuis la sous-collection
class UserSession extends ChangeNotifier {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  UserProfile? _currentUser;
  bool _isLoading = false;
  bool _hasServerSnapshot = false;

  /// Cache du dernier doc user et modération pour fusion lors des doubles abonnements
  Map<String, dynamic>? _lastUserData;
  Map<String, dynamic>? _lastModerationData;
  String? _listeningUid;

  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  /// True après le premier snapshot venu du serveur (pas du cache).
  bool get hasServerSnapshot => _hasServerSnapshot;

  /// Rôle actuel basé sur activeContext
  String? get currentRole => _currentUser?.activeContext?.role;

  /// Club actuel basé sur activeContext
  String? get currentClubId => _currentUser?.activeContext?.clubId;

  /// Vérifie si le contexte actif est valide
  bool get hasValidContext => _currentUser?.activeContext?.isValid ?? false;

  void _applyMerge(String uid) {
    final userData = _lastUserData;
    if (userData == null) return;
    final merged = Map<String, dynamic>.from(userData);
    final mod = _lastModerationData;
    if (mod != null) {
      merged['avatarModerationRejected'] = mod['avatarModerationRejected'];
      merged['avatarModerationPending'] = mod['avatarModerationPending'];
      merged['avatarModerationReason'] = mod['avatarModerationReason'];
      merged['avatarModerationRejectedAt'] = mod['avatarModerationRejectedAt'];
      merged['avatarModerationOk'] = mod['avatarModerationOk'];
    } else {
      merged['avatarModerationRejected'] = false;
      merged['avatarModerationPending'] = false;
      merged['avatarModerationReason'] = null;
      merged['avatarModerationRejectedAt'] = null;
      merged['avatarModerationOk'] = false;
    }
    _currentUser = UserProfile.fromMergedData(uid, merged);
  }

  /// Charge l'utilisateur depuis Firestore (user doc + avatar_moderation/state)
  Future<void> loadUser(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userRef = appFirestore
          .collection(FirebaseCollections.users)
          .doc(uid);
      final modRef = userRef
          .collection(FirebaseCollections.avatarModeration)
          .doc(FirebaseCollections.avatarModerationStateDocId);

      final userSnap = await userRef.get();
      final modSnap = await modRef.get();

      if (!userSnap.exists) {
        _currentUser = null;
        _lastUserData = null;
        _lastModerationData = null;
      } else {
        _lastUserData = userSnap.data();
        _lastModerationData = modSnap.exists ? modSnap.data() : null;
        _applyMerge(uid);
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors du chargement de l\'utilisateur',
        error: e,
        context: {'userId': uid},
      );
      _currentUser = null;
      _lastUserData = null;
      _lastModerationData = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subUser;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subModeration;

  /// Démarre l'écoute en temps réel (user doc + avatar_moderation/state)
  void startListening(String uid) {
    _subUser?.cancel();
    _subModeration?.cancel();
    _isLoading = true;
    _hasServerSnapshot = false;
    _listeningUid = uid;
    _lastUserData = null;
    _lastModerationData = null;
    notifyListeners();

    final userRef = appFirestore
        .collection(FirebaseCollections.users)
        .doc(uid);
    final modRef = userRef
        .collection(FirebaseCollections.avatarModeration)
        .doc(FirebaseCollections.avatarModerationStateDocId);

    void onUpdate() {
      if (_lastUserData == null) {
        _currentUser = null;
      } else {
        _applyMerge(uid);
        final u = _currentUser;
        if (u != null &&
            u.hasAnyRole &&
            !u.isActiveContextCoherent) {
          restoreActiveContextIfNeeded();
        }
      }
      _isLoading = false;
      notifyListeners();
    }

    _subUser = userRef.snapshots().listen((doc) {
      try {
        if (!doc.metadata.isFromCache) _hasServerSnapshot = true;
        if (doc.exists) {
          _lastUserData = doc.data();
        } else {
          _lastUserData = null;
          _lastModerationData = null;
          _currentUser = null;
        }
        onUpdate();
      } catch (e, st) {
        AppLogger.instance.error(
          'Erreur parsing user doc',
          error: e,
          stackTrace: st,
          context: {'userId': uid},
        );
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (error) {
      AppLogger.instance.error(
        'Erreur écoute user',
        error: error,
        context: {'userId': uid},
      );
      _isLoading = false;
      notifyListeners();
    });

    _subModeration = modRef.snapshots().listen((doc) {
      _lastModerationData = doc.exists ? doc.data() : null;
      if (_listeningUid == uid && _lastUserData != null) {
        _applyMerge(uid);
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (_) {
      if (_listeningUid == uid) {
        _lastModerationData = null;
        if (_lastUserData != null) {
          _applyMerge(uid);
        }
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  /// Arrête l'écoute
  void stopListening() {
    _subUser?.cancel();
    _subModeration?.cancel();
    _subUser = null;
    _subModeration = null;
    _currentUser = null;
    _lastUserData = null;
    _lastModerationData = null;
    _listeningUid = null;
    _hasServerSnapshot = false;
    notifyListeners();
  }

  /// Annule uniquement l'abonnement Firestore sans effacer [currentUser].
  void cancelListeningOnly() {
    _subUser?.cancel();
    _subModeration?.cancel();
    _subUser = null;
    _subModeration = null;
  }

  /// Restaure activeContext à partir de profileSummaries (priorité : admin_fondateur > admin > coach > player)
  Future<bool> restoreActiveContextIfNeeded() async {
    final u = _currentUser;
    if (u == null) return false;
    if (u.isActiveContextCoherent) return false;

    String? role;
    String? clubId;
    final summaries = u.profileSummaries;
    final fondateur = summaries.where((s) => s.role == 'admin_fondateur').toList();
    final admin = summaries.where((s) => s.role == 'admin').toList();
    final coach = summaries.where((s) => s.role == 'coach').toList();
    final player = summaries.where((s) => s.role == 'player').toList();

    if (fondateur.isNotEmpty) {
      role = 'admin_fondateur';
      clubId = fondateur.first.clubId;
    } else if (admin.isNotEmpty) {
      role = 'admin';
      clubId = admin.first.clubId;
    } else if (coach.isNotEmpty) {
      role = 'coach';
      clubId = coach.first.clubId;
    } else if (player.isNotEmpty) {
      role = 'player';
      clubId = player.first.clubId;
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

  bool canSwitchTo(String role, String clubId) {
    final u = _currentUser;
    if (u == null) return false;
    return u.hasRoleInClub(role, clubId);
  }

  /// Profils disponibles pour le switcher (depuis profileSummaries)
  List<ProfileOption> getAvailableProfiles() {
    final u = _currentUser;
    if (u == null) return [];

    String displayNameFor(String role) {
      switch (role) {
        case 'player':
          return 'Joueur';
        case 'coach':
          return 'Coach';
        case 'admin_fondateur':
          return 'Administrateur fondateur';
        case 'admin':
          return 'Administrateur';
        default:
          return role;
      }
    }

    final fondateurClubIds = u.profileSummaries
        .where((s) => s.role == 'admin_fondateur')
        .map((s) => s.clubId)
        .toSet();
    return u.profileSummaries
        .where((s) {
          if (s.role == 'admin' && fondateurClubIds.contains(s.clubId)) {
            return false;
          }
          return true;
        })
        .map((s) => ProfileOption(
              role: s.role,
              clubId: s.clubId,
              clubName: null,
              displayName: displayNameFor(s.role),
            ))
        .toList();
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
