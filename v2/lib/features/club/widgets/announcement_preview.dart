import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/models/club_announcement.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';
import 'package:viro_team_v2/widgets/common/viro_pressable.dart';

class AnnouncementPreview extends StatelessWidget {
  const AnnouncementPreview({
    super.key,
    required this.announcement,
  });

  final ClubAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return ViroCard(
      onTap: () => _showFullMessage(context),
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
            ],
          ),
          const SizedBox(height: ViroSpacing.sm),
          Text(
            announcement.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _showFullMessage(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ViroColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ViroSpacing.cardRadius),
        ),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx).textTheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            ViroSpacing.lg,
            ViroSpacing.lg,
            ViroSpacing.lg,
            MediaQuery.paddingOf(ctx).bottom + ViroSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                announcement.authorName,
                style: theme.titleMedium?.copyWith(
                  color: ViroColors.primary800,
                ),
              ),
              const SizedBox(height: ViroSpacing.xs),
              Text(
                formatRelativeDate(announcement.createdAt),
                style: theme.bodySmall?.copyWith(color: ViroColors.gray400),
              ),
              const SizedBox(height: ViroSpacing.md),
              Text(announcement.message, style: theme.bodyLarge),
              const SizedBox(height: ViroSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: ViroPressable(
                  onTap: () => Navigator.pop(ctx),
                  child: Text(
                    'Fermer',
                    style: theme.labelLarge?.copyWith(
                      color: ViroColors.primary600,
                      fontWeight: FontWeight.w600,
                    ),
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
