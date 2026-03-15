import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'app_logger.dart';
import 'firebase_error_handler.dart';
import 'photo_permission_helper.dart';

/// Supprime le fichier Storage correspondant à une URL de téléchargement Firebase
/// (extrait le chemin entre /o/ et ? puis décode). Ignore les erreurs (URL invalide, fichier absent).
Future<void> deleteStorageFileFromUrl(String? downloadUrl) async {
  if (downloadUrl == null || downloadUrl.trim().isEmpty) return;
  try {
    final uri = Uri.parse(downloadUrl);
    if (!uri.host.contains('firebasestorage')) return;
    final pathSegment = uri.pathSegments;
    final oIndex = pathSegment.indexOf('o');
    if (oIndex == -1 || oIndex + 1 >= pathSegment.length) return;
    final encodedPath = pathSegment[oIndex + 1];
    final path = Uri.decodeComponent(encodedPath);
    await FirebaseStorage.instance.ref().child(path).delete();
  } catch (e) {
    // Fichier déjà supprimé, URL invalide ou autre bucket : on ignore
    AppLogger.instance.error('deleteStorageFileFromUrl failed', error: e);
  }
}

/// Permet à un joueur (ou admin/coach) de choisir une image en galerie,
/// supprime l'ancien avatar en Storage s'il existe, uploade le nouveau et met à jour Firestore.
Future<void> pickAndUploadTeamAvatar(
  BuildContext context, {
  required String clubId,
  required String teamId,
  String? teamName,
}) async {
  try {
    final file = await pickPhotoWithPermission(context, imageQuality: 80);
    if (file == null || !context.mounted) return;

    final teamRef = appFirestore
        .collection(FirebaseCollections.clubs)
        .doc(clubId)
        .collection(FirebaseCollections.teams)
        .doc(teamId);
    final teamSnap = await teamRef.get();
    final currentAvatarUrl =
        (teamSnap.data()?['avatarUrl'] as String?)?.trim();

    await deleteStorageFileFromUrl(currentAvatarUrl);

    final path =
        'clubs/$clubId/teams/$teamId/avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(File(file.path));
    final url = await ref.getDownloadURL();
    await teamRef.set({'avatarUrl': url}, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Photo de ${teamName ?? 'l\'équipe'} mise à jour")),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(FirebaseErrorHandler.getErrorMessage(e))),
      );
    }
  }
}
