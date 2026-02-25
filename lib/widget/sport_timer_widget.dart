import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/viro_theme.dart';

/// Widget de chronomètre pour les matchs
class SportTimerWidget extends StatefulWidget {
  final String clubId;
  final String? sport;
  final ValueNotifier<int>? resetTrigger;

  const SportTimerWidget({
    super.key,
    required this.clubId,
    this.sport,
    this.resetTrigger,
  });

  @override
  State<SportTimerWidget> createState() => _SportTimerWidgetState();
}

class _SportTimerWidgetState extends State<SportTimerWidget> {
  Timer? _timer;
  int _totalCentiseconds = 0;
  bool _isRunning = false;
  bool _isInitialized = false;
  int _lastResetVersion = 0;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadTimer();
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
      _resetTimer();
    }
  }

  bool _isHidden = false;

  Future<void> _loadTimer() async {
    _prefs = await SharedPreferences.getInstance();
    final key = 'timer_${widget.clubId}_${widget.sport ?? 'default'}';

    setState(() {
      _totalCentiseconds = _prefs.getInt('${key}_centiseconds') ?? 0;
      _isRunning = _prefs.getBool('${key}_running') ?? false;
      _isHidden = _prefs.getBool('${key}_hidden') ?? false;
      _isInitialized = true;
    });

    if (_isRunning) {
      _startTimer();
    }
  }

  Future<void> _saveTimer() async {
    final key = 'timer_${widget.clubId}_${widget.sport ?? 'default'}';
    await _prefs.setInt('${key}_centiseconds', _totalCentiseconds);
    await _prefs.setBool('${key}_running', _isRunning);
    await _prefs.setBool('${key}_hidden', _isHidden);
  }

  void _toggleVisibility() {
    setState(() {
      _isHidden = !_isHidden;
      _saveTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _totalCentiseconds++;
        _saveTimer();
      });
    });
    setState(() {
      _isRunning = true;
      _saveTimer();
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _saveTimer();
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _totalCentiseconds = 0;
      _isRunning = false;
      _saveTimer();
    });
  }

  String _formatTime(int totalCentiseconds) {
    final totalSeconds = totalCentiseconds ~/ 100;
    final centiseconds = totalCentiseconds % 100;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

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
                'Chronomètre',
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
            Text(
              _formatTime(_totalCentiseconds),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ViroColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRunning)
                  ElevatedButton(
                    onPressed: _startTimer,
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
                    onPressed: _pauseTimer,
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
                    color: _totalCentiseconds > 0
                        ? ViroColors.primary
                        : Colors.grey,
                  ),
                  onPressed: _resetTimer,
                  tooltip: 'Réinitialiser',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    backgroundColor: _totalCentiseconds > 0
                        ? ViroColors.primary.withValues(alpha: 0.15)
                        : Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
