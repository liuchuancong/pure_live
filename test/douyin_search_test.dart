import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/douyin/douyin_search.dart';

void main() {
  test('parses live-search rawdata and keeps a stable room identity', () {
    final rooms = DouyinSearch.parseSearchPayloadForTesting([
      {
        'lives': {
          'rawdata': jsonEncode({
            'id_str': 'internal-room-id',
            'status': 2,
            'title': '三角洲行动',
            'owner': {
              'nickname': '主播',
              'avatar_thumb': {
                'url_list': ['https://example.com/avatar.webp'],
              },
            },
            'cover': {
              'url_list': ['https://example.com/cover.webp'],
            },
            'room_view_stats': {'user_count': 321},
          }),
        },
      },
    ]);

    expect(rooms, hasLength(1));
    expect(rooms.single.roomId, 'internal-room-id');
    expect(rooms.single.link, 'https://live.douyin.com/internal-room-id');
    expect(rooms.single.liveStatus, LiveStatus.live);
    expect(rooms.single.onlineViewers, '321');
  });

  test('prefers web_rid and removes duplicate search cards', () {
    Map<String, dynamic> item() => {
      'rawdata': jsonEncode({
        'id_str': 'session-id',
        'status': 2,
        'title': '直播标题',
        'owner': {'nickname': '主播', 'web_rid': 'stable-web-rid'},
      }),
    };

    final rooms = DouyinSearch.parseSearchPayloadForTesting([item(), item()]);

    expect(rooms, hasLength(1));
    expect(rooms.single.roomId, 'stable-web-rid');
  });
}
