import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

void main() {
  group('resolveCloseDisposition', () {
    test('macOS never quits from the close button, whatever the setting says', () {
      for (final action in CloseAction.values) {
        expect(
          resolveCloseDisposition(platform: PlatformKind.macos, action: action, role: WindowRole.main, hasTray: true),
          action == CloseAction.quit ? CloseDisposition.quit : CloseDisposition.destroy,
          reason: '${action.name} on macOS',
        );
      }
    });

    test('a quit already running lets the default close through', () {
      expect(
        resolveCloseDisposition(
          platform: PlatformKind.windows,
          action: CloseAction.hideToTray,
          role: WindowRole.main,
          hasTray: true,
          isQuitting: true,
        ),
        CloseDisposition.quit,
      );
    });

    test('hiding to the tray needs a tray, and quits without one', () {
      expect(
        resolveCloseDisposition(
          platform: PlatformKind.windows,
          action: CloseAction.hideToTray,
          role: WindowRole.main,
          hasTray: true,
        ),
        CloseDisposition.hide,
      );
      expect(
        resolveCloseDisposition(
          platform: PlatformKind.linux,
          action: CloseAction.hideToTray,
          role: WindowRole.main,
          hasTray: false,
        ),
        CloseDisposition.quit,
        reason: 'a window hidden with no icon to bring it back is an unreachable process',
      );
    });

    test('a secondary window only ever goes away itself', () {
      for (final role in WindowRole.values.where((entry) => !entry.ownsAppState)) {
        expect(
          resolveCloseDisposition(
            platform: PlatformKind.windows,
            action: CloseAction.hideToTray,
            role: role,
            hasTray: true,
          ),
          CloseDisposition.destroy,
          reason: role.name,
        );
      }
    });
  });

  group('QuitLedger', () {
    test('the intent is taken at destruction, not at the window count', () {
      final ledger = QuitLedger(platform: PlatformKind.windows)
        ..record(trigger: QuitTrigger.windowClose, minimizeToTray: true, hasTray: true);

      expect(ledger.hasPending, isTrue);
      expect(ledger.consumeOnLastWindowClosed(), isFalse);
      expect(ledger.hasPending, isFalse, reason: 'consumed, so an unrelated close cannot reuse it');
      expect(ledger.consumeOnLastWindowClosed(), isTrue, reason: 'with no intent, the platform convention applies');
    });

    test('an unconsumed intent survives a panel closing in between', () async {
      final ledger = QuitLedger(platform: PlatformKind.windows)
        ..record(trigger: QuitTrigger.windowClose, minimizeToTray: true, hasTray: true);
      // The cast panel is still open, so no event fires yet; when the last
      // window does go, the answer is still the one decided earlier.
      expect(ledger.peek, isFalse);
      expect(ledger.consumeOnLastWindowClosed(), isFalse);
    });

    test('lightweight mode keeps the process even when the setting says quit', () {
      final ledger = QuitLedger(platform: PlatformKind.windows)
        ..record(trigger: QuitTrigger.lightweightMode, minimizeToTray: false, hasTray: true);

      expect(ledger.consumeOnLastWindowClosed(), isFalse, reason: 'a recording must not stop with the interface');
    });

    test('lightweight mode still quits when the tray failed to appear', () {
      final ledger = QuitLedger(platform: PlatformKind.windows)
        ..record(trigger: QuitTrigger.memoryWatchdog, minimizeToTray: true, hasTray: false);

      expect(ledger.consumeOnLastWindowClosed(), isTrue);
    });

    test('macOS keeps running on its own', () {
      final ledger = QuitLedger(platform: PlatformKind.macos)
        ..record(trigger: QuitTrigger.windowClose, minimizeToTray: false, hasTray: false);

      expect(ledger.consumeOnLastWindowClosed(), isFalse);
    });
  });
}
