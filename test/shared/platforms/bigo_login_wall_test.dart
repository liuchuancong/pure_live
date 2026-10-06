import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_api.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_site.dart';

/// 房间详情走过的真路径：两次 web token 握手，再读工作室信息。
///
/// 探针（`tool/probes/bigo_metadata_probe_test.dart`）证明 2026-10-06 起
/// `getInternalStudioInfo` 对每一个在播房间都回 `needLogin: true`、`alive` 缺省、
/// `hls_src` 为空——直连和经代理两条出口一样。所以这不是解析坏了，也不是网络坏了：
/// 匿名接口被要求登录。这条测试钉住的是**这种情况要说什么**：适配器知道原因，
/// 界面就不能说"未开播"。
final class _StubbedBigo {
  _StubbedBigo({required bool needLogin, required int alive, String hlsSrc = ''}) {
    _studio = <String, dynamic>{
      'code': 0,
      'data': <String, dynamic>{
        'sid': 2759006138,
        'siteId': '',
        'uid': 732513016,
        'avatar': '',
        'nick_name': 'IpMan5',
        'country_code': '',
        'gameTitle': '',
        'roomTopic': 'Hi there',
        'snapshot': '',
        'alive': alive,
        'roomId': '0',
        'roomStatus': 0,
        'client_ip': '',
        'hls_src': hlsSrc,
        'cdn_src': <Object?>[],
        'needLogin': needLogin,
        'passRoom': false,
        'isPaidShow': '',
        'clientBigoId': 'THEBOSS8',
        'roomType': '',
      },
    };
  }

  late final Map<String, dynamic> _studio;
  final List<String> asked = <String>[];

  BigoApi get api => BigoApi(
    callbackFactory: () => 'jsonp_probe',
    tokenDataBuilder: (timestamp) => 'data-for-$timestamp',
    request: (method, uri, form, cancel) async {
      asked.add('${uri.host}${uri.path}');
      if (uri.path.endsWith('/webjs/t')) {
        return (status: 200, body: 'jsonp_probe({"code":0,"time":"1700000000"});');
      }
      if (uri.path.endsWith('/webjs/status')) {
        return (status: 200, body: 'jsonp_probe({"code":0,"info":"success","token":"tok"});');
      }
      if (uri.path.endsWith('/studio/getInternalStudioInfo')) {
        return (status: 200, body: jsonEncode(_studio));
      }
      return (status: 404, body: '{}');
    },
  );
}

void main() {
  group('bigo 房间详情对登录墙的说明', () {
    test('要登录的房间带着 needsLogin 回来，而不是被说成下播', () async {
      final stub = _StubbedBigo(needLogin: true, alive: 0);
      final site = BigoSite(api: stub.api);
      final room = await site.getRoomDetail(LiveRoom(platform: site.id, roomId: '3000692883'));

      expect(stub.asked, containsAllInOrder(['sec.bigo.sg/v1/webjs/t', 'sec.bigo.sg/v1/webjs/status']));
      // 登录墙下 `alive` 不代表在不在播，状态只能是 unknown。
      expect(room.liveStatus, LiveStatus.unknown);
      // 而限制种类是平台对房间本身说的实话，界面就按它给文案。
      expect(room.restriction, LiveRestriction.needsLogin);
      expect(room.effectiveRestriction, LiveRestriction.needsLogin);
      expect(room.isRestricted, isTrue);
    });

    test('公开且明确不在播的房间仍然只说下播，不许冒充受限', () async {
      // 这正是原来那道 liveStatus 闸保护的东西：别把一次普通下播报成"需要登录"。
      final stub = _StubbedBigo(needLogin: false, alive: 0);
      final site = BigoSite(api: stub.api);
      final room = await site.getRoomDetail(LiveRoom(platform: site.id, roomId: '3000692883'));

      expect(room.liveStatus, LiveStatus.offline);
      expect(room.restriction, isNull);
      expect(room.isRestricted, isFalse);
    });

    test('公开在播、拿到地址的房间不受限', () async {
      final stub = _StubbedBigo(needLogin: false, alive: 1, hlsSrc: 'https://esx.bigo.sg/live/2759006138/live.m3u8');
      final site = BigoSite(api: stub.api);
      final room = await site.getRoomDetail(LiveRoom(platform: site.id, roomId: '3000692883'));

      expect(room.liveStatus, LiveStatus.live);
      expect(room.isRestricted, isFalse);
    });
  });
}
