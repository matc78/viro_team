import 'dart:async';

/// Combine plusieurs streams de listes en un seul stream fusionné.
Stream<List<T>> combineLatestListStreams<T>(List<Stream<List<T>>> streams) {
  if (streams.isEmpty) return Stream.value([]);

  final controller = StreamController<List<T>>.broadcast();
  final latest = List<List<T>?>.filled(streams.length, null);
  final subscriptions = <StreamSubscription<List<T>>>[];

  void emitIfReady() {
    if (latest.every((e) => e != null)) {
      controller.add(latest.expand((e) => e!).toList());
    }
  }

  for (var i = 0; i < streams.length; i++) {
    final index = i;
    subscriptions.add(
      streams[i].listen(
        (data) {
          latest[index] = data;
          emitIfReady();
        },
        onError: controller.addError,
      ),
    );
  }

  controller.onCancel = () async {
    for (final sub in subscriptions) {
      await sub.cancel();
    }
  };

  return controller.stream;
}
