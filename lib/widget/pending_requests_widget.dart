import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../theme/viro_theme.dart';

/// Widget pour afficher les demandes en attente et traitées
class PendingRequestsWidget extends StatelessWidget {
  final String userId;

  const PendingRequestsWidget({super.key, required this.userId});

  Future<void> _dismissProcessedRequest(String docId) async {
    await appFirestore
        .collection(FirebaseCollections.joinRequests)
        .doc(docId)
        .delete();
  }

  Future<bool> _deleteRequest(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Annuler la demande"),
        content: const Text(
          "Voulez-vous vraiment annuler cette demande ? Cette action est irréversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Non, garder"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Oui, supprimer"),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    await appFirestore
        .collection(FirebaseCollections.joinRequests)
        .doc(docId)
        .delete();

    // Mettre à jour le flag si plus aucune demande en attente
    final remaining = await appFirestore
        .collection(FirebaseCollections.joinRequests)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (remaining.docs.isEmpty) {
      await appFirestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .update({'hasPendingRequest': false});
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: appFirestore
          .collection(FirebaseCollections.joinRequests)
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final pendingRequests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).toList();

        final processedRequests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'accepted' || data['status'] == 'refused';
        }).toList();

        if (pendingRequests.isEmpty && processedRequests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingRequests.isNotEmpty) ...[
              const Text(
                "MES DEMANDES EN ATTENTE",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ...pendingRequests.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _SlidableDeleteTile(
                  key: Key(doc.id),
                  onDeleteTap: () => _deleteRequest(context, doc.id),
                  // Le builder reçoit l'animation (0=fermé, 1=ouvert)
                  // et la passe au card pour adapter ses tailles.
                  builder: (animation) => _RequestCardWithSport(
                    data: data,
                    status: 'pending',
                    slideAnimation: animation,
                  ),
                );
              }),
            ],
            if (processedRequests.isNotEmpty) ...[
              if (pendingRequests.isNotEmpty) const SizedBox(height: 20),
              const Text(
                "DEMANDES TRAITÉES",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ...processedRequests.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _RequestCardWithSport(
                  data: data,
                  status: data['status'] == 'accepted' ? 'accepted' : 'refused',
                  onDismiss: () => _dismissProcessedRequest(doc.id),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe-to-reveal delete button
// ---------------------------------------------------------------------------

/// Tile avec swipe gauche pour révéler un bouton de suppression rond.
///
/// Utilise un [builder] (plutôt qu'un [child] statique) pour que le contenu
/// puisse adapter ses tailles en temps réel via l'[Animation<double>] fournie
/// (valeur 0 = fermé/taille normale, valeur 1 = ouvert/taille réduite).
class _SlidableDeleteTile extends StatefulWidget {
  /// Builder appelé avec l'animation de slide (0→1).
  final Widget Function(Animation<double> slideAnimation) builder;

  /// Affiche le dialogue de confirmation et supprime si confirmé.
  /// Doit renvoyer [true] si la suppression a eu lieu, [false] sinon.
  final Future<bool> Function() onDeleteTap;

  const _SlidableDeleteTile({
    required super.key,
    required this.builder,
    required this.onDeleteTap,
  });

  @override
  State<_SlidableDeleteTile> createState() => _SlidableDeleteTileState();
}

class _SlidableDeleteTileState extends State<_SlidableDeleteTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Largeur totale du panneau d'action révélé.
  static const double _revealWidth = 68.0;

  /// Diamètre du bouton rond.
  static const double _buttonSize = 46.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() => _controller.animateTo(1.0, curve: Curves.easeOut);
  void _close() => _controller.animateTo(0.0, curve: Curves.easeOut);

  void _onDragStart(DragStartDetails _) => _controller.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.value =
        (_controller.value - details.delta.dx / _revealWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    if (vx < -400) {
      _open();
    } else if (vx > 400) {
      _close();
    } else if (_controller.value >= 0.4) {
      _open();
    } else {
      _close();
    }
  }

  Future<void> _onButtonTap() async {
    final deleted = await widget.onDeleteTap();
    if (!deleted && mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Le card occupe tout l'espace restant. Il rétrécit au fur et à
          // mesure que le panneau d'action s'agrandit, et reçoit l'animation
          // pour adapter ses tailles internes.
          Expanded(child: widget.builder(_controller)),

          // Panneau d'action : s'étend de 0 à _revealWidth depuis la droite.
          SizeTransition(
            axis: Axis.horizontal,
            sizeFactor: _controller,
            axisAlignment: -1.0,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 8),
              child: SizedBox(
                width: _revealWidth - 10,
                child: Center(
                  child: Material(
                    color: Colors.red.shade400,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _onButtonTap,
                      child: const SizedBox(
                        width: _buttonSize,
                        height: _buttonSize,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// Widget qui résout le sport du club depuis Firestore puis affiche la carte.
///
/// [slideAnimation] est optionelle : fournie uniquement pour les demandes
/// swipables (en attente). Quand elle est présente, les tailles du contenu
/// (icône, texte, badge) s'adaptent dynamiquement via [AnimatedBuilder].
class _RequestCardWithSport extends StatelessWidget {
  final Map<String, dynamic> data;
  final String status;

  /// Animation de slide du parent (0 = fermé/taille normale, 1 = ouvert/compressé).
  final Animation<double>? slideAnimation;

  /// Callback de suppression pour les demandes traitées (affiche une croix).
  final VoidCallback? onDismiss;

  const _RequestCardWithSport({
    required this.data,
    required this.status,
    this.slideAnimation,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final clubName = data['clubName'] as String? ?? 'Club inconnu';
    final role = data['roleRequested'] == 'player' ? 'joueur' : 'coach';
    final storedSport = data['clubSport'] as String?;
    final clubId = data['clubId'] as String?;

    if (storedSport != null) {
      return _buildCard(
        formatClubNameWithEmoji(clubName, storedSport),
        role,
        status,
      );
    }

    if (clubId == null || clubId.isEmpty) {
      return _buildCard(clubName, role, status);
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .get(),
      builder: (context, snap) {
        final clubSport = snap.data?.data()?['sport'] as String?;
        return _buildCard(
          formatClubNameWithEmoji(clubName, clubSport),
          role,
          status,
        );
      },
    );
  }

  Widget _buildCard(String clubName, String role, String status) {

    final isAccepted = status == 'accepted';
    final isPending = status == 'pending';
    final isRefused = status == 'refused';

    final cardColor = isAccepted
        ? Colors.green.shade50
        : isRefused
        ? Colors.red.shade50
        : Colors.white;
    final borderColor = isAccepted
        ? Colors.green
        : isRefused
        ? Colors.red
        : ViroColors.borderColor;
    final textColor = isAccepted
        ? Colors.green.shade900
        : isRefused
        ? Colors.red.shade900
        : Colors.black;
    final iconColor = isAccepted
        ? Colors.green
        : isRefused
        ? Colors.red
        : Colors.orange;
    final iconData = isAccepted
        ? Icons.check_circle
        : isRefused
        ? Icons.cancel
        : Icons.pending;
    final label = isPending
        ? "Demande $role chez\n$clubName"
        : "${isAccepted ? 'Accepté' : 'Refusé'} : $role chez $clubName";

    // Construit le contenu en interpolant les tailles selon [t] (0→1).
    Widget buildContent(double t) {
      // Tailles interpolées
      final iconSize = 20.0 - 4.0 * t; // 20 → 16
      final fontSize = 13.0 - 2.0 * t; // 13 → 11
      final gapWidth = 12.0 - 5.0 * t; // 12 → 7
      // Le badge disparaît progressivement dès le début du swipe
      final badgeOpacity = (1.0 - t * 1.8).clamp(0.0, 1.0);

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(iconData, color: iconColor, size: iconSize),
            SizedBox(width: gapWidth),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  color: textColor,
                ),
              ),
            ),
            if (isPending && badgeOpacity > 0)
              Opacity(
                opacity: badgeOpacity,
                child: const Badge(
                  label: Text("En attente"),
                  backgroundColor: Colors.orange,
                ),
              ),
            if (!isPending && onDismiss != null)
              GestureDetector(
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: iconColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (slideAnimation == null) return buildContent(0.0);

    return AnimatedBuilder(
      animation: slideAnimation!,
      builder: (context, _) => buildContent(slideAnimation!.value),
    );
  }
}
