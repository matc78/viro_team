import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/viro_theme.dart';

/// Zone de notes pour le coach, auto-expand et sauvegarde locale.
class CoachNotesWidget extends StatefulWidget {
  final String clubId;
  final String? sport;
  final ValueNotifier<int>? resetTrigger;

  const CoachNotesWidget({
    super.key,
    required this.clubId,
    this.sport,
    this.resetTrigger,
  });

  @override
  State<CoachNotesWidget> createState() => _CoachNotesWidgetState();
}

class _CoachNotesWidgetState extends State<CoachNotesWidget> {
  late TextEditingController _controller;
  bool _isInitialized = false;
  bool _isHidden = false;
  int _lastResetVersion = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadNotes();
    widget.resetTrigger?.addListener(_onResetTriggered);
  }

  @override
  void dispose() {
    _saveNotes();
    _controller.dispose();
    widget.resetTrigger?.removeListener(_onResetTriggered);
    super.dispose();
  }

  void _onResetTriggered() {
    if (widget.resetTrigger != null &&
        widget.resetTrigger!.value > _lastResetVersion) {
      _lastResetVersion = widget.resetTrigger!.value;
      _controller.clear();
      _saveNotes();
    }
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notes_${widget.clubId}_${widget.sport ?? 'default'}';
    final text = prefs.getString(key) ?? '';
    final hidden = prefs.getBool('${key}_hidden') ?? false;

    if (mounted) {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      setState(() {
        _isHidden = hidden;
        _isInitialized = true;
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notes_${widget.clubId}_${widget.sport ?? 'default'}';
    await prefs.setString(key, _controller.text);
    await prefs.setBool('${key}_hidden', _isHidden);
  }

  void _toggleVisibility() {
    setState(() {
      _isHidden = !_isHidden;
      _saveNotes();
    });
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Notes',
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
          if (!_isHidden)
            TextField(
              controller: _controller,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notes pendant l\'entraînement ou le match...',
                border: OutlineInputBorder(borderSide: BorderSide.none),
                contentPadding: EdgeInsets.all(12),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => _saveNotes(),
            ),
        ],
      ),
    );
  }
}
