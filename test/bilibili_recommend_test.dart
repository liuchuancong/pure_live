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
              'roomid': 7,
              'title': '低热度直播',
              'cover': 'https://i0.hdslb.com/bfs/live/low.jpg',
              'area_v2_name': '单机游戏',
              'uname': '主播二',
              'online': 23036,
            },
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

      expect(rooms, hasLength(2));
      expect(rooms.map((room) => room.roomId), <String>['6', '7']);
      expect(rooms.first.cover, endsWith('@400w.jpg'));
      expect(rooms.first.avatar, startsWith('https://'));
      expect(rooms.first.popularity, '123456');
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
      expect(
        () => BiliBiliSite.parseRecommendRooms({'code': -352, 'message': '-352'}),
        throwsStateError,
      );
    });

    test('sorts equal popularity by stable room identity', () {
      final rooms = BiliBiliSite.parseRecommendRooms({
        'code': 0,
        'data': [
          {'roomid': 20, 'title': 'B', 'online': 100},
          {'roomid': 10, 'title': 'A', 'online': 100},
        ],
      });

      expect(rooms.map((room) => room.roomId), <String>['10', '20']);
    });
  });

  group('Bilibili room metadata parsing', () {
    test('accepts a complete signed response', () {
      final data = BiliBiliSite.parseRoomInfoResponse({
        'code': 0,
        'data': {
          'room_info': {'room_id': 6, 'live_status': 1},
          'anchor_info': {
            'base_info': {'uname': '主播'},
          },
        },
      });

      expect((data['room_info'] as Map)['room_id'], 6);
    });

    test('rejects expired WBI and incomplete payloads before dynamic indexing', () {
      expect(
        () => BiliBiliSite.parseRoomInfoResponse({'code': -352, 'data': null}),
        throwsStateError,
      );
      expect(
        () => BiliBiliSite.parseRoomInfoResponse({
          'code': 0,
          'data': {'room_info': {}},
        }),
        throwsFormatException,
      );
    });
  });
}
