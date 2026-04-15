import 'package:flutter/scheduler.dart';

/// Repousse une action de navigation après au moins deux frames pour limiter les
/// assertions Navigator (`didStopUserGesture`, `_userGesturesInProgress`) quand un
/// [push] / [pushReplacement] / [pushAndRemoveUntil] suit un [await], une autre
/// transition de route, ou la fermeture d’un overlay.
void scheduleDeferredNavigation(void Function() action) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      action();
    });
  });
}
