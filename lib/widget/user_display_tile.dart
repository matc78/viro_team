import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../pages/profil_display_page.dart';
import '../theme/viro_theme.dart';
import '../utils/formatters.dart';
import '../utils/avatar_moderation.dart';

/// Affiche le prénom et nom d'un utilisateur formatés, avec un avatar (initiales ou photo),
/// et rend le tout cliquable pour ouvrir [ProfilDisplayPage] lorsque [userId] est fourni.
/// Quand [userId] est fourni, l'avatar est récupéré depuis le document Firestore users (comme
/// dans [ProfilDisplayPage]) pour garantir la même source de données.
class UserDisplayTile extends StatelessWidget {
  /// ID de l'utilisateur (Firestore document id). Si null, le bloc n'est pas cliquable.
  /// Quand fourni, utilisé pour charger l'avatar depuis Firestore si besoin.
  final String? userId;

  final String? firstName;
  final String? lastName;

  /// URL de l'avatar passée par le parent. Si null/vide et [userId] est fourni,
  /// l'avatar est chargé depuis le document users (même logique que ProfilDisplayPage).
  final String? avatarUrl;

  /// Taille compacte (avatar 14, texte 12) pour lignes secondaires (ex: expéditeur d'un message).
  final bool compact;

  /// Fallback affiché si prénom et nom sont vides.
  final String fallback;

  /// Style optionnel pour le texte du nom.
  final TextStyle? textStyle;

  /// Si true, le tap ouvre ProfilDisplayPage. Si le parent gère déjà le tap (ex: ListTile),
  /// mettre à false pour éviter double navigation.
  final bool navigateOnTap;

  const UserDisplayTile({
    super.key,
    this.userId,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.compact = false,
    this.fallback = 'Membre',
    this.textStyle,
    this.navigateOnTap = true,
  });

  /// Normalise une valeur en URL string (Firestore peut retourner dynamic).
  static String? _urlFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    final t = value.toString().trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 12.0 : 18.0;
    final urlFromParam = _urlFromDynamic(avatarUrl);
    final hasUrlFromParam = urlFromParam != null && urlFromParam.isNotEmpty;

    // Si le nom ET l'avatar sont fournis en param, rendu statique (pas de Firestore)
    final hasNameParam = (firstName?.trim().isNotEmpty ?? false) ||
        (lastName?.trim().isNotEmpty ?? false);

    if (hasNameParam && (hasUrlFromParam || userId == null || userId!.isEmpty)) {
      return _buildRow(
        context,
        firstName: firstName,
        lastName: lastName,
        resolvedAvatarUrl: hasUrlFromParam ? urlFromParam : null,
        radius: radius,
      );
    }

    // Chargement depuis Firestore : nom et/ou avatar manquants
    if (userId != null && userId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: appFirestore
            .collection(FirebaseCollections.users)
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final loadedFirst =
              hasNameParam ? firstName : data['firstName'] as String?;
          final loadedLast =
              hasNameParam ? lastName : data['lastName'] as String?;
          final url = hasUrlFromParam
              ? urlFromParam
              : effectiveAvatarUrl(data);
          return _buildRow(
            context,
            firstName: loadedFirst,
            lastName: loadedLast,
            resolvedAvatarUrl: url,
            radius: radius,
          );
        },
      );
    }

    // Pas de userId : rendu statique avec fallback
    return _buildRow(
      context,
      firstName: firstName,
      lastName: lastName,
      resolvedAvatarUrl: hasUrlFromParam ? urlFromParam : null,
      radius: radius,
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String? firstName,
    required String? lastName,
    required String? resolvedAvatarUrl,
    required double radius,
  }) {
    final fontSize = compact ? 12.0 : 14.0;
    final effectiveStyle =
        textStyle ??
        TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textStyle?.color ?? Colors.grey[800],
        );
    final name = NameFormatter.formatFromData(
      firstName,
      lastName,
      fallback: fallback,
    );

    final Widget avatar;
    if (resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty) {
      avatar = _buildAvatarFromUrl(
        context,
        url: resolvedAvatarUrl,
        radius: radius,
        compact: compact,
        firstName: firstName,
        lastName: lastName,
      );
    } else {
      avatar = _buildInitialsAvatar(
        radius: radius,
        compact: compact,
        firstName: firstName,
        lastName: lastName,
      );
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        SizedBox(width: compact ? 6 : 12),
        Flexible(
          child: Text(
            name,
            style: effectiveStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final canNavigate = navigateOnTap && userId != null && userId!.isNotEmpty;
    if (canNavigate) {
      return InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfilDisplayPage(userId: userId!),
            ),
          );
        },
        borderRadius: BorderRadius.circular(radius * 2),
        child: content,
      );
    }
    return content;
  }

  static String _initials(String? first, String? last) {
    final f = (first ?? '').trim();
    final l = (last ?? '').trim();
    if (f.isNotEmpty && l.isNotEmpty) {
      return '${f[0]}${l[0]}'.toUpperCase();
    }
    if (f.isNotEmpty) return f[0].toUpperCase();
    if (l.isNotEmpty) return l[0].toUpperCase();
    return '?';
  }

  static Widget _buildAvatarFromUrl(
    BuildContext context, {
    required String url,
    required double radius,
    required bool compact,
    String? firstName,
    String? lastName,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
        backgroundImage: imageProvider,
      ),
      placeholder: (context, imageUrl) => CircleAvatar(
        radius: radius,
        backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, imageUrl, error) => _buildInitialsAvatar(
        radius: radius,
        compact: compact,
        firstName: firstName,
        lastName: lastName,
      ),
      memCacheWidth: (radius * 4).round(),
      memCacheHeight: (radius * 4).round(),
    );
  }

  static Widget _buildInitialsAvatar({
    required double radius,
    required bool compact,
    String? firstName,
    String? lastName,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
      child: Text(
        _initials(firstName, lastName),
        style: TextStyle(
          color: ViroColors.primary,
          fontSize: compact ? 10 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
