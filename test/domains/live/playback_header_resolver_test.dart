import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_header_policy.dart';
import 'package:pure_live/domains/live/data/playback_header_resolver.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/shared/platforms/looklive/look_live_api.dart';
import 'package:pure_live/shared/platforms/twitcasting/twitcasting_api.dart';

void main() {
  group('播放请求头解析', () {
    test('没有专属规则的站点用房间自己声明的头，不再发空表', () async {
      // looklive / jdlive / baidulive / sixroom / kugoulive / fc2live /
      // steambroadcast 都在房间上声明了媒体头，却都不在解析器的 switch 里；
      // 默认分支曾经给空表，于是这些站的 CDN 一个头都收不到（mpv 日志里的
      // `http-header-fields=[]`）。只有站点自己知道该拿哪个 id 拼 Referer，
      // 解析器手上只有 roomId，重建会拼错，所以默认分支必须透传声明。
      final declared = LookLiveApi.mediaHeaders('123456');
      expect(declared, isNotEmpty, reason: '前置条件：站点确实声明了媒体头');

      final resolved = await PlaybackHeaderResolver.resolve(
        platform: Sites.lookLiveSite,
        roomId: '123456',
        roomHeaders: declared,
      );

      expect(resolved, HttpHeaderPolicy.normalize(declared));
      expect(resolved['referer'], 'https://look.163.com/live?id=123456');
      expect(resolved['origin'], LookLiveApi.origin);
      expect(resolved['user-agent'], isNotEmpty);
    });

    test('有专属规则的站点仍按规则来，房间声明不覆盖它', () async {
      // 专属规则里带着设置项（Cookie、自定义 UA），不能被房间声明盖掉；
      // 这条钉的是优先级方向，改动它会静默换掉一批站点的鉴权头。
      final resolved = await PlaybackHeaderResolver.resolve(
        platform: Sites.twitcastingSite,
        roomId: 'someone',
        roomHeaders: const <String, String>{'referer': 'https://example.invalid/room'},
      );

      expect(resolved, HttpHeaderPolicy.normalize(TwitcastingApi.playHeaders));
      expect(resolved['referer'], isNot('https://example.invalid/room'));
    });

    test('IPTV 把每频道声明的头和自定义 UA 合起来', () async {
      final resolved = await PlaybackHeaderResolver.resolve(
        platform: Sites.iptvSite,
        roomHeaders: const <String, String>{'Referer': 'https://iptv.example/channel'},
      );

      expect(resolved['referer'], 'https://iptv.example/channel');
    });

    test('什么都没声明时仍然是空表，不会凭空造头', () async {
      expect(await PlaybackHeaderResolver.resolve(platform: Sites.lookLiveSite, roomId: '123456'), isEmpty);
    });
  });
}
