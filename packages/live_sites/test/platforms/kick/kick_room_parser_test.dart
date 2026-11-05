import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_json.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_room_parser.dart';
import 'package:test/test.dart';

/// A channel of Kick, in the case Kick answers it.
const String _slug = 'XqcIsOnline';

/// The same slug as the room id: lower-cased.
const String _room = 'xqcisonline';

/// The signed master a live channel answers with.
const String _masterUrl = 'https://ab12cd.live-video.net/playlist/master.m3u8?token=t';

String _body(Map<String, Object?> value) => jsonEncode(value);

Map<String, dynamic> _map(Map<String, Object?> value) => jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

Map<String, Object?> _user([Map<String, Object?>? override]) => {
  'username': 'xQc',
  'bio': 'streamer',
  'profile_pic': '//cdn.kick.com/avatar.png',
  ...?override,
};

Map<String, Object?> _category(String slug, String name, [Map<String, Object?>? override]) => {
  'slug': slug,
  'name': name,
  ...?override,
};

Map<String, Object?> _liveStream([Map<String, Object?>? override]) => {
  'is_live': true,
  'session_title': '深夜聊天',
  'viewer_count': 42000,
  'start_time': '2026-09-30 19:24:14',
  'is_mature': false,
  'thumbnail': {'url': '//cdn.kick.com/thumb.jpg'},
  'categories': [_category('just-chatting', 'Just Chatting')],
  ...?override,
};

Map<String, Object?> _channelJson({
  bool live = true,
  Map<String, Object?>? livestream,
  Map<String, Object?>? override,
}) => {
  'id': 101691,
  'slug': _slug,
  'user': _user(),
  'followers_count': '91000',
  'is_banned': false,
  'chatroom': {'id': 101689},
  'playback_url': live ? _masterUrl : '?token=t',
  'livestream': live ? _liveStream(livestream) : livestream,
  'offline_banner_image': {'src': '//cdn.kick.com/offline.jpg'},
  ...?override,
};

Map<String, Object?> _listRow([Map<String, Object?>? override]) => {
  'channel': {'id': 101691, 'slug': _slug, 'is_banned': false, 'user': _user()},
  'is_live': true,
  'session_title': '深夜聊天',
  'viewer_count': 1000,
  'show_view_count': true,
  'is_mature': false,
  'thumbnail': {'src': '//cdn.kick.com/thumb.jpg'},
  'start_time': '2026-09-30 19:24:14',
  'categories': [_category('just-chatting', 'Just Chatting')],
  ...?override,
};

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on KickFailure catch (failure) {
    return failure.kind;
  }
}

KickFailure _failure(void Function() read) {
  try {
    read();
  } on KickFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the status gate', () {
    test('the table', () {
      expect(_kindOf(() => KickRoomParser.checkStatus(204, 'ok', 'x')), isNull);
      expect(
        {
          for (final status in [401, 403, 404, 429, 500, 302])
            status: _kindOf(() => KickRoomParser.checkStatus(status, 'x', 'what')),
        },
        {
          401: KickFailureKind.riskControl,
          403: KickFailureKind.riskControl,
          404: KickFailureKind.notFound,
          429: KickFailureKind.rateLimited,
          500: KickFailureKind.network,
          302: KickFailureKind.apiChanged,
        },
      );
      expect(_failure(() => KickRoomParser.checkStatus(403, 'plain', 'what')).message, 'what: HTTP 403');
      expect(
        _failure(() => KickRoomParser.checkStatus(403, 'blocked by the security policy', 'what')).message,
        'what: Cloudflare refused this client (Kick needs a browser TLS stack)',
      );
      expect(_failure(() => KickRoomParser.checkStatus(418, 'x', 'what')).message, 'what: HTTP 418 (x)');
    });

    test('a body over four megabytes is not even decoded', () {
      expect(decodeJson('{"a":${'1' * (maxJsonBytes + 1)}}'), isNull);
      expect(decodeJson('not json'), isNull);
      expect(decodeJson('{"a":1}'), {'a': 1});
    });

    test('the readers', () {
      expect(jsonInt(7), 7);
      expect(jsonInt(7.0), 7);
      expect(jsonInt(7.5), isNull);
      expect(jsonInt(' 7 '), 7);
      expect(jsonInt('7.5'), isNull);
      expect(jsonCount(0), 0, reason: 'a live room with nobody reads as zero, not unknown');
      expect(jsonCount(-1), isNull);
      expect(jsonCount('12'), 12);
      expect(jsonString('  a  '), 'a');
      expect(jsonString('   '), isNull);
      expect(jsonString(7), '7');
      expect(jsonString(null), isNull);
      expect(jsonDouble('1.5'), 1.5);
      expect(jsonDouble(true), isNull);
      expect(jsonList('not a list'), isEmpty);
      expect(jsonObject('{"a":1}'), isNull, reason: 'jsonObject never decodes text');
      expect(jsonOrText('{"a":1}'), {'a': 1}, reason: 'a Pusher payload is JSON inside a string');
      expect(jsonSnippet('{"a": ${'1' * 200}}'), endsWith('…'));
    });

    test('a Kick time, with or without its offset', () {
      expect(jsonTime('2026-09-30 19:24:14'), DateTime.utc(2026, 9, 30, 19, 24, 14));
      expect(jsonTime('2026-09-30T19:24:14Z'), DateTime.utc(2026, 9, 30, 19, 24, 14));
      expect(
        jsonTime('2026-09-30T19:24:14.500Z'),
        DateTime.utc(2026, 9, 30, 19, 24, 14),
        reason: 'the fractional seconds are matched but never read',
      );
      expect(jsonTime('2026-09-30T19:24:14+08:00'), DateTime.utc(2026, 9, 30, 11, 24, 14));
      expect(jsonTime('2026-09-30T05:00:00-0530'), DateTime.utc(2026, 9, 30, 10, 30));
      expect(
        jsonTime('2026-09-30T19:24:14-0530'),
        isNull,
        reason: 'an offset that rolls the day over fails the date check',
      );
      expect(jsonTime('2026-02-30 00:00:00'), isNull, reason: 'the 30th of February is not a date');
      expect(jsonTime('2000-01-01 00:00:00'), isNull, reason: 'nothing before 2001 is a broadcast');
      expect(jsonTime('tomorrow'), isNull);
      expect(jsonTime(null), isNull);
      expect(jsonMessageTime(1730000000), DateTime.fromMillisecondsSinceEpoch(1730000000 * 1000));
      expect(jsonMessageTime(0), isNull);
    });
  });

  group('the channel answer', () {
    test('a live channel, its chatroom and its signed master', () {
      final found = KickRoomParser.channel(_body(_channelJson()), requestedSlug: _room);
      expect(found.channelId, 101691);
      expect(found.chatroomId, 101689, reason: 'the chatroom id is read, never guessed from the channel id');
      expect(found.master.toString(), _masterUrl);
      final room = found.room;
      expect(room.roomId, _room);
      expect(room.content.title, '深夜聊天');
      expect(room.content.coverUrl, 'https://cdn.kick.com/thumb.jpg');
      expect(room.content.introduction, 'streamer');
      expect(room.content.notice, isEmpty);
      expect(room.anchor?.anchorId, '101691');
      expect(room.anchor?.name, 'xQc');
      expect(room.anchor?.avatarUrl, 'https://cdn.kick.com/avatar.png');
      expect(room.anchor?.profileUrl, KickEndpoints.roomPageUrl(_room));
      expect(room.anchor?.followerCount, 91000);
      expect(room.anchor?.introduction, 'streamer');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.area?.areaId, 'just-chatting');
      expect(room.area?.areaName, 'Just Chatting');
      expect(room.audience.onlineViewers, 42000);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 30, 19, 24, 14));
      expect(room.links.webUrl, KickEndpoints.roomPageUrl(_room));
      expect(found.toString(), 'KickChannel($_room, chatroom 101689, channel 101691)');
    });

    test('the slug asked for is matched in any case', () {
      expect(KickRoomParser.channel(_body(_channelJson()), requestedSlug: '  XQCISONLINE ').room.roomId, _room);
      expect(
        _failure(() => KickRoomParser.channel(_body(_channelJson()), requestedSlug: 'someoneelse')).message,
        'channel: asked for "someoneelse", answered "$_room"',
      );
      expect(
        _kindOf(
          () => KickRoomParser.channel(_body(_channelJson(override: {'slug': 'browse'})), requestedSlug: 'browse'),
        ),
        KickFailureKind.apiChanged,
        reason: 'a reserved page owns no channel',
      );
    });

    test('a banned channel is banned, whatever its livestream says', () {
      final found = KickRoomParser.channel(
        _body(_channelJson(live: false, override: {'is_banned': true, 'livestream': _liveStream()})),
        requestedSlug: _room,
      );
      expect(found.room.anchor?.liveStatus, LiveStatus.banned);
      expect(found.room.broadcast.liveStatus, LiveStatus.banned);
      expect(found.room.audience.onlineViewers, isNull);
      expect(found.master, isNull);
      expect(found.room.content.title, isEmpty);
      expect(found.room.area, isNull);
      expect(found.room.broadcast.startedAt, isNull);
    });

    test('an offline channel answers the banner, not a thumbnail', () {
      final found = KickRoomParser.channel(
        _body(
          _channelJson(
            live: false,
            override: {
              'banner_image': {'url': '//cdn.kick.com/banner.jpg'},
            },
          ),
        ),
        requestedSlug: _room,
      );
      expect(found.room.broadcast.liveStatus, LiveStatus.offline);
      expect(found.room.content.coverUrl, 'https://cdn.kick.com/offline.jpg');
      expect(found.room.area, isNull, reason: 'offline has no category to name');
      expect(found.master, isNull, reason: 'the offline answer carries only a token');
      expect(found.chatroomId, 101689);
    });

    test('a livestream thumbnail that is no picture leaves the cover empty', () {
      final found = KickRoomParser.channel(
        _body(
          _channelJson(
            livestream: {
              'thumbnail': {'src': 'javascript:alert(1)'},
            },
          ),
        ),
        requestedSlug: _room,
      );
      expect(found.room.content.coverUrl, isEmpty);
      expect(found.room.audience.onlineViewers, 42000);
    });

    test('a mature live channel says so in the notice', () {
      expect(
        KickRoomParser.channel(
          _body(_channelJson(livestream: {'is_mature': true})),
          requestedSlug: _room,
        ).room.content.notice,
        KickEndpoints.matureNotice,
      );
      expect(
        KickRoomParser.channel(
          _body(_channelJson(live: false, override: {'is_mature': true})),
          requestedSlug: _room,
        ).room.content.notice,
        isEmpty,
        reason: 'the mature flag only means something on a livestream',
      );
    });

    test('a broken channel answer is api-changed, a gone one is not-found', () {
      expect(
        _failure(() => KickRoomParser.channel('{}', requestedSlug: _room, status: 404)).message,
        'no channel "$_room"',
      );
      expect(_kindOf(() => KickRoomParser.channel('{}', requestedSlug: _room)), KickFailureKind.apiChanged);
      for (final bad in [
        _channelJson(override: {'slug': null}),
        _channelJson(override: {'slug': ''}),
        _channelJson(override: {'id': 0}),
        _channelJson(override: {'id': null}),
        _channelJson(override: {'user': 'not an object'}),
        _channelJson(override: {'user': null}),
      ]) {
        expect(
          _kindOf(() => KickRoomParser.channel(_body(bad), requestedSlug: _room)),
          KickFailureKind.apiChanged,
          reason: '$bad',
        );
      }
      expect(
        _failure(() => KickRoomParser.channel('nope', requestedSlug: _room)).message,
        contains('channel: no slug'),
      );
      expect(
        _kindOf(() => KickRoomParser.channel(_body(_channelJson()), requestedSlug: _room, status: 429)),
        KickFailureKind.rateLimited,
        reason: 'the status is asked before the body',
      );
    });

    test('the chatroom id may be missing or zero, and the times may be unreadable', () {
      expect(
        KickRoomParser.channel(_body(_channelJson(override: {'chatroom': null})), requestedSlug: _room).chatroomId,
        isNull,
      );
      expect(
        KickRoomParser.channel(
          _body(
            _channelJson(
              override: {
                'chatroom': {'id': 0},
              },
              livestream: {'start_time': 'later'},
            ),
          ),
          requestedSlug: _room,
        ).room.broadcast.startedAt,
        isNull,
      );
      expect(
        KickRoomParser.channel(
          _body(_channelJson(livestream: {'viewer_count': null})),
          requestedSlug: _room,
        ).room.audience.onlineViewers,
        isNull,
      );
    });
  });

  group('the categories', () {
    test("the top-level list keeps Kick's order and names six in Chinese", () {
      final found = KickRoomParser.mainCategories(
        jsonEncode([
          _category('Games', 'Games'),
          _category('irl', 'IRL'),
          _category('music', 'Music'),
          _category('gambling', 'Gambling'),
          _category('poker', 'Poker'),
          _category('irl', 'IRL again'),
          _category('not a slug!', 'Bad'),
          _category('empty', ''),
          'not an object',
        ]),
      );
      expect(found, [
        (slug: 'games', name: '游戏'),
        (slug: 'irl', name: '生活'),
        (slug: 'music', name: '音乐'),
        (slug: 'gambling', name: '博彩'),
        (slug: 'poker', name: 'Poker'),
      ], reason: "a known category is renamed, an unknown one keeps Kick's own");
    });

    test('a categories answer that is not a list, is too long, or names nothing', () {
      expect(_kindOf(() => KickRoomParser.mainCategories('{"data":[]}')), KickFailureKind.apiChanged);
      expect(
        _kindOf(
          () => KickRoomParser.mainCategories(jsonEncode(List.generate(65, (index) => _category('c$index', 'N')))),
        ),
        KickFailureKind.apiChanged,
      );
      expect(_failure(() => KickRoomParser.mainCategories('[]')).message, contains('categories: no usable category'));
      expect(_failure(() => KickRoomParser.mainCategories('x', status: 500)).message, 'categories: HTTP 500');
    });

    test("the subcategories of one parent, in Kick's order", () {
      const parent = (slug: 'games', name: '游戏');
      final areas = KickRoomParser.subcategories(
        _body({
          'data': [
            _category('League+Of+Legends', 'League of Legends', {
              'category': {'slug': 'Games'},
              'banner': {'url': '//cdn.kick.com/banner.png'},
            }),
            _category('dota2', 'Dota 2', {
              'category': {'slug': 'games'},
            }),
            _category('valorant', 'Valorant', {
              'category': {'slug': 'creative'},
            }),
            _category('games', 'No Name', {'name': ''}),
            {'slug': 'no-name'},
            _category('dota2', 'Dota 2 again'),
          ],
        }),
        parent: parent,
      );
      expect(areas.map((area) => area.areaId), ['League+Of+Legends', 'dota2']);
      expect(areas.first.areaName, 'League of Legends');
      expect(areas.first.iconUrl, 'https://cdn.kick.com/banner.png');
      expect(areas.first.parentAreaId, 'games');
      expect(areas.first.parentAreaName, '游戏');
    });

    test('a row that names no category is kept, one of another category is not', () {
      const parent = (slug: 'games', name: '游戏');
      expect(
        KickRoomParser.subcategories(
          _body({
            'data': [_category('x', 'X')],
          }),
          parent: parent,
        ).single.areaId,
        'x',
        reason: 'a row that names no category is not refused',
      );
      expect(KickRoomParser.subcategories(_body({'data': <Object?>[]}), parent: parent), isEmpty);
      expect(
        _kindOf(
          () => KickRoomParser.subcategories(
            _body({
              'data': [
                _category('y', 'Y', {
                  'category': {'slug': 'irl'},
                }),
              ],
            }),
            parent: parent,
          ),
        ),
        KickFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => KickRoomParser.subcategories(
            _body({
              'data': {'a': 1},
            }),
            parent: parent,
          ),
        ),
        KickFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => KickRoomParser.subcategories(
            _body({'data': List.generate(101, (index) => _category('c$index', 'N'))}),
            parent: parent,
          ),
        ),
        KickFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => KickRoomParser.subcategories(_body({'data': _category('x', 'X')}), parent: parent)),
        KickFailureKind.apiChanged,
      );
    });
  });

  group('the live directory', () {
    String page(List<Object?> rows, {Object? current = 1, Object? next = 'https://api.kick.com/x?page=2'}) =>
        _body({'current_page': current, 'next_page_url': next, 'data': rows});

    test('the cards of a matching page', () {
      final (:rooms, :hasMore) = KickRoomParser.directoryPage(page([_listRow()]), page: 1, pageSize: 30);
      expect(rooms.single.roomId, _room);
      expect(hasMore, isTrue);
      expect(KickRoomParser.directoryPage(page([_listRow()], next: null), page: 1, pageSize: 30).hasMore, isFalse);
      expect(
        KickRoomParser.directoryPage(page([], next: 'https://api.kick.com/x?page=3'), page: 1, pageSize: 30).hasMore,
        isFalse,
        reason: 'an empty page ends the walk whatever the link says',
      );
    });

    test('the page must echo what was asked', () {
      expect(
        _failure(() => KickRoomParser.directoryPage(page([_listRow()], current: 3), page: 2, pageSize: 30)).message,
        contains('livestreams: not page 2'),
      );
      expect(
        _kindOf(() => KickRoomParser.directoryPage(page([_listRow()], current: null), page: 1, pageSize: 30)),
        KickFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => KickRoomParser.directoryPage(
            page(
              List.generate(
                61,
                (index) => _listRow({
                  'channel': {'id': index + 1, 'slug': 'c$index'},
                }),
              ),
            ),
            page: 1,
            pageSize: 30,
          ),
        ),
        KickFailureKind.apiChanged,
        reason: 'an answer of more than double the page size is not this page',
      );
      expect(_kindOf(() => KickRoomParser.directoryPage('{}', page: 1, pageSize: 30)), KickFailureKind.apiChanged);
    });

    test('a filter Kick does not know answers the whole directory, and fails as not-found', () {
      final (:rooms, :hasMore) = KickRoomParser.directoryPage(
        page([
          _listRow(),
          _listRow({
            'categories': [_category('poker', 'Poker')],
          }),
        ]),
        page: 1,
        pageSize: 30,
        subcategory: 'JUST-CHATTING',
      );
      expect(rooms.map((room) => room.roomId), [_room]);
      expect(hasMore, isTrue);
      expect(
        _failure(
          () => KickRoomParser.directoryPage(
            page([
              _listRow({'is_live': false}),
              _listRow({
                'categories': [_category('poker', 'Poker')],
              }),
            ]),
            page: 1,
            pageSize: 30,
            subcategory: 'chess',
          ),
        ).message,
        'livestreams: no subcategory "chess"',
      );
    });

    test('a page whose rows are all unreadable is api-changed, never an empty page', () {
      expect(
        _failure(
          () => KickRoomParser.directoryPage(
            page([
              {'no': 'channel'},
              'not an object',
            ]),
            page: 1,
            pageSize: 30,
          ),
        ).message,
        contains('livestreams: no usable row'),
      );
      expect(
        KickRoomParser.directoryPage(_body({'current_page': 1, 'data': <Object?>[]}), page: 1, pageSize: 30).rooms,
        isEmpty,
      );
    });
  });

  group('a list card', () {
    test('the row as a live room', () {
      final room = KickRoomParser.listCard(_map(_listRow()))!;
      expect(room.roomId, _room);
      expect(room.content.title, '深夜聊天');
      expect(room.content.coverUrl, 'https://cdn.kick.com/thumb.jpg');
      expect(room.anchor?.anchorId, '101691');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.audience.onlineViewers, 1000);
      expect(room.area?.areaName, 'Just Chatting');
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 30, 19, 24, 14));
      expect(room.links.webUrl, KickEndpoints.roomPageUrl(_room));
    });

    test('no card without a channel, a slug, an id, or when banned or not live', () {
      expect(KickRoomParser.listCard(_map(_listRow())), isNotNull);
      expect(KickRoomParser.listCard(_map(_listRow()..remove('channel'))), isNull);
      expect(
        KickRoomParser.listCard(
          _map(
            _listRow({
              'channel': {'id': 1},
            }),
          ),
        ),
        isNull,
        reason: 'no slug',
      );
      expect(
        KickRoomParser.listCard(
          _map(
            _listRow({
              'channel': {'slug': 'x'},
            }),
          ),
        ),
        isNull,
        reason: 'no id',
      );
      expect(
        KickRoomParser.listCard(
          _map(
            _listRow({
              'channel': {'slug': 'x', 'id': 1, 'is_banned': true},
            }),
          ),
        ),
        isNull,
        reason: 'a banned channel is not listed',
      );
      expect(
        KickRoomParser.listCard(
          _map({
            'channel': {'slug': 'x', 'id': 1},
            'is_live': false,
          }),
        ),
        isNull,
      );
      expect(
        KickRoomParser.listCard(
          _map({
            'channel': {'slug': 'x', 'id': 1},
          }),
        )!.broadcast.liveStatus,
        LiveStatus.live,
        reason: 'a row that does not say is_live is still a live row',
      );
      expect(
        KickRoomParser.listCard(
          _map({
            'channel': {'slug': 'browse', 'id': 1},
          }),
        ),
        isNull,
        reason: 'a reserved page owns no channel',
      );
    });

    test('the id may ride on the row, the count may be hidden, and both spellings are read', () {
      final room = KickRoomParser.listCard(
        _map({
          'channel': {'slug': 'xqc'},
          'channel_id': 55,
          'viewers': 12,
          'show_view_count': true,
          'thumbnail': {'url': '//cdn.kick.com/u.jpg'},
          'is_mature': true,
        }),
      )!;
      expect(room.anchor?.anchorId, '55');
      expect(room.anchor?.name, isEmpty);
      expect(room.anchor?.avatarUrl, isNull);
      expect(room.audience.onlineViewers, 12, reason: 'search rows write the count as `viewers`');
      expect(room.content.coverUrl, 'https://cdn.kick.com/u.jpg');
      expect(room.content.notice, KickEndpoints.matureNotice);
      expect(room.area, isNull);
      expect(room.broadcast.startedAt, isNull);
      expect(
        KickRoomParser.listCard(_map(_listRow({'show_view_count': false})))!.audience.onlineViewers,
        isNull,
        reason: 'a streamer who hides the count gets no number',
      );
    });
  });

  group('the search answer', () {
    String search(List<Object?> channels, {Object? livestreams}) =>
        _body({'channels': channels, 'livestreams': ?livestreams});

    test('the channels first, then the tagged broadcasts, a channel once', () {
      final rooms = KickRoomParser.searchRooms(
        search(
          [
            {
              'id': 1,
              'slug': 'Alpha',
              'user': _user({'username': 'a'}),
            },
            {'id': 1, 'slug': 'alpha', 'user': _user()},
            {'slug': 'no-id'},
            'not an object',
          ],
          livestreams: {
            'tags': [
              _listRow({
                'channel': {'id': 1, 'slug': 'alpha'},
              }),
              _listRow({
                'channel': {'id': 9, 'slug': 'Other'},
              }),
            ],
          },
        ),
      );
      expect(rooms.map((room) => room.roomId), ['alpha', 'other'], reason: 'a channel already listed is not repeated');
      expect(rooms.first.content.title, isEmpty, reason: 'a search channel answers no broadcast title');
      expect(rooms.first.content.coverUrl, isEmpty);
      expect(rooms.first.audience.onlineViewers, isNull);
      expect(rooms.first.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(rooms.last.anchor?.liveStatus, LiveStatus.live);
    });

    test('both spellings of the keys the search answers with', () {
      final camel = KickRoomParser.searchCard(
        _map({
          'id': 2,
          'slug': 'b',
          'isLive': true,
          'followersCount': 30,
          'user': _user({'profilePic': '//cdn.kick.com/p.png'}),
        }),
      )!;
      final snake = KickRoomParser.searchCard(_map({'id': 2, 'slug': 'b', 'is_live': true, 'followers_count': 30}))!;
      expect(camel.anchor?.followerCount, 30);
      expect(snake.anchor?.followerCount, 30);
      expect(camel.anchor?.liveStatus, LiveStatus.live);
      expect(snake.anchor?.liveStatus, LiveStatus.live);
      expect(camel.anchor?.avatarUrl, 'https://cdn.kick.com/p.png');
      expect(snake.anchor?.avatarUrl, isNull);
      expect(
        KickRoomParser.searchCard(_map({'id': 2, 'slug': 'b', 'is_banned': true, 'isLive': true}))!.anchor?.liveStatus,
        LiveStatus.banned,
      );
      expect(KickRoomParser.searchCard(_map({'slug': 'b'})), isNull);
      expect(KickRoomParser.searchCard(_map({'id': 2})), isNull);
    });

    test('the search envelope', () {
      expect(_kindOf(() => KickRoomParser.searchRooms('{}')), KickFailureKind.apiChanged);
      expect(
        _kindOf(
          () => KickRoomParser.searchRooms(
            _body({
              'channels': {'a': 1},
            }),
          ),
        ),
        KickFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => KickRoomParser.searchRooms(
            _body({
              'channels': List.generate(101, (index) => {'id': index + 1, 'slug': 'c$index'}),
            }),
          ),
        ),
        KickFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => KickRoomParser.searchRooms(
            _body({
              'channels': [
                {'id': 1, 'slug': 'a'},
              ],
              'livestreams': {'tags': 7},
            }),
          ),
        ),
        KickFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => KickRoomParser.searchRooms(
            _body({
              'channels': [
                {'slug': 'no-id'},
              ],
            }),
          ),
        ).message,
        contains('search: no usable channel'),
      );
      expect(KickRoomParser.searchRooms(_body({'channels': <Object?>[]})), isEmpty);
      expect(
        KickRoomParser.searchRooms(
          _body({
            'channels': <Object?>[],
            'livestreams': {
              'tags': List.generate(
                120,
                (index) => _listRow({
                  'channel': {'id': index + 1, 'slug': 'c$index'},
                }),
              ),
            },
          }),
        ),
        hasLength(100),
        reason: 'at most a hundred tagged rows are read',
      );
    });
  });

  group('the page link and the master', () {
    test('a kick.com page is a channel slug, lower-cased', () {
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://kick.com/xqc')), 'xqc');
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://www.kick.com/XQC/')), 'xqc');
      expect(KickRoomParser.slugFromUrl(Uri.parse('http://m.kick.com/xqc/videos')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://kick.com/browse')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://kick.com/?a=1')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://kick.com/xqc#f')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://someone@kick.com/xqc')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('https://twitch.tv/xqc')), isNull);
      expect(KickRoomParser.slugFromUrl(Uri.parse('ftp://kick.com/xqc')), isNull);
      expect(KickRoomParser.isKickHost('www.kick.com'), isTrue);
      expect(KickRoomParser.isKickHost('api.kick.com'), isFalse);
    });

    test('ivsMaster: only a signed https playlist on the IVS hosts', () {
      expect(KickRoomParser.ivsMaster(_masterUrl)?.host, 'ab12cd.live-video.net');
      expect(KickRoomParser.ivsMaster('https://user@ab12cd.live-video.net/master.m3u8'), isNull);
      expect(KickRoomParser.ivsMaster('http://ab12cd.live-video.net/master.m3u8'), isNull);
      expect(
        KickRoomParser.ivsMaster('https://live-video.net/master.m3u8'),
        isNull,
        reason: 'the bare host has no node',
      );
      expect(KickRoomParser.ivsMaster('?token=t'), isNull);
      expect(KickRoomParser.ivsMaster(''), isNull);
      expect(KickRoomParser.ivsMaster(null), isNull);
    });

    test('image: a picture or nothing', () {
      expect(KickRoomParser.image('//cdn.kick.com/a.png'), 'https://cdn.kick.com/a.png');
      expect(KickRoomParser.image('http://cdn.kick.com/a.png'), 'http://cdn.kick.com/a.png');
      expect(KickRoomParser.image(''), isNull);
      expect(KickRoomParser.image(null), isNull);
      expect(KickRoomParser.image('javascript:alert(1)'), isNull);
    });
  });

  group('the area reads', () {
    test('categoryArea names the first readable subcategory only', () {
      final area = KickRoomParser.categoryArea([
        _category('League+Of+Legends', 'League of Legends'),
        _category('other', 'Other'),
      ]);
      expect(area?.areaId, 'league+of+legends');
      expect(area?.areaName, 'League of Legends');
      expect(area?.parentAreaId, isNull);
      expect(
        KickRoomParser.categoryArea([
          {'name': ''},
        ]),
        isNull,
      );
      expect(
        KickRoomParser.categoryArea([
          {'slug': 'x'},
        ]),
        isNull,
      );
      expect(KickRoomParser.categoryArea(const <Object?>[]), isNull);
      expect(KickRoomParser.categoryArea('not a list'), isNull);
      expect(
        KickRoomParser.categoryArea(['not an object', _category('a', 'A')]),
        isNull,
        reason: 'only the first entry is looked at',
      );
    });

    test('subcategorySlugs reads every slug the row names, lower-cased', () {
      expect(
        KickRoomParser.subcategorySlugs([
          _category('Just-Chatting', 'Just Chatting'),
          _category('LEAGUE', 'LoL'),
          {'no-slug': 1},
          'not an object',
        ]),
        {'just-chatting', 'league'},
      );
      expect(KickRoomParser.subcategorySlugs(null), isEmpty);
    });
  });
}
