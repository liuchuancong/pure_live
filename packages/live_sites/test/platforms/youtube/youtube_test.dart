import 'dart:convert';

import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_room_parser.dart';
import 'package:test/test.dart';

/// A `player` body of a live broadcast whose channel describes itself.
String _player({bool live = true}) => jsonEncode({
  'playabilityStatus': {'status': 'OK'},
  'videoDetails': {
    'videoId': 'v1',
    'externalChannelId': 'UCabc',
    'author': '频道',
    'title': '直播标题',
    'isLive': live,
    'shortDescription': '频道简介',
    'thumbnail': {
      'thumbnails': [
        {'url': 'https://i.ytimg.com/vi/v1/hq.jpg', 'width': 480, 'height': 270},
      ],
    },
  },
  'microformat': {
    'playerMicroformatRenderer': {
      'liveBroadcastDetails': {'isLiveNow': live},
    },
  },
  'streamingData': <String, Object?>{},
});

void main() {
  group('room content', () {
    test('the room carries the channel description and the online-figure notice', () {
      final parse = YoutubeRoomParser.room(_player(), '{}', requestedId: 'v1');
      expect(parse.room.content.title, '直播标题');
      expect(parse.room.content.introduction, '频道简介');
      expect(parse.room.content.notice, YoutubeRoomParser.chatNotice);
      expect(parse.room.content.coverUrl, 'https://i.ytimg.com/vi/v1/hq.jpg');
      expect(parse.room.roomId, 'UCabc');
    });

    test('a card has neither a description nor a notice: lists carry neither', () {
      final card = YoutubeRoomParser.card({
        'videoId': 'v1',
        'title': {'simpleText': '卡片'},
        'ownerText': {
          'runs': [
            {'text': '频道'},
          ],
        },
        'thumbnail': {
          'thumbnails': [
            {'url': 'https://i.ytimg.com/vi/v1/hq.jpg'},
          ],
        },
      });
      expect(card?.content.title, '卡片');
      expect(card?.content.introduction, isNull);
      expect(card?.content.notice, isNull);
    });
  });
}
