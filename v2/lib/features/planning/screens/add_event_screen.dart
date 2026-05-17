import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club/providers/club_detail_providers.dart';
import 'package:viro_team_v2/features/members/providers/member_providers.dart';
import 'package:viro_team_v2/features/teams/providers/team_providers.dart';
import 'package:viro_team_v2/features/teams/utils/team_roster_members.dart';
import 'package:viro_team_v2/models/club_event.dart';
import 'package:viro_team_v2/models/club_team.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/date_format_fr.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class AddEventScreen extends ConsumerStatefulWidget {
  const AddEventScreen({
    super.key,
    required this.clubId,
    this.initialDate,
  });

  final String clubId;
  final DateTime? initialDate;

  @override
  ConsumerState<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends ConsumerState<AddEventScreen> {
  final _locationController = TextEditingController();
  final _titleController = TextEditingController();

  String _type = EventTypes.training;
  String? _teamId;
  late DateTime _date;
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 19, minute: 30);
  TimeOfDay _meetingTime = const TimeOfDay(hour: 17, minute: 30);
  String? _matchVenue;
  bool _isRecurring = false;
  DateTime? _recurrenceEndDate;
  bool _saving = false;

  bool get _isMatch => _type == EventTypes.match;
  bool get _isTraining => _type == EventTypes.training;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _locationController.text = 'Stade du club';
  }

  @override
  void dispose() {
    _locationController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isRecurrenceEnd}) async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('fr', 'FR'),
      initialDate: isRecurrenceEnd
          ? (_recurrenceEndDate ?? _date.add(const Duration(days: 28)))
          : _date,
      firstDate: isRecurrenceEnd ? _date : DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isRecurrenceEnd) {
        _recurrenceEndDate = picked;
      } else {
        _date = picked;
        if (_recurrenceEndDate != null && _recurrenceEndDate!.isBefore(_date)) {
          _recurrenceEndDate = _date.add(const Duration(days: 28));
        }
      }
    });
  }

  Future<void> _pickTime({
    required void Function(TimeOfDay) onPicked,
    required TimeOfDay initial,
  }) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) setState(() => onPicked(picked));
  }

  List<String> _audienceForTeam(ClubTeam team) {
    final members = ref.read(clubMembersProvider(widget.clubId)).value;
    if (members == null || members.isEmpty) {
      return List<String>.from(team.playerIds);
    }
    return audienceIdsForTeam(team, indexClubMembersByUid(members));
  }

  String? _resolveLocation() {
    if (_isMatch) {
      if (_matchVenue == MatchVenues.home) {
        return MatchVenues.homeLocationLabel;
      }
      final loc = _locationController.text.trim();
      return loc.isEmpty ? null : loc;
    }
    return _locationController.text.trim();
  }

  Future<void> _save() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final teams = ref.read(clubTeamsProvider(widget.clubId)).value ?? [];
    if (_type != EventTypes.other && _teamId == null) {
      ViroSnackBar.show(context, 'Choisissez une équipe');
      return;
    }
    if (_type == EventTypes.other && _titleController.text.trim().isEmpty) {
      ViroSnackBar.show(context, 'Titre requis');
      return;
    }

    if (_isMatch) {
      if (_matchVenue == null) {
        ViroSnackBar.show(context, 'Indiquez domicile ou extérieur');
        return;
      }
      if (_matchVenue == MatchVenues.away &&
          _locationController.text.trim().isEmpty) {
        ViroSnackBar.show(context, 'Lieu du match requis');
        return;
      }
    } else if (!_isMatch) {
      final startMin = _start.hour * 60 + _start.minute;
      final endMin = _end.hour * 60 + _end.minute;
      if (endMin <= startMin) {
        ViroSnackBar.show(context, 'L\'heure de fin doit être après le début');
        return;
      }
    }

    if (_isRecurring) {
      if (_recurrenceEndDate == null) {
        ViroSnackBar.show(context, 'Choisissez une date de fin');
        return;
      }
      if (_recurrenceEndDate!.isBefore(_date)) {
        ViroSnackBar.show(context, 'La fin doit être après la date de début');
        return;
      }
    }

    ClubTeam? team;
    if (_teamId != null) {
      for (final t in teams) {
        if (t.id == _teamId) {
          team = t;
          break;
        }
      }
    }

    final location = _resolveLocation();
    if (location == null || location.isEmpty) {
      ViroSnackBar.show(context, 'Lieu requis');
      return;
    }

    setState(() => _saving = true);
    try {
      final count = await ref.read(eventServiceProvider).createEvents(
            clubId: widget.clubId,
            creatorId: uid,
            type: _type,
            title: _type == EventTypes.other
                ? _titleController.text.trim()
                : (team?.name ?? ''),
            startDate: _date,
            teamIds: team != null ? [team.id] : <String>[],
            teamMemberIds: team != null ? _audienceForTeam(team) : <String>[],
            allTeams: false,
            location: location,
            startTime: _formatTime(_start),
            endTime: _isMatch ? null : _formatTime(_end),
            meetingTime: _isMatch ? _formatTime(_meetingTime) : null,
            matchVenue: _isMatch ? _matchVenue : null,
            recurrenceEndDate:
                _isTraining && _isRecurring ? _recurrenceEndDate : null,
          );
      if (mounted) {
        ViroSnackBar.show(
          context,
          count > 1 ? '$count événements créés' : 'Événement créé',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) ViroSnackBar.show(context, 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onTypeChanged(String? v) {
    final type = v ?? EventTypes.training;
    setState(() {
      _type = type;
      if (type == EventTypes.other) _teamId = null;
      if (type == EventTypes.match) {
        _isRecurring = false;
        _recurrenceEndDate = null;
        _matchVenue = MatchVenues.home;
        if (_matchVenue == MatchVenues.home) {
          _locationController.clear();
        }
      } else {
        _matchVenue = null;
        if (_locationController.text.isEmpty) {
          _locationController.text = 'Stade du club';
        }
      }
    });
  }

  void _onMatchVenueChanged(String? venue) {
    setState(() {
      _matchVenue = venue;
      if (venue == MatchVenues.home) {
        _locationController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(clubMemberProvider(widget.clubId)).value;
    if (member != null &&
        !MemberRoleHierarchy.isCoachOrAbove(member.role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return const ViroScaffold(
        body: Center(child: Text('Réservé aux coachs et administrateurs')),
      );
    }

    final teamsAsync = ref.watch(clubTeamsProvider(widget.clubId));

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: ViroIcon(ViroIcons.chevronLeft),
          onPressed: _saving ? null : () => context.pop(),
        ),
        title: const Text('Nouvel événement'),
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (teams) {
          if (_teamId == null &&
              teams.isNotEmpty &&
              _type != EventTypes.other) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _teamId == null) {
                setState(() => _teamId = teams.first.id);
              }
            });
          }

          return ListView(
            padding: const EdgeInsets.all(ViroSpacing.screenHorizontal),
            children: [
              const _FieldLabel('Type'),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: _inputDecoration(),
                items: const [
                  DropdownMenuItem(
                    value: EventTypes.training,
                    child: Text('Entraînement'),
                  ),
                  DropdownMenuItem(
                    value: EventTypes.match,
                    child: Text('Match'),
                  ),
                  DropdownMenuItem(
                    value: EventTypes.other,
                    child: Text('Autre'),
                  ),
                ],
                onChanged: _saving ? null : _onTypeChanged,
              ),
              const SizedBox(height: ViroSpacing.md),
              if (_type != EventTypes.other) ...[
                const _FieldLabel('Équipe'),
                DropdownButtonFormField<String>(
                  initialValue:
                      teams.any((t) => t.id == _teamId) ? _teamId : null,
                  decoration: _inputDecoration(),
                  hint: const Text('Choisir une équipe'),
                  items: teams
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.category != null && t.category!.isNotEmpty
                                ? '${t.name} (${t.category})'
                                : t.name,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving ? null : (v) => setState(() => _teamId = v),
                ),
                const SizedBox(height: ViroSpacing.md),
              ] else ...[
                const _FieldLabel('Titre'),
                TextField(
                  controller: _titleController,
                  decoration: _inputDecoration(hint: 'Réunion, stage…'),
                  enabled: !_saving,
                ),
                const SizedBox(height: ViroSpacing.md),
              ],
              if (_isMatch) ...[
                const _FieldLabel('Domicile ou extérieur'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: MatchVenues.home,
                      label: Text('Domicile'),
                    ),
                    ButtonSegment(
                      value: MatchVenues.away,
                      label: Text('Extérieur'),
                    ),
                  ],
                  selected: {_matchVenue ?? MatchVenues.home},
                  onSelectionChanged: _saving
                      ? null
                      : (s) => _onMatchVenueChanged(s.first),
                ),
                if (_matchVenue == MatchVenues.away) ...[
                  const SizedBox(height: ViroSpacing.md),
                  const _FieldLabel('Lieu du match'),
                  TextField(
                    controller: _locationController,
                    decoration: _inputDecoration(hint: 'Ville, stade adverse…'),
                    enabled: !_saving,
                  ),
                ],
                const SizedBox(height: ViroSpacing.md),
              ],
              if (_isMatch)
                const _FieldLabel('Jour du match')
              else
                const _FieldLabel('Date'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatEventDate(_date)),
                trailing:
                    ViroIcon(ViroIcons.calendar, color: ViroColors.primary600),
                onTap: _saving ? null : () => _pickDate(isRecurrenceEnd: false),
              ),
              const SizedBox(height: ViroSpacing.sm),
              if (_isMatch) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Heure du match'),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatTime(_start)),
                            onTap: _saving
                                ? null
                                : () => _pickTime(
                                      initial: _start,
                                      onPicked: (t) => _start = t,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Heure de RDV'),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatTime(_meetingTime)),
                            onTap: _saving
                                ? null
                                : () => _pickTime(
                                      initial: _meetingTime,
                                      onPicked: (t) => _meetingTime = t,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Début'),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatTime(_start)),
                            onTap: _saving
                                ? null
                                : () => _pickTime(
                                      initial: _start,
                                      onPicked: (t) => _start = t,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Fin'),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatTime(_end)),
                            onTap: _saving
                                ? null
                                : () => _pickTime(
                                      initial: _end,
                                      onPicked: (t) => _end = t,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ViroSpacing.md),
                const _FieldLabel('Lieu'),
                TextField(
                  controller: _locationController,
                  decoration: _inputDecoration(),
                  enabled: !_saving,
                ),
              ],
              if (_isTraining) ...[
                const SizedBox(height: ViroSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Récurrence hebdomadaire',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: _isRecurring,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                            _isRecurring = v;
                            if (v && _recurrenceEndDate == null) {
                              _recurrenceEndDate =
                                  _date.add(const Duration(days: 28));
                            }
                          }),
                ),
                if (_isRecurring) ...[
                  const _FieldLabel('Date de fin'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _recurrenceEndDate != null
                          ? DateFormat('EEEE dd/MM/yyyy', 'fr_FR')
                              .format(_recurrenceEndDate!)
                          : 'Choisir une date',
                    ),
                    trailing: ViroIcon(
                      ViroIcons.calendar,
                      color: ViroColors.primary600,
                    ),
                    onTap: _saving
                        ? null
                        : () => _pickDate(isRecurrenceEnd: true),
                  ),
                ],
              ],
              const SizedBox(height: ViroSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: ViroColors.primary600,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ViroColors.white,
                        ),
                      )
                    : Text(_isRecurring && _isTraining
                        ? 'Créer la série'
                        : 'Créer l\'événement'),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: ViroColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
          borderSide: BorderSide(color: ViroColors.primary100),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ViroSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: ViroColors.primary800,
            ),
      ),
    );
  }
}
