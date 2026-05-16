// ignore_for_file: unused_element_parameter

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../models/tournament/tournament_model.dart';
import '../../../../models/tournament/tournament_team.dart';
import '../../../../services/tournament_service.dart';
import '../../../../theme/viro_theme.dart';
import 'step1_general_info.dart';
import 'step2_match_format.dart';
import 'step3_structure.dart';
import 'step4_teams.dart';

enum _CreationStage { idle, creation, teams, generation }

class CreateTournamentWizard extends StatefulWidget {
  final String clubId;

  const CreateTournamentWizard({super.key, required this.clubId});

  @override
  State<CreateTournamentWizard> createState() => _CreateTournamentWizardState();
}

class _CreateTournamentWizardState extends State<CreateTournamentWizard> {
  int _currentStep = 0;
  bool _isSaving = false;
  _CreationStage _creationStage = _CreationStage.idle;

  final _formKey1 = GlobalKey<FormState>();

  String _name = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _linkedEventId;
  TournamentType _type = TournamentType.ponctuel;

  int _playersPerTeam = 1;
  VictoryFormat _victoryFormat = VictoryFormat.auTemps;
  int _timeDuration = 20;
  int _pointsTarget = 21;
  int _setsCount = 3;

  TournamentStructure _structure = TournamentStructure.tournoiSeul;
  int _nbGroups = 2;
  int _nbQualifiedPerGroup = 2;
  bool _hasIntermediate = false;
  int _nbIntermediateGroups = 2;
  int _nbQualifiedFromIntermediate = 2;
  bool _hasConsolation = false;

  List<String> _selectedPlayerIds = [];
  List<TournamentTeam> _teams = [];
  bool _isManualDraft = false;
  double _driftFactor = 0.0;
  Map<String, Map<String, String>> _guestPlayers = {};

  String? _lastCreatedTournamentId;

  static const List<String> _stepLabels = [
    'Infos',
    'Format',
    'Structure',
    'Équipes',
  ];

  bool _isCurrentStepValid() {
    if (_currentStep == 0) {
      if (_name.trim().isEmpty || _startDate == null) return false;
      if (_endDate != null &&
          _startDate != null &&
          _endDate!.isBefore(_startDate!)) {
        return false;
      }
      return true;
    }
    if (_currentStep == 2) {
      if (_structure == TournamentStructure.poulesVersTournoi ||
          _structure == TournamentStructure.poulesInterVersTournoi) {
        if (_nbQualifiedPerGroup > _maxQualifiedPerGroup) return false;
      }
      if (_structure == TournamentStructure.poulesInterVersTournoi &&
          _nbQualifiedFromIntermediate > _maxIntermediateQualifiedPerGroup) {
        return false;
      }
    }
    if (_currentStep == 3) {
      final totalPlayers = _teams.fold<int>(
        0,
        (sum, t) => sum + t.playerIds.length,
      );
      return _teams.isNotEmpty && totalPlayers > 0;
    }
    return true;
  }

  int get _maxQualifiedPerGroup {
    final totalTeams = _teams.isNotEmpty
        ? _teams.length
        : (_selectedPlayerIds.length / _playersPerTeam).ceil();
    if (totalTeams <= 0) return 16; // pas encore d'équipes — pas de contrainte
    final perGroup = (totalTeams / _nbGroups).ceil();
    return perGroup.clamp(1, 16);
  }

  int get _maxIntermediateQualifiedPerGroup {
    final interTeams = _nbGroups * _nbQualifiedPerGroup;
    if (interTeams <= 0) return 16; // pas encore d'équipes — pas de contrainte
    return (interTeams / _nbIntermediateGroups).ceil().clamp(1, 16);
  }

  void _onNext() {
    if (_currentStep == 0 && !(_formKey1.currentState?.validate() ?? false)) {
      return;
    }
    if (!_isCurrentStepValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Corrigez les champs avant de continuer.'),
        ),
      );
      return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  TournamentModel _buildTournamentModel(String uid) {
    return TournamentModel(
      id: '',
      name: _name.trim(),
      type: _type,
      status: TournamentStatus.draft,
      startDate: _startDate!,
      endDate: _endDate,
      linkedEventId: _linkedEventId,
      playersPerTeam: _playersPerTeam,
      victoryFormat: _victoryFormat,
      timeDurationMinutes: _timeDuration,
      pointsTarget: _pointsTarget,
      setsCount: _setsCount,
      structure: _structure,
      nbGroups: _nbGroups,
      nbQualifiedPerGroup: _nbQualifiedPerGroup,
      hasIntermediatePhase: _hasIntermediate,
      nbIntermediateGroups: _nbIntermediateGroups,
      nbQualifiedFromIntermediate: _nbQualifiedFromIntermediate,
      hasConsolationBracket: _hasConsolation,
      driftFactor: _driftFactor,
      isManualDraft: _isManualDraft,
      createdAt: DateTime.now(),
      createdBy: uid,
    );
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final tournament = _buildTournamentModel(uid);
    final svc = TournamentService.instance;
    setState(() {
      _isSaving = true;
      _creationStage = _CreationStage.creation;
    });

    try {
      final tournamentId =
          _lastCreatedTournamentId ??
          await svc.createTournament(widget.clubId, tournament);
      _lastCreatedTournamentId = tournamentId;

      setState(() => _creationStage = _CreationStage.teams);
      // Enrichit chaque équipe avec les données des joueurs hors club qu'elle contient
      final enrichedTeams = _teams.map((t) {
        final guests = Map<String, Map<String, String>>.fromEntries(
          _guestPlayers.entries.where((e) => t.playerIds.contains(e.key)),
        );
        return guests.isEmpty ? t : t.copyWith(guestPlayers: guests);
      }).toList();
      await svc.saveTeams(widget.clubId, tournamentId, enrichedTeams);

      setState(() => _creationStage = _CreationStage.generation);
      await svc.generateTournament(
        widget.clubId,
        tournament.copyWith(id: tournamentId),
        _teams,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tournoi "${tournament.name}" créé.'),
          backgroundColor: ViroColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Échec de création. Réessayez ou reprenez la génération.',
          ),
          backgroundColor: ViroColors.error,
          action: SnackBarAction(
            label: 'Réessayer',
            textColor: Colors.white,
            onPressed: _save,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _creationStage = _CreationStage.idle;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBack,
        ),
        title: const Text(
          'Créer un tournoi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: _buildStepIndicator(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildCurrentStep(),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: List.generate(_stepLabels.length, (i) {
          final active = i == _currentStep;
          final done = i < _currentStep;
          final isLast = i == _stepLabels.length - 1;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (active || done)
                              ? ViroColors.primary
                              : Colors.grey.shade300,
                        ),
                        child: Center(
                          child: done
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stepLabels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: active ? ViroColors.primary : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: done ? ViroColors.primary : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return Step1GeneralInfo(
          key: const ValueKey(0),
          clubId: widget.clubId,
          name: _name,
          startDate: _startDate,
          endDate: _endDate,
          linkedEventId: _linkedEventId,
          type: _type,
          formKey: _formKey1,
          onNameChanged: (v) => setState(() => _name = v),
          onStartDateChanged: (v) => setState(() => _startDate = v),
          onEndDateChanged: (v) => setState(() => _endDate = v),
          onLinkedEventChanged: (v) => setState(() => _linkedEventId = v),
          onTypeChanged: (v) => setState(() => _type = v),
        );
      case 1:
        return Step2MatchFormat(
          key: const ValueKey(1),
          clubId: widget.clubId,
          playersPerTeam: _playersPerTeam,
          victoryFormat: _victoryFormat,
          timeDuration: _timeDuration,
          pointsTarget: _pointsTarget,
          setsCount: _setsCount,
          onPlayersPerTeamChanged: (v) => setState(() => _playersPerTeam = v),
          onVictoryFormatChanged: (v) => setState(() => _victoryFormat = v),
          onTimeDurationChanged: (v) => setState(() => _timeDuration = v),
          onPointsTargetChanged: (v) => setState(() => _pointsTarget = v),
          onSetsCountChanged: (v) => setState(() => _setsCount = v),
        );
      case 2:
        return Step3Structure(
          key: const ValueKey(2),
          structure: _structure,
          nbGroups: _nbGroups,
          nbQualifiedPerGroup: _nbQualifiedPerGroup,
          hasIntermediate: _hasIntermediate,
          nbIntermediateGroups: _nbIntermediateGroups,
          nbQualifiedFromIntermediate: _nbQualifiedFromIntermediate,
          hasConsolation: _hasConsolation,
          onStructureChanged: (v) => setState(() {
            _structure = v;
            _hasIntermediate = v == TournamentStructure.poulesInterVersTournoi;
          }),
          onNbGroupsChanged: (v) => setState(() => _nbGroups = v),
          onNbQualifiedPerGroupChanged: (v) =>
              setState(() => _nbQualifiedPerGroup = v),
          onHasIntermediateChanged: (v) => setState(() => _hasIntermediate = v),
          onNbIntermediateGroupsChanged: (v) =>
              setState(() => _nbIntermediateGroups = v),
          onNbQualifiedFromIntermediateChanged: (v) =>
              setState(() => _nbQualifiedFromIntermediate = v),
          onHasConsolationChanged: (v) => setState(() => _hasConsolation = v),
        );
      case 3:
      default:
        return Column(
          key: const ValueKey(3),
          children: [
            Expanded(
              child: Step4Teams(
                clubId: widget.clubId,
                structure: _structure,
                nbGroups: _nbGroups,
                playersPerTeam: _playersPerTeam,
                selectedPlayerIds: _selectedPlayerIds,
                teams: _teams,
                isManualDraft: _isManualDraft,
                driftFactor: _driftFactor,
                guestPlayers: _guestPlayers,
                onPlayersChanged: (v) => setState(() => _selectedPlayerIds = v),
                onTeamsChanged: (v) => setState(() => _teams = v),
                onManualDraftChanged: (v) => setState(() => _isManualDraft = v),
                onDriftFactorChanged: (v) => setState(() => _driftFactor = v),
                onGuestPlayersChanged: (v) =>
                    setState(() => _guestPlayers = v),
              ),
            ),
            _buildFinalSummary(),
          ],
        );
    }
  }

  Widget _buildFinalSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ViroColors.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résumé final',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('Format: ${_formatLabel()}'),
          Text('Structure: ${_structureLabel(_structure)}'),
          Text(
            'Équipes: ${_teams.length} (${_selectedPlayerIds.length} joueurs)',
          ),
          Text('Matchs estimés: ${_estimatedMatches()}'),
        ],
      ),
    );
  }

  String _formatLabel() {
    switch (_victoryFormat) {
      case VictoryFormat.auTemps:
        return '2 × $_timeDuration min';
      case VictoryFormat.auxPoints:
        return 'Premier à $_pointsTarget';
      case VictoryFormat.auxSets:
        return 'Meilleur des $_setsCount sets';
    }
  }

  int _estimatedMatches() {
    final n = _teams.length;
    if (n < 2) return 0;
    switch (_structure) {
      case TournamentStructure.championnatSeul:
        return (n * (n - 1)) ~/ 2;
      case TournamentStructure.tournoiSeul:
        return n - 1;
      case TournamentStructure.poulesVersTournoi:
        return ((n * (n - 1)) ~/ 4) +
            (_nbGroups * _nbQualifiedPerGroup - 1).clamp(0, 9999);
      case TournamentStructure.poulesInterVersTournoi:
        final phase1 = ((n * (n - 1)) ~/ 4);
        final inter = (_nbGroups * _nbQualifiedPerGroup);
        final phase2 = inter > 1 ? ((inter * (inter - 1)) ~/ 4) : 0;
        final finalK = (_nbIntermediateGroups * _nbQualifiedFromIntermediate);
        final phase3 = finalK > 1 ? finalK - 1 : 0;
        return phase1 + phase2 + phase3;
    }
  }

  String _structureLabel(TournamentStructure s) {
    switch (s) {
      case TournamentStructure.championnatSeul:
        return 'Championnat';
      case TournamentStructure.tournoiSeul:
        return 'Tournoi direct';
      case TournamentStructure.poulesVersTournoi:
        return 'Poules + finale';
      case TournamentStructure.poulesInterVersTournoi:
        return 'Poules + intermédiaire + finale';
    }
  }

  Widget _buildBottomBar() {
    final isLast = _currentStep == 3;
    final canContinue = _isCurrentStepValid() && !_isSaving;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSaving) _buildCreationProgress(),
            if (!_isSaving && !canContinue)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Complétez cette étape pour continuer.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canContinue ? _onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ViroColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isLast ? 'CRÉER' : 'SUIVANT',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreationProgress() {
    final stages = [
      ('Création', _creationStage.index >= _CreationStage.creation.index),
      ('Équipes', _creationStage.index >= _CreationStage.teams.index),
      ('Génération', _creationStage.index >= _CreationStage.generation.index),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final s in stages)
            Expanded(
              child: Row(
                children: [
                  Icon(
                    s.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 14,
                    color: s.$2 ? ViroColors.success : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(s.$1, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
