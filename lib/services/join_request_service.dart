import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/services/membership_service.dart';
import 'package:viro_team/utils/app_logger.dart';
import 'package:viro_team/utils/firestore_instance.dart';

/// Service centralisé pour toute la logique de demande d'adhésion à un club.
///
/// Flux joueur :
///   sendRequest → [admin : acceptRequest | refuseRequest] | cancelRequest
///
/// Toutes les écritures Firestore critiques sont regroupées via WriteBatch
/// pour éviter les états partiels.
class JoinRequestService {
  JoinRequestService._();
  static final JoinRequestService instance = JoinRequestService._();

  final _db = appFirestore;

  // ─────────────────────────────────────────────────────────────────────────
  // Envoi / relance d'une demande (côté joueur)
  // ─────────────────────────────────────────────────────────────────────────

  /// Crée ou relance une demande d'adhésion pour [userId] dans [clubId].
  ///
  /// Si une demande `pending` existe déjà pour ce triplet (userId, clubId, role),
  /// le message est concaténé avec la mention [Relance].
  /// Met à jour `users/{userId}.hasPendingRequest = true`.
  Future<void> sendRequest({
    required String userId,
    required String clubId,
    required String clubName,
    required String role,
    required String message,
    required String phone,
    required String firstName,
    required String lastName,
    String? clubSport,
  }) async {
    final requestsRef = _db.collection(FirebaseCollections.joinRequests);

    final existing = await requestsRef
        .where('userId', isEqualTo: userId)
        .where('clubId', isEqualTo: clubId)
        .where('roleRequested', isEqualTo: role)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    final requestData = <String, dynamic>{
      'userId': userId,
      'clubId': clubId,
      'clubName': clubName,
      if (clubSport != null) 'clubSport': clubSport,
      'roleRequested': role,
      'message': message,
      'status': 'pending',
      'firstName': firstName,
      'lastName': lastName,
      if (phone.isNotEmpty) 'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existing.docs.isNotEmpty) {
      final oldMessage = existing.docs.first.data()['message'] as String? ?? '';
      final combined = oldMessage.isEmpty
          ? message
          : '$oldMessage\n\n[Relance] : $message';
      await existing.docs.first.reference.update({
        ...requestData,
        'message': combined,
      });
    } else {
      await requestsRef.add({
        ...requestData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _db.collection(FirebaseCollections.users).doc(userId).set({
      'hasPendingRequest': true,
      'lastClubRequested': clubName,
      'phone': phone,
    }, SetOptions(merge: true));

    AppLogger.instance.info('JoinRequest: demande envoyée', {
      'userId': userId,
      'clubId': clubId,
      'role': role,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Annulation (côté joueur)
  // ─────────────────────────────────────────────────────────────────────────

  /// Annule la demande en attente pour [userId].
  ///
  /// Supprime le(s) document(s) `join_requests` pendants et efface
  /// les flags sur `users/{userId}`.
  Future<void> cancelRequest(String userId) async {
    final pending = await _db
        .collection(FirebaseCollections.joinRequests)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = _db.batch();

    for (final doc in pending.docs) {
      batch.delete(doc.reference);
    }

    batch.set(
      _db.collection(FirebaseCollections.users).doc(userId),
      {
        'hasPendingRequest': false,
        'lastClubRequested': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    AppLogger.instance.info('JoinRequest: demande annulée', {'userId': userId});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Acceptation (côté admin)
  // ─────────────────────────────────────────────────────────────────────────

  /// Accepte la demande [requestId] pour [userId] dans [clubId] avec [role].
  ///
  /// Opérations :
  ///   1. users/{userId} : hasPendingRequest=false, activeContext
  ///   2. clubs/{clubId}.members|coaches|admins : arrayUnion([userId])
  ///   3. clubs/{clubId}/members/{userId} : doc de membership (via MembershipService)
  ///   4. users/{userId}.profileSummaries : entrée ajoutée (via MembershipService)
  ///   5. pending_members fusionnés si même email (via PendingMemberMergeService)
  ///   6. join_requests/{requestId} : supprimé
  ///
  /// Les écritures 1 et 2 sont dans un batch. Les étapes 3-5 passent par
  /// leurs services respectifs. L'étape 6 est la dernière (nettoyage).
  Future<void> acceptRequest({
    required String requestId,
    required String userId,
    required String clubId,
    required String role,
  }) async {
    final normalizedRole = role == 'admin_fondateur' ? 'admin' : role;

    final userDoc = await _db
        .collection(FirebaseCollections.users)
        .doc(userId)
        .get();
    final userData = userDoc.data() ?? {};

    final requestRef = _db
        .collection(FirebaseCollections.joinRequests)
        .doc(requestId);
    final requestSnap = await requestRef.get();
    final license = requestSnap.data()?['license'] as String?;

    final clubField = _clubFieldForRole(normalizedRole);
    final batch = _db.batch();
    batch.set(
      _db.collection(FirebaseCollections.users).doc(userId),
      {
        'hasPendingRequest': false,
        'activeContext': {'role': normalizedRole, 'clubId': clubId},
      },
      SetOptions(merge: true),
    );
    batch.update(
      _db.collection(FirebaseCollections.clubs).doc(clubId),
      {clubField: FieldValue.arrayUnion([userId])},
    );
    await batch.commit();

    await MembershipService.instance.ensureMemberAndProfileSummary(
      uid: userId,
      clubId: clubId,
      role: normalizedRole,
      playerLicense: normalizedRole == 'player' ? license : null,
      userDataOverride: userData,
    );

    // mergePendingMembersForUser non appelé ici : il tourne avec les droits de
    // l'utilisateur (email match), pas de l'admin. Il est déclenché côté joueur
    // via InviteApplyService et invite_signup_page.

    await requestRef.delete();

    AppLogger.instance.info('JoinRequest: demande acceptée', {
      'requestId': requestId,
      'userId': userId,
      'clubId': clubId,
      'role': normalizedRole,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Refus (côté admin)
  // ─────────────────────────────────────────────────────────────────────────

  /// Refuse la demande [requestId] pour [userId].
  ///
  /// Met à jour users/{userId}.hasPendingRequest = false et supprime le doc.
  Future<void> refuseRequest({
    required String requestId,
    required String userId,
    required String? clubId,
  }) async {
    final requestRef = _db
        .collection(FirebaseCollections.joinRequests)
        .doc(requestId);

    final batch = _db.batch();

    batch.set(
      _db.collection(FirebaseCollections.users).doc(userId),
      {
        'hasPendingRequest': false,
        if (clubId != null) 'lastProcessedJoinRequestClubId': clubId,
      },
      SetOptions(merge: true),
    );

    batch.delete(requestRef);

    await batch.commit();

    AppLogger.instance.info('JoinRequest: demande refusée', {
      'requestId': requestId,
      'userId': userId,
      'clubId': clubId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers privés
  // ─────────────────────────────────────────────────────────────────────────

  /// Retourne le champ `arrayUnion` du doc `clubs/{clubId}` pour un rôle donné.
  ///
  /// | role    | champ   |
  /// |---------|---------|
  /// | player  | members |
  /// | coach   | coaches |
  /// | admin   | admins  |
  String _clubFieldForRole(String role) {
    switch (role) {
      case 'admin':
        return 'admins';
      case 'coach':
        return 'coaches';
      default:
        return 'members';
    }
  }
}
