import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/live_play_controller.dart';

/// 未知在播状态该说什么。
///
/// 这条路径以前只会说"获取直播间信息失败，请重试"，可站点在答案里明明
/// 标了限制种类（bigo 现在每个房间都回 `needLogin`，状态因此是 unknown 而不是下播），
/// 于是整站被登录墙挡住时观众看到的是一句会重试成功的话。测试断的是键名：单元测试
/// 里没有语言包，缺键就渲染成键名本身。
void main() {
  group('未知状态的说明要接住平台声明的原因', () {
    test('站点标了要登录，就不说"请重试"', () {
      final room = LiveRoom(
        platform: 'bigo',
        roomId: '3000692883',
        liveStatus: LiveStatus.unknown,
        restriction: LiveRestriction.needsLogin,
      );

      expect(unknownRoomStatusMessage(room), 'restriction_needs_login');
      expect(roomStateMessage(room), 'restriction_needs_login');
      expect(unknownRoomStatusMessage(room), isNot('get_room_info_failed_retry'));
    });

    test('平台没给原因时才说取信息失败', () {
      expect(unknownRoomStatusMessage(LiveRoom(platform: 'bigo', roomId: '1')), 'get_room_info_failed_retry');
      expect(unknownRoomStatusMessage(null), 'get_room_info_failed_retry');
      expect(
        unknownRoomStatusMessage(LiveRoom(platform: 'bigo', roomId: '1', liveStatus: LiveStatus.unknown)),
        'get_room_info_failed_retry',
      );
    });

    test('密码房说密码房，不是一句通用受限', () {
      expect(
        unknownRoomStatusMessage(LiveRoom(platform: 'bigo', roomId: '1', restriction: LiveRestriction.password)),
        'restriction_password',
      );
    });
  });
}
