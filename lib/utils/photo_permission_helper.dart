import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Affiche un BottomSheet pour choisir entre Caméra et Galerie,
/// demande la permission adaptée à la source et à la version Android,
/// puis retourne le [XFile] sélectionné (ou null si annulé/refusé).
///
/// - Caméra : [Permission.camera]
/// - Galerie Android 13+ : Photo Picker système (aucune permission requise)
/// - Galerie Android ≤ 12 : [Permission.storage] (READ_EXTERNAL_STORAGE)
/// - iOS : [Permission.photos] pour la galerie, [Permission.camera] pour la caméra
Future<XFile?> pickPhotoWithPermission(
  BuildContext context, {
  int imageQuality = 80,
  double? maxWidth,
}) async {
  final source = await _showSourcePicker(context);
  if (source == null) return null;

  final granted = await _requestPermissionForSource(context, source);
  if (!granted) return null;

  if (!context.mounted) return null;

  final picker = ImagePicker();
  return picker.pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
}

/// Affiche le BottomSheet de choix de source.
Future<ImageSource?> _showSourcePicker(BuildContext context) async {
  return showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text("Prendre une photo"),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text("Choisir depuis la galerie"),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Demande la permission adaptée à la [source] et à la version Android.
/// Retourne [true] si accordée, [false] sinon (avec feedback à l'utilisateur).
Future<bool> _requestPermissionForSource(
  BuildContext context,
  ImageSource source,
) async {
  PermissionStatus status;

  if (source == ImageSource.camera) {
    status = await Permission.camera.request();
  } else {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ : le Photo Picker système ne nécessite aucune permission
        return true;
      }
      status = await Permission.storage.request();
    } else {
      status = await Permission.photos.request();
    }
  }

  if (status.isGranted || status.isLimited) return true;

  if (!context.mounted) return false;

  if (status.isPermanentlyDenied) {
    final label =
        source == ImageSource.camera ? "l'appareil photo" : "la galerie";
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Accès à $label refusé"),
        content: Text(
          "L'accès à $label a été refusé définitivement. "
          "Veuillez l'autoriser dans les réglages de l'application.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text("Ouvrir les réglages"),
          ),
        ],
      ),
    );
  } else {
    final label =
        source == ImageSource.camera ? "l'appareil photo" : "la galerie";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("L'accès à $label est nécessaire pour changer la photo."),
      ),
    );
  }

  return false;
}
