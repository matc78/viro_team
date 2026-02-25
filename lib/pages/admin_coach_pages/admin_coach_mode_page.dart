import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/whistle_sound.dart';
import '../../widget/coach_countdown_widget.dart';
import '../../widget/coach_notes_widget.dart';
import '../../widget/coach_zapata_widget.dart';
import '../../widget/sport_score_widget.dart';
import '../../widget/sport_timer_widget.dart';

const _defaultOrder = ['timer', 'countdown', 'zapata', 'score', 'notes'];

/// Page Mode Coach : chronomètre, countdown, Zapata, scoreur et notes pour les entraînements/matchs.
class AdminCoachModePage extends StatefulWidget {
  final String clubId;
  final String? sport;

  const AdminCoachModePage({
    super.key,
    required this.clubId,
    this.sport,
  });

  @override
  State<AdminCoachModePage> createState() => _AdminCoachModePageState();
}

class _AdminCoachModePageState extends State<AdminCoachModePage> {
  final ValueNotifier<int> _resetTrigger = ValueNotifier(0);
  List<String> _orderedIds = List.from(_defaultOrder);
  bool _isInitialized = false;

  void _playWhistle() {
    WhistleSound.play();
  }

  void _resetAll() {
    _resetTrigger.value++;
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'coach_widget_order_${widget.clubId}_${widget.sport ?? 'default'}';
    final saved = prefs.getStringList(key);
    if (mounted && saved != null && saved.length == _defaultOrder.length) {
      final valid = saved.every((id) => _defaultOrder.contains(id));
      if (valid) {
        setState(() => _orderedIds = List.from(saved));
      }
    }
    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'coach_widget_order_${widget.clubId}_${widget.sport ?? 'default'}';
    await prefs.setStringList(key, _orderedIds);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final id = _orderedIds.removeAt(oldIndex);
      _orderedIds.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, id);
    });
    _saveOrder();
  }

  Widget _buildWidgetForId(String id, {bool includeBottomSpacing = true}) {
    final child = switch (id) {
      'timer' => SportTimerWidget(
          clubId: widget.clubId,
          sport: widget.sport,
          resetTrigger: _resetTrigger,
        ),
      'countdown' => CoachCountdownWidget(
          clubId: widget.clubId,
          sport: widget.sport,
          resetTrigger: _resetTrigger,
        ),
      'zapata' => CoachZapataWidget(
          clubId: widget.clubId,
          sport: widget.sport,
          resetTrigger: _resetTrigger,
        ),
      'score' => SportScoreWidget(
          sport: widget.sport,
          clubId: widget.clubId,
          resetTrigger: _resetTrigger,
        ),
      'notes' => CoachNotesWidget(
          clubId: widget.clubId,
          sport: widget.sport,
          resetTrigger: _resetTrigger,
        ),
      _ => const SizedBox.shrink(),
    };
    if (!includeBottomSpacing) return child;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _resetTrigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 248, 249, 250),
      appBar: AppBar(
        title: const Text("Mode Coach"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_martial_arts),
            tooltip: 'Coup de sifflet',
            onPressed: _playWhistle,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset tout',
            onPressed: _resetAll,
          ),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.all(20.0),
        buildDefaultDragHandles: false,
        onReorder: _onReorder,
        proxyDecorator: (child, index, animation) => Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: _buildWidgetForId(
            _orderedIds[index],
            includeBottomSpacing: false,
          ),
        ),
        children: [
          for (var i = 0; i < _orderedIds.length; i++)
            ReorderableDelayedDragStartListener(
              key: ValueKey(_orderedIds[i]),
              index: i,
              child: _buildWidgetForId(_orderedIds[i]),
            ),
        ],
      ),
    );
  }
}
