import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_json.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_room_parser.dart';
import 'package:live_sites/src/platforms/twitch/twitch_manifest.dart';
import 'package:test/test.dart';

/// The instant the covers are stamped with.
final DateTime _now = DateTime.utc(2026, 9, 27, 12, 49, 35);

/// The seconds 3.x writes into a preview address.
final String _stamp = '${_now.millisecondsSinceEpoch ~/ 1000}';

/// The category the directories are asked under.
const TwitchTag _tag = (id: '507800', name: '游戏');

/// An answer as the web client hands it over: decoded, so a map really is a map.
Object? _json(Object? value) => jsonDecode(jsonEncode(value));

/// An envelope with `data`.
Object? _envelope(Object? data, {Object? errors}) => _json({'data': data, 'errors': ?errors});

/// A Relay connection.
Map<String, Object?> _connection(List<Object?> edges, {Object? hasNextPage}) => {
  'edges': edges,
  if (hasNextPage != null) 'pageInfo': {'hasNextPage': hasNextPage},
};

Map<String, Object?> _edge(Map<String, Object?> node, {Object? cursor}) => {'node': node, 'cursor': ?cursor};

Map<String, Object?> _game([Map<String, Object?>? override]) => {
  'id': '3102399',
  'slug': 'league-of-legends',
  'displayName': '英雄联盟',
  'avatarURL': 'https://static-cdn.jtvnw.net/box.jpg',
  ...?override,
};

Map<String, Object?> _broadcaster([Map<String, Object?>? override]) => {
  'login': 'PlayerOne',
  'displayName': 'PlayerOne',
  'profileImageURL': null,
  ...?override,
};

Map<String, Object?> _streamNode([Map<String, Object?>? override]) => {
  'broadcaster': _broadcaster(),
  'viewersCount': '1200',
  'type': 'live',
  'createdAt': '2026-09-27T10:00:00Z',
  'previewImageURL': 'https://passport.twitch.tv/preview.jpg',
  'title': '深夜排位',
  ...?override,
};

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on TwitchFailure catch (failure) {
    return failure.kind;
  }
}

TwitchFailure _failure(void Function() read) {
  try {
    read();
  } on TwitchFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the envelope rules', () {
    test('the status table and the body kinds', () {
      expect(_kindOf(() => TwitchJson.decode('{"data":{}}', status: 200, what: 'x')), isNull);
      expect(_kindOf(() => TwitchJson.decode('[]', status: 200, what: 'x')), isNull);
      expect(
        {
          for (final status in [401, 429, 500, 404, 302])
            status: _kindOf(() => TwitchJson.decode('{"data":{}}', status: status, what: 'x')),
        },
        {
          401: TwitchFailureKind.needsLogin,
          429: TwitchFailureKind.rateLimited,
          500: TwitchFailureKind.network,
          404: TwitchFailureKind.apiChanged,
          302: TwitchFailureKind.apiChanged,
        },
        reason: 'a 401 here is a refused session, not a password ask',
      );
      expect(
        _failure(() => TwitchJson.decode('"a string"', status: 200, what: 'x')).message,
        contains('x: not a GraphQL answer'),
      );
      expect(
        _failure(() => TwitchJson.decode('{"data":{}}', status: 404, what: 'x')).message,
        'x: HTTP 404 ({"data":{}})',
      );
    });

    test('the integrity challenge is a refusal of this client', () {
      expect(
        _failure(
          () => TwitchJson.decode(
            '{"errors":[{"message":"[Failed To Load] Failed integrity check"}]}',
            status: 200,
            what: 'x',
          ),
        ).message,
        'x: integrity check required',
      );
      expect(
        _kindOf(() => TwitchJson.decode('{"extensions":{"challenge":{"a":"b"}}}', status: 200, what: 'x')),
        TwitchFailureKind.riskControl,
      );
      expect(
        _kindOf(() => TwitchJson.decode('[{"data":{}},{"extensions":{"challenge":{}}}]', status: 200, what: 'x')),
        TwitchFailureKind.riskControl,
        reason: 'a batch is refused when any envelope asks for the challenge',
      );
      expect(
        TwitchJson.isIntegrityRejection({
          'data': {
            'errors': const [
              {'message': 'ok'},
            ],
          },
        }),
        isFalse,
      );
    });

    test('data and errors: only errors that left no data behind count', () {
      expect(TwitchJson.data(_envelope({'user': null}), 'user'), {'user': null});
      expect(
        _failure(
          () => TwitchJson.data(
            _envelope(
              null,
              errors: [
                {'message': 'service error'},
              ],
            ),
            'x',
          ),
        ).message,
        'x: no data (service error)',
      );
      expect(
        TwitchJson.data(
          _envelope(
            {'a': 1},
            errors: [
              {'message': 'service error'},
            ],
          ),
          'x',
        ),
        {'a': 1},
        reason: 'partial service errors are common, so data still stands',
      );
      expect(
        _failure(() => TwitchJson.data(_json([1, 2]), 'x')).message,
        'x: no envelope',
        reason: 'a batch whose first answer is not an envelope is not an answer at all',
      );
      expect(
        _failure(
          () => TwitchJson.data(
            _json({
              'errors': [
                {'message': 'PersistedQueryNotFound'},
              ],
            }),
            'x',
          ),
        ).message,
        contains('persisted query no longer known'),
      );
    });

    test('the loose accessors read the wrong type as absent', () {
      expect(TwitchJson.textOf(null), isEmpty);
      expect(TwitchJson.textOf(7), '7');
      expect(TwitchJson.stringOf(null), isNull);
      expect(TwitchJson.stringOf(''), isEmpty, reason: 'an empty string is still an answer');
      expect(TwitchJson.intOf('12'), 12);
      expect(TwitchJson.intOf(12.0), 12);
      expect(TwitchJson.intOf('x'), isNull);
      expect(TwitchJson.object('text'), isNull);
      expect(TwitchJson.fields('text'), isEmpty);
      expect(TwitchJson.list('text'), isEmpty);
      expect(TwitchJson.time('2026-09-27T12:49:35Z'), _now);
      expect(TwitchJson.time('nope'), isNull);
      expect(TwitchJson.time(0), isNull, reason: 'a time at the epoch is no time');
      expect(
        TwitchJson.batch(
          [
            {'data': 1},
          ],
          expected: 1,
          what: 'x',
        ),
        hasLength(1),
      );
      expect(
        _failure(
          () => TwitchJson.batch(
            [
              {'data': 1},
            ],
            expected: 2,
            what: 'x',
          ),
        ).message,
        'x: 1 answers for 2 operations',
      );
    });
  });

  group('the category tags', () {
    test("every tag in the server's order", () {
      final tags = TwitchRoomParser.tags(
        _envelope({
          'searchCategoryTags': [
            {'id': '507800', 'tagName': 'Games', 'localizedName': '游戏'},
            {'id': 30, 'localizedName': 'Just Chatting'},
            {'id': '7', 'tagName': '', 'localizedName': ''},
            {'tagName': 'no id'},
            'not an object',
          ],
        }),
      );
      expect(tags, [
        (id: '507800', name: 'Games'),
        (id: '30', name: 'Just Chatting'),
        (id: '7', name: ''),
      ], reason: 'a number reads as text, and an empty tagName falls through to localizedName');
      expect(_failure(() => TwitchRoomParser.tags(_envelope({}))).message, 'SearchCategoryTags: no list');
      expect(
        _kindOf(
          () => TwitchRoomParser.tags(
            _envelope({
              'searchCategoryTags': {'a': 1},
            }),
          ),
        ),
        TwitchFailureKind.apiChanged,
      );
    });

    test('namedTags fills an empty Chinese name from the English answer', () {
      final named = TwitchRoomParser.namedTags([
        const (id: '507800', name: '游戏'),
        const (id: 'c7', name: ''),
        const (id: 'd4', name: ''),
      ], const [
        (id: '507800', name: 'Games'),
        (id: 'c7', name: 'Gambling'),
        (id: 'zz', name: 'Not Asked'),
      ]);
      expect(named, [
        const (id: '507800', name: '游戏'),
        const (id: 'c7', name: 'Gambling'),
        const (id: 'd4', name: ''),
      ], reason: 'a Chinese name is kept, and a tag the English answer cannot name stays empty');
    });
  });

  group('the directories', () {
    test('one area per game, the tag as its parent', () {
      final (:areas, :cursor) = TwitchRoomParser.directories(
        _envelope({
          'directoriesWithTags': _connection([
            _edge(_game(), cursor: 'c1'),
            _edge({'id': '2', 'slug': 'x', 'name': 'Old Only'}),
            _edge({'id': '3', 'displayName': '没有 slug'}),
            _edge({'slug': 'no-id', 'displayName': '没有 id'}),
            {
              'node': _game({'id': '4', 'slug': 'four', 'displayName': '四'}),
              'cursor': 'c1',
            },
            'not an object',
          ], hasNextPage: true),
        }),
        _tag,
      );
      expect(areas.map((area) => area.areaId), ['3102399', '2', '4']);
      expect(areas.first.areaName, '英雄联盟');
      expect(areas[1].areaName, 'Old Only', reason: 'a directory with no display name is named by its own name');
      expect(areas.first.shortName, 'league-of-legends');
      expect(areas.first.iconUrl, 'https://static-cdn.jtvnw.net/box.jpg');
      expect(areas.first.parentAreaId, '507800');
      expect(areas.first.parentAreaName, '游戏');
      expect(cursor, 'c1', reason: "the last edge's cursor, when pageInfo says there is more");
    });

    test('the cursor ends with the page, and errors without data are an empty page', () {
      expect(
        TwitchRoomParser.directories(
          _envelope({
            'directoriesWithTags': _connection([_edge(_game(), cursor: 'c1')]),
          }),
          _tag,
        ).cursor,
        isNull,
        reason: 'no pageInfo is no next page',
      );
      expect(
        TwitchRoomParser.directories(
          _envelope({'directoriesWithTags': _connection([], hasNextPage: true)}),
          _tag,
        ).cursor,
        isNull,
      );
      expect(
        TwitchRoomParser.directories(
          _json({
            'errors': [
              {'message': 'service error'},
            ],
          }),
          _tag,
        ).areas,
        isEmpty,
        reason: 'an envelope with errors and no data is a page without areas, not a failure',
      );
      expect(_kindOf(() => TwitchRoomParser.directories('{"data":1}', _tag)), TwitchFailureKind.apiChanged);
    });
  });

  group('the stream lists', () {
    test('a directory page answers its streams as cards', () {
      final (:rooms, :cursor) = TwitchRoomParser.gameStreams(
        _envelope({
          'game': {
            'streams': _connection([
              _edge(_streamNode({'game': _game()})),
              _edge(
                _streamNode({
                  'type': 'rerun',
                  'broadcaster': _broadcaster({'login': 'Rerun'}),
                }),
              ),
              _edge({'title': '没有 broadcaster'}),
              _edge({
                'broadcaster': {'displayName': '没有 login'},
              }, cursor: 'next'),
            ], hasNextPage: true),
          },
        }),
        now: _now,
        slug: 'league-of-legends',
      );
      expect(rooms.map((room) => room.roomId), ['PlayerOne', 'Rerun']);
      expect(rooms.first.content.title, '深夜排位');
      expect(rooms.first.content.coverUrl, 'https://passport.twitch.tv/preview.jpg?&t=$_stamp');
      expect(
        rooms.first.anchor?.anchorId,
        'playerone',
        reason: 'the anchor id is lower-cased, the room id keeps the case',
      );
      expect(rooms.first.anchor?.name, 'PlayerOne');
      expect(rooms.first.area?.areaName, '英雄联盟');
      expect(rooms.first.audience.onlineViewers, 1200);
      expect(rooms.first.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(rooms.first.broadcast.liveStatus, LiveStatus.live);
      expect(rooms.first.broadcast.startedAt, DateTime.utc(2026, 9, 27, 10));
      expect(rooms.first.broadcast.restriction, isNull, reason: 'the persisted queries do not ask for a restriction');
      expect(rooms.last.broadcast.liveStatus, LiveStatus.replay);
      expect(rooms.first.links.webUrl, TwitchEndpoints.roomPageUrl('PlayerOne'));
      expect(cursor, 'next');
    });

    test('an unknown directory is not-found', () {
      expect(
        _failure(() => TwitchRoomParser.gameStreams(_envelope({'game': null}), now: _now, slug: 'gone')).message,
        'DirectoryPage_Game: no directory gone',
      );
      expect(
        _failure(() => TwitchRoomParser.gameStreams(_envelope({'game': null}), now: _now)).message,
        'DirectoryPage_Game: no directory',
        reason: 'with no slug to name, the message stops short',
      );
    });

    test('a card without a preview has no cover, and no count reads as zero', () {
      final room = TwitchRoomParser.streams(
        _envelope({
          'streams': _connection([
            _edge(
              _streamNode({
                'viewersCount': null,
                'previewImageURL': null,
                'broadcaster': _broadcaster({'displayName': null}),
              }),
            ),
          ]),
        }),
        now: _now,
      ).rooms.single;
      expect(room.content.coverUrl, isEmpty);
      expect(room.audience.onlineViewers, 0);
      expect(room.anchor?.name, 'PlayerOne', reason: 'a broadcaster with no display name is named by its login');
      expect(room.area, isNull);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 27, 10));
      expect(TwitchRoomParser.streams(_envelope({}), now: _now).rooms, isEmpty);
    });

    test('a card may carry a restriction the page asked for', () {
      final room = TwitchRoomParser.streams(
        _envelope({
          'streams': _connection([
            _edge(
              _streamNode({
                'restriction': {'type': 'SUB_ONLY_LIVE'},
              }),
            ),
          ]),
        }),
        now: _now,
      ).rooms.single;
      expect(room.broadcast.restriction, LiveRestriction.subscribersOnly);
    });
  });

  group('the search page', () {
    Map<String, Object?> item([Map<String, Object?>? override]) => {
      'login': 'PlayerOne',
      'displayName': '玩家一',
      ...?override,
    };

    test('a live channel, its start only when the broadcast is the one on air', () {
      final (:rooms, :cursor) = TwitchRoomParser.searchPage(
        _envelope({
          'searchFor': {
            'channels': {
              'cursor': 'c9',
              'edges': [
                {
                  'item': item({
                    'stream': {
                      'id': '4242',
                      'viewersCount': 300,
                      'game': _game({'id': '9', 'slug': 'lol'}),
                      'previewImageURL': 'https://passport.twitch.tv/p.jpg',
                    },
                    'lastBroadcast': {'id': '4242', 'startedAt': '2026-09-27T09:00:00Z'},
                    'broadcastSettings': {'title': '排位中'},
                  }),
                },
                {
                  'item': item({
                    'login': 'Stale',
                    'stream': {'id': '1', 'type': 'live'},
                    'lastBroadcast': {'id': '2', 'startedAt': '2026-09-27T09:00:00Z'},
                  }),
                },
                {
                  'item': item({
                    'login': 'Offline',
                    'lastBroadcast': {'id': '3'},
                  }),
                },
                {
                  'item': item({
                    'login': 'Rerun',
                    'stream': {'id': '4', 'type': 'rerun'},
                  }),
                },
                {
                  'item': {'displayName': '没有 login'},
                },
                {'no-item': 1},
              ],
            },
          },
        }),
        now: _now,
      );
      expect(rooms.map((room) => room.roomId), ['PlayerOne', 'Stale', 'Offline', 'Rerun']);
      expect(rooms.first.content.title, '排位中');
      expect(rooms.first.content.coverUrl, 'https://passport.twitch.tv/p.jpg?&t=$_stamp');
      expect(rooms.first.area?.areaName, '英雄联盟');
      expect(rooms.first.area?.areaId, '9');
      expect(rooms.first.area?.shortName, 'lol');
      expect(rooms.first.anchor?.name, '玩家一');
      expect(rooms.first.broadcast.startedAt, DateTime.utc(2026, 9, 27, 9));
      expect(rooms.first.broadcast.liveStatus, LiveStatus.live);
      expect(rooms[1].broadcast.startedAt, isNull, reason: 'lastBroadcast names another stream');
      expect(rooms[2].broadcast.liveStatus, LiveStatus.offline);
      expect(rooms[2].content.coverUrl, isEmpty);
      expect(rooms[2].audience.onlineViewers, 0, reason: 'a search page answers no count as zero');
      expect(rooms.last.broadcast.liveStatus, LiveStatus.replay);
      expect(cursor, 'c9');
    });

    test('a page with no channels is empty, and carries no cursor', () {
      final (:rooms, :cursor) = TwitchRoomParser.searchPage(
        _envelope({
          'searchFor': {
            'channels': {'edges': <Object?>[], 'cursor': 'c1'},
          },
        }),
        now: _now,
      );
      expect(rooms, isEmpty);
      expect(cursor, isNull, reason: 'an empty page never carries the index forward');
      expect(TwitchRoomParser.searchPage(_envelope({'searchFor': null}), now: _now).rooms, isEmpty);
      expect(TwitchRoomParser.searchPage(_envelope({}), now: _now).cursor, isNull);
    });
  });

  group('the room detail', () {
    Object? userAnswer([Map<String, Object?>? override]) => _envelope({
      'user': {
        'login': 'PlayerOne',
        'displayName': '玩家一',
        'description': ' 一个主播 ',
        'profileImageURL': 'https://static-cdn.jtvnw.net/avatar.jpg',
        'lastBroadcast': {'title': '深夜排位'},
        ...?override,
      },
    });

    test('a live channel, its preview as the cover', () {
      final room = TwitchRoomParser.roomDetail(
        userAnswer({
          'stream': {
            'type': 'live',
            'viewersCount': '1200',
            'createdAt': '2026-09-27T10:00:00Z',
            'previewImageURL': 'https://passport.twitch.tv/p.jpg',
            'game': _game(),
          },
        }),
        requestedId: ' PlayerOne ',
        now: _now,
      );
      expect(room.roomId, 'PlayerOne', reason: 'the room keeps the id as the user asked for it');
      expect(room.platform, twitchSiteId);
      expect(room.content.title, '深夜排位');
      expect(room.content.coverUrl, 'https://passport.twitch.tv/p.jpg?&t=$_stamp');
      expect(room.content.introduction, '一个主播', reason: 'the description is trimmed once');
      expect(room.anchor?.anchorId, 'playerone');
      expect(room.anchor?.name, '玩家一');
      expect(room.anchor?.avatarUrl, 'https://static-cdn.jtvnw.net/avatar.jpg');
      expect(room.anchor?.introduction, '一个主播');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.area?.areaId, '3102399');
      expect(room.area?.areaName, '英雄联盟');
      expect(room.audience.onlineViewers, 1200);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 27, 10));
      expect(room.broadcast.restriction, isNull, reason: 'the answer carried no restriction key');
      expect(room.links.webUrl, TwitchEndpoints.roomPageUrl('PlayerOne'));
    });

    test('an offline channel keeps the profile image and says nothing about a restriction', () {
      final room = TwitchRoomParser.roomDetail(userAnswer(), requestedId: 'playerone', now: _now);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.content.coverUrl, 'https://static-cdn.jtvnw.net/avatar.jpg');
      expect(room.content.title, '深夜排位', reason: 'the title comes from lastBroadcast, on air or not');
      expect(room.audience.onlineViewers, 0);
      expect(room.broadcast.startedAt, isNull);
      expect(room.broadcast.restriction, isNull);
      expect(room.area, isNull);
      expect(room.anchor?.liveStatus, LiveStatus.offline);
    });

    test('a rerun is a replay, any other type is offline', () {
      final replay = TwitchRoomParser.roomDetail(
        userAnswer({
          'stream': {'type': 'rerun', 'previewImageURL': 'https://passport.twitch.tv/p.jpg'},
        }),
        requestedId: 'playerone',
        now: _now,
      );
      expect(replay.broadcast.liveStatus, LiveStatus.replay);
      expect(replay.content.coverUrl, contains('?&t='));
      expect(replay.anchor?.liveStatus, LiveStatus.replay);
      final other = TwitchRoomParser.roomDetail(
        userAnswer({
          'stream': {'type': 'unknown'},
        }),
        requestedId: 'playerone',
        now: _now,
      );
      expect(other.broadcast.liveStatus, LiveStatus.offline);
      expect(other.content.coverUrl, 'https://static-cdn.jtvnw.net/avatar.jpg', reason: 'no broadcast, no preview');
    });

    test('a preview that is not there falls back to the profile image', () {
      final room = TwitchRoomParser.roomDetail(
        userAnswer({
          'stream': {'type': 'live', 'previewImageURL': ''},
        }),
        requestedId: 'playerone',
        now: _now,
      );
      expect(room.content.coverUrl, 'https://static-cdn.jtvnw.net/avatar.jpg');
    });

    test('a channel with no profile image has no cover at all', () {
      final room = TwitchRoomParser.roomDetail(
        userAnswer({'profileImageURL': null}),
        requestedId: 'playerone',
        now: _now,
      );
      expect(room.content.coverUrl, isEmpty);
      expect(room.anchor?.avatarUrl, isEmpty);
    });

    test('the answer must be about the channel asked for', () {
      expect(
        _failure(() => TwitchRoomParser.roomDetail(_envelope({'user': null}), requestedId: 'gone', now: _now)).message,
        'user: no channel gone',
      );
      expect(
        _failure(
          () => TwitchRoomParser.roomDetail(
            _envelope({
              'user': {'login': 'SomeoneElse'},
            }),
            requestedId: 'playerone',
            now: _now,
          ),
        ).message,
        'user: answered someoneelse for playerone',
      );
      expect(
        TwitchRoomParser.roomDetail(
          _envelope({
            'user': {'login': 'PLAYERONE'},
          }),
          requestedId: 'playerone',
          now: _now,
        ).roomId,
        'playerone',
      );
    });

    test('a game with no name is no area, and a missing id or slug is empty text', () {
      final none = TwitchRoomParser.roomDetail(
        userAnswer({
          'stream': {
            'type': 'live',
            'game': {'displayName': ''},
          },
        }),
        requestedId: 'playerone',
        now: _now,
      );
      expect(none.area, isNull, reason: 'nothing names it, so there is no area');
      final bare = TwitchRoomParser.roomDetail(
        userAnswer({
          'stream': {
            'type': 'live',
            'game': {'name': 'Old'},
          },
        }),
        requestedId: 'playerone',
        now: _now,
      );
      expect(bare.area?.areaId, isEmpty);
      expect(bare.area?.shortName, isEmpty);
      expect(bare.area?.areaName, 'Old');
    });

    test('gameName keeps a blank display name, because it is not empty text', () {
      expect(TwitchRoomParser.gameName(_game({'displayName': '  '})), '  ');
      expect(TwitchRoomParser.gameName(_game({'displayName': null, 'name': 'Old'})), 'Old');
    });
  });

  group('the restriction and the access token', () {
    test('a restriction key says what it says, its absence says nothing', () {
      expect(TwitchRoomParser.restriction(null), isNull);
      expect(TwitchRoomParser.restriction({}), isNull);
      expect(TwitchRoomParser.restriction({'restriction': null}), LiveRestriction.none);
      expect(
        TwitchRoomParser.restriction({
          'restriction': {'type': 'SUB_ONLY_LIVE'},
        }),
        LiveRestriction.subscribersOnly,
      );
      expect(
        TwitchRoomParser.restriction({
          'restriction': {'type': 'sub'},
        }),
        LiveRestriction.subscribersOnly,
      );
      expect(
        TwitchRoomParser.restriction({
          'restriction': {'type': 'FOLLOWERS_ONLY'},
        }),
        LiveRestriction.unplayable,
      );
      expect(
        TwitchRoomParser.restriction({
          'restriction': {'no-type': 1},
        }),
        LiveRestriction.unplayable,
      );
      expect(
        TwitchRoomParser.restriction({'restriction': '文本'}),
        LiveRestriction.unplayable,
        reason: 'a value that is not an object names no type, so it is still a refusal',
      );
    });

    test('the token is asked for with usher, and its claims can refuse this viewer', () {
      Object? tokenAnswer(Object? token) => _envelope({'streamPlaybackAccessToken': token});
      String claims({required bool forbidden, String reason = ''}) => jsonEncode({
        'authorization': {'forbidden': forbidden, if (reason.isNotEmpty) 'reason': reason},
      });

      expect(
        TwitchRoomParser.accessToken(
          tokenAnswer({'value': claims(forbidden: false), 'signature': 'sig'}),
          login: 'playerone',
        ),
        (value: claims(forbidden: false), signature: 'sig'),
      );
      expect(
        _failure(() => TwitchRoomParser.accessToken(tokenAnswer(null), login: 'gone')).message,
        'PlaybackAccessToken: no channel gone',
      );
      expect(
        _failure(() => TwitchRoomParser.accessToken(tokenAnswer({'value': claims(forbidden: false)}), login: 'p'))
            .message,
        'PlaybackAccessToken: incomplete',
      );
      expect(
        _failure(() => TwitchRoomParser.accessToken(tokenAnswer({'signature': 'sig'}), login: 'p')).message,
        'PlaybackAccessToken: incomplete',
      );
      Object? geo() => TwitchRoomParser.accessToken(
        tokenAnswer({'value': claims(forbidden: true, reason: 'GEO_BLOCKED'), 'signature': 's'}),
        login: 'p',
      );
      expect(_failure(geo).message, 'PlaybackAccessToken: GEO_BLOCKED');
      expect(_kindOf(geo), TwitchFailureKind.regionBlocked);
      expect(
        _kindOf(
          () => TwitchRoomParser.accessToken(
            tokenAnswer({'value': claims(forbidden: true), 'signature': 's'}),
            login: 'p',
          ),
        ),
        TwitchFailureKind.needsLogin,
      );
      expect(
        TwitchRoomParser.accessToken(tokenAnswer({'value': 'not json', 'signature': 's'}), login: 'p').value,
        'not json',
        reason: 'a value that is not JSON cannot forbid anything',
      );
    });
  });

  group('the login', () {
    test('a channel login, trimmed and lower-cased', () {
      expect(TwitchRoomParser.loginOf(' Player_One '), 'player_one');
      expect(TwitchRoomParser.loginOf('a' * 25), 'a' * 25);
      expect(TwitchRoomParser.loginOf('a' * 26), isNull);
      expect(TwitchRoomParser.loginOf('player-one'), isNull, reason: 'a hyphen is not a login character');
      expect(TwitchRoomParser.loginOf(''), isNull);
    });
  });
}
