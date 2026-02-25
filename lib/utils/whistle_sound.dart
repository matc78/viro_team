import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Joue le son de sifflet (assets/sons/son_sifflet.mp3).
/// Utilisé pour le bouton sifflet, les alertes countdown et les changements Zapata.
class WhistleSound {
  static final AudioPlayer _player = AudioPlayer();

  static const _assetPath = 'sons/son_sifflet.mp3';

  /// Joue le son de sifflet une fois.
  /// Inclut une vibration haptique.
  static Future<void> play() async {
    HapticFeedback.mediumImpact();
    try {
      await _player.stop();
      await _player.play(AssetSource(_assetPath));
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }
}
