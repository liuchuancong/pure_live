import 'dart:async';

import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

void main() {
  group('SingleWindowGate', () {
    test('triggers that arrive together share one creation', () async {
      var created = 0;
      final gate = SingleWindowGate(
        create: ({required forceShow}) async {
          created++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
        present: () => created > 0,
      );

      await Future.wait([gate.ensure(), gate.ensure(forceShow: true), gate.ensure()]);

      expect(created, 1);
    });

    test('a show request that lands mid-creation is not lost', () async {
      var sawForceShow = false;
      final gate = SingleWindowGate(
        create: ({required forceShow}) async {
          sawForceShow = forceShow;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
        present: () => false,
      );

      final first = gate.ensure();
      await gate.ensure(forceShow: true);
      await first;

      expect(sawForceShow, isTrue);
    });

    test('an existing window is not created over', () async {
      var created = 0;
      final gate = SingleWindowGate(create: ({required forceShow}) async => created++, present: () => true);

      await gate.ensure(forceShow: true);

      expect(created, 0);
      expect(gate.isCreating, isFalse);
    });

    test('a failed creation leaves the gate reusable', () async {
      var attempts = 0;
      final gate = SingleWindowGate(
        create: ({required forceShow}) async {
          attempts++;
          if (attempts == 1) {
            throw StateError('the display refused');
          }
        },
        present: () => attempts > 1,
      );

      await expectLater(gate.ensure(), throwsStateError);
      expect(gate.isCreating, isFalse, reason: 'a rejected promise must not be joined forever');
      await gate.ensure();

      expect(attempts, 2);
    });
  });
}
