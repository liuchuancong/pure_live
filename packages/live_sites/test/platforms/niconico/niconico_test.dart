import 'package:live_sites/src/models/room/live_room/live_room.dart';
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
        NiconicoRoomParser.notice(
          _watch(roomId: 'user/123', access: NiconicoAccess.loginRequired),
        ),
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
}
