import 'dart:async';

import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

void main() {
  group('DragThrottle', () {
    const settle = Duration(milliseconds: 30);

    test('a drag begins on the first move and ends once moves stop', () async {
      var began = 0;
      var ended = 0;
      final throttle = DragThrottle(settle: settle, onBegin: () => began++, onEnd: () => ended++);

      expect(throttle.allowsUiWork, isTrue);
      throttle.noteMoved();
      expect(throttle.isDragging, isTrue);
      expect(throttle.allowsUiWork, isFalse);
      throttle.noteMoved();
      expect(began, 1, reason: 'one drag, however many move events');

      await Future<void>.delayed(settle * 3);

      expect(throttle.isDragging, isFalse);
      expect(ended, 1);
      throttle.dispose();
    });

    test('reset ends the drag at once, so a destroyed window cannot strand it', () async {
      var ended = 0;
      final throttle = DragThrottle(settle: settle, onEnd: () => ended++)
        ..noteMoved()
        ..reset();

      expect(throttle.isDragging, isFalse);
      expect(ended, 1);
      await Future<void>.delayed(settle * 3);
      expect(ended, 1, reason: 'the pending timer must not fire a second end');
      throttle.dispose();
    });

    test('a disposed throttle ignores late moves', () async {
      var began = 0;
      final throttle = DragThrottle(settle: settle, onBegin: () => began++)
        ..dispose()
        ..noteMoved();

      expect(throttle.isDragging, isFalse);
      expect(began, 0);
    });
  });

  group('LatestValueGate', () {
    test('outside a drag a value is delivered straight away', () {
      final throttle = DragThrottle(settle: const Duration(milliseconds: 30));
      final gate = LatestValueGate<int>(throttle);
      final delivered = <int>[];

      expect(gate.offer(1, delivered.add), isTrue);
      expect(delivered, [1]);
      expect(gate.hasPending, isFalse);
      throttle.dispose();
    });

    test('during a drag only the newest value is kept, and it is emitted once', () {
      final throttle = DragThrottle(settle: const Duration(milliseconds: 30))..noteMoved();
      final gate = LatestValueGate<int>(throttle);
      final delivered = <int>[];

      expect(gate.offer(1, delivered.add), isFalse);
      expect(gate.offer(2, delivered.add), isFalse);
      expect(gate.offer(3, delivered.add), isFalse);
      expect(delivered, isEmpty, reason: 'nothing was drawn while the window was being dragged');
      expect(gate.hasPending, isTrue);

      gate.flush(delivered.add);

      expect(delivered, [3], reason: 'the numbers catch up instead of freezing');
      expect(gate.hasPending, isFalse);
      gate.flush(delivered.add);
      expect(delivered, [3], reason: 'flushing twice delivers nothing twice');
      throttle.dispose();
    });
  });
}
