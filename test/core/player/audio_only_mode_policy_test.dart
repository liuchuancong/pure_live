import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/player/core/audio_only_mode_policy.dart';

void main() {
  group('纯音频模式的解码策略', () {
    test('手动切进纯音频不关视频解码，画面只是被盖住', () {
      // 这是"切回即时"的前提：视频组件留在树上继续解码与渲染，切回来不必重建
      // 纹理、不必重新等首帧，帧心跳也不会断（断了帧停滞看门狗会误判重开）。
      expect(audioOnlyStopsVideoDecoding(entering: true, stopVideoDecoding: false), isFalse);
    });

    test('助眠自动进入时就关掉视频解码省电', () {
      expect(audioOnlyStopsVideoDecoding(entering: true, stopVideoDecoding: true), isTrue);
    });

    test('退出纯音频总是恢复视频轨，不管进来时走的哪条路', () {
      // 标记不记录"当初是谁设的"：助眠可能已经把视频轨关了，退出时只置标记会把
      // 房间留在有声无画的状态。
      expect(audioOnlyStopsVideoDecoding(entering: false, stopVideoDecoding: false), isTrue);
      expect(audioOnlyStopsVideoDecoding(entering: false, stopVideoDecoding: true), isTrue);
    });
  });
}
