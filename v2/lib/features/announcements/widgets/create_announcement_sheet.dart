import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/announcements/announcement_target_types.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/team_categories.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';

Future<void> showCreateAnnouncementSheet(
  BuildContext context,
  WidgetRef ref, {
  required String clubId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ViroColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ViroSpacing.cardRadius),
      ),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: _CreateAnnouncementSheet(clubId: clubId),
    ),
  );
}

class _CreateAnnouncementSheet extends ConsumerStatefulWidget {
  const _CreateAnnouncementSheet({required this.clubId});

  final String clubId;

  @override
  ConsumerState<_CreateAnnouncementSheet> createState() =>
      _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState
    extends ConsumerState<_CreateAnnouncementSheet> {
  final _messageController = TextEditingController();
  final _selectedIds = <String>{};
  var _isSending = false;
  String? _targetType;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  List<String> get _targetOptions {
    final member = ref.read(clubMemberProvider(widget.clubId)).value;
    final isAdmin = member?.role == MemberRoles.admin;
    return isAdmin
        ? AnnouncementTargetTypes.adminOptions
        : AnnouncementTargetTypes.coachOptions;
  }

  Future<void> _publish() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ViroSnackBar.show(context, 'Veuillez saisir un message.');
      return;
    }

    final targetType = _resolveTargetType(_targetOptions);
    if (targetType != AnnouncementTargetTypes.tousLesMembres &&
        _selectedIds.isEmpty) {
      ViroSnackBar.show(context, 'Veuillez sélectionner au moins une cible.');
      return;
    }

    final auth = ref.read(authStateProvider).value;
    final user = ref.read(viroUserProvider).value;
    if (auth == null || user == null) {
      ViroSnackBar.show(context, 'Session expirée, reconnectez-vous.');
      return;
    }

    setState(() => _isSending = true);

    try {
      await ref.read(announcementServiceProvider).createAnnouncement(
            clubId: widget.clubId,
            senderId: auth.uid,
            senderFirstName: user.firstName,
            senderLastName: user.lastName,
            message: message,
            targetType: targetType,
            targetIds: _selectedIds.toList(),
          );

      if (!mounted) return;
      Navigator.pop(context);
      ViroSnackBar.show(context, 'Annonce publiée.');
    } catch (e) {
      if (mounted) {
        ViroSnackBar.show(context, 'Erreur : $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final clubAsync = ref.watch(clubProvider(widget.clubId));
    final teamsAsync = ref.watch(clubTeamsProvider(widget.clubId));
    final options = _targetOptions;
    final targetType = _resolveTargetType(options);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ViroSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nouvelle annonce',
              style: theme.titleLarge?.copyWith(color: ViroColors.primary800),
            ),
            const SizedBox(height: ViroSpacing.md),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Votre message important…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: ViroSpacing.lg),
            Text(
              'Destinataires',
              style: theme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: ViroSpacing.sm),
            _TargetTypeRow(
              options: options,
              selected: targetType,
              onSelected: (type) => setState(() {
                _targetType = type;
                _selectedIds.clear();
              }),
            ),
            const SizedBox(height: ViroSpacing.md),
            clubAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (club) => _TargetPicker(
                club: club,
                targetType: targetType,
                teams: teamsAsync.value ?? [],
                selectedIds: _selectedIds,
                onToggle: (id, selected) => setState(() {
                  if (selected) {
                    _selectedIds.add(id);
                  } else {
                    _selectedIds.remove(id);
                  }
                }),
              ),
            ),
            const SizedBox(height: ViroSpacing.lg),
            ViroPrimaryButton(
              label: 'Publier',
              isLoading: _isSending,
              onPressed: _isSending ? null : _publish,
            ),
          ],
        ),
      ),
    );
  }

  String _resolveTargetType(List<String> options) {
    if (options.isEmpty) return AnnouncementTargetTypes.tousLesMembres;
    if (_targetType != null && options.contains(_targetType)) {
      return _targetType!;
    }
    final member = ref.read(clubMemberProvider(widget.clubId)).value;
    final isAdmin = member?.role == MemberRoles.admin;
    final initial = isAdmin
        ? AnnouncementTargetTypes.tousLesMembres
        : AnnouncementTargetTypes.equipes;
    return options.contains(initial) ? initial : options.first;
  }
}

class _TargetTypeRow extends StatelessWidget {
  const _TargetTypeRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ViroSpacing.sm,
      runSpacing: ViroSpacing.sm,
      children: options.map((type) {
        final isSelected = selected == type;
        return FilterChip(
          label: Text(type),
          selected: isSelected,
          onSelected: (_) => onSelected(type),
          selectedColor: ViroColors.primary100,
          checkmarkColor: ViroColors.primary800,
        );
      }).toList(),
    );
  }
}

class _TargetPicker extends StatelessWidget {
  const _TargetPicker({
    required this.club,
    required this.targetType,
    required this.teams,
    required this.selectedIds,
    required this.onToggle,
  });

  final Club? club;
  final String targetType;
  final List<ClubTeam> teams;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    if (targetType == AnnouncementTargetTypes.tousLesMembres) {
      return Text(
        "L'annonce sera diffusée à tous les membres du club.",
        style: theme.bodyMedium?.copyWith(color: ViroColors.gray600),
      );
    }

    if (targetType == AnnouncementTargetTypes.equipes) {
      if (teams.isEmpty) {
        return Text(
          'Aucune équipe dans ce club.',
          style: theme.bodyMedium?.copyWith(color: ViroColors.gray400),
        );
      }
      return Wrap(
        spacing: ViroSpacing.sm,
        runSpacing: ViroSpacing.sm,
        children: teams.map((team) {
          final isSelected = selectedIds.contains(team.id);
          return FilterChip(
            label: Text(team.name),
            selected: isSelected,
            onSelected: (v) => onToggle(team.id, v),
          );
        }).toList(),
      );
    }

    if (targetType == AnnouncementTargetTypes.categories) {
      final sport = club?.sport ?? '';
      final fromTeams = teams
          .map((t) => t.category)
          .whereType<String>()
          .where((c) => c.isNotEmpty)
          .toSet();
      final suggested = teamCategoriesForSport(sport).toSet();
      final categories = {...fromTeams, ...suggested}.toList()..sort();

      if (categories.isEmpty) {
        return Text(
          'Aucune catégorie disponible.',
          style: theme.bodyMedium?.copyWith(color: ViroColors.gray400),
        );
      }

      return Wrap(
        spacing: ViroSpacing.sm,
        runSpacing: ViroSpacing.sm,
        children: categories.map((cat) {
          final isSelected = selectedIds.contains(cat);
          return FilterChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (v) => onToggle(cat, v),
          );
        }).toList(),
      );
    }

    return const SizedBox.shrink();
  }
}
