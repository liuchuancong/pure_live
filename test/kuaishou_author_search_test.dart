import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/kuaishou/kuaishou_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('author search maps live, offline and banned streamers to rooms', () {
    final rooms = KuaishowSite.parseAuthorSearch({
      'data': {
        'type': 'authors',
        'result': 1,
        'list': [
          {
            'id': 'live_streamer',
            'name': 'Live streamer',
            'description': 'Nightly at 8',
            'avatar': 'https://example.com/a.jpg',
            'living': true,
            'counts': {'fan': '2960.9w'},
            'bannedStatus': {'banned': false},
          },
          {'id': 'offline_streamer', 'name': 'Offline streamer', 'living': false},
          {
            'id': 'banned_streamer',
            'name': 'Banned',
            'living': true,
            'bannedStatus': {'banned': true},
          },
          {'id': '', 'name': 'No id'},
          'not a map',
        ],
      },
    });

    expect(rooms.map((room) => room.roomId), ['live_streamer', 'offline_streamer', 'banned_streamer']);
    final live = rooms.first;
    expect(live.platform, Sites.kuaishouSite);
    expect(live.nick, 'Live streamer');
    expect(live.avatar, 'https://example.com/a.jpg');
    expect(live.followers, '2960.9w');
    expect(live.introduction, 'Nightly at 8');
    expect(live.link, 'https://live.kuaishou.com/u/live_streamer');
    expect(live.liveStatus, LiveStatus.live);
    expect(live.audienceValue(preferRealOnline: false, platformEnabled: false), isEmpty);
    expect(rooms[1].liveStatus, LiveStatus.offline);
    expect(rooms[1].followers, '0');
    expect(rooms[2].liveStatus, LiveStatus.banned);
  });

  test('a gated or malformed response yields no rooms', () {
    expect(
      KuaishowSite.parseAuthorSearch({
        'data': {'result': 10, 'error_msg': '服务器繁忙，请稍后再试。'},
      }),
      isEmpty,
    );
    expect(KuaishowSite.parseAuthorSearch(null), isEmpty);
    expect(
      KuaishowSite.parseAuthorSearch({
        'data': {'list': 'x'},
      }),
      isEmpty,
    );
  });
}
