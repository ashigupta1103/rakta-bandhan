import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/services/live_merge.dart';

/// Regression guard for "Bad state: Stream has already been listened to":
/// leaving the Near you tab and coming back listens to the same stream again.
void main() {
  late Map<String, StreamController<List<int>>> sources;
  late int opened;

  Stream<List<int>> merged() => mergeCellStreams<int>(
        cells: const ['a', 'b'],
        idOf: (n) => '$n',
        open: (cell) {
          opened++;
          return sources.putIfAbsent(cell, () => StreamController<List<int>>.broadcast()).stream;
        },
      );

  setUp(() {
    sources = {};
    opened = 0;
  });

  test('listening again after cancelling works and reopens the sources', () async {
    final stream = merged();

    final first = <List<int>>[];
    var sub = stream.listen(first.add);
    sources['a']!.add([1, 2]);
    await Future<void>.delayed(Duration.zero);
    expect(first.last, [1, 2]);
    await sub.cancel();

    // Same Stream object, listened to a second time (a tab switch).
    final second = <List<int>>[];
    sub = stream.listen(second.add);
    expect(opened, 4, reason: 'both cells are opened again');
    sources['b']!.add([2, 3]);
    await Future<void>.delayed(Duration.zero);
    expect(second.last, [2, 3], reason: 'nothing stale from the first listen');
    await sub.cancel();
  });

  test('cells are merged and deduplicated by id', () async {
    final out = <List<int>>[];
    final sub = merged().listen(out.add);
    sources['a']!.add([1, 2]);
    sources['b']!.add([2, 3]);
    await Future<void>.delayed(Duration.zero);
    expect(out.last, [1, 2, 3]);
    await sub.cancel();
  });

  test('two listeners at once share one set of sources', () async {
    final stream = merged();
    final a = stream.listen((_) {});
    final b = stream.listen((_) {});
    expect(opened, 2);
    await a.cancel();
    await b.cancel();
  });

  test('a failing cell reaches the listener', () async {
    final errors = <Object>[];
    final sub = merged().listen((_) {}, onError: errors.add);
    sources['a']!.addError(StateError('permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    await sub.cancel();
  });
}
