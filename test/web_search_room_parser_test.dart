import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';

void main() {
  test('extracts native room identities for every web-search platform', () {
    final cases = <String, (String, String)>{
      'https://www.huya.com/abc_123': (Sites.huyaSite, 'abc_123'),
      'https://live.douyin.com/123456': (Sites.douyinSite, '123456'),
      'https://www.douyu.com/9999?from=search': (Sites.douyuSite, '9999'),
      'https://live.kuaishou.com/u/profile_name': (Sites.kuaishouSite, 'profile_name'),
      'https://cc.163.com/12345/': (Sites.ccSite, '12345'),
      'https://live.bilibili.com/67890': (Sites.bilibiliSite, '67890'),
      'https://www.twitch.tv/some_streamer': (Sites.twitchSite, 'some_streamer'),
      'https://play.sooplive.co.kr/streamer_1/123': (Sites.soopSite, 'streamer_1'),
      'https://www.yy.com/1382731151': (Sites.yySite, '1382731151'),
      'https://live.acfun.cn/live/42?from=search': (Sites.acfunSite, '42'),
      'https://live.shopee.co.id/share?from=live&session=225239358': (Sites.shopeeLiveSite, 'id:225239358'),
    };

    for (final entry in cases.entries) {
      final target = WebSearchRoomParser.parse(entry.key);
      expect(target?.platform, entry.value.$1, reason: entry.key);
      expect(target?.roomId, entry.value.$2, reason: entry.key);
    }
  });

  test('ignores search/navigation pages and lookalike domains', () {
    const urls = [
      'https://www.huya.com/search?hsk=test',
      'https://www.twitch.tv/directory',
      'https://www.douyu.com/topic/something',
      'https://live.kuaishou.com/search?keyword=test',
      'https://live.bilibili.com/p/eden/area-tags',
      'https://www.yy.com/search-test',
      'https://www.huya.com.evil.example/1234',
      'javascript:alert(1)',
      'https://www.acfun.cn/u/42',
      'https://www.acfun.cn/v/ac42',
      'https://live.acfun.cn/live/0',
      'https://live.acfun.cn/live/42/extra',
      'https://live.acfun.cn.evil.example/live/42',
      'https://secret@live.acfun.cn/live/42',
    ];

    for (final url in urls) {
      expect(WebSearchRoomParser.parse(url), isNull, reason: url);
    }
  });

  test('AcFun shared room links resolve offline without treating author pages as streams', () async {
    expect(await LiveUrlTool.parseLiveUrl('看看这个直播 https://live.acfun.cn/live/42?source=share'), ['42', 'acfun']);
    expect(await LiveUrlTool.parseLiveUrl('https://live.acfun.cn/search?keyword=huya.com'), isEmpty);
  });

  test('Shopee Live official share links resolve to durable regional session IDs', () async {
    expect(await LiveUrlTool.parseLiveUrl('Shopee Live https://live.shopee.co.id/share?from=live&session=225239358'), [
      'id:225239358',
      Sites.shopeeLiveSite,
    ]);
  });
}
