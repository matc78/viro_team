import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/services/user_session.dart';
import 'package:viro_team/theme/viro_theme.dart';
import 'package:viro_team/utils/avatar_moderation.dart';
import 'package:viro_team/pages/add_profile_page.dart';
import 'package:viro_team/pages/admin_coach_pages/admin_home_page.dart';
import 'package:viro_team/pages/player_pages/player_home_page.dart';

/// Affiche le menu déroulant profil sous le bouton (avatar).
/// [context] doit être le contexte du widget cliqué (pour la position).
/// [settingsPage] est la page à ouvrir pour "Paramètres" (AdminProfilPage ou PlayerProfilPage).
void showProfileDropdown(
  BuildContext context, {
  required Widget settingsPage,
}) {
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return;
  final overlay = Overlay.of(context);
  final RenderBox? overlayBox =
      overlay.context.findRenderObject() as RenderBox?;
  if (overlayBox == null) return;

  const menuWidth = 280.0;
  const padding = 8.0;
  const bottomPadding = 16.0;
  final buttonPosition = box.localToGlobal(Offset.zero);
  final buttonSize = box.size;
  double left = buttonPosition.dx + buttonSize.width - menuWidth;
  double top = buttonPosition.dy + buttonSize.height + padding;
  if (left < padding) left = padding;
  if (left + menuWidth > overlayBox.size.width - padding) {
    left = overlayBox.size.width - menuWidth - padding;
  }
  final availableHeight = overlayBox.size.height - top - bottomPadding;
  final profileCount = context.read<UserSession>().getAvailableProfiles().length;
  const rowHeight = 68.0;
  const headerHeight = 48.0;
  const extraRows = 3;
  final contentHeight = headerHeight + (profileCount + extraRows) * rowHeight;
  final menuHeight = contentHeight.clamp(rowHeight * 2, availableHeight);

  OverlayEntry? barrierEntry;
  OverlayEntry? menuEntry;
  void remove() {
    barrierEntry?.remove();
    menuEntry?.remove();
  }

  barrierEntry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: remove,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              color: Colors.white.withValues(alpha: 0.1),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
  menuEntry = OverlayEntry(
    builder: (_) => Positioned(
      left: left,
      top: top,
      width: menuWidth,
      height: menuHeight,
      child: Material(
        elevation: 8,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ProfileMenuDropdownContent(
            onClose: remove,
            maxHeight: menuHeight,
            settingsPage: settingsPage,
          ),
        ),
      ),
    ),
  );
  overlay.insert(barrierEntry);
  overlay.insert(menuEntry);
}

/// Contenu du menu déroulant : liste des profils, rejoindre/créer club, paramètres.
class ProfileMenuDropdownContent extends StatefulWidget {
  const ProfileMenuDropdownContent({
    super.key,
    required this.onClose,
    required this.settingsPage,
    this.maxHeight,
  });

  final VoidCallback onClose;
  final Widget settingsPage;
  final double? maxHeight;

  @override
  State<ProfileMenuDropdownContent> createState() =>
      _ProfileMenuDropdownContentState();
}

class _ProfileMenuDropdownContentState extends State<ProfileMenuDropdownContent> {
  bool _isSwitching = false;
  bool _hasLoadedClubNames = false;
  Map<String, String> _clubNamesCache = {};
  Map<String, String> _clubSportsCache = {};
  Map<String, String> _clubLogosCache = {};
  String? _userAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadClubNames();
    _loadUserAvatar();
  }

  Future<void> _loadUserAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await appFirestore
          .collection(FirebaseCollections.users)
          .doc(uid)
          .get();
      if (!mounted) return;
      final url = effectiveAvatarUrl(snap.data());
      setState(() => _userAvatarUrl = url);
    } catch (_) {}
  }

  Future<void> _loadClubNames() async {
    final session = UserSession();
    final profiles = session.getAvailableProfiles();
    final clubIds = profiles
        .map((p) => p.clubId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (clubIds.isEmpty) {
      if (mounted) setState(() => _hasLoadedClubNames = true);
      return;
    }

    final Map<String, String> names = {};
    final Map<String, String> sports = {};
    final Map<String, String> logos = {};
    for (var i = 0; i < clubIds.length; i += 10) {
      final batch = clubIds.sublist(
        i,
        i + 10 > clubIds.length ? clubIds.length : i + 10,
      );
      try {
        final snapshot = await appFirestore
            .collection(FirebaseCollections.clubs)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          names[doc.id] = data['name'] as String? ?? doc.id;
          final sport = data['sport'] as String?;
          if (sport != null && sport.isNotEmpty) sports[doc.id] = sport;
          final logoUrl = data['logoUrl'] as String?;
          if (logoUrl != null && logoUrl.toString().trim().isNotEmpty) {
            logos[doc.id] = logoUrl.toString().trim();
          }
        }
      } catch (_) {
        for (var clubId in batch) names[clubId] = clubId;
      }
    }
    if (mounted) {
      setState(() {
        _clubNamesCache = names;
        _clubSportsCache = sports;
        _clubLogosCache = logos;
        _hasLoadedClubNames = true;
      });
    }
  }

  String _getClubName(String clubId) =>
      _clubNamesCache[clubId] ?? clubId;

  String? _getClubLogoUrl(String clubId) {
    final url = _clubLogosCache[clubId];
    return (url != null && url.isNotEmpty) ? url : null;
  }

  Widget? _buildLeadingForProfile({
    required String role,
    required String clubId,
    required bool isCurrent,
  }) {
    const size = 40.0;
    if (role == 'player') {
      if (_userAvatarUrl == null || _userAvatarUrl!.isEmpty) return null;
      return SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: _userAvatarUrl!,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            backgroundColor: ViroColors.primary.withValues(alpha: 0.1),
            backgroundImage: imageProvider,
          ),
          placeholder: (_, __) => CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
          memCacheWidth: 80,
          memCacheHeight: 80,
        ),
      );
    }
    final logoUrl = _getClubLogoUrl(clubId);
    if (logoUrl == null) return null;
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          backgroundColor: isCurrent
              ? ViroColors.primary.withValues(alpha: 0.2)
              : Colors.grey.shade200,
          backgroundImage: imageProvider,
        ),
        placeholder: (_, __) => CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
        memCacheWidth: 80,
        memCacheHeight: 80,
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'player':
        return 'Joueur';
      case 'coach':
        return 'Coach';
      case 'admin':
        return 'Administrateur';
      case 'admin_fondateur':
        return 'Fondateur';
      default:
        return role;
    }
  }

  Future<void> _switchProfile(String role, String clubId) async {
    if (_isSwitching) return;
    setState(() => _isSwitching = true);
    final session = context.read<UserSession>();
    final navigator = Navigator.of(context);
    final success = await session.switchContext(role, clubId);
    if (!mounted) return;
    setState(() => _isSwitching = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors du changement de profil'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    widget.onClose();
    if (role == 'player') {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PlayerHomePage()),
        (route) => false,
      );
    } else {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminHomePage()),
        (route) => false,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil changé avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<UserSession>();
    final profiles = session.getAvailableProfiles();
    final currentRole = session.currentRole;
    final currentClubId = session.currentClubId;

    if (!_hasLoadedClubNames) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final playerProfiles =
        profiles.where((p) => p.role == 'player').toList();
    final otherProfiles =
        profiles.where((p) => p.role != 'player').toList();

    final List<({String role, String clubId, String title, String subtitle, bool isCurrent})> items = [];

    if (playerProfiles.isNotEmpty) {
      final isCurrent = currentRole == 'player';
      final targetClubId = isCurrent && currentClubId != null
          ? currentClubId
          : playerProfiles.first.clubId;
      final ids = playerProfiles
          .map((p) => p.clubId)
          .where((id) => id.isNotEmpty)
          .toList();
      final subtitle = ids.length > 1
          ? '${ids.length} clubs'
          : formatClubNameWithEmoji(
              _getClubName(ids.isNotEmpty ? ids.first : ''),
              _clubSportsCache[ids.isNotEmpty ? ids.first : ''],
            );
      items.add((
        role: 'player',
        clubId: targetClubId,
        title: _getRoleDisplayName('player'),
        subtitle: subtitle,
        isCurrent: isCurrent,
      ));
    }
    for (final p in otherProfiles) {
      final isCurrent = p.role == currentRole && p.clubId == currentClubId;
      items.add((
        role: p.role,
        clubId: p.clubId,
        title: _getRoleDisplayName(p.role),
        subtitle: formatClubNameWithEmoji(
          _getClubName(p.clubId),
          _clubSportsCache[p.clubId],
        ),
        isCurrent: isCurrent,
      ));
    }

    if (_isSwitching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    const leadingPlaceholder = SizedBox(width: 40, height: 40);
    final listChildren = <Widget>[
      ...items.map((item) => ListTile(
            leading: _buildLeadingForProfile(
              role: item.role,
              clubId: item.clubId,
              isCurrent: item.isCurrent,
            ) ?? leadingPlaceholder,
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(item.subtitle),
            trailing: item.isCurrent
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: item.isCurrent
                ? null
                : () => _switchProfile(item.role, item.clubId),
          )),
      const Divider(height: 24),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          'Rejoindre / créer un club',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Ajouter un profil ou créer un club'),
        onTap: () {
          final navigator = Navigator.of(context);
          widget.onClose();
          navigator.push(
            MaterialPageRoute(
              builder: (_) => const AddProfilePage(),
            ),
          );
        },
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          'Paramètres',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Profil et préférences'),
        onTap: () {
          final navigator = Navigator.of(context);
          widget.onClose();
          navigator.push(
            MaterialPageRoute(
              builder: (_) => widget.settingsPage,
            ),
          );
        },
      ),
    ];

    final listItems = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'Profil et paramètres',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      ...listChildren,
    ];

    final maxHeight = widget.maxHeight;
    if (maxHeight != null && maxHeight.isFinite) {
      return SizedBox(
        height: maxHeight,
        child: ListView(
          shrinkWrap: false,
          padding: EdgeInsets.zero,
          children: listItems,
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: listItems,
    );
  }
}
