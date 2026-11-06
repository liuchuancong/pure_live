import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_room_parser.dart';
import 'package:test/test.dart';

const String _scope = '收藏对应本次节目，主播的新节目需重新添加。';

NiconicoWatch _watch({
  String programId = 'lv123',
  String? roomId,
  NiconicoProgramStatus status = NiconicoProgramStatus.onAir,
  NiconicoAccess access = NiconicoAccess.allowed,
}) => NiconicoWatch(
  programId: programId,
  roomId: roomId,
  title: '番組',
  broadcaster: '配信者',
  status: status,
  access: access,
  paid: access == NiconicoAccess.denied,
);

void main() {
  group('notices (3.x zh.json text)', () {
    test('a scheduled program says so and names the program scope', () {
      expect(NiconicoRoomParser.notice(_watch(status: NiconicoProgramStatus.scheduled)), '节目尚未开始。 $_scope');
    });

    test('an on-air program only names the scope when anyone may watch', () {
      expect(NiconicoRoomParser.notice(_watch()), _scope);
    });

    test('an on-air program adds why an anonymous viewer cannot watch', () {
      expect(NiconicoRoomParser.notice(_watch(access: NiconicoAccess.loginRequired)), '此节目要求登录官方站点。 $_scope');
      expect(NiconicoRoomParser.notice(_watch(access: NiconicoAccess.regionRestricted)), '此节目设有地区访问限制。 $_scope');
      expect(NiconicoRoomParser.notice(_watch(access: NiconicoAccess.denied)), '此节目的当前观看权限受限。 $_scope');
    });

    test('an ended program keeps the scope; a broadcaster room has no notice', () {
      expect(NiconicoRoomParser.notice(_watch(status: NiconicoProgramStatus.ended)), _scope);
      expect(
        NiconicoRoomParser.notice(_watch(roomId: 'user/123', access: NiconicoAccess.loginRequired)),
        '此节目要求登录官方站点。',
      );
      expect(
        NiconicoRoomParser.notice(
          _watch(roomId: 'user/123', status: NiconicoProgramStatus.ended, access: NiconicoAccess.denied),
        ),
        isNull,
      );
    });

    test('the room carries the notice beside its description', () {
      final room = NiconicoRoomParser.room(
        _watch(status: NiconicoProgramStatus.scheduled, access: NiconicoAccess.denied),
      );
      expect(room.content.notice, '节目尚未开始。 $_scope');
      expect(room.content.title, '番組');
      expect(room.roomId, 'lv123');
    });
  });

  group('search rows (S02-search-channel shape)', () {
    // The channel row of the upstream fixture: its supplier has a name but no
    // icons, and the channel icon rides the social group's `thumbnailUrl`.
    Map<String, dynamic> channelRow() => {
      'nicoliveProgramId': 'lv351483018',
      'title': '番組',
      'status': 'ON_AIR',
      'providerType': 'channel',
      'watchPageUrl': 'https://live.nicovideo.jp/watch/lv351483018',
      'supplier': {'name': '有限会社阿部珈琲館'},
      'socialGroup': {
        'id': 'ch2611887',
        'name': 'A-beans. エービーンズチャンネル',
        'thumbnailUrl': 'https://secure-dcdn.cdn.nimg.jp/comch/channel-icon/128x128/ch2611887.jpg',
      },
      'statistics': {'watchCount': 12},
      'beginTime': 1790534283,
    };

    test('a channel card falls back to the social group picture', () {
      final room = NiconicoRoomParser.listRoom(channelRow(), search: true);
      expect(room.roomId, 'ch2611887');
      expect(room.anchor?.avatarUrl, 'https://secure-dcdn.cdn.nimg.jp/comch/channel-icon/128x128/ch2611887.jpg');
    });

    test('a row with neither a provider nor a social name drops', () {
      final row = channelRow()
        ..['supplier'] = <String, dynamic>{}
        ..remove('socialGroup');
      expect(() => NiconicoRoomParser.listRoom(row, search: true), throwsA(isA<NiconicoFailure>()));
    });
  });

  group('the seat socket of a watch page', () {
    Map<String, dynamic> data({Object? webSocketUrl, Object? frontendId}) => {
      'program': {
        'nicoliveProgramId': 'lv123',
        'title': '番組',
        'providerType': 'community',
        'status': 'ON_AIR',
        'supplier': {'supplierType': 'user', 'programProviderId': 123, 'name': '配信者'},
        'statistics': {'watchCount': 1},
        'beginTime': 1790534283,
      },
      'programWatch': {'condition': {'needLogin': false}},
      'userProgramWatch': {'isCountryRestrictionTarget': false, 'canWatch': true},
      'site': {'relive': {'webSocketUrl': webSocketUrl}, 'frontendId': frontendId},
    };

    test('a good socket gains the frontend id', () {
      final watch = NiconicoRoomParser.watchData(
        data(
          webSocketUrl: 'wss://a.live2.nicovideo.jp/wsapi/v2/watch/123?audience_token=t',
          frontendId: 7,
        ),
        roomId: 'user/123',
      );
      expect(watch.socket, isNotNull);
      expect(watch.socket!.queryParameters['frontend_id'], '7');
    });

    test('a malformed socket or frontend id is apiChanged, not a seatless room', () {
      expect(
        () => NiconicoRoomParser.watchData(
          data(webSocketUrl: 'wss://a.live2.nicovideo.jp/wsapi/v2/watch/123', frontendId: 7),
          roomId: 'user/123',
        ),
        throwsA(isA<NiconicoFailure>()),
      );
      expect(
        () => NiconicoRoomParser.watchData(
          data(webSocketUrl: 'wss://other.example/wsapi/v2/watch/123?audience_token=t', frontendId: 7),
          roomId: 'user/123',
        ),
        throwsA(isA<NiconicoFailure>()),
      );
      expect(
        () => NiconicoRoomParser.watchData(
          data(webSocketUrl: 'wss://a.live2.nicovideo.jp/wsapi/v2/watch/123?audience_token=t', frontendId: 0),
          roomId: 'user/123',
        ),
        throwsA(isA<NiconicoFailure>()),
      );
    });
  });
}
