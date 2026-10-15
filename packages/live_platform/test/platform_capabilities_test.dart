import 'package:live_platform/live_platform.dart';
import 'package:test/test.dart';

/// `PlatformCapabilities.defaults` is the conservative answer to "what can
/// this device do": unknown platforms claim nothing, TV form factors give up
/// windowing and tray, and picture-in-picture is a phone-only claim today.
void main() {
  test('an unknown platform claims nothing', () {
    final capabilities = PlatformCapabilities.defaults(kind: PlatformKind.unknown, formFactor: FormFactor.desktop);

    expect(capabilities.mediaSession, isFalse);
    expect(capabilities.pictureInPicture, isFalse);
    expect(capabilities.windowing, isFalse);
    expect(capabilities.systemTray, isFalse);
    expect(capabilities.filePicker, isFalse);
  });

  test('a desktop platform claims windowing and tray but not PiP', () {
    for (final kind in [PlatformKind.windows, PlatformKind.macos, PlatformKind.linux]) {
      final capabilities = PlatformCapabilities.defaults(kind: kind, formFactor: FormFactor.desktop);

      expect(capabilities.mediaSession, isTrue, reason: '$kind');
      expect(capabilities.windowing, isTrue, reason: '$kind');
      expect(capabilities.systemTray, isTrue, reason: '$kind');
      expect(capabilities.pictureInPicture, isFalse, reason: '$kind');
      expect(capabilities.filePicker, isTrue, reason: '$kind');
    }
  });

  test('an android phone claims PiP but no windowing or tray', () {
    final capabilities = PlatformCapabilities.defaults(kind: PlatformKind.android, formFactor: FormFactor.phone);

    expect(capabilities.pictureInPicture, isTrue);
    expect(capabilities.mediaSession, isTrue);
    expect(capabilities.filePicker, isTrue);
    expect(capabilities.windowing, isFalse);
    expect(capabilities.systemTray, isFalse);
  });

  test('a TV build gives up PiP and tray even on a desktop OS', () {
    final capabilities = PlatformCapabilities.defaults(kind: PlatformKind.windows, formFactor: FormFactor.tv);

    expect(capabilities.pictureInPicture, isFalse);
    expect(capabilities.systemTray, isFalse);
  });

  test('iOS claims media session and file picking only', () {
    final capabilities = PlatformCapabilities.defaults(kind: PlatformKind.ios, formFactor: FormFactor.phone);

    expect(capabilities.mediaSession, isTrue);
    expect(capabilities.filePicker, isTrue);
    expect(capabilities.pictureInPicture, isFalse);
    expect(capabilities.windowing, isFalse);
    expect(capabilities.systemTray, isFalse);
  });

  test('copyWith overrides single answers without touching the rest', () {
    final capabilities = PlatformCapabilities.defaults(
      kind: PlatformKind.android,
      formFactor: FormFactor.phone,
    ).copyWith(systemTray: true);

    expect(capabilities.systemTray, isTrue);
    expect(capabilities.pictureInPicture, isTrue, reason: 'the untouched answers stay');
  });
}
