import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../models/tournament/tournament_match.dart';
import '../../models/tournament/tournament_team.dart';
import '../../theme/viro_theme.dart';

class ScoreEntryDialog extends StatefulWidget {
  final TournamentMatch match;
  final TournamentTeam? teamA;
  final TournamentTeam? teamB;
  final Future<void> Function(int scoreA, int scoreB, bool completed) onSave;
  final FutureOr<void> Function()? onSaveAndNext;

  const ScoreEntryDialog({
    super.key,
    required this.match,
    required this.teamA,
    required this.teamB,
    required this.onSave,
    this.onSaveAndNext,
  });

  @override
  State<ScoreEntryDialog> createState() => _ScoreEntryDialogState();
}

class _ScoreEntryDialogState extends State<ScoreEntryDialog> {
  late final TextEditingController _ctrlA;
  late final TextEditingController _ctrlB;
  late final FocusNode _focusA;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ctrlA = TextEditingController(
        text: widget.match.scoreA > 0 ? '${widget.match.scoreA}' : '');
    _ctrlB = TextEditingController(
        text: widget.match.scoreB > 0 ? '${widget.match.scoreB}' : '');
    _focusA = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusA.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _ctrlA.dispose();
    _ctrlB.dispose();
    _focusA.dispose();
    super.dispose();
  }

  Future<void> _save({
    required bool completed,
    bool goNext = false,
  }) async {
    final sA = int.tryParse(_ctrlA.text.trim()) ?? 0;
    final sB = int.tryParse(_ctrlB.text.trim()) ?? 0;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(sA, sB, completed);
      if (mounted) Navigator.of(context).pop();
      if (goNext) {
        await widget.onSaveAndNext?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: ViroColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameA = widget.teamA?.name ?? 'Équipe A';
    final nameB = widget.teamB?.name ?? 'Équipe B';

    return AlertDialog(
      title: const Text('Score du match',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(nameA,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    TextField(
                      focusNode: _focusA,
                      autofocus: true,
                      controller: _ctrlA,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: false,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('—',
                    style: TextStyle(
                        fontSize: 24, color: Colors.grey)),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(nameB,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ctrlB,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: false,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        OutlinedButton(
          onPressed: _isSaving
              ? null
              : () => _save(completed: false),
          child: const Text('Enregistrer brouillon'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () => _save(completed: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: ViroColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Terminer match'),
        ),
        if (widget.onSaveAndNext != null)
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () => _save(completed: true, goNext: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ViroColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Terminer et suivant'),
        ),
      ],
    );
  }
}
