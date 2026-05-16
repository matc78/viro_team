import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/utils/firestore_instance.dart';

/// Retours utilisateur (objectifs onboarding, feedback produit, etc.).
class RetourUserService {
  RetourUserService({FirebaseFirestore? firestore})
      : _db = firestore ?? appFirestore;

  final FirebaseFirestore _db;

  static const String typeClubSetupObjectives = 'club_setup_objectives';

  /// Enregistre les objectifs choisis à la création d'un club.
  Future<void> saveClubSetupObjectives({
    required String userId,
    required String clubId,
    required Set<String> objectiveKeys,
    String? clubName,
    String? clubSport,
  }) async {
    if (objectiveKeys.isEmpty) return;

    final labels = objectiveKeys.map(ClubObjectives.label).toList();

    await _db.collection(ProjectConfig.retourUserCollection).add({
      FirestoreFields.userId: userId,
      FirestoreFields.clubId: clubId,
      'type': typeClubSetupObjectives,
      if (clubName != null) FirestoreFields.clubName: clubName,
      if (clubSport != null) FirestoreFields.clubSport: clubSport,
      FirestoreFields.objectives: objectiveKeys.toList(),
      'objectivesLabels': labels,
      FirestoreFields.createdAt: FieldValue.serverTimestamp(),
    });
  }
}
