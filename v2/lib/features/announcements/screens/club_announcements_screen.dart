import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/announcements/providers/announcement_providers.dart';
import 'package:viro_team_v2/features/announcements/widgets/announcement_message_sheet.dart';
import 'package:viro_team_v2/features/announcements/widgets/create_announcement_sheet.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/models/club_announcement.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class ClubAnnouncementsScreen extends ConsumerWidget {
  const ClubAnnouncementsScreen({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(visibleClubAnnouncementsProvider(clubId));
    final memberAsync = ref.watch(clubMemberProvider(clubId));
    final teamsAsync = ref.watch(clubTeamsProvider(clubId));
    final canManage = memberAsync.maybeWhen(
      data: (m) =>
          m != null && MemberRoleHierarchy.isCoachOrAbove(m.role),
      orElse: () => false,
    );

    final teamNames = <String, String>{
      for (final t in teamsAsync.value ?? []) t.id: t.name,
    };

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: ViroIcon(ViroIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Annonces'),
        onTitleTap: () => Navigator.pop(context),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () =>
                  showCreateAnnouncementSheet(context, ref, clubId: clubId),
              icon: ViroIcon(ViroIcons.add, color: ViroColors.white),
              label: const Text('Nouvelle annonce'),
            )
          : null,
      body: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(ViroSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ViroIcon(
                      ViroIcons.bell,
                      size: 48,
                      color: ViroColors.gray300,
                    ),
                    const SizedBox(height: ViroSpacing.md),
                    Text(
                      'Aucune annonce pour le moment',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: ViroColors.gray400,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(ViroSpacing.screenHorizontal),
            itemCount: announcements.length,
            separatorBuilder: (_, _) => const SizedBox(height: ViroSpacing.sm),
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return _AnnouncementHistoryCard(
                announcement: announcement,
                targetLabel: announcement.targetLabel(
                  teamNamesById: teamNames,
                ),
                canManage: canManage,
                onTap: () => showAnnouncementMessageSheet(
                  context,
                  announcement: announcement,
                ),
                onEdit: () => _showEditDialog(context, ref, announcement),
                onDelete: () => _confirmDelete(context, ref, announcement),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ClubAnnouncement announcement,
  ) async {
    final controller = TextEditingController(text: announcement.message);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier l\'annonce'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) return;

    try {
      await ref.read(announcementServiceProvider).updateAnnouncement(
            clubId: clubId,
            announcementId: announcement.id,
            message: controller.text,
          );
      if (context.mounted) {
        ViroSnackBar.show(context, 'Annonce mise à jour.');
      }
    } catch (e) {
      if (context.mounted) {
        ViroSnackBar.show(context, 'Erreur : $e');
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ClubAnnouncement announcement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'annonce ?'),
        content: const Text(
          'Cette annonce sera définitivement supprimée pour tous les membres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Supprimer',
              style: TextStyle(color: ViroColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(announcementServiceProvider).deleteAnnouncement(
            clubId: clubId,
            announcementId: announcement.id,
          );
      if (context.mounted) {
        ViroSnackBar.show(context, 'Annonce supprimée.');
      }
    } catch (e) {
      if (context.mounted) {
        ViroSnackBar.show(context, 'Erreur : $e');
      }
    }
  }
}

class _AnnouncementHistoryCard extends StatelessWidget {
  const _AnnouncementHistoryCard({
    required this.announcement,
    required this.targetLabel,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ClubAnnouncement announcement;
  final String targetLabel;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return ViroCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  announcement.authorName,
                  style: theme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ViroColors.primary800,
                  ),
                ),
              ),
              Text(
                formatRelativeDate(announcement.createdAt),
                style: theme.bodySmall?.copyWith(color: ViroColors.gray400),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  icon: ViroIcon(ViroIcons.moreVertical, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Modifier'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: ViroSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ViroSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: ViroColors.primary50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              targetLabel,
              style: theme.labelSmall?.copyWith(
                color: ViroColors.primary800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: ViroSpacing.sm),
          Text(
            announcement.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
