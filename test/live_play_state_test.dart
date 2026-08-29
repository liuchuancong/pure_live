import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/states/danmaku_state.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';

void main() {
  group('live play immutable state', () {
    test('can clear the current danmaku room id', () {
      const state = DanmakuState(currentDanmakuRoomId: 'old-room');

      expect(state.copyWith(currentDanmakuRoomId: null).currentDanmakuRoomId, isNull);
    });

    test('can clear a previous room load error', () {
      const state = RoomState(loadError: 'network error');

      expect(state.copyWith(loadError: null).loadError, isNull);
      expect(state.clearError().loadError, isNull);
    });

    test('portrait fullscreen is a distinct presentation state', () {
      const state = UIState();

      final fullscreen = state.copyWith(screenMode: VideoMode.portraitFullscreen);
      expect(fullscreen.screenMode, VideoMode.portraitFullscreen);
      expect(state.screenMode, VideoMode.normal);
      expect(requiresSystemFullscreenExit(VideoMode.portraitFullscreen), isTrue);
      expect(requiresSystemFullscreenExit(VideoMode.fullscreen), isTrue);
      expect(requiresSystemFullscreenExit(VideoMode.widescreen), isFalse);
      expect(requiresSystemFullscreenExit(VideoMode.normal), isFalse);
    });
  });
}
