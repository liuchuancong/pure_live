import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/player/utils/fullscreen.dart';

void main() {
  test('Windows PiP snapshot retains widescreen presentation', () {
    final state = GlobalPlayerState();
    state.isWindowFullscreen.value = true;

    final snapshot = WindowPresentationSnapshot.capture(state);

    expect(snapshot.fullscreen, isFalse);
    expect(snapshot.widescreen, isTrue);
  });

  test('fullscreen presentation takes precedence over widescreen state', () {
    final state = GlobalPlayerState();
    state.isFullscreen.value = true;
    state.isWindowFullscreen.value = true;

    final snapshot = WindowPresentationSnapshot.capture(state);

    expect(snapshot.fullscreen, isTrue);
    expect(snapshot.widescreen, isTrue);
  });
}
