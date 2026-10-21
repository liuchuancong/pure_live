// The play queue, pinned: sequence wraps and stops, repeat-one repeats, the
// shuffled order plays every item once before reshuffling, play-next moves
// the chosen item after the current one, and the failure budget stops a
// skipping player.
// A queue test drives a sequence of calls on one receiver; the cascade
// preference would make the steps harder to read.
// ignore_for_file: cascade_invocations

import 'package:live_vod/live_vod.dart';
import 'package:test/test.dart';

String _id(String item) => item;

List<String> _walk(PlayQueue<String> queue, int steps) => [
  for (var i = 0; i < steps; i++)
    if (queue.next() case final item?) item else '#end#',
];

void main() {
  test('sequence walks the list and wraps', () {
    final queue = PlayQueue.of(['a', 'b', 'c'], idOf: _id);
    expect(queue.current, 'a');
    expect(_walk(queue, 3), ['b', 'c', 'a']);
  });

  test('a queue that does not wrap ends instead of repeating', () {
    final queue = PlayQueue.of(['a', 'b'], idOf: _id, wrap: false);
    expect(queue.next(), 'b');
    expect(queue.next(), isNull);
  });

  test('repeat-one repeats the current item', () {
    final queue = PlayQueue.of(['a', 'b'], idOf: _id, mode: PlayMode.repeatOne);
    expect(queue.next(), 'a');
    expect(queue.next(), 'a');
  });

  test('shuffle plays every item once before reshuffling', () {
    final queue = PlayQueue.of(['a', 'b', 'c', 'd'], idOf: _id, mode: PlayMode.shuffle);
    final heard = [queue.current!, ..._walk(queue, 3)];
    expect(heard.toSet(), {'a', 'b', 'c', 'd'});
  });

  test('play-next puts the item after the current one and moves an existing one', () {
    final queue = PlayQueue.of(['a', 'b', 'c'], idOf: _id);
    expect(queue.playNext('z'), PlayNextResult.inserted);
    expect(queue.items, ['a', 'z', 'b', 'c']);
    expect(queue.playNext('c'), PlayNextResult.moved);
    expect(queue.items, ['a', 'c', 'z', 'b']);
    expect(queue.playNext('c'), PlayNextResult.alreadyNext);
  });

  test('previous walks back; at the start there is none', () {
    final queue = PlayQueue.of(['a', 'b', 'c'], idOf: _id);
    queue
      ..next()
      ..next();
    expect(queue.previous(), 'b');
    expect(queue.previous(), 'a');
    expect(queue.previous(), isNull);
  });

  test('a success clears failures; spent reports the budget', () {
    final queue = PlayQueue.of(['a', 'b', 'c', 'd', 'e', 'f'], idOf: _id);
    for (var i = 0; i < 5; i++) {
      queue.settled(failed: true);
    }
    expect(queue.spent, isTrue);
    queue.settled(failed: false);
    expect(queue.spent, isFalse);
    expect(queue.failures, 0);
  });

  test('removing the current item keeps a current item', () {
    final queue = PlayQueue.of(['a', 'b', 'c'], idOf: _id);
    expect(queue.remove('a'), isTrue);
    expect(queue.current, 'b');
    expect(queue.items, ['b', 'c']);
    expect(queue.remove('missing'), isFalse);
  });

  test('replace de-duplicates by id', () {
    final queue = PlayQueue.of(['a', 'a', 'b'], idOf: _id);
    expect(queue.items, ['a', 'b']);
  });
}
