import 'dart:convert';

import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
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

/// The channel the listing rows name.
const String _channel = 'UCabc1234567890123456789';

/// A live directory row of [_channel].
Map<String, Object?> _liveRow([Map<String, Object?>? override]) => {
  'videoId': 'v1234567890',
  'title': {'simpleText': '直播标题'},
  'ownerText': {
    'runs': [
      {'text': '频道'},
    ],
  },
  'browseEndpoint': {'browseId': _channel},
  'viewCountText': {'simpleText': '1,204 watching'},
  'thumbnail': {
    'thumbnails': [
      {'url': 'https://i.ytimg.com/vi/v1/hq.jpg'},
    ],
  },
  ...?override,
};

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
      final card = YoutubeRoomParser.card(_liveRow());
      expect(card?.content.title, '直播标题');
      expect(card?.content.introduction, isNull);
      expect(card?.content.notice, isNull);
    });
  });

  group('the listing', () {
    test('a LIVE NOW badge or a LIVE overlay marks the row live, no signal does not', () {
      final badge = YoutubeRoomParser.card(
        _liveRow()
          ..remove('viewCountText')
          ..['badges'] = [
            {
              'metadataBadgeRenderer': {'style': 'BADGE_STYLE_TYPE_LIVE_NOW', 'label': 'LIVE'},
            },
          ],
      );
      final overlay = YoutubeRoomParser.card(
        _liveRow()
          ..remove('viewCountText')
          ..['thumbnailOverlays'] = [
            {
              'thumbnailOverlayTimeStatusRenderer': {'style': 'LIVE'},
            },
          ],
      );
      expect(badge?.broadcast.liveStatus, LiveStatus.live);
      expect(overlay?.broadcast.liveStatus, LiveStatus.live);
    });

    test('ended and upcoming rows are left out, and a members badge restricts', () {
      final ended = YoutubeRoomParser.card(_liveRow()..remove('viewCountText'));
      final upcoming = YoutubeRoomParser.card(
        _liveRow()
          ..remove('viewCountText')
          ..['upcomingEventData'] = <String, Object?>{},
      );
      expect(ended, isNull, reason: 'a row with no live signal is not a card');
      expect(upcoming, isNull, reason: 'an upcoming broadcast is not a card');
      final members = YoutubeRoomParser.card(
        _liveRow()
          ..['badges'] = [
            {
              'metadataBadgeRenderer': {'style': 'BADGE_STYLE_TYPE_MEMBERS_ONLY'},
            },
          ],
      );
      expect(members?.broadcast.restriction, LiveRestriction.subscribersOnly);
      expect(YoutubeRoomParser.card(_liveRow())?.broadcast.restriction, LiveRestriction.none);
    });

    test('an incomplete live row is malformed, a whole one keyed by its channel', () {
      expect(YoutubeRoomParser.card(_liveRow({'browseEndpoint': {'browseId': 'nope'}})), isNull);
      expect(YoutubeRoomParser.card(_liveRow({'title': {'simpleText': ''}})), isNull);
      final card = YoutubeRoomParser.card(_liveRow());
      expect(card?.roomId, _channel);
    });

    test('browse without video rows is api-changed; search pages along live rows only', () {
      expect(
        _kindOf(() => YoutubeRoomParser.listing({'contents': <Object?>[]}, search: false)),
        YoutubeFailureKind.apiChanged,
      );
      final page = {
        'contents': [
          {
            'videoRenderer': _liveRow(),
            'continuationItemRenderer': {
              'continuationEndpoint': {
                'continuationCommand': {'token': 'tok1'},
              },
            },
          },
          {'videoRenderer': _liveRow({'viewCountText': {'simpleText': '5 watching'}})},
          {
            'videoRenderer': _liveRow({
              'browseEndpoint': {'browseId': 'UCxyz1234567890123456789'},
              'videoId': 'v9876543210',
              'viewCountText': {'simpleText': '5 watching'},
            }),
          },
        ],
      };
      final search = YoutubeRoomParser.listing(page, search: true);
      expect(search.rooms, hasLength(2), reason: 'the channel of rows 1 and 2 shows once, the first card');
      expect(search.rooms[0].roomId, _channel);
      expect(search.rooms[1].roomId, 'UCxyz1234567890123456789');
      expect(search.continuation, 'tok1');

      final endedPage = {
        'contents': [
          {
            'videoRenderer': _liveRow()
              ..remove('viewCountText'),
            'continuationItemRenderer': {
              'continuationEndpoint': {
                'continuationCommand': {'token': 'tok2'},
              },
            },
          },
        ],
      };
      final ended = YoutubeRoomParser.listing(endedPage, search: true);
      expect(ended.rooms, isEmpty);
      expect(ended.continuation, isNull, reason: 'a page without a live row has no next page');

      expect(
        _kindOf(
          () => YoutubeRoomParser.listing({
            'contents': [
              {'videoRenderer': _liveRow()..remove('browseEndpoint')},
            ],
          }, search: true),
        ),
        YoutubeFailureKind.apiChanged,
        reason: 'every live row malformed is api-changed',
      );
    });
  });
}

/// The failure kind [read] throws, or null when it does not.
YoutubeFailureKind? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on YouTubeFailure catch (failure) {
    return failure.kind;
  }
}
