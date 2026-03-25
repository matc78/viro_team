import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Ouvre une page plein écran pour afficher une image avec zoom (InteractiveViewer).
/// Si [onEditTap] est fourni, un bouton "Modifier" permet de changer l'image (ex. avatar d'équipe).
void showFullScreenImage(
  BuildContext context,
  String imageUrl, {
  Future<void> Function(BuildContext)? onEditTap,
}) {
  final hasImage = imageUrl.trim().isNotEmpty;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Image',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            if (onEditTap != null)
              TextButton.icon(
                onPressed: () async {
                  await onEditTap(context);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                label: const Text(
                  'Modifier',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        body: hasImage
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "Ajoute une photo d'équipe toi meme !",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
