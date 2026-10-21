import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/room/danmaku_fps.dart';

void main() {
  group('resolvedDanmakuFps', () {
    test('manual keeps the configured number, clamped into the floor..240', () {
      expect(resolvedDanmakuFps(automatic: false, configured: 120, mode: 'balanced'), 120);
      expect(resolvedDanmakuFps(automatic: false, configured: 10, mode: 'balanced'), 30);
      expect(resolvedDanmakuFps(automatic: false, configured: 999, mode: 'performance'), 240);
    });

    test('automatic reads the display maximum first', () {
      expect(
        resolvedDanmakuFps(automatic: true, configured: 60, mode: 'performance', maxHz: 144, currentHz: 60),
        144,
      );
    });

    test('balanced and power saving cap the automatic clock at 60', () {
      expect(resolvedDanmakuFps(automatic: true, configured: 60, mode: 'balanced', maxHz: 144), 60);
      expect(resolvedDanmakuFps(automatic: true, configured: 60, mode: 'powerSaving', maxHz: 144), 60);
    });

    test('performance rides the display uncapped', () {
      expect(resolvedDanmakuFps(automatic: true, configured: 60, mode: 'performance', maxHz: 240), 240);
    });

    test('with no display answer it falls back to 60', () {
      expect(resolvedDanmakuFps(automatic: true, configured: 144, mode: 'performance'), 60);
    });

    test('currentHz is used when no maximum is reported', () {
      expect(resolvedDanmakuFps(automatic: true, configured: 30, mode: 'performance', currentHz: 90), 90);
    });

    test('the pip floor is 15 and the pip saving stops at 30', () {
      expect(resolvedDanmakuFps(automatic: false, configured: 5, mode: 'powerSaving', pip: true), 15);
      expect(resolvedDanmakuFps(automatic: true, configured: 60, mode: 'powerSaving', maxHz: 120, pip: true), 30);
    });
  });
}
