import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/get/get_state_manager/src/simple/list_notifier.dart';

void main() {
  group('ListNotifier lifecycle', () {
    test('late widget unsubscribe is harmless after controller disposal', () {
      final notifier = ListNotifierSingle();
      void listener() {}
      final unsubscribe = notifier.addListener(listener);

      notifier.dispose();

      expect(unsubscribe, returnsNormally);
      expect(() => notifier.removeListener(listener), returnsNormally);
    });

    test('group listener cleanup is idempotent after group disposal', () {
      final notifier = ListNotifierGroup();
      void listener() {}
      notifier.addListenerId('room', listener);

      notifier.dispose();

      expect(() => notifier.removeListenerId('room', listener), returnsNormally);
      expect(() => notifier.disposeId('room'), returnsNormally);
    });
  });
}
