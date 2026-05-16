import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:viro_team_v2/config/project_config.dart';

/// Instance Firestore — base [ProjectConfig.firestoreDatabaseId] uniquement.
///
/// Ne jamais utiliser [FirebaseFirestore.instance] (base default).
FirebaseFirestore get appFirestore => FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: ProjectConfig.firestoreDatabaseId,
    );
