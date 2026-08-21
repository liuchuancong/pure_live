import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';

void main() {
  group('Bilibili recommendation parsing', () {
    test('parses the current webMain response', () {
      final rooms = BiliBiliSite.parseRecommendRooms({
        'code': 0,
        'data': {
          'recommend_room_list': [
            {
              'roomid': 6,
              'title': '直播标题',
              'cover': 'https://i0.hdslb.com/bfs/live/cover.jpg',
              'area_v2_name': '单机游戏',
              'uname': '主播',
              'face': '//i0.hdslb.com/bfs/face/avatar.jpg',
              'online': 123456,
            },
          ],
        },
      });

      expect(rooms, hasLength(1));
      expect(rooms.single.roomId, '6');
      expect(rooms.single.cover, endsWith('@400w.jpg'));
      expect(rooms.single.avatar, startsWith('https://'));
      expect(rooms.single.popularity, '123456');
    });

    test('parses the anonymous fallback response', () {
      final rooms = BiliBiliSite.parseRecommendRooms({
        'code': 0,
        'data': [
          {
            'roomid': 7,
            'title': '备用接口',
            'user_cover': 'https://i0.hdslb.com/bfs/live/fallback.jpg',
            'areaName': '娱乐',
            'uname': '主播二',
            'online': 100,
          },
        ],
      });

      expect(rooms.single.roomId, '7');
      expect(rooms.single.area, '娱乐');
    });

    test('surfaces platform rejection instead of a null-index error', () {
      expect(() => BiliBiliSite.parseRecommendRooms({'code': -352, 'message': '-352'}), throwsStateError);
    });
  });
}
