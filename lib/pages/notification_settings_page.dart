import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/services/notification_preferences_service.dart';
import 'package:viro_team/theme/viro_theme.dart';
import 'package:viro_team/utils/firebase_error_handler.dart';
import 'package:viro_team/widget/viro_loader.dart';

/// Page permettant d'activer ou désactiver les notifications par type.
/// Les préférences sont stockées dans Firestore (users/{uid}.notificationPreferences).
/// [types] : liste des types à afficher (player ou admin). Si null, affiche tous les types.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.types});

  /// Types de notifications à afficher (ex. kNotificationTypesPlayer ou kNotificationTypesAdmin).
  /// Si null, affiche tous les types.
  final List<String>? types;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationPreferencesService _prefsService =
      NotificationPreferencesService.instance;

  Map<String, bool>? _preferences;
  String? _loadError;
  bool _enablingAll = false;

  List<String> get _visibleTypes => widget.types ?? kNotificationTypes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() {
        _loadError = 'Utilisateur non connecté';
        _preferences = null;
      });
      return;
    }
    setState(() {
      _loadError = null;
      _preferences = null;
    });
    try {
      final prefs = await _prefsService.getPreferences(uid);
      if (mounted) {
        setState(() {
          _preferences = prefs;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _preferences = null;
        });
      }
    }
  }

  Future<void> _enableAll() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    setState(() => _enablingAll = true);
    try {
      final updates = <String, bool>{};
      for (final type in _visibleTypes) {
        updates[type] = true;
      }
      await _prefsService.setPreferences(uid, updates);
      if (mounted) {
        setState(() {
          _enablingAll = false;
          _preferences ??= {};
          for (final type in _visibleTypes) {
            _preferences![type] = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toutes les notifications activées')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enablingAll = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorHandler.getErrorMessage(e)),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    }
  }

  Future<void> _setPreference(String type, bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    // Mise à jour optimiste immédiate : pas de spinner, transition fluide
    setState(() {
      _preferences ??= {};
      _preferences![type] = enabled;
    });

    // Sauvegarde en arrière-plan
    try {
      await _prefsService.setPreference(uid, type, enabled);
    } catch (e) {
      // En cas d'erreur, on annule le changement optimiste
      if (mounted) {
        setState(() {
          _preferences![type] = !enabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorHandler.getErrorMessage(e)),
            backgroundColor: ViroColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Paramètres des notifications')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    if (_preferences == null) {
      return const Center(child: ViroLoader(size: 80));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Choisissez les notifications que vous souhaitez recevoir.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _enablingAll ? null : _enableAll,
                icon: _enablingAll
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(
                  _enablingAll
                      ? 'Enregistrement…'
                      : 'Activer toutes les notifications',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ViroColors.primary,
                  side: const BorderSide(color: ViroColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          ..._visibleTypes.map((type) {
            final label = kNotificationTypeLabels[type] ?? type;
            final value = _preferences![type] ?? true;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: ViroColors.borderColor),
              ),
              child: SwitchListTile(
                value: value,
                onChanged: (bool newValue) => _setPreference(type, newValue),
                title: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                secondary: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    value
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    key: ValueKey(value),
                    color: value ? ViroColors.primary : Colors.grey,
                  ),
                ),
                activeThumbColor: ViroColors.primary,
              ),
            );
          }),
        ],
      ),
    );
  }
}
