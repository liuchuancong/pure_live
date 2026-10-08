import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/local_video_player_page.dart';

void main() {
  group('录像播放页的小屏形状', () {
    test('窗口最小值 400 不再把视频挤成一条黑带', () {
      // 列表栏固定 320，加分隔线和内边距要吃掉 345：并排的话画面只剩几十像素。
      expect(localPlayerShowsSideBySide(400), isFalse);
    });

    test('差一像素也不并排', () {
      expect(localPlayerShowsSideBySide(localPlayerSideBySideMinWidth - 1), isFalse);
    });

    test('到阈值才回到左右两栏', () {
      expect(localPlayerShowsSideBySide(localPlayerSideBySideMinWidth), isTrue);
      expect(localPlayerShowsSideBySide(1280), isTrue);
    });
  });
}
