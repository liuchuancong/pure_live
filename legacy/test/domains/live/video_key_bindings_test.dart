import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/keyboard/video_keyboard.dart';

void main() {
  group('房间键位', () {
    test('空格和 K 都是播放/暂停，播放器还没就绪也照样能用', () {
      for (final hasController in <bool>[true, false]) {
        expect(
          resolveVideoKeyAction(LogicalKeyboardKey.space, hasController: hasController),
          VideoKeyAction.togglePlay,
        );
        expect(resolveVideoKeyAction(LogicalKeyboardKey.keyK, hasController: hasController), VideoKeyAction.togglePlay);
      }
    });

    test('刷新 / 全屏 / 音量都挂在控制器上，没有控制器就不消费', () {
      final gated = <(LogicalKeyboardKey, VideoKeyAction)>[
        (LogicalKeyboardKey.keyR, VideoKeyAction.refresh),
        (LogicalKeyboardKey.keyF, VideoKeyAction.toggleFullscreen),
        (LogicalKeyboardKey.keyM, VideoKeyAction.toggleMute),
        (LogicalKeyboardKey.arrowUp, VideoKeyAction.volumeUp),
        (LogicalKeyboardKey.arrowDown, VideoKeyAction.volumeDown),
      ];
      for (final (key, action) in gated) {
        expect(resolveVideoKeyAction(key, hasController: true), action);
        expect(resolveVideoKeyAction(key, hasController: false), VideoKeyAction.none);
      }
    });

    test('F 是全屏切换，方向键是音量而不是快进（直播没有可拖的时间轴）', () {
      expect(resolveVideoKeyAction(LogicalKeyboardKey.keyF, hasController: true), VideoKeyAction.toggleFullscreen);
      expect(resolveVideoKeyAction(LogicalKeyboardKey.arrowLeft, hasController: true), VideoKeyAction.none);
      expect(resolveVideoKeyAction(LogicalKeyboardKey.arrowRight, hasController: true), VideoKeyAction.none);
    });

    test('认不出的键不拦事件', () {
      expect(resolveVideoKeyAction(LogicalKeyboardKey.keyQ, hasController: true), VideoKeyAction.none);
    });
  });

  group('Esc 的归属', () {
    test('画中画不接 Esc：它有自己的关闭路径', () {
      expect(
        resolveEscapePresentationAction(pip: true, fullscreen: true, widescreen: true),
        EscapePresentationAction.none,
      );
    });

    test('全屏优先于宽屏', () {
      expect(
        resolveEscapePresentationAction(pip: false, fullscreen: true, widescreen: true),
        EscapePresentationAction.exitFullscreen,
      );
    });

    test('没有控制器时不能把 Esc 变成死键：留在弹路由', () {
      // 房间可能在创建 VideoController 之前就失败，此时全局呈现标志可能是脏的；
      // 界面上的返回按钮还能用，Esc 也必须能退出页面。
      expect(
        resolveEscapePresentationAction(pip: false, fullscreen: false, widescreen: false),
        EscapePresentationAction.popRoute,
      );
    });
  });
}
