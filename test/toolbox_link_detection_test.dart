import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/toolbox/toolbox_controller.dart';

void main() {
  for (final url in [
    'https://live.bilibili.com/123',
    'https://b23.tv/AbCd',
    'https://www.douyu.com/123',
    'https://www.huya.com/fixture',
    'https://live.douyin.com/123',
    'https://www.douyin.com/123?source=share',
    'https://v.douyin.com/AbCd/',
    'https://webcast.amemv.com/douyin/webcast/reflow/123',
    'https://live.kuaishou.com/u/fixture',
    'https://live.kuaishou.cn/u/fixture',
    'https://cc.163.com/123',
    'https://www.twitch.tv/fixture',
    'https://play.sooplive.co.kr/fixture',
    'https://www.sooplive.com/fixture',
    'https://www.yy.com/123',
    'https://live.acfun.cn/live/123',
    'HTTP://LIVE.BILIBILI.COM/123',
    'www.huya.com/fixture',
  ]) {
    test('detects supported link $url in share text', () {
      expect(ToolBoxController.containsSupportedLink('Share: $url live now'), isTrue);
    });
  }
  for (final text in [
    '',
    'bilibili notes 163',
    'https://example.org',
    'https://huya.com.example.org/123',
    'https://notbilibili.com/123',
    'https://example.org/?next=https://www.huya.com/123',
    'https://huya.com@example.org/123',
    'https://user@www.huya.com/123',
    'file:///huya.com/123',
    'ftp://live.bilibili.com/123',
    'ftp://www.huya.com/123',
    'javascript://www.huya.com/123',
    'https://',
    'https://%/',
    'https://live.bilibili.com/',
    'https://www.douyu.com/search?kw=game',
    'https://www.twitch.tv/directory',
    'https://picarto.tv/search?q=art',
    'https://twitcasting.tv/artist/movie/42',
    'https://live.kuaishou.com/search',
    'https://www.douyin.com/search/123?type=live',
    'https://www.douyin.com/video/123',
  ]) {
    test('does not auto-fill unrelated or ambiguous text: $text', () {
      expect(ToolBoxController.containsSupportedLink(text), isFalse);
    });
  }
}
