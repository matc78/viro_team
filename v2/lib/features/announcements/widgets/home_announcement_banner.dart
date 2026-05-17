import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/features/announcements/providers/announcement_providers.dart';
import 'package:viro_team_v2/features/announcements/widgets/announcement_message_sheet.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/club_color.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_pressable.dart';

class HomeAnnouncementBanner extends ConsumerStatefulWidget {
  const HomeAnnouncementBanner({super.key});

  @override
  ConsumerState<HomeAnnouncementBanner> createState() =>
      _HomeAnnouncementBannerState();
}

class _HomeAnnouncementBannerState extends ConsumerState<HomeAnnouncementBanner> {
  /// Masquage optimiste en attendant la synchro Firestore.
  final _locallyDismissed = <String>{};

  String _dismissKey(HomeAnnouncementItem item) =>
      '${item.clubId}_${item.announcement.id}';

  Future<void> _dismiss(HomeAnnouncementItem item) async {
    setState(() => _locallyDismissed.add(_dismissKey(item)));

    try {
      final member = await ref.read(
        clubMemberProvider(item.clubId).future,
      );
      if (member == null) {
        if (mounted) {
          setState(() => _locallyDismissed.remove(_dismissKey(item)));
          ViroSnackBar.show(context, 'Impossible de masquer l\'annonce.');
        }
        return;
      }

      await ref.read(announcementServiceProvider).dismissAnnouncement(
            clubId: item.clubId,
            memberId: member.memberId,
            announcementId: item.announcement.id,
          );
    } catch (e) {
      if (mounted) {
        setState(() => _locallyDismissed.remove(_dismissKey(item)));
        ViroSnackBar.show(context, 'Erreur : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(homeActiveAnnouncementsProvider);

    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        final visible = items
            .where((item) => !_locallyDismissed.contains(_dismissKey(item)))
            .take(3)
            .toList();

        if (visible.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            ViroSpacing.screenHorizontal,
            ViroSpacing.sm,
            ViroSpacing.screenHorizontal,
            ViroSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: ViroSpacing.sm),
                  child: _AnnouncementBannerCard(
                    item: item,
                    onDismiss: () => _dismiss(item),
                    onTap: () => showAnnouncementMessageSheet(
                      context,
                      announcement: item.announcement,
                      clubName: item.clubName,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnnouncementBannerCard extends StatelessWidget {
  const _AnnouncementBannerCard({
    required this.item,
    required this.onDismiss,
    required this.onTap,
  });

  final HomeAnnouncementItem item;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final accent = clubAccentColor(
      brandColorHex: item.brandColorHex,
      clubId: item.clubId,
    );
    final announcement = item.announcement;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ViroSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ViroPressable(
                onTap: onTap,
                floating: false,
                borderRadius:
                    BorderRadius.circular(ViroSpacing.cardRadius),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ViroIcon(ViroIcons.bell, color: accent, size: 22),
                    const SizedBox(width: ViroSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.clubName,
                                  style: theme.labelMedium?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                formatRelativeDate(announcement.createdAt),
                                style: theme.bodySmall?.copyWith(
                                  color: ViroColors.gray400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: ViroSpacing.xs),
                          Text(
                            announcement.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (announcement.authorName.isNotEmpty) ...[
                            const SizedBox(height: ViroSpacing.xs),
                            Text(
                              announcement.authorName,
                              style: theme.bodySmall?.copyWith(
                                color: ViroColors.gray600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: ViroIcon(
                ViroIcons.close,
                size: 20,
                color: ViroColors.gray400,
              ),
              onPressed: onDismiss,
              tooltip: 'Masquer',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
