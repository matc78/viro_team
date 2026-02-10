import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Instance Firestore ciblant la base [prod] en release et [test] en debug.
/// Permet de séparer les données de production et de test dans le même projet.
/// Ne jamais utiliser [FirebaseFirestore.instance] (base default). Uniquement test ou prod.
FirebaseFirestore get appFirestore => FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: kReleaseMode ? 'prod' : 'test',
);
