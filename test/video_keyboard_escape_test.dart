import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/keyboard/video_keyboard.dart';

void main() {
  test('Escape pops a normal live room route', () {
    expect(
      resolveEscapePresentationAction(pip: false, fullscreen: false, widescreen: false),
      EscapePresentationAction.popRoute,
    );
  });

  test('Escape exits the active fullscreen presentation', () {
    expect(
      resolveEscapePresentationAction(pip: false, fullscreen: true, widescreen: false),
      EscapePresentationAction.exitFullscreen,
    );
  });

  test('Escape exits widescreen instead of entering fullscreen', () {
    expect(
      resolveEscapePresentationAction(pip: false, fullscreen: false, widescreen: true),
      EscapePresentationAction.exitWidescreen,
    );
  });

  test('PiP owns Escape even if stale presentation flags remain set', () {
    expect(
      resolveEscapePresentationAction(pip: true, fullscreen: true, widescreen: true),
      EscapePresentationAction.none,
    );
  });
}
