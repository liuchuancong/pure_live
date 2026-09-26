import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/showroom/showroom_api.dart';

Map<String, Object?> _live(int roomId) => {
  'cell_type': 100,
  'room_id': roomId,
  'room_url_key': 'sample_$roomId',
  'main_name': 'Sample $roomId',
  'image': 'https://static.showroom-live.com/image/room/$roomId.png',
  'genre_id': 108,
  'follower_num': 516,
  'view_num': 78544,
  'telop': '',
  'started_at': 1790251202,
  'live_id': 23469535,
  'streaming_url_list': [
    {
      'is_default': true,
      'url': 'https://hls-css.live.showroom-live.com/live/$roomId.m3u8',
      'label': 'low quality',
      'type': 'hls',
      'id': 4,
      'quality': 100,
    },
  ],
};

// Production shape (2026-09-25): a genre with nobody live carries a message
// cell instead of an empty list.
const _placeholder = {'cell_type': 7, 'message': 'Currently, there are no live performance.'};

ShowroomApi _api(Object body) => ShowroomApi(request: (uri, cancel) async => (status: 200, body: jsonEncode(body)));

void main() {
  test('catalog skips "no live performance" placeholder cells instead of failing the whole snapshot', () async {
    final catalog = await _api({
      'onlives': [
        {
          'genre_id': 108,
          'genre_name': 'Idol',
          'lives': [_live(1001), _live(1002)],
        },
        {
          'genre_id': 758,
          'genre_name': 'Newcomer',
          'lives': [_placeholder],
        },
      ],
    }).catalog();

    expect(catalog.genres.map((g) => g.id), [108, 758]);
    expect(catalog.genres.first.lives.map((l) => l.roomId), [1001, 1002]);
    expect(catalog.genres.last.lives, isEmpty);
  });

  test('a malformed live row is still rejected', () async {
    final broken = _live(1003)..remove('main_name');
    await expectLater(
      _api({
        'onlives': [
          {
            'genre_id': 108,
            'genre_name': 'Idol',
            'lives': [broken],
          },
        ],
      }).catalog(),
      throwsA(isA<ShowroomException>()),
    );
  });
}
