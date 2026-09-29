import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/douyin_danmaku.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/modules/live_play/services/room_external_opener.dart';

void main() {
  final newPlatformWebTargets = <String, (String, String)>{
    'fc2live': ('12345', 'https://live.fc2.com/12345/'),
    'steambroadcast': ('76561198373527746', 'https://steamcommunity.com/broadcast/watch/76561198373527746'),
    'jdlive': ('12345', 'https://lives.jd.com/#/12345'),
    'kugoulive': ('12345', 'https://fanxing.kugou.com/12345'),
    'baidulive': ('123456', 'https://live.baidu.com/m/room/123456'),
    'sixroom': ('12345', 'https://v.6.cn/12345'),
    'looklive': ('12345', 'https://look.163.com/live?id=12345'),
  };
  for (final entry in newPlatformWebTargets.entries) {
    test('${entry.key} opens its verified official room URL', () async {
      final room = LiveRoom(platform: entry.key, roomId: entry.value.$1, link: 'https://untrusted.example/room');
      final target = RoomExternalOpener.resolve(entry.key, room);
      expect(target?.web, entry.value.$2);
      expect(target?.native, isNull);
      final launches = <String>[];
      expect(
        await RoomExternalOpener.open(
          site: entry.key,
          room: room,
          android: false,
          launch: (url) async {
            launches.add(url);
            return true;
          },
        ),
        RoomExternalOpenResult.opened,
      );
      expect(launches, [entry.value.$2]);
    });
  }
  test('new platform malformed identities never become shell targets', () {
    final invalid = <String, String>{
      'fc2live': 'abc',
      'steambroadcast': '123',
      'jdlive': 'abc',
      'kugoulive': 'abc',
      'baidulive': '12345',
      'sixroom': '1',
      'looklive': '1',
    };
    for (final entry in invalid.entries) {
      expect(RoomExternalOpener.resolve(entry.key, LiveRoom(roomId: entry.value)), isNull, reason: entry.key);
    }
  });
  final webTargets = {
    'yy': 'https://www.yy.com/12345',
    'bilibili': 'https://live.bilibili.com/12345',
    'douyin': 'https://live.douyin.com/12345',
    'huya': 'https://www.huya.com/12345',
    'douyu': 'https://www.douyu.com/12345',
    'cc': 'https://cc.163.com/12345',
    'twitch': 'https://www.twitch.tv/12345',
    'soop': 'https://play.sooplive.co.kr/12345',
    'picarto': 'https://picarto.tv/12345',
    'twitcasting': 'https://twitcasting.tv/12345',
    'missevan': 'https://fm.missevan.com/live/12345',
    'acfun': 'https://live.acfun.cn/live/12345',
    'kuaishou': 'https://live.kuaishou.com/u/12345',
    'inke': 'https://www.inke.cn/',
    'kilakila': 'https://live.hongrenshuo.com.cn/index/roomuser/uid/12345',
  };

  for (final entry in webTargets.entries) {
    test('${entry.key} desktop opens the expected web target exactly once', () async {
      final calls = <String>[];
      final result = await RoomExternalOpener.open(
        site: entry.key,
        room: LiveRoom(roomId: '12345', platform: entry.key),
        android: false,
        launch: (url) async {
          calls.add(url);
          return true;
        },
      );
      expect(result, RoomExternalOpenResult.opened);
      expect(calls, [entry.value]);
    });
  }

  test('YY Android uses the same official page, without an invented deep link', () async {
    final calls = <String>[];
    expect(
      await RoomExternalOpener.open(
        site: 'yy',
        room: LiveRoom(roomId: '12345'),
        android: true,
        launch: (url) async {
          calls.add(url);
          return true;
        },
      ),
      RoomExternalOpenResult.opened,
    );
    expect(calls, [webTargets['yy']]);
  });

  for (final throws in [false, true]) {
    test('Android native ${throws ? 'exception' : 'false'} falls back once', () async {
      final calls = <String>[];
      var notices = 0;
      final result = await RoomExternalOpener.open(
        site: 'bilibili',
        room: LiveRoom(roomId: '12345'),
        android: true,
        onBrowserFallback: () => notices++,
        launch: (url) async {
          calls.add(url);
          if (calls.length == 1) {
            if (throws) throw StateError('fixture');
            return false;
          }
          return true;
        },
      );
      expect(result, RoomExternalOpenResult.opened);
      expect(calls, ['bilibili://live/12345', webTargets['bilibili']]);
      expect(notices, 1);
    });
  }

  test('native success does not open a browser', () async {
    final calls = <String>[];
    expect(
      await RoomExternalOpener.open(
        site: 'bilibili',
        room: LiveRoom(roomId: '12345'),
        android: true,
        onBrowserFallback: () => fail('unneeded fallback'),
        launch: (url) async {
          calls.add(url);
          return true;
        },
      ),
      RoomExternalOpenResult.opened,
    );
    expect(calls, ['bilibili://live/12345']);
  });

  test('both failures produce a failed result, never an unhandled second exception', () async {
    var calls = 0;
    expect(
      await RoomExternalOpener.open(
        site: 'bilibili',
        room: LiveRoom(roomId: '12345'),
        android: true,
        launch: (_) async {
          calls++;
          throw StateError('fixture');
        },
      ),
      RoomExternalOpenResult.failed,
    );
    expect(calls, 2);
  });

  for (final android in [false, true]) {
    test('web-only failure on android=$android is not retried', () async {
      var calls = 0;
      expect(
        await RoomExternalOpener.open(
          site: 'yy',
          room: LiveRoom(roomId: '12345'),
          android: android,
          onBrowserFallback: () => fail('same web target is not a native fallback'),
          launch: (_) async {
            calls++;
            return false;
          },
        ),
        RoomExternalOpenResult.failed,
      );
      expect(calls, 1);
    });
  }

  test('exit during a native attempt suppresses stale fallback and notifications', () async {
    final pending = Completer<bool>();
    var current = true;
    var calls = 0;
    final action = RoomExternalOpener.open(
      site: 'bilibili',
      room: LiveRoom(roomId: '12345'),
      android: true,
      isCurrent: () => current,
      onBrowserFallback: () => fail('owner is stale'),
      launch: (_) {
        calls++;
        return pending.future;
      },
    );
    current = false;
    pending.complete(false);
    expect(await action, RoomExternalOpenResult.cancelled);
    expect(calls, 1);
  });

  test('an already stale owner sends no OS request', () async {
    expect(
      await RoomExternalOpener.open(
        site: 'yy',
        room: LiveRoom(roomId: '12345'),
        android: true,
        isCurrent: () => false,
        launch: (_) async => fail('stale action'),
      ),
      RoomExternalOpenResult.cancelled,
    );
  });

  test('a stale browser completion is not reported as success/failure for a new room', () async {
    var current = true;
    expect(
      await RoomExternalOpener.open(
        site: 'yy',
        room: LiveRoom(roomId: '12345'),
        android: false,
        isCurrent: () => current,
        launch: (_) async {
          current = false;
          return true;
        },
      ),
      RoomExternalOpenResult.cancelled,
    );
  });

  test('unknown site and IPTV ignore imported URLs', () async {
    for (final site in ['unknown', 'iptv']) {
      expect(
        await RoomExternalOpener.open(
          site: site,
          room: LiveRoom(roomId: '12345', link: 'file:///C:/Windows/System32'),
          android: false,
          launch: (_) async => fail('not an official room URL'),
        ),
        RoomExternalOpenResult.unavailable,
      );
    }
  });

  test('invalid identities never become shell or guessed room targets', () {
    for (final id in <String?>[null, '', ' ', '.', '..', '../1', '1/2', '1?x=y', '1#x', '1%2f2', '1\n2', '1\\2']) {
      for (final site in ['yy', 'twitch', 'bilibili']) {
        expect(RoomExternalOpener.resolve(site, LiveRoom(roomId: id)), isNull, reason: '$site/$id');
      }
    }
    expect(RoomExternalOpener.resolve('yy', LiveRoom(roomId: 'abc')), isNull);
    expect(
      RoomExternalOpener.resolve('twitcasting', LiveRoom(roomId: 'c:fixture'))!.web,
      'https://twitcasting.tv/c%3Afixture',
    );
  });

  test('Douyin uses separate canonical web and native IDs without copying cookies', () {
    final args = DouyinDanmakuArgs(webRid: '2468', roomId: '98765', userId: '44', cookie: 'private-fixture');
    final target = RoomExternalOpener.resolve('douyin', LiveRoom(roomId: '12345', danmakuData: args))!;
    expect(target.web, 'https://live.douyin.com/2468');
    expect(target.native, 'snssdk1128://webcast_room?room_id=98765');
    expect('${target.web}${target.native}', isNot(contains(args.cookie)));
  });

  test('missing or wrong optional deep-link metadata keeps independent webpage targets', () {
    for (final data in [
      null,
      {'old': 'fixture'},
    ]) {
      for (final site in ['douyin', 'huya']) {
        final target = RoomExternalOpener.resolve(site, LiveRoom(roomId: '12345', danmakuData: data))!;
        expect(target.web, webTargets[site]);
        expect(target.native, isNull);
      }
    }
    expect(RoomExternalOpener.resolve('cc', LiveRoom(roomId: '12345'))!.native, isNull);
    expect(RoomExternalOpener.resolve('kuaishou', LiveRoom(roomId: '12345'))!.native, isNull);
  });

  test('existing Huya and CC deep-link contracts stay available with their metadata', () {
    final huya = RoomExternalOpener.resolve(
      'huya',
      LiveRoom(roomId: '12345', danmakuData: HuyaDanmakuArgs(uid: 11, topSid: 22, subSid: 33)),
    )!;
    expect(huya.native, startsWith('yykiwi://homepage/index.html?'));
    expect(huya.native, contains('subid%3D33'));
    final cc = RoomExternalOpener.resolve('cc', LiveRoom(roomId: '12345', userId: '456'))!;
    expect(cc.native, 'cc://join-room/12345/456/');
  });

  test('Kuaishou stream value stays in a single query field', () {
    final target = RoomExternalOpener.resolve('kuaishou', LiveRoom(roomId: '12345', link: 'stream&path=bad'))!;
    final query = Uri.parse(target.native!).queryParameters;
    expect(query['liveStreamId'], 'stream&path=bad');
    expect(query['path'], '/rest/n/live/feed/sharePage/slide/more');
  });
}
