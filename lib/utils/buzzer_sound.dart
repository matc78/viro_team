import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Joue le son de buzzer (assets/sons/son_buzzer.mp3).
/// Utilisé pour le countdown 3-2-1 et les alertes avant repos/reprise Zapata.
class BuzzerSound {
  static final AudioPlayer _player = AudioPlayer();

  static const _assetPath = 'sons/son_buzzer.mp3';

  /// Joue le son de buzzer une fois.
  static Future<void> play() async {
    HapticFeedback.lightImpact();
    try {
      await _player.stop();
      await _player.play(AssetSource(_assetPath));
    } catch (_) {
      HapticFeedback.mediumImpact();
    }
  }
}
