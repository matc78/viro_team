import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../constants/firebase_collections.dart';
import '../../../theme/viro_theme.dart';
import '../../../utils/firestore_instance.dart';

/// Section affichant la liste des membres en attente de création de compte
/// ou la liste des refus d'invitation (selon [onlyDeclined]).
class PendingMembersSection extends StatelessWidget {
  final String clubId;
  final String search;
  /// Si true, n'affiche que les membres ayant refusé l'invitation (section "Refus d'invitation").
  /// Si false, n'affiche que les membres en attente (section "En attente de création de compte").
  final bool onlyDeclined;
  final bool canEdit;
  final bool canSendInviteLink;
  final void Function(
    BuildContext context,
    String pendingMemberId,
    String firstName,
    String lastName,
    String email,
  ) onSendInviteLink;
  final void Function(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
    String firstName,
    String lastName,
    String email,
  ) onEditPendingMember;
  final void Function(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
    String displayName,
  ) onRemovePendingMember;

  const PendingMembersSection({
    super.key,
    required this.clubId,
    required this.search,
    this.onlyDeclined = false,
    required this.canEdit,
    required this.canSendInviteLink,
    required this.onSendInviteLink,
    required this.onEditPendingMember,
    required this.onRemovePendingMember,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.pendingMembers)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        final list = docs
            .map((doc) => {'doc': doc, 'data': doc.data()})
            .where((e) {
              final status =
                  (e['data'] as Map<String, dynamic>)['invitationStatus']
                      as String? ??
                  'pending';
              if (onlyDeclined) return status == 'declined';
              return status != 'declined';
            })
            .toList();

        if (list.isEmpty) {
          if (onlyDeclined) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Aucun membre en attente.",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          );
        }

        list.sort((a, b) {
          final aLast = ((a['data'] as Map)['lastName'] as String? ?? '')
              .toLowerCase();
          final bLast = ((b['data'] as Map)['lastName'] as String? ?? '')
              .toLowerCase();
          final cmp = aLast.compareTo(bLast);
          if (cmp != 0) return cmp;
          final aFirst = ((a['data'] as Map)['firstName'] as String? ?? '')
              .toLowerCase();
          final bFirst = ((b['data'] as Map)['firstName'] as String? ?? '')
              .toLowerCase();
          return aFirst.compareTo(bFirst);
        });

        final searchLower = search.toLowerCase();
        final filtered = searchLower.isEmpty
            ? list
            : list.where((e) {
                final data = e['data'] as Map<String, dynamic>;
                final first = (data['firstName'] as String? ?? '').toLowerCase();
                final last = (data['lastName'] as String? ?? '').toLowerCase();
                final email = (data['email'] as String? ?? '').toLowerCase();
                return first.contains(searchLower) ||
                    last.contains(searchLower) ||
                    email.contains(searchLower);
              }).toList();

        if (filtered.isEmpty) {
          if (onlyDeclined) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Aucun membre en attente.",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final e = filtered[index];
              final doc = e['doc'] as DocumentSnapshot<Map<String, dynamic>>;
              final data = e['data'] as Map<String, dynamic>;
              final firstName = data['firstName'] as String? ?? '';
              final lastName = data['lastName'] as String? ?? '';
              final email = data['email'] as String? ?? '';
              final isDeclined = onlyDeclined;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '$firstName $lastName'.trim().isEmpty
                      ? email
                      : '$firstName $lastName'.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  email,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: (canEdit || canSendInviteLink)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canSendInviteLink)
                            IconButton(
                              onPressed: () => onSendInviteLink(
                                context,
                                doc.id,
                                firstName,
                                lastName,
                                email,
                              ),
                              icon: const Icon(Icons.link),
                              color: ViroColors.primary,
                              tooltip: isDeclined
                                  ? "Renvoyer le lien"
                                  : "Envoyer lien de connexion",
                            ),
                          if (canEdit)
                            IconButton(
                              onPressed: () => onEditPendingMember(
                                context,
                                doc.reference,
                                firstName,
                                lastName,
                                email,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              color: ViroColors.accent,
                              tooltip: "Éditer",
                            ),
                          if (canEdit)
                            IconButton(
                              onPressed: () => onRemovePendingMember(
                                context,
                                doc.reference,
                                '$firstName $lastName'.trim(),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              tooltip: "Supprimer",
                            ),
                        ],
                      )
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}
