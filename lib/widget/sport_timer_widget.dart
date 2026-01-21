import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/viro_theme.dart';

/// Widget de chronomètre pour les matchs
class SportTimerWidget extends StatefulWidget {
  final String clubId;
  final String? sport;

  const SportTimerWidget({super.key, required this.clubId, this.sport});

  @override
  State<SportTimerWidget> createState() => _SportTimerWidgetState();
}

class _SportTimerWidgetState extends State<SportTimerWidget> {
  Timer? _timer;
  int _totalCentiseconds = 0;
  bool _isRunning = false;
  bool _isInitialized = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTimer() async {
    _prefs = await SharedPreferences.getInstance();
    final key = 'timer_${widget.clubId}_${widget.sport ?? 'default'}';

    setState(() {
      _totalCentiseconds = _prefs.getInt('${key}_centiseconds') ?? 0;
      _isRunning = _prefs.getBool('${key}_running') ?? false;
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

    final isInactive = !_isRunning && _totalCentiseconds == 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isInactive ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInactive ? Colors.grey[300]! : ViroColors.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(_totalCentiseconds),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isInactive ? Colors.grey[600] : ViroColors.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
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
                  color: isInactive ? Colors.grey[400] : Colors.grey,
                ),
                onPressed: _resetTimer,
                tooltip: 'Réinitialiser',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  backgroundColor: isInactive
                      ? Colors.grey[200]
                      : Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
