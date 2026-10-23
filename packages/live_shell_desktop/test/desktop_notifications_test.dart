import 'package:flutter_test/flutter_test.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

void main() {
  group('DesktopNotificationCenter', () {
    test('the host-supplied tag reaches the native show call', () {
      final shown = <(String, String, String)>[];
      final center = DesktopNotificationCenter(
        bridge: (
          isSupported: () => true,
          initialize: () => true,
          show: (title, body, tag) {
            shown.add((title, body, tag));
            return true;
          },
        ),
      );

      expect(center.show(title: 'Recording finished', body: 'saved.m4a', tag: 'unit_host'), isTrue);
      expect(shown, [('Recording finished', 'saved.m4a', 'unit_host')]);
    });

    test('a refused initialization is remembered, not re-asked per notice', () {
      var initCalls = 0;
      final center = DesktopNotificationCenter(
        bridge: (
          isSupported: () => true,
          initialize: () {
            initCalls++;
            return false;
          },
          show: (_, _, _) => true,
        ),
      );

      expect(center.show(title: 'notice', tag: 'unit_host'), isFalse);
      expect(center.show(title: 'notice', tag: 'unit_host'), isFalse);
      expect(initCalls, 1, reason: 'the refusal is a fact, the OS is not pestered again');
    });

    test('a platform with no notification surface drops silently', () {
      final center = DesktopNotificationCenter(
        bridge: (isSupported: () => false, initialize: () => true, show: (_, _, _) => true),
      );

      expect(center.supported, isFalse);
      expect(center.show(title: 'notice', tag: 'unit_host'), isFalse);
    });
  });
}
