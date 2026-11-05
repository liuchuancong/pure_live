import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_play_parser.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_room_parser.dart';
import 'package:test/test.dart';

/// A streamer id, which is also the room id here.
const String _user = 'ks_user_31';

/// A signed CDN address whose `txTime` names 2024-10-12.
const String _streamUrl = 'https://ts4-kn-pro.wskwai.com/live/a_1730000000.flv?txTime=6709E5C0';

/// The instant the platform's epoch-millisecond cards write.
final DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(1730000000000, isUtc: true);

/// A `live_api` answer.
String _api(Object? data) => jsonEncode({'data': data});

/// The `data` of a list answer.
Map<String, Object?> _listData(List<Object?> rows, {Object? hasMore, Object? cursor, Object? result}) => {
  'list': rows,
  'hasMore': ?hasMore,
  'cursor': ?cursor,
  'result': ?result,
};

/// A card's `playUrls`: one descriptor, one quality.
List<Object?> _playUrls({String url = _streamUrl, Object? level, String? name}) => [
  {
    'adaptationSet': {
      'representation': [
        {'url': url, 'level': ?level, 'name': ?name},
      ],
    },
  },
];

/// A room page's `{h264: ...}` object.
Map<String, Object?> _pageUrls({String url = _streamUrl}) => {
  'h264': {
    'adaptationSet': {
      'representation': [
        {'url': url, 'level': 10, 'name': '蓝光'},
      ],
    },
  },
};

Map<String, Object?> _author([Map<String, Object?>? override]) => {
  'id': _user,
  'name': '主播',
  'avatar': '//ali2.a.yximgs.com/avatar.jpg',
  'description': '个性\n签名',
  'counts': {'fan': '1.2万'},
  ...?override,
};

Map<String, Object?> _cardRow([Map<String, Object?>? override]) => {
  'author': _author(),
  'caption': '在播',
  'poster': 'https://ali2.a.yximgs.com/cover',
  'watchingCount': '1.2万',
  'gameInfo': {'name': '王者荣耀'},
  'statrtTime': 1730000000000,
  ...?override,
};

Map<String, Object?> _room([Map<String, Object?>? override]) => {
  'author': _author(),
  'liveStream': {'id': 'live_stream_1', 'poster': 'https://ali2.a.yximgs.com/cover'},
  'gameInfo': {'name': '王者荣耀'},
  'isLiving': true,
  ...?override,
};

Map<String, Object?> _state(Map<String, Object?> room, {Object? emojiPanel}) => {
  'liveroom': {
    'playList': [room],
  },
  'pcConfig': {
    'pcConfig': {
      'config': {'pcLive.webConfig.emojiPanel': ?emojiPanel},
    },
  },
};

/// A room page as the site writes it.
String _page(Map<String, Object?> state) =>
    '<html><script>window.__INITIAL_STATE__ = ${jsonEncode(state)};</script></html>';

KuaishouRoomParse _detail(Map<String, Object?> room, {String requestedId = _user, Uri? url}) =>
    KuaishouRoomParser.roomDetail(_page(_state(room)), requestedId: requestedId, url: url);

LiveRoom _areaCard([Map<String, Object?>? override]) =>
    KuaishouRoomParser.areaRooms(_api(_listData([_cardRow(override)]))).rooms.single;

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on KuaishouFailure catch (failure) {
    return failure.kind;
  }
}

KuaishouFailure _failure(void Function() read) {
  try {
    read();
  } on KuaishouFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the live_api envelope', () {
    test('the status table', () {
      expect(KuaishouRoomParser.areaRooms(_api(_listData([]))), isNotNull);
      expect(
        {
          for (final status in [429, 500, 401, 403, 404, 302])
            status: _kindOf(() => KuaishouRoomParser.areaRooms(_api(_listData([])), status: status)),
        },
        {
          429: KuaishouFailureKind.rateLimited,
          500: KuaishouFailureKind.network,
          401: KuaishouFailureKind.riskControl,
          403: KuaishouFailureKind.riskControl,
          404: KuaishouFailureKind.apiChanged,
          302: KuaishouFailureKind.apiChanged,
        },
        reason: 'a 404 here is the answer changing shape, not the room being gone',
      );
    });

    test('no data object, and a body that is not JSON', () {
      expect(
        _failure(() => KuaishouRoomParser.areaRooms('{"data":null}')).message,
        'area rooms: no data object ({"data":null})',
      );
      expect(_failure(() => KuaishouRoomParser.areaRooms('not json')).message, contains('no data object (not json)'));
      expect(_kindOf(() => KuaishouRoomParser.areaRooms('[1,2]')), KuaishouFailureKind.apiChanged);
    });

    test('a long body is snippeted into the message', () {
      final message = _failure(() => KuaishouRoomParser.areaRooms('{"x":${'y' * 200}}')).message;
      expect(message, contains('${'y' * 66}…'), reason: 'the diagnostic keeps at most 80 characters');
    });

    test('result 2 is a throttle, 10 the guest gate, anything else a change', () {
      expect(_kindOf(() => KuaishouRoomParser.areaRooms(_api(_listData([], result: 1)))), isNull);
      expect(_kindOf(() => KuaishouRoomParser.areaRooms(_api(_listData([], result: '1')))), isNull);
      expect(
        _kindOf(() => KuaishouRoomParser.areaRooms(_api(_listData([], result: 2)))),
        KuaishouFailureKind.rateLimited,
      );
      expect(
        _kindOf(() => KuaishouRoomParser.areaRooms(_api(_listData([], result: 10)))),
        KuaishouFailureKind.riskControl,
      );
      expect(
        _kindOf(() => KuaishouRoomParser.areaRooms(_api(_listData([], result: 7)))),
        KuaishouFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => KuaishouRoomParser.areaRooms(_api({'list': const <Object?>[], 'result': 2, 'error_msg': '操作太快了'})),
        ).message,
        'area rooms: result 2 操作太快了',
      );
    });

    test('a missing list is api-changed, not an empty page', () {
      expect(
        _failure(() => KuaishouRoomParser.areas(_api({'hasMore': true}), categoryId: '1', categoryName: '游戏')).message,
        contains('category/data: no list'),
      );
      expect(
        _kindOf(() => KuaishouRoomParser.searchRooms(_api({'result': 7}))),
        KuaishouFailureKind.apiChanged,
        reason: 'search only answers "no result" with result 1',
      );
      expect(KuaishouRoomParser.searchRooms(_api({'result': 1})), isEmpty);
    });
  });

  group('the areas', () {
    test('server order, one per id, the asked category as the parent', () {
      final (:areas, :hasMore) = KuaishouRoomParser.areas(
        _api(
          _listData([
            {'id': '11', 'name': '热门', 'poster': '//ali2.a.yximgs.com/a.png'},
            {'id': '12', 'name': '游戏女神', 'iconUrl': 'http://ali2.a.yximgs.com/b.png'},
            {'id': '11', 'name': '重复'},
            {'name': '没有 id'},
            '不是对象',
            {'id': '13', 'name': '没有图'},
          ], hasMore: 1),
        ),
        categoryId: '1',
        categoryName: '游戏',
      );
      expect(areas.map((area) => area.areaId), ['11', '12', '13']);
      expect(areas.first.areaName, '热门');
      expect(areas.first.iconUrl, 'https://ali2.a.yximgs.com/a.png');
      expect(areas[1].iconUrl, 'http://ali2.a.yximgs.com/b.png', reason: 'imageUrl keeps http as written');
      expect(areas.last.iconUrl, isEmpty, reason: 'an area with no picture keeps the empty text');
      expect(areas.first.parentAreaId, '1');
      expect(areas.first.parentAreaName, '游戏');
      expect(hasMore, isTrue, reason: 'hasMore may be the number 1');
    });

    test('poster wins over iconUrl, and a non-image address is no icon', () {
      final (:areas, :hasMore) = KuaishouRoomParser.areas(
        _api(
          _listData([
            {'id': '1', 'name': 'a', 'poster': 'javascript:alert(1)', 'iconUrl': '//ali2.a.yximgs.com/i.png'},
          ]),
        ),
        categoryId: '1',
        categoryName: '游戏',
      );
      expect(areas.single.iconUrl, 'https://ali2.a.yximgs.com/i.png');
      expect(hasMore, isFalse, reason: 'the answer never said hasMore');
    });

    test('an empty page is never "more", and only three values are true', () {
      expect(
        KuaishouRoomParser.areas(_api(_listData([], hasMore: true)), categoryId: '1', categoryName: '游戏').hasMore,
        isFalse,
      );
      for (final (value, more) in [('TRUE', true), ('true', true), (1, true), ('1', false), (2, false)]) {
        expect(
          KuaishouRoomParser.areas(
            _api(
              _listData([
                {'id': '1'},
              ], hasMore: value),
            ),
            categoryId: '1',
            categoryName: '游戏',
          ).hasMore,
          more,
          reason: '$value',
        );
      }
    });
  });

  group('a list card', () {
    test('an area page: live, with the count the card wrote', () {
      final (:rooms, :hasMore, :cursor) = KuaishouRoomParser.areaRooms(
        _api(
          _listData(
            [
              _cardRow(),
              _cardRow({
                'author': {'id': 'other'},
              }),
              {'caption': '没有作者'},
              {'author': <String, Object?>{}},
            ],
            hasMore: 'true',
            cursor: 42,
          ),
        ),
      );
      expect(rooms.map((room) => room.roomId), [_user, 'other']);
      expect(hasMore, isTrue);
      expect(cursor, '42', reason: 'the non-gameboard cursor comes back as text');
      final room = rooms.first;
      expect(room.content.title, '在播');
      expect(room.content.introduction, isNull, reason: 'an area card keeps no bio');
      expect(room.content.notice, isNull);
      expect(room.anchor?.name, '主播');
      expect(room.anchor?.avatarUrl, 'https://ali2.a.yximgs.com/avatar.jpg');
      expect(room.anchor?.anchorId, _user);
      expect(room.area?.areaName, '王者荣耀');
      expect(room.audience.onlineViewers, 12000);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, _startedAt);
      expect(room.broadcast.restriction, isNull, reason: 'a card with no stream says nothing');
      expect(room.links.webUrl, KuaishouEndpoints.roomPageUrl(_user));
    });

    test("the start accepts the platform's own misspelling, and only milliseconds", () {
      expect(_areaCard({'startTime': 1730000000000}).broadcast.startedAt, _startedAt);
      expect(_areaCard({'statrtTime': 1730000000}).broadcast.startedAt, isNull, reason: 'seconds are not ms');
      expect(_areaCard({'statrtTime': 0}).broadcast.startedAt, isNull);
      expect(_areaCard({'statrtTime': '1730000000000'}).broadcast.startedAt, _startedAt);
      expect(_areaCard({'statrtTime': -5}).broadcast.startedAt, isNull);
      expect(_areaCard({'statrtTime': null, 'startTime': 1730000000000}).broadcast.startedAt, _startedAt);
    });

    test('the count text, and no number is no count', () {
      expect(_areaCard({'watchingCount': '1,234'}).audience.onlineViewers, 1234);
      expect(_areaCard({'watchingCount': ''}).audience.onlineViewers, isNull);
      expect(_areaCard({'watchingCount': null}).audience.onlineViewers, isNull);
      expect(_areaCard({'watchingCount': 0}).audience.onlineViewers, 0);
      expect(
        _areaCard({'watchingCount': 0}).audience.primaryMetric,
        LiveAudienceMetricType.onlineViewers,
        reason: "the metric is the card's kind, whatever the figure says",
      );
    });

    test('a playable card says it may be watched', () {
      final room = _areaCard({'playUrls': _playUrls(level: 10, name: '蓝光')});
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(_areaCard({'playUrls': 'not a list'}).broadcast.restriction, isNull);
      expect(
        _areaCard({
          'playUrls': [_playUrls().first],
        }).broadcast.restriction,
        LiveRestriction.none,
      );
    });

    test('a cover without an image type gets .jpg, a query keeps it as written', () {
      for (final (raw, kept) in const [
        ('https://ali2.a.yximgs.com/x.png', 'https://ali2.a.yximgs.com/x.png'),
        ('https://ali2.a.yximgs.com/x.PICTURE', 'https://ali2.a.yximgs.com/x.PICTURE.jpg'),
        ('https://ali2.a.yximgs.com/x?a=1', 'https://ali2.a.yximgs.com/x?a=1'),
        ('https://ali2.a.yximgs.com/x#f', 'https://ali2.a.yximgs.com/x#f'),
        ('//ali2.a.yximgs.com/c', 'https://ali2.a.yximgs.com/c.jpg'),
        ('not a url', ''),
        ('', ''),
      ]) {
        expect(_areaCard({'poster': raw}).content.coverUrl, kept, reason: raw);
      }
    });
  });

  group('the recommended rooms', () {
    test('every group and label, one card per streamer, in server order', () {
      final rooms = KuaishouRoomParser.recommendRooms(
        _api(
          _listData([
            {
              'gameLiveInfo': [
                {
                  'liveInfo': [
                    _cardRow(),
                    _cardRow({
                      'author': {'id': 'other'},
                    }),
                  ],
                },
                {
                  'liveInfo': [
                    _cardRow({
                      'author': {'id': 'fourth'},
                    }),
                  ],
                },
              ],
            },
            {
              'gameLiveInfo': [
                {
                  'liveInfo': {'caption': 'liveInfo 不是列表'},
                },
                {'liveInfo': '不是列表'},
              ],
            },
            {'gameLiveInfo': '不是列表'},
            '不是对象',
          ]),
        ),
      );
      expect(rooms.map((room) => room.roomId), [
        _user,
        'other',
        'fourth',
      ], reason: 'a liveInfo that is a map rather than a list yields nothing');
      expect(KuaishouRoomParser.recommendRooms(_api(_listData([]))), isEmpty);
    });

    test('a recommendation puts the bio in its place', () {
      final room = KuaishouRoomParser.recommendRooms(
        _api(
          _listData([
            {
              'gameLiveInfo': [
                {
                  'liveInfo': [
                    _cardRow({'caption': ''}),
                  ],
                },
              ],
            },
          ]),
        ),
      ).single;
      expect(room.content.title, '个性 签名', reason: 'no caption: the flattened bio stands in for it');
      expect(room.content.introduction, '个性 签名');
      expect(room.content.notice, '个性\n签名', reason: 'the notice keeps the line break');
      final captioned = KuaishouRoomParser.recommendRooms(
        _api(
          _listData([
            {
              'gameLiveInfo': [
                {
                  'liveInfo': [
                    _cardRow({'caption': '有标题'}),
                  ],
                },
              ],
            },
          ]),
        ),
      ).single;
      expect(captioned.content.title, '有标题');
      expect(captioned.content.introduction, '个性 签名');
      final noBio = KuaishouRoomParser.recommendRooms(
        _api(
          _listData([
            {
              'gameLiveInfo': [
                {
                  'liveInfo': [
                    _cardRow({
                      'caption': '',
                      'author': _author({'description': null}),
                    }),
                  ],
                },
              ],
            },
          ]),
        ),
      ).single;
      expect(noBio.content.title, isEmpty);
      expect(noBio.content.introduction, isEmpty);
      expect(noBio.content.notice, isNull);
    });
  });

  group('the searched streamers', () {
    test('a row without an id is dropped; the name is both title and cover', () {
      final rooms = KuaishouRoomParser.searchRooms(
        _api(
          _listData([
            _author(),
            {'name': '没有 id'},
            _author({'id': 'other', 'living': true}),
          ]),
        ),
      );
      expect(rooms.map((room) => room.roomId), [_user, 'other']);
      final room = rooms.first;
      expect(room.content.title, '主播');
      expect(room.content.coverUrl, 'https://ali2.a.yximgs.com/avatar.jpg', reason: 'a streamer has no cover');
      expect(room.content.introduction, '个性\n签名', reason: 'a search row keeps its bio unflattened');
      expect(room.anchor?.followerCount, 12000);
      expect(room.anchor?.liveStatus, LiveStatus.offline);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.links.webUrl, KuaishouEndpoints.roomPageUrl(_user));
      expect(rooms.last.anchor?.liveStatus, LiveStatus.live);
    });

    test('a banned author is banned, whatever the living flag says', () {
      final rooms = KuaishouRoomParser.searchRooms(
        _api(
          _listData([
            _author({
              'bannedStatus': {'banned': true},
              'living': true,
            }),
          ]),
        ),
      );
      expect(rooms.single.anchor?.liveStatus, LiveStatus.banned);
      expect(rooms.single.broadcast.liveStatus, LiveStatus.banned);
      expect(
        KuaishouRoomParser.searchRooms(
          _api(
            _listData([
              _author({
                'bannedStatus': {'banned': 'true'},
              }),
            ]),
          ),
        ).single.anchor?.liveStatus,
        LiveStatus.offline,
        reason: 'the ban flag must really be true',
      );
    });

    test('no fan count is no follower number, and a searched row carries no area', () {
      final room = KuaishouRoomParser.searchRooms(
        _api(
          _listData([
            _author({'counts': {}, 'description': null}),
          ]),
        ),
      ).single;
      expect(room.anchor?.followerCount, isNull);
      expect(room.content.introduction, isNull);
      expect(room.area, isNull);
      expect(room.audience.primaryMetric, isNull);
    });
  });

  group('the room page', () {
    test('the state marker, and the words of a verification page', () {
      expect(_detail(_room()).room.roomId, _user);
      expect(
        _failure(() => KuaishouRoomParser.initialState('<html><p>请输入验证码</p></html>')).kind,
        KuaishouFailureKind.riskControl,
      );
      expect(
        _failure(() => KuaishouRoomParser.initialState('<html>nothing</html>')).message,
        'room page: no __INITIAL_STATE__',
      );
      expect(
        _failure(() => KuaishouRoomParser.initialState('window.__INITIAL_STATE__ = {"a": 1')).message,
        'room page: __INITIAL_STATE__ is not a complete object',
      );
      expect(
        _failure(() => KuaishouRoomParser.initialState('window.__INITIAL_STATE__ = undefined')).message,
        'room page: __INITIAL_STATE__ is not a complete object',
        reason: 'the cut starts at a brace, so anything else never even began',
      );
      expect(
        _failure(() => KuaishouRoomParser.initialState('window.__INITIAL_STATE__ = {"a": 1,};')).message,
        'room page: __INITIAL_STATE__ is not a JSON object',
        reason: 'a trailing comma is JavaScript, not JSON',
      );
      expect(KuaishouRoomParser.initialState('window.__INITIAL_STATE__={"a":undefined};'), {'a': null});
      expect(KuaishouRoomParser.initialState('window.__INITIAL_STATE__ = {"a": "x;undefined", "b": undefined};'), {
        'a': 'x;undefined',
        'b': null,
      }, reason: 'a semicolon or the word inside a string does not end or change the object');
      expect(KuaishouRoomParser.initialState('window.__INITIAL_STATE__ = {"a": "notundefined"};'), {
        'a': 'notundefined',
      });
      expect(KuaishouRoomParser.initialState('window.__INITIAL_STATE__ = {"a": 1} // trailing'), {'a': 1});
    });

    test('a captcha redirect and the status gate come first', () {
      expect(
        _failure(() => _detail(_room(), url: Uri.parse('https://kuaishou.com/captcha/verify'))).message,
        contains('room page redirected to kuaishou.com/captcha/verify'),
      );
      expect(
        _kindOf(
          () =>
              KuaishouRoomParser.roomDetail(_page(_state(_room())), requestedId: _user, status: 403, userCookie: true),
        ),
        KuaishouFailureKind.riskControl,
      );
    });

    test('errorType 22 is no such room, anything else is the gate', () {
      expect(_failure(() => _detail(_room({'errorType': 22}))).message, 'errorType 22');
      expect(_kindOf(() => _detail(_room({'errorType': 5}))), KuaishouFailureKind.riskControl);
      expect(
        _failure(
          () => _detail(
            _room({
              'errorType': {'type': 22, 'title': '用户不存在'},
            }),
          ),
        ).message,
        'errorType 22 用户不存在',
      );
      expect(
        _failure(
          () => _detail(
            _room({
              'errorType': {'title': '没有类型'},
            }),
          ),
        ).message,
        'errorType null 没有类型',
      );
      expect(_detail(_room({'errorType': null})).room.broadcast.liveStatus, LiveStatus.live);
    });

    test('no playList is the page changing shape', () {
      expect(
        _failure(() => KuaishouRoomParser.roomDetail(_page({'liveroom': {}}), requestedId: _user)).message,
        'room page: liveroom.playList[0] missing',
      );
      expect(
        _kindOf(
          () => KuaishouRoomParser.roomDetail(
            _page({
              'liveroom': {'playList': <Object?>[]},
            }),
            requestedId: _user,
          ),
        ),
        KuaishouFailureKind.apiChanged,
      );
    });

    test('the room the page says, keyed by the id the caller asked for', () {
      final parse = _detail(
        _room({
          'liveStream': {'id': 'live_stream_1', 'poster': 'https://ali2.a.yximgs.com/cover', 'playUrls': _pageUrls()},
        }),
      );
      expect(parse.room.roomId, _user);
      expect(parse.room.content.title, isEmpty, reason: 'the page carries no broadcast title');
      expect(parse.room.content.coverUrl, 'https://ali2.a.yximgs.com/cover.jpg');
      expect(parse.room.content.introduction, '个性\n签名');
      expect(parse.room.content.notice, '个性\n签名', reason: 'the bio is both the introduction and the notice');
      expect(parse.room.anchor?.anchorId, _user);
      expect(parse.room.anchor?.followerCount, 12000);
      expect(parse.room.anchor?.liveStatus, isNull, reason: 'the page writes its state on the broadcast only');
      expect(parse.room.area?.areaName, '王者荣耀');
      expect(parse.room.audience.onlineViewers, isNull, reason: 'the page has no audience figure');
      expect(parse.room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(parse.room.broadcast.liveStatus, LiveStatus.live);
      expect(parse.room.broadcast.restriction, LiveRestriction.none);
      expect(parse.liveStreamId, 'live_stream_1', reason: 'the comment feed keys on it');
      expect(KuaishouPlayParser.qualities(parse.playUrls).map((quality) => quality.label), ['蓝光']);
      expect(parse.emotes, isEmpty);
    });

    test('the room keeps its page identity, the link its asked-for id', () {
      expect(
        _detail(
          _room({
            'author': {'id': 'another'},
          }),
          requestedId: ' asked_id ',
        ).room.roomId,
        'asked_id',
      );
      expect(_detail(_room(), requestedId: 'asked_id').room.links.webUrl, KuaishouEndpoints.roomPageUrl('asked_id'));
    });

    test('living without a playable stream is unplayable, offline says nothing', () {
      expect(_detail(_room()).room.broadcast.restriction, LiveRestriction.unplayable);
      expect(_detail(_room({'isLiving': 'true'})).room.broadcast.liveStatus, LiveStatus.live);
      expect(_detail(_room({'isLiving': '1'})).room.broadcast.liveStatus, LiveStatus.offline);
      final offline = _detail(
        _room({
          'isLiving': false,
          'liveStream': {'playUrls': _pageUrls()},
        }),
      ).room;
      expect(offline.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.broadcast.restriction, isNull, reason: 'the unified rule: offline carries no restriction');
      expect(offline.anchor?.liveStatus, isNull);
    });

    test('the stream fields may simply not be there', () {
      final parse = _detail(_room({'liveStream': null, 'isLiving': 1}));
      expect(parse.liveStreamId, isNull);
      expect(parse.playUrls, isNull);
      expect(parse.room.broadcast.restriction, LiveRestriction.unplayable);
      expect(parse.room.content.coverUrl, isEmpty);
    });

    test('the emoji table: bracketed codes with an address, https-ified', () {
      final table = KuaishouRoomParser.emojiTable(
        KuaishouRoomParser.initialState(
          _page(
            _state(
              _room(),
              emojiPanel: {
                '[笑哭]': '//ali2.a.yximgs.com/bs2/emotion/a.png',
                '没有括号': '//ali2.a.yximgs.com/bs2/emotion/b.png',
                '[]': '//ali2.a.yximgs.com/bs2/emotion/c.png',
                '[没图]': '',
                '[坏]': 'javascript:alert(1)',
                '[数字]': 7,
              },
            ),
          ),
        ),
      );
      expect(table, {'[笑哭]': 'https://ali2.a.yximgs.com/bs2/emotion/a.png'});
      expect(KuaishouRoomParser.emojiTable(const {}), isEmpty);
    });
  });

  group('the session', () {
    test('the five cookies a bare visit keeps, out of the joined header', () {
      expect(
        KuaishouRoomParser.sessionCookies({
          'Set-Cookie': 'kuaishou.live.bfb1s=abc; clientid=3; did=web_abc; client_key=def; kpn=GAME_LIVE; other=drop',
        }),
        {'kuaishou.live.bfb1s': 'abc', 'clientid': '3', 'did': 'web_abc', 'client_key': 'def', 'kpn': 'GAME_LIVE'},
        reason: 'names the site does not use for the session are left out',
      );
      expect(KuaishouRoomParser.sessionCookies({}), isEmpty);
      expect(KuaishouRoomParser.sessionCookies({'set-cookie': 'did=; kpn=X'}), {'kpn': 'X'});
      expect(KuaishouRoomParser.sessionCookies({'Set-Cookie': 'did=a, kpn=B'}), {
        'did': 'a',
        'kpn': 'B',
      }, reason: 'the transport joins repeated headers with a comma');
      expect(KuaishouRoomParser.sessionCookies({'set-cookie': ''}), isEmpty, reason: 'an empty header is no header');
    });

    test('the device report imitates the web client', () {
      final payload = KuaishouRoomParser.devicePayload('web_abc', timestamp: 1730000000, incrementId: 7);
      final common = payload['common']! as Map<String, Object?>;
      expect((common['identity_package']! as Map)['device_id'], 'web_abc');
      expect((common['app_package']! as Map)['product_name'], 'KS_GAME_LIVE_PC');
      expect(common['need_encrypt'], 'false');
      final log = (payload['logs']! as List).single! as Map<String, Object?>;
      expect(log['client_timestamp'], 1730000000);
      expect(log['client_increment_id'], 7);
      expect(log['time_zone'], 'GMT+08:00');
      expect(log['session_id'], isA<String>());
      expect((log['event_package']! as Map)['task_event']! as Map, isNot(isEmpty));
    });
  });
}
