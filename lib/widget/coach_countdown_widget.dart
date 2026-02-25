import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/viro_theme.dart';
import '../utils/whistle_sound.dart';

/// Countdown pour le mode coach avec alerte son et notification optionnelle.
class CoachCountdownWidget extends StatefulWidget {
  final String clubId;
  final String? sport;
  final ValueNotifier<int>? resetTrigger;

  const CoachCountdownWidget({
    super.key,
    required this.clubId,
    this.sport,
    this.resetTrigger,
  });

  @override
  State<CoachCountdownWidget> createState() => _CoachCountdownWidgetState();
}

class _CoachCountdownWidgetState extends State<CoachCountdownWidget> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _targetSeconds = 60;
  bool _isRunning = false;
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
    widget.resetTrigger?.removeListener(_onResetTriggered);
    super.dispose();
  }

  void _onResetTriggered() {
    if (widget.resetTrigger != null &&
        widget.resetTrigger!.value > _lastResetVersion) {
      _lastResetVersion = widget.resetTrigger!.value;
      _resetCountdown();
    }
  }

  bool _isHidden = false;

  Future<void> _loadState() async {
    _prefs = await SharedPreferences.getInstance();
    final key = 'countdown_${widget.clubId}_${widget.sport ?? 'default'}';

    setState(() {
      _targetSeconds = _prefs.getInt('${key}_target') ?? 60;
      _remainingSeconds = _prefs.getInt('${key}_remaining') ?? 60;
      _isRunning = false;
      _isHidden = _prefs.getBool('${key}_hidden') ?? false;
      _isInitialized = true;
    });
  }

  Future<void> _saveState() async {
    final key = 'countdown_${widget.clubId}_${widget.sport ?? 'default'}';
    await _prefs.setInt('${key}_target', _targetSeconds);
    await _prefs.setInt('${key}_remaining', _remainingSeconds);
    await _prefs.setBool('${key}_hidden', _isHidden);
  }

  void _toggleVisibility() {
    setState(() {
      _isHidden = !_isHidden;
      _saveState();
    });
  }

  void _startCountdown() {
    if (_remainingSeconds <= 0) _remainingSeconds = _targetSeconds;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        _saveState();
      });

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _saveState();

        WhistleSound.play();

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Temps écoulé !'),
              content: const Text('Le compte à rebours est terminé.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    });

    setState(() => _isRunning = true);
  }

  Future<void> _showTimerPicker() async {
    Duration selectedDuration = Duration(seconds: _targetSeconds);

    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 320,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(selectedDuration.inSeconds),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hms,
                initialTimerDuration: selectedDuration,
                minuteInterval: 1,
                secondInterval: 1,
                onTimerDurationChanged: (Duration value) {
                  selectedDuration = value;
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null && result > 0 && mounted) {
      final totalSeconds = result.clamp(1, 86399);
      setState(() {
        _targetSeconds = totalSeconds;
        if (!_isRunning) _remainingSeconds = totalSeconds;
        _saveState();
      });
    }
  }

  void _pauseCountdown() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _saveState();
    });
  }

  void _resetCountdown() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _targetSeconds;
      _isRunning = false;
      _saveState();
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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
              Text(
                'Compte à rebours',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _isHidden ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                ),
                onPressed: _toggleVisibility,
                tooltip: _isHidden ? 'Afficher' : 'Cacher',
              ),
            ],
          ),
          if (!_isHidden) ...[
            GestureDetector(
              onTap: _remainingSeconds == _targetSeconds && !_isRunning
                  ? _showTimerPicker
                  : null,
              child: Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _remainingSeconds <= 10 && _isRunning
                      ? ViroColors.error
                      : ViroColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (_remainingSeconds == _targetSeconds && !_isRunning)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Appuyez pour modifier',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRunning)
                  ElevatedButton(
                    onPressed: _startCountdown,
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
                    onPressed: _pauseCountdown,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ViroColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(40, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(
                      Icons.pause,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 18,
                    color: _remainingSeconds != _targetSeconds
                        ? ViroColors.primary
                        : Colors.grey,
                  ),
                  onPressed: _resetCountdown,
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
