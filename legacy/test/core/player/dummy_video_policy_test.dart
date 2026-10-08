import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/player/core/dummy_video_policy.dart';

void main() {
  group('占位视频轨的判定', () {
    test('猫耳那种 16×16 是占位，不是画面', () {
      expect(isDummyVideoSize(width: 16, height: 16), isTrue);
      // 阈值留了一倍余量：32 仍算占位，33 就不是了。
      expect(isDummyVideoSize(width: 32, height: 32), isTrue);
      expect(isDummyVideoSize(width: 33, height: 33), isFalse);
    });

    test('看短边，所以竖屏与横屏的真实档位都不会被误判', () {
      expect(isDummyVideoSize(width: 1080, height: 2280), isFalse, reason: '竖屏直播');
      expect(isDummyVideoSize(width: 1920, height: 1080), isFalse);
      expect(isDummyVideoSize(width: 256, height: 144), isFalse, reason: '最低的 144p');
      expect(isDummyVideoSize(width: 20, height: 1080), isTrue, reason: '短边只有 20，仍是占位形状');
    });

    test('尺寸未知不算占位：那会儿该显示加载态，不是封面', () {
      expect(isDummyVideoSize(width: 0, height: 0), isFalse);
      expect(isDummyVideoSize(width: -1, height: 16), isFalse);
      expect(isDummyVideoSize(width: 16, height: 0), isFalse);
    });
  });
}
