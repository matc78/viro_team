import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/viro_theme.dart';
import '../utils/buzzer_sound.dart';
import '../utils/whistle_sound.dart';

/// Chrono Zapata : temps d'exercice, temps de pause, repos tous les N exercices.
enum ZapataPhase { exercise, pause, rest }

class CoachZapataWidget extends StatefulWidget {
  final String clubId;
  final String? sport;
  final ValueNotifier<int>? resetTrigger;

  const CoachZapataWidget({
    super.key,
    required this.clubId,
    this.sport,
    this.resetTrigger,
  });

  @override
  State<CoachZapataWidget> createState() => _CoachZapataWidgetState();
}

class _CoachZapataWidgetState extends State<CoachZapataWidget> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _exerciseSeconds = 30;
  int _pauseSeconds = 15;
  int _restEveryN = 0; // 0 = désactivé
  int _restSeconds = 60;
  int _exerciseCount = 0;
  int _pauseCount = 0;
  ZapataPhase _phase = ZapataPhase.exercise;
  bool _isRunning = false;
  bool _isInCountdown = false;
  int _countdownValue = 0; // 3, 2, 1 ou 0 (partez)
  Timer? _countdownTimer;
  Timer? _preSoundTimer;
  bool _isInitialized = false;
  int _lastResetVersion = 0;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadState();
    widget.resetTrigger?.addListener(_onResetTriggered);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _preSoundTimer?.cancel();
    widget.resetTrigger?.removeListener(_onResetTriggered);
    super.dispose();
  }

  void _onResetTriggered() {
    if (widget.resetTrigger != null &&
        widget.resetTrigger!.value > _lastResetVersion) {
      _lastResetVersion = widget.resetTrigger!.value;
      _resetZapata();
    }
  }

  bool _isHidden = false;

  Future<void> _loadState() async {
    _prefs = await SharedPreferences.getInstance();
    final key = 'zapata_${widget.clubId}_${widget.sport ?? 'default'}';

    setState(() {
      _exerciseSeconds = _prefs.getInt('${key}_exercise') ?? 30;
      _pauseSeconds = _prefs.getInt('${key}_pause') ?? 15;
      _restEveryN = _prefs.getInt('${key}_restEveryN') ?? 0;
      _restSeconds = _prefs.getInt('${key}_restSeconds') ?? 60;
      _remainingSeconds = _exerciseSeconds;
      _phase = ZapataPhase.exercise;
      _exerciseCount = 0;
      _pauseCount = 0;
      _isRunning = false;
      _isHidden = _prefs.getBool('${key}_hidden') ?? false;
      _isInitialized = true;
    });
  }

  Future<void> _saveState() async {
    final key = 'zapata_${widget.clubId}_${widget.sport ?? 'default'}';
    await _prefs.setInt('${key}_exercise', _exerciseSeconds);
    await _prefs.setInt('${key}_pause', _pauseSeconds);
    await _prefs.setInt('${key}_restEveryN', _restEveryN);
    await _prefs.setInt('${key}_restSeconds', _restSeconds);
    await _prefs.setBool('${key}_hidden', _isHidden);
  }

  void _toggleVisibility() {
    setState(() {
      _isHidden = !_isHidden;
      _saveState();
    });
  }

  void _tick() {
    setState(() => _remainingSeconds--);

    if (_remainingSeconds == 3 &&
        _phase == ZapataPhase.rest &&
        _restSeconds > 4) {
      _timer?.cancel();
      _phase = ZapataPhase.exercise;
      _remainingSeconds = _exerciseSeconds;
      setState(() {
        _isInCountdown = true;
        _countdownValue = 3;
      });
      _runCountdownThenStartExercise();
      return;
    }

    if (_remainingSeconds == 1 && !(_phase == ZapataPhase.rest && _restSeconds > 4)) {
      final useBuzzer = _phase == ZapataPhase.exercise &&
          _restEveryN > 0 &&
          (_exerciseCount + 1) % _restEveryN == 0;
      final useBuzzerRest = _phase == ZapataPhase.rest && _restSeconds <= 4;
      final sound = useBuzzer || useBuzzerRest
          ? () => BuzzerSound.play()
          : () => WhistleSound.play();
      _preSoundTimer?.cancel();
      _preSoundTimer = Timer(const Duration(milliseconds: _soundOffsetMs), sound);
    }

    if (_remainingSeconds <= 0) {
      _timer?.cancel();

      if (_phase == ZapataPhase.exercise) {
        _exerciseCount++;

        if (_restEveryN > 0 && _exerciseCount % _restEveryN == 0) {
          _phase = ZapataPhase.rest;
          _remainingSeconds = _restSeconds;
        } else {
          _phase = ZapataPhase.pause;
          _pauseCount++;
          _remainingSeconds = _pauseSeconds;
        }
      } else if (_phase == ZapataPhase.rest) {
        _phase = ZapataPhase.exercise;
        _remainingSeconds = _exerciseSeconds;
      } else {
        _phase = ZapataPhase.exercise;
        _remainingSeconds = _exerciseSeconds;
      }

      if (_isRunning) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    }
  }

  static const _soundOffsetMs = 250;

  void _runCountdownThenStartExercise() {
    _countdownTimer?.cancel();
    BuzzerSound.play();
    _countdownTimer = Timer(const Duration(milliseconds: _soundOffsetMs), () {
      if (!mounted) return;
      setState(() {
        _isInCountdown = true;
        _countdownValue = 3;
      });
      _countdownTimer = Timer(const Duration(milliseconds: 1000 - _soundOffsetMs), () {
        _scheduleCountdownStep(2);
      });
    });
  }

  void _scheduleCountdownStep(int n) {
    if (!mounted) return;
    _countdownTimer?.cancel();
    if (n > 1) {
      BuzzerSound.play();
      _countdownTimer = Timer(const Duration(milliseconds: _soundOffsetMs), () {
        if (!mounted) return;
        setState(() => _countdownValue = n);
        _countdownTimer = Timer(const Duration(milliseconds: 1000 - _soundOffsetMs), () {
          _scheduleCountdownStep(n - 1);
        });
      });
    } else {
      BuzzerSound.play();
      _countdownTimer = Timer(const Duration(milliseconds: _soundOffsetMs), () {
        if (!mounted) return;
        setState(() => _countdownValue = 1);
        _countdownTimer = Timer(const Duration(milliseconds: 1000 - _soundOffsetMs), () {
          if (!mounted) return;
          WhistleSound.play();
          _countdownTimer = Timer(const Duration(milliseconds: _soundOffsetMs), () {
            if (!mounted) return;
            setState(() {
              _countdownValue = 0;
              _isInCountdown = false;
            });
            if (_isRunning) {
              _timer = Timer.periodic(
                  const Duration(seconds: 1), (_) => _tick());
            }
          });
        });
      });
    }
  }

  void _startZapata() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    setState(() => _isRunning = true);

    final isAtStart = _phase == ZapataPhase.exercise &&
        _exerciseCount == 0 &&
        _remainingSeconds == _exerciseSeconds;

    if (isAtStart) {
      _runCountdownThenStartExercise();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _pauseZapata() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _preSoundTimer?.cancel();
    setState(() {
      _isRunning = false;
      _isInCountdown = false;
    });
  }

  void _resetZapata() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _preSoundTimer?.cancel();
    setState(() {
      _phase = ZapataPhase.exercise;
      _remainingSeconds = _exerciseSeconds;
      _exerciseCount = 0;
      _pauseCount = 0;
      _isRunning = false;
      _isInCountdown = false;
      _saveState();
    });
  }

  Future<void> _showConfigDialog() async {
    final exController =
        TextEditingController(text: _exerciseSeconds.toString());
    final pauseController =
        TextEditingController(text: _pauseSeconds.toString());
    final restNController = TextEditingController(
      text: _restEveryN > 0 ? _restEveryN.toString() : '',
    );
    final restSecController =
        TextEditingController(text: _restSeconds.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurer Zapata'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: exController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Temps exercice (sec)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pauseController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Temps pause (sec)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: restNController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Repos tous les N exercices (0 = désactivé)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: restSecController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Temps repos long (sec)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _timer?.cancel();
      _countdownTimer?.cancel();
      _preSoundTimer?.cancel();
      setState(() {
        _exerciseSeconds =
            (int.tryParse(exController.text) ?? 30).clamp(1, 999);
        _pauseSeconds =
            (int.tryParse(pauseController.text) ?? 15).clamp(0, 999);
        _restEveryN =
            (int.tryParse(restNController.text) ?? 0).clamp(0, 99);
        _restSeconds =
            (int.tryParse(restSecController.text) ?? 60).clamp(1, 999);
        _phase = ZapataPhase.exercise;
        _remainingSeconds = _exerciseSeconds;
        _exerciseCount = 0;
        _pauseCount = 0;
        _isRunning = false;
        _isInCountdown = false;
        _saveState();
      });
    }
  }

  String _phaseLabel() {
    switch (_phase) {
      case ZapataPhase.exercise:
        return 'Exercice';
      case ZapataPhase.pause:
        return 'Pause $_pauseCount';
      case ZapataPhase.rest:
        return 'Repos';
    }
  }

  Color _phaseColor() {
    switch (_phase) {
      case ZapataPhase.exercise:
        return ViroColors.primary;
      case ZapataPhase.pause:
        return ViroColors.accent;
      case ZapataPhase.rest:
        return ViroColors.success;
    }
  }

  String _formatTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ViroColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Zapata',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              if (!_isHidden)
                IconButton(
                  icon: const Icon(Icons.settings, size: 18),
                  onPressed: _showConfigDialog,
                  tooltip: 'Configurer',
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(
                      _isHidden ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                    ),
                    onPressed: _toggleVisibility,
                    tooltip: _isHidden ? 'Afficher' : 'Cacher',
                  ),
                ),
              ),
            ],
          ),
          if (!_isHidden) ...[
          if (_isInCountdown) ...[
            Text(
              _countdownValue > 0 ? '$_countdownValue' : 'Partez !',
              style: TextStyle(
                fontSize: _countdownValue > 0 ? 48 : 24,
                fontWeight: FontWeight.bold,
                color: ViroColors.primary,
              ),
            ),
          ] else ...[
            Text(
              _phaseLabel(),
              style: TextStyle(
                fontSize: 14,
                color: _phaseColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _formatTime(_remainingSeconds),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _phaseColor(),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (_phase == ZapataPhase.exercise)
              Text(
                'Exo ${_exerciseCount + 1}',
                style: const TextStyle(fontSize: 12, color: Colors.black),
              ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRunning)
                ElevatedButton(
                  onPressed: _startZapata,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ViroColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 16,
                    color: Colors.white,
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _pauseZapata,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ViroColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.pause, size: 16, color: Colors.white),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  size: 18,
                  color: _exerciseCount > 0 || _remainingSeconds != _exerciseSeconds
                      ? ViroColors.primary
                      : Colors.grey,
                ),
                onPressed: _resetZapata,
                tooltip: 'Réinitialiser',
              ),
            ],
          ),
          ],
        ],
      ),
    );
  }
}
