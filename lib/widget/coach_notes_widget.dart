import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/firebase_collections.dart';
import '../theme/viro_theme.dart';
import '../utils/firestore_instance.dart';

/// Zone de notes pour le coach, auto-expand et sauvegarde locale (SharedPreferences).
/// Quand [eventId] est fourni, les notes sont également persistées dans Firestore
/// sous `clubs/{clubId}/events/{eventId}.sessionNotes` avec un debounce de 1,5 s.
class CoachNotesWidget extends StatefulWidget {
  final String clubId;
  final String? sport;
  final ValueNotifier<int>? resetTrigger;

  /// Identifiant de l'événement en cours. Si fourni, les notes sont sauvegardées
  /// sur Firestore en plus du stockage local.
  final String? eventId;

  const CoachNotesWidget({
    super.key,
    required this.clubId,
    this.sport,
    this.resetTrigger,
    this.eventId,
  });

  @override
  State<CoachNotesWidget> createState() => _CoachNotesWidgetState();
}

class _CoachNotesWidgetState extends State<CoachNotesWidget> {
  late TextEditingController _controller;
  bool _isInitialized = false;
  bool _isHidden = false;
  int _lastResetVersion = 0;
  Timer? _debounce;

  String get _localKey =>
      'notes_${widget.clubId}_${widget.sport ?? 'default'}';

  DocumentReference? get _eventRef => widget.eventId != null
      ? appFirestore
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.events)
          .doc(widget.eventId)
      : null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadNotes();
    widget.resetTrigger?.addListener(_onResetTriggered);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _saveLocal();
    _controller.dispose();
    widget.resetTrigger?.removeListener(_onResetTriggered);
    super.dispose();
  }

  void _onResetTriggered() {
    if (widget.resetTrigger != null &&
        widget.resetTrigger!.value > _lastResetVersion) {
      _lastResetVersion = widget.resetTrigger!.value;
      _controller.clear();
      _onNotesChanged('');
    }
  }

  Future<void> _loadNotes() async {
    // Si event lié, on charge depuis Firestore en priorité
    if (_eventRef != null) {
      try {
        final doc = await _eventRef!.get();
        final data = (doc.data() as Map<String, dynamic>?);
        final remote = data?['sessionNotes'] as String?;
        if (remote != null && remote.isNotEmpty && mounted) {
          _controller.text = remote;
          _controller.selection =
              TextSelection.collapsed(offset: remote.length);
          setState(() => _isInitialized = true);
          return;
        }
      } catch (_) {
        // Fallback sur local en cas d'erreur réseau
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_localKey) ?? '';
    final hidden = prefs.getBool('${_localKey}_hidden') ?? false;

    if (mounted) {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      setState(() {
        _isHidden = hidden;
        _isInitialized = true;
      });
    }
  }

  void _onNotesChanged(String text) {
    _saveLocal();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      _saveFirestore(text);
    });
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, _controller.text);
    await prefs.setBool('${_localKey}_hidden', _isHidden);
  }

  Future<void> _saveFirestore(String text) async {
    if (_eventRef == null) return;
    try {
      await _eventRef!.update({
        'sessionNotes': text,
        'sessionNotesUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silencieux : la sauvegarde locale garantit que rien n'est perdu
    }
  }

  void _toggleVisibility() {
    setState(() => _isHidden = !_isHidden);
    _saveLocal();
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
              onChanged: _onNotesChanged,
            ),
        ],
      ),
    );
  }
}
