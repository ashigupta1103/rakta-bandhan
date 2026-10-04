import 'dart:async';

/// Merges one live stream per geohash cell into a single deduped list.
///
/// The result is a **broadcast** stream that opens its per-cell sources again
/// every time it gains its first listener. That matters: a screen that leaves
/// and comes back (the Near you / Yours tabs) listens again, and a
/// single-subscription stream throws "Bad state: Stream has already been
/// listened to" the second time, which blanked the Requests tab.
Stream<List<T>> mergeCellStreams<T>({
  required Iterable<String> cells,
  required Stream<List<T>> Function(String cell) open,
  required String Function(T item) idOf,
}) {
  late final StreamController<List<T>> controller;
  final latest = <String, List<T>>{};
  var subs = <StreamSubscription<List<T>>>[];

  void emit() {
    final seen = <String>{};
    final merged = <T>[];
    for (final items in latest.values) {
      for (final item in items) {
        if (seen.add(idOf(item))) merged.add(item);
      }
    }
    controller.add(merged);
  }

  controller = StreamController<List<T>>.broadcast(
    onListen: () {
      for (final cell in cells) {
        subs.add(open(cell).listen((items) {
          latest[cell] = items;
          emit();
        }, onError: controller.addError));
      }
    },
    onCancel: () async {
      // Swap the list out before cancelling, so a listener that returns at
      // once starts from a clean slate instead of inheriting stale cells.
      final old = subs;
      subs = [];
      latest.clear();
      await Future.wait(old.map((s) => s.cancel()));
    },
  );
  return controller.stream;
}
