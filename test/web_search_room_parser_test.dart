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
      'https://live.vkvideo.ru/HighMySide': (Sites.vkVideoLiveSite, 'highmyside'),
      'https://www.nimo.tv/live/40972312': (Sites.nimoTvSite, '40972312'),
      'https://www.dailymotion.com/video/x3b68jn': (Sites.dailymotionSite, 'x3b68jn'),
      'https://rumble.com/v7fngda-rt-de-live-tv.html': (Sites.rumbleSite, 'v7fngda-rt-de-live-tv'),
      'https://goodgame.ru/Verloin': (Sites.goodGameSite, 'verloin'),
      'https://goodgame.ru/player?15365': (Sites.goodGameSite, 'id:15365'),
      'https://live.fc2.com/10608314/': (Sites.fc2LiveSite, '10608314'),
      'https://steamcommunity.com/broadcast/watch/76561198373527746': (Sites.steamBroadcastSite, '76561198373527746'),
      'https://lives.jd.com/#/48266468?origin=0': (Sites.jdLiveSite, '48266468'),
      'https://h5.m.taobao.com/taolive/video.html?id=12345678901': (Sites.taobaoLiveSite, 'live:12345678901'),
      'https://www.xiaohongshu.com/livestream/1234567890123456789?source=share':
          (Sites.xiaohongshuSite, '1234567890123456789'),
      'https://www.flextv.co.kr/channels/123456/live': (Sites.ttingSite, '123456'),
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
      'https://www.xiaohongshu.com/explore/1234567890123456789',
      'https://www.xiaohongshu.com/livestream/1234567890123456789/extra',
      'https://www.xiaohongshu.com.evil.example/livestream/1234567890123456789',
      'https://www.flextv.co.kr/channels/123456',
      'https://www.flextv.co.kr/channels/123456/live/extra',
      'https://www.flextv.co.kr.evil.example/channels/123456/live',
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

  test('VK Video Live current and legacy hosts resolve to a stable channel slug', () async {
    expect(await LiveUrlTool.parseLiveUrl('VK https://live.vkvideo.ru/HighMySide'), [
      'highmyside',
      Sites.vkVideoLiveSite,
    ]);
    expect(await LiveUrlTool.parseLiveUrl('https://vkplay.live/HighMySide'), ['highmyside', Sites.vkVideoLiveSite]);
  });

  test('NimoTV numeric rooms and aliases resolve to stable channel keys', () async {
    expect(await LiveUrlTool.parseLiveUrl('NimoTV https://www.nimo.tv/live/40972312'), ['40972312', Sites.nimoTvSite]);
    expect(await LiveUrlTool.parseLiveUrl('https://m.nimo.tv/SBTCPotm'), ['sbtcpotm', Sites.nimoTvSite]);
  });

  test('Dailymotion video, live, embed and short links resolve to a stable video ID', () async {
    for (final url in [
      'https://www.dailymotion.com/video/x3b68jn',
      'https://www.dailymotion.com/live/x3b68jn',
      'https://www.dailymotion.com/embed/video/x3b68jn',
      'https://dai.ly/x3b68jn',
    ]) {
      expect(await LiveUrlTool.parseLiveUrl(url), ['x3b68jn', Sites.dailymotionSite], reason: url);
    }
    expect(await LiveUrlTool.parseLiveUrl('https://www.dailymotion.com/CNEWS'), isEmpty);
  });

  test('Rumble public video links resolve without confusing embed or channel identities', () async {
    const url = 'https://rumble.com/v7fngda-rt-de-live-tv.html?e9s=src_v1_blp';
    expect(await LiveUrlTool.parseLiveUrl(url), ['v7fngda-rt-de-live-tv', Sites.rumbleSite]);
    expect(await LiveUrlTool.parseLiveUrl('https://rumble.com/embed/v7dh3fs/'), isEmpty);
    expect(await LiveUrlTool.parseLiveUrl('https://rumble.com/c/RTDE'), isEmpty);
  });

  test('GoodGame channel and player links resolve to durable channel or stream identities', () async {
    expect(await LiveUrlTool.parseLiveUrl('https://goodgame.ru/Verloin'), ['verloin', Sites.goodGameSite]);
    expect(await LiveUrlTool.parseLiveUrl('https://goodgame.ru/player?15365'), ['id:15365', Sites.goodGameSite]);
    expect(await LiveUrlTool.parseLiveUrl('https://live.fc2.com/10608314/'), ['10608314', Sites.fc2LiveSite]);
    expect(await LiveUrlTool.parseLiveUrl('https://goodgame.ru/streams'), isEmpty);
  });

  test('Steam community watch links resolve to their durable SteamID64', () async {
    expect(
      LiveUrlTool.containsSupportedLink('Steam https://steamcommunity.com/broadcast/watch/76561198373527746'),
      isTrue,
    );
    expect(
      await LiveUrlTool.parseLiveUrl('Steam https://steamcommunity.com/broadcast/watch/76561198373527746?l=english'),
      ['76561198373527746', Sites.steamBroadcastSite],
    );
    expect(await LiveUrlTool.parseLiveUrl('https://steamcommunity.com/app/730/broadcasts'), isEmpty);
  });

  test('JD Live hash routes resolve to their stable live ID', () async {
    expect(LiveUrlTool.containsSupportedLink('京东直播 https://lives.jd.com/#/48266468?origin=0'), isTrue);
    expect(await LiveUrlTool.parseLiveUrl('京东直播 https://lives.jd.com/#/48266468?origin=0'), [
      '48266468',
      Sites.jdLiveSite,
    ]);
    expect(await LiveUrlTool.parseLiveUrl('https://lives.jd.com/#/channel'), isEmpty);
  });

  test('Taobao Live official room links resolve without a network request', () async {
    const url = 'https://h5.m.taobao.com/taolive/video.html?id=12345678901';
    expect(LiveUrlTool.containsSupportedLink('淘宝直播 $url'), isTrue);
    expect(await LiveUrlTool.parseLiveUrl('淘宝直播 $url'), ['live:12345678901', Sites.taobaoLiveSite]);
  });
}
