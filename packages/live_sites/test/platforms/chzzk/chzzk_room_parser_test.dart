import 'dart:convert';

import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_json.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';
import 'package:test/test.dart';

/// A channel id as the platform writes it.
const String _cid = '0123456789abcdef0123456789abcdef';

const String _other = 'fedcba9876543210fedcba9876543210';

/// One HLS master of a live.
final ChzzkMedia _masterMedia = ChzzkMedia('HLS', Uri.parse('https://t.akamaized.net/a.m3u8'));

/// An answer of `{code, message, content}`.
String _api(Object? content, {int code = 200, String? message}) =>
    jsonEncode(<String, Object?>{'code': code, 'message': ?message, 'content': ?content});

Map<String, Object?> _channel([Map<String, Object?>? override]) => {
  'channelId': _cid,
  'channelName': '主播甲',
  'channelImageUrl': 'https://pstatic.net/ch/a.jpg',
  'channelDescription': '频道简介',
  'followerCount': 500,
  'openLive': true,
  ...?override,
};

Map<String, Object?> _liveRow({Object? liveId = 7001, Map<String, Object?>? channel, Map<String, Object?>? override}) =>
    {
      'liveId': liveId,
      'channel': channel ?? _channel(),
      'liveTitle': '直播标题',
      'liveImageUrl': 'https://pstatic.net/live/{type}/cover.jpg',
      'concurrentUserCount': 120,
      'cvExposure': true,
      'openDate': '2026-09-29 10:00:00',
      'liveCategoryValue': '배틀그라운드',
      ...?override,
    };

/// A lives page of [rows] with an optional `page.next`.
String _lives(List<Object?> rows, {Object? next}) => _api({
  'data': rows,
  if (next != null) 'page': {'next': next},
});

String _mediaJson({bool valid = true, Object? path}) => jsonEncode({
  'media': [
    {
      'protocol': 'HLS',
      'mediaId': 'HLS',
      'path': valid ? (path ?? 'https://test.akamaized.net/a/index.m3u8?hdnts=abc') : 'ftp://x/a.m3u8',
    },
  ],
});

const ChzzkChannel _owner = ChzzkChannel(
  id: _cid,
  name: '主播甲',
  avatar: 'https://pstatic.net/ch/a.jpg',
  description: '频道简介',
  followers: 500,
  isLive: true,
);

ChzzkLive _live({
  bool isLive = true,
  List<ChzzkMedia> media = const [],
  ChzzkFailure? mediaError,
  bool adult = false,
  bool krOnly = false,
  bool abroadBlind = false,
  bool paid = false,
  String area = '배틀그라운드',
  String? chatChannelId = 'chat-1',
  int? online = 120,
}) => ChzzkLive(
  isLive: isLive,
  title: '直播标题',
  nick: '主播甲',
  avatar: 'https://pstatic.net/ch/a.jpg',
  cover: 'https://pstatic.net/live/480/cover.jpg',
  area: area,
  media: media,
  mediaError: mediaError,
  online: online,
  adult: adult,
  krOnly: krOnly,
  abroadBlind: abroadBlind,
  paid: paid,
  chatChannelId: chatChannelId,
);

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on ChzzkFailure catch (failure) {
    return failure.kind;
  }
}

ChzzkFailure _failure(void Function() answer) {
  try {
    answer();
  } on ChzzkFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the envelope and the field rules', () {
    test('every non-200 has its own kind, and 200 is not the whole story', () {
      expect(statusFailure(200, 'x'), isNull);
      expect(
        _failure(() => ChzzkRoomParser.channelById('{}', channelId: _cid, status: 400)).kind,
        ChzzkFailureKind.apiChanged,
      );
      expect(_kindOf(() => content('{}', what: 'x', status: 401)), ChzzkFailureKind.riskControl);
      expect(_kindOf(() => content('{}', what: 'x', status: 403)), ChzzkFailureKind.riskControl);
      expect(_kindOf(() => content('{}', what: 'x', status: 404)), ChzzkFailureKind.notFound);
      expect(_kindOf(() => content('{}', what: 'x', status: 429)), ChzzkFailureKind.rateLimited);
      expect(_kindOf(() => content('{}', what: 'x', status: 302)), ChzzkFailureKind.network);
      expect(
        _kindOf(() => content('{"code":404}', what: 'x')),
        ChzzkFailureKind.apiChanged,
        reason: 'the platform answers 200 with its own code',
      );
      expect(_failure(() => content('{"code":500,"message":"실패"}', what: 'x')).message, 'x: code 500 실패');
      expect(_kindOf(() => content('not json', what: 'x')), ChzzkFailureKind.apiChanged);
      expect(_kindOf(() => content('[]', what: 'x')), ChzzkFailureKind.apiChanged);
      expect(_kindOf(() => content('{"code":200}', what: 'x')), isNull, reason: "no content is the caller's business");
      expect(
        _failure(
          () => content(jsonEncode({'code': 200, 'content': 'x' * (ChzzkEndpoints.responseLimit + 1)}), what: 'x'),
        ).message,
        contains('answer over'),
      );
    });

    test("the readers of the platform's own shapes", () {
      expect(jsonInt('12'), 12);
      expect(jsonInt(12.0), 12);
      expect(jsonInt(12.5), isNull);
      expect(jsonInt(-3), -3, reason: 'these readers never clamp on their own');
      expect(jsonCount(-3), isNull);
      expect(text(7), isEmpty, reason: 'a number where text was sent is not text');
      expect(stringify(7), '7');
      expect(stringify('  '), isNull);
      expect(object({'a': 1}, 'x'), {'a': 1});
      expect(optionalObject('x'), isNull);
      expect(list(const [], 'x'), isEmpty);
      expect(_kindOf(() => list('x', 'x')), ChzzkFailureKind.apiChanged);
      expect(optionalList('x'), isEmpty);
      expect(snippet('a  b'), 'a b');
    });

    test('ids, images and times', () {
      expect(channelId(' $_cid '), _cid);
      expect(channelId(_cid.toUpperCase()), isNull, reason: 'an answer writes its ids lower-case');
      expect(channelId('short'), isNull);
      expect(isChannelId(_cid), isTrue);
      for (final id in ['a b', 'a/b', r'a\b', 'a?b', 'a#b', '.', '..', '', 'x' * 129]) {
        expect(isAreaId(id), isFalse, reason: id);
      }
      expect(isAreaId('Mount_&_Blade2_Bannerlord'), isTrue, reason: 'the platform itself accepts the ampersand');
      expect(image('https://pstatic.net/a.jpg'), 'https://pstatic.net/a.jpg');
      expect(image('https://china.akamaized.net/a.jpg'), 'https://china.akamaized.net/a.jpg');
      expect(image('https://evil.example/a.jpg'), isEmpty);
      expect(image('http://pstatic.net/a.jpg'), isEmpty);
      expect(image('https://pstatic.net/a.jpg#x'), isEmpty);
      expect(image('https://u@pstatic.net/a.jpg'), isEmpty);
      expect(image('https://pstatic.net/${'a' * 8200}.jpg'), isEmpty);
      expect(cover('https://pstatic.net/x/{type}/a.jpg', null), 'https://pstatic.net/x/480/a.jpg');
      expect(cover('https://evil/x.jpg', 'https://pstatic.net/f.jpg'), 'https://pstatic.net/f.jpg');
      expect(cover(null, null), isEmpty);
      expect(seoulTime('2026-09-29 10:00:00'), DateTime.utc(2026, 9, 29, 1));
      expect(seoulTime('2026-09-29T10:00:00'), DateTime.utc(2026, 9, 29, 1), reason: 'the ISO separator is allowed');
      expect(seoulTime('2026-02-30 10:00:00'), isNull);
      expect(seoulTime('1999-12-31 23:59:59'), isNull, reason: 'nothing before 2000 is a broadcast');
      expect(seoulTime('2026-09-29 10:00'), isNull);
      expect(categoryTypeName('GAME'), '游戏');
      expect(categoryTypeName('UNKNOWN_TYPE'), 'UNKNOWN_TYPE');
    });

    test('what the audience and the flags say', () {
      expect(online({'cvExposure': true, 'concurrentUserCount': 120}), 120);
      expect(online({'cvExposure': false, 'concurrentUserCount': 120}), isNull, reason: 'hidden is not zero');
      expect(online({'concurrentUserCount': 120}), isNull, reason: 'no exposure flag is no number');
      expect(areaName({'liveCategoryValue': '', 'liveCategory': '게임'}), isEmpty, reason: 'an empty value stays empty');
      expect(areaName({'liveCategory': '게임'}), '게임');
      expect(regionLocked({'krOnlyViewing': true}), isTrue);
      expect(regionLocked({'blindType': 'ABROAD'}), isTrue);
      expect(regionLocked({'blindType': 'DOMESTIC'}), isFalse);
      expect(paid({'paidProductId': 1}), isTrue);
      expect(paid({'watchPartyPaidProductId': 2}), isTrue);
      expect(paid({}), isFalse);
    });
  });

  group('the catalog', () {
    Map<String, Object?> cat(String id) => {'categoryType': 'GAME', 'categoryId': id, 'categoryValue': '배틀그라운드'};
    String page(List<Object?> rows, {Object? next}) => _api({
      'data': rows,
      if (next != null) 'page': {'next': next},
    });

    test("one area per entry, and the next page's query as it came", () {
      final read = ChzzkRoomParser.categoryPage(
        page(
          [
            _channel({
              'categoryType': 'GAME',
              'categoryId': 'bg1',
              'categoryValue': '배틀그라운드',
              'posterImageUrl': 'https://pstatic.net/p.jpg',
            }),
            {'categoryType': 'GAME', 'categoryId': 'no_name'},
            {'categoryType': 'bad type!', 'categoryId': 'x'},
            {'categoryType': 'GAME', 'categoryId': 'a/b'},
            {'categoryType': 'ENTERTAINMENT', 'categoryId': 'music', 'categoryValue': '음악'},
            'not a row',
          ],
          next: {'size': 50, 'cursor': 'abc', 'empty': '', 'skipped': null},
        ),
      );
      expect(read.areas.map((area) => area.areaId), ['bg1', 'no_name', 'music']);
      expect(read.areas[1].areaName, 'no_name', reason: 'an unnamed area is named by its id');
      expect(read.areas.first.parentAreaId, 'GAME');
      expect(read.areas.first.parentAreaName, '游戏');
      expect(read.areas.first.iconUrl, 'https://pstatic.net/p.jpg');
      expect(read.next, {'size': '50', 'cursor': 'abc'}, reason: 'blank and absent scalars are not sent back');
      expect(ChzzkRoomParser.categoryPage(page(const [])).areas, isEmpty);
      expect(ChzzkRoomParser.categoryPage(page([cat('bg1')])).areas.single.areaId, 'bg1');
      expect(
        ChzzkRoomParser.categoryPage(page(const [], next: {'a': 1})).next,
        isNull,
        reason: 'an empty page ends the list',
      );
      expect(
        ChzzkRoomParser.categoryPage(page([cat('music')], next: 'x')).next,
        isNull,
        reason: 'a next that is not a query',
      );
      expect(ChzzkRoomParser.categoryPage(page([cat('a')])).next, isNull);
      expect(
        _kindOf(
          () => ChzzkRoomParser.categoryPage(
            page([
              {'categoryType': 'GAME'},
            ]),
          ),
        ),
        ChzzkFailureKind.apiChanged,
        reason: 'every row malformed is a changed API, not an empty catalog',
      );
      expect(
        _failure(
          () => ChzzkRoomParser.categoryPage(
            page([
              {'categoryType': 'GAME'},
            ]),
          ),
        ).message,
        contains('no readable entry of 1'),
      );
      expect(_kindOf(() => ChzzkRoomParser.categoryPage(_api({'data': 'x'}))), ChzzkFailureKind.apiChanged);
    });

    test("pages flatten into the platform's own order", () {
      LiveArea area(String id, String type) =>
          LiveArea.normalized(platform: 'chzzk', areaId: id, areaName: id, parentAreaId: type);
      final flat = ChzzkRoomParser.categories([
        [area('a', 'ETC'), area('b', 'GAME'), area('a2', 'MYSTERY')],
        [area('a', 'ETC'), area('c', 'GAME'), area('d', 'ENTERTAINMENT')],
      ]);
      expect(flat.map((entry) => entry.areaId), [
        'b',
        'c',
        'd',
        'a',
        'a2',
      ], reason: "known types come first in the platform's order, unknown ones last");
      expect(ChzzkRoomParser.categories(const <List<LiveArea>>[]), isEmpty);
    });

    test('a category type is letters and underscores only', () {
      expect(ChzzkRoomParser.isCategoryType('GAME'), isTrue);
      expect(ChzzkRoomParser.isCategoryType('my_type'), isTrue);
      expect(ChzzkRoomParser.isCategoryType('GAME1'), isFalse);
      expect(ChzzkRoomParser.isCategoryType(''), isFalse);
    });
  });

  group('the lives lists', () {
    test('a row is a card of a live we cannot watch yet', () {
      final page = ChzzkRoomParser.lives(
        _lives([
          _liveRow(),
          _liveRow(liveId: 7002, channel: _channel({'channelId': _other})),
          _liveRow(liveId: 7003, channel: _channel()),
          _liveRow(liveId: 0, channel: _channel({'channelId': _other})),
          _liveRow(liveId: null, channel: _channel({'channelId': _other})),
          _liveRow(channel: _channel({'channelId': 'not-a-channel-id'})),
          'not a row',
        ]),
      );
      expect(page.rooms.map((room) => room.roomId), [_cid, _other], reason: 'the repeated channel is one room');
      expect(page.nextCursor, isNull, reason: 'the answer named no next');
      expect(page.hasMore, isFalse);
      final first = page.rooms.first;
      expect(first.content.title, '直播标题');
      expect(first.content.coverUrl, 'https://pstatic.net/live/480/cover.jpg');
      expect(first.anchor?.name, '主播甲');
      expect(first.anchor?.avatarUrl, 'https://pstatic.net/ch/a.jpg');
      expect(first.anchor?.liveStatus, LiveStatus.live);
      expect(first.area?.areaName, '배틀그라운드');
      expect(first.audience.onlineViewers, 120);
      expect(first.broadcast.startedAt, DateTime.utc(2026, 9, 29, 1));
      expect(first.broadcast.restriction, LiveRestriction.none);
      expect(first.links.webUrl, 'https://chzzk.naver.com/live/$_cid');
    });

    test('an empty title, a hidden count and the restrictions of a row', () {
      LiveRoom card([Map<String, Object?>? override]) =>
          ChzzkRoomParser.lives(_lives([_liveRow(channel: _channel(), override: override ?? const {})])).rooms.single;
      expect(card({'liveTitle': '  '}).content.title, '主播甲', reason: 'an empty title is the channel name');
      expect(card({'cvExposure': false}).audience.onlineViewers, isNull);
      expect(card({'krOnlyViewing': true}).broadcast.restriction, LiveRestriction.regionBlocked);
      expect(card({'blindType': 'ABROAD'}).broadcast.restriction, LiveRestriction.regionBlocked);
      expect(card({'adult': true}).broadcast.restriction, LiveRestriction.adult);
      expect(
        card({
          'paidProduct': {'id': 1},
        }).broadcast.restriction,
        isNull,
        reason: 'a paid product is not guessed at',
      );
      expect(
        card({'krOnlyViewing': true, 'adult': true}).broadcast.restriction,
        LiveRestriction.regionBlocked,
        reason: 'the region lock is asked first',
      );
      expect(card({'adult': true, 'paidProduct': 1}).broadcast.restriction, LiveRestriction.adult);
    });

    test('the cursor is exclusive and the trimmed page points after the last row kept', () {
      List<Map<String, Object?>> rows(int count) => [
        for (var i = 0; i < count; i++)
          _liveRow(
            liveId: 1000 + i,
            channel: _channel({'channelId': '0123456789abcdef0123456789abcd${i.toRadixString(16).padLeft(2, '0')}'}),
          ),
      ];
      final long = ChzzkRoomParser.lives(_lives(rows(31)));
      expect(long.rooms, hasLength(ChzzkEndpoints.pageSize), reason: 'more rows than a page are dropped');
      expect(long.nextCursor, ChzzkEndpoints.encodeCursor(120, 1029), reason: 'the cursor is the last row kept');
      expect(ChzzkRoomParser.lives(_lives(rows(31))).hasMore, isTrue);
      final hidden = ChzzkRoomParser.lives(
        _lives([
          for (final row in rows(31)) {...row, 'concurrentUserCount': null},
        ]),
      );
      expect(hidden.nextCursor, isNull, reason: 'the last row kept names no count, so no cursor can be built');
      final replayed = ChzzkRoomParser.lives(
        _lives(rows(31), next: {'concurrentUserCount': 1, 'liveId': 2}),
        cursor: ChzzkEndpoints.encodeCursor(120, 1000),
      );
      expect(replayed.rooms, hasLength(ChzzkEndpoints.pageSize), reason: "the first row was the cursor's own live");
      expect(replayed.nextCursor, isNot(ChzzkRoomParser.lives(_lives(rows(31))).nextCursor));
      expect(
        ChzzkRoomParser.lives(_lives(rows(5), next: {'concurrentUserCount': 9, 'liveId': 3})).nextCursor,
        ChzzkEndpoints.encodeCursor(9, 3),
      );
      expect(
        ChzzkRoomParser.lives(
          _lives(rows(5), next: {'concurrentUserCount': 9, 'liveId': 3}),
          cursor: ChzzkEndpoints.encodeCursor(9, 3),
        ).nextCursor,
        isNull,
        reason: 'an answer pointing where we already asked is no next page',
      );
      expect(_kindOf(() => ChzzkRoomParser.lives(_lives(rows(5), next: {'liveId': 3}))), ChzzkFailureKind.apiChanged);
      expect(
        _kindOf(() => ChzzkRoomParser.lives(_lives(rows(5), next: {'concurrentUserCount': 9, 'liveId': 0}))),
        ChzzkFailureKind.apiChanged,
      );
      expect(ChzzkRoomParser.lives(_lives(rows(5), next: 'x')).nextCursor, isNull);
    });
  });

  group('the search and the channel', () {
    test('the keyword is trimmed and cut without splitting a pair', () {
      expect(ChzzkRoomParser.searchKeyword('  主播  '), '主播');
      expect(ChzzkRoomParser.searchKeyword(''), isEmpty);
      final long = 'a' * 150;
      expect(ChzzkRoomParser.searchKeyword(long).length, ChzzkEndpoints.maxKeywordLength);
      final pairs = ChzzkRoomParser.searchKeyword('🐥' * 60);
      expect(pairs.length, ChzzkEndpoints.maxKeywordLength);
      final split = ChzzkRoomParser.searchKeyword('a' * 99 + '🐥🐥');
      expect(split.length, 99, reason: 'a pair that would be cut in half is left out entirely');
      expect(ChzzkRoomParser.searchKeyword('${'a' * 99}   ').length, 99, reason: 'the cut is trimmed again');
    });

    test('search rows name themselves, so a bad one is skipped', () {
      final rooms = ChzzkRoomParser.searchRooms(
        _api({
          'data': [
            {'channel': _channel()},
            {
              'channel': _channel({'channelId': _other, 'channelName': '乙', 'openLive': false}),
            },
            {
              'channel': {'channelId': null, 'channelName': '(알 수 없음)'},
            },
            {
              'channel': _channel({'channelId': 'bad'}),
            },
            {'no_channel': 1},
          ],
        }),
      );
      expect(rooms.map((room) => room.roomId), [_cid, _other]);
      expect(rooms.first.content.title, '主播甲', reason: 'a profile has no live title');
      expect(rooms.first.content.coverUrl, 'https://pstatic.net/ch/a.jpg', reason: 'the card shows the channel avatar');
      expect(rooms.first.content.introduction, '频道简介');
      expect(rooms.first.anchor?.followerCount, 500);
      expect(rooms.first.broadcast.liveStatus, LiveStatus.live);
      expect(rooms[1].broadcast.liveStatus, LiveStatus.offline);
      expect(rooms.first.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(ChzzkRoomParser.searchRooms(_api({'data': <Object?>[]})), isEmpty);
      expect(_kindOf(() => ChzzkRoomParser.searchRooms(_api({'data': 'x'}))), ChzzkFailureKind.apiChanged);
    });

    test('the channel of an answer must be the one that was asked for', () {
      expect(ChzzkRoomParser.channel(_channel(), requestedId: _cid)!.id, _cid);
      expect(ChzzkRoomParser.channel(_channel(), requestedId: '')!.name, '主播甲');
      expect(ChzzkRoomParser.channel({'channelId': null}, requestedId: ''), isNull);
      expect(ChzzkRoomParser.channel({'channelId': 'bad'}, requestedId: ''), isNull);
      expect(
        _failure(() => ChzzkRoomParser.channel({'channelId': null}, requestedId: _cid)).kind,
        ChzzkFailureKind.notFound,
      );
      expect(
        _failure(() => ChzzkRoomParser.channel({'channelId': 'bad'}, requestedId: _cid)).kind,
        ChzzkFailureKind.apiChanged,
      );
      expect(
        _failure(() => ChzzkRoomParser.channel(_channel({'channelId': _other}), requestedId: _cid)).message,
        contains('for $_cid'),
      );
      final found = ChzzkRoomParser.channel(
        _channel({'followerCount': -1, 'openLive': 'Y', 'channelDescription': '  '}),
        requestedId: _cid,
      )!;
      expect(found.followers, isNull, reason: 'a negative count is no count');
      expect(found.isLive, isFalse, reason: 'openLive must really be true');
      expect(found.description, isEmpty);
      expect(ChzzkRoomParser.channelById(_api(_channel()), channelId: _cid).id, _cid);
      expect(
        _failure(() => ChzzkRoomParser.channelById(_api(null), channelId: _cid)).message,
        contains('no content for'),
      );
      expect(
        _failure(() => ChzzkRoomParser.channelById(_api('x'), channelId: _cid)).message,
        contains('expected an object'),
      );
      expect(
        _failure(() => ChzzkRoomParser.channelById(_api({'channelId': null}), channelId: '')).message,
        contains('no channel for'),
      );
      expect(
        _kindOf(() => ChzzkRoomParser.channelById(_api(_channel({'channelId': _other})), channelId: _cid)),
        ChzzkFailureKind.apiChanged,
      );
    });

    test('a channel card is offline whatever the channel claims', () {
      final room = ChzzkRoomParser.channelCard(_owner, status: LiveStatus.offline);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.anchor?.liveStatus, LiveStatus.offline);
      expect(
        ChzzkRoomParser.channelCard(const ChzzkChannel(id: _cid, name: '甲', avatar: '')).broadcast.liveStatus,
        LiveStatus.offline,
      );
      expect(ChzzkRoomParser.channelCard(_owner).broadcast.liveStatus, LiveStatus.live);
      expect(ChzzkRoomParser.channelCard(_owner).content.introduction, '频道简介');
      expect(
        ChzzkRoomParser.channelCard(const ChzzkChannel(id: _cid, name: '甲', avatar: '')).content.introduction,
        isNull,
      );
    });
  });

  group('the live of a channel', () {
    String detail([Map<String, Object?>? override]) => _api({
      'status': 'OPEN',
      'liveTitle': '直播标题',
      'liveImageUrl': 'https://pstatic.net/live/{type}/cover.jpg',
      'liveCategoryValue': '배틀그라운드',
      'concurrentUserCount': 120,
      'cvExposure': true,
      'openDate': '2026-09-29 10:00:00',
      'chatChannelId': 'chat-1',
      'timeMachineActive': true,
      'livePlaybackJson': _mediaJson(),
      'channel': _channel(),
      ...?override,
    });

    test('a channel that never broadcast has no live', () {
      expect(ChzzkRoomParser.liveDetail(_api(null), owner: _owner), isNull);
      final read = ChzzkRoomParser.liveDetail(detail(), owner: _owner)!;
      expect(read.isLive, isTrue);
      expect(read.title, '直播标题');
      expect(read.nick, '主播甲');
      expect(read.cover, 'https://pstatic.net/live/480/cover.jpg');
      expect(read.area, '배틀그라운드');
      expect(read.online, 120);
      expect(read.startedAt, DateTime.utc(2026, 9, 29, 1));
      expect(read.timeMachine, isTrue);
      expect(read.chatChannelId, 'chat-1');
      expect(read.media.map((media) => media.id), ['HLS']);
      expect(read.mediaError, isNull);
      expect(
        ChzzkRoomParser.liveDetail(_api({'status': 'CLOSE'}), owner: _owner)!.startedAt,
        isNull,
        reason: "a closed live's openDate is the previous broadcast's",
      );
      expect(
        ChzzkRoomParser.liveDetail(
          _api({'status': 'CLOSE', 'livePlaybackJson': 'not json'}),
          owner: _owner,
        )!.mediaError,
        isNull,
        reason: 'playback data is read only for an open live',
      );
    });

    test('the status is never guessed, and the channel must be the owner', () {
      expect(ChzzkRoomParser.liveDetail(_api({'status': 'CLOSE'}), owner: _owner)!.isLive, isFalse);
      expect(ChzzkRoomParser.liveDetail(_api({'status': 'CLOSED'}), owner: _owner)!.isLive, isFalse);
      expect(
        _failure(() => ChzzkRoomParser.liveDetail(_api({'status': 'WAITING'}), owner: _owner)).message,
        contains('status WAITING'),
      );
      expect(
        _kindOf(
          () => ChzzkRoomParser.liveDetail(
            detail({
              'channel': {'channelId': _other},
            }),
            owner: _owner,
          ),
        ),
        ChzzkFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => ChzzkRoomParser.liveDetail(detail({'channel': 'x'}), owner: _owner)),
        isNull,
        reason: 'a live without a channel block is still a live',
      );
      expect(
        ChzzkRoomParser.liveDetail(detail({'channel': null}), owner: _owner)!.nick,
        '主播甲',
        reason: 'the owner names it',
      );
      expect(ChzzkRoomParser.liveDetail(detail({'liveTitle': ''}), owner: _owner)!.title, _owner.name);
    });

    test('an unreadable playback data does not hide the room', () {
      final broken = ChzzkRoomParser.liveDetail(detail({'livePlaybackJson': 'not json'}), owner: _owner)!;
      expect(broken.isLive, isTrue);
      expect(broken.media, isEmpty);
      expect(broken.mediaError?.kind, ChzzkFailureKind.apiChanged);
      expect(ChzzkRoomParser.restriction(broken), isNull, reason: "the read's own failure is the reason");
      expect(ChzzkRoomParser.unavailable(broken).kind, ChzzkFailureKind.apiChanged);
      final ftp = ChzzkRoomParser.liveDetail(detail({'livePlaybackJson': _mediaJson(valid: false)}), owner: _owner)!;
      expect(ftp.mediaError?.message, contains('unusable media'));
      final none = ChzzkRoomParser.liveDetail(detail({'livePlaybackJson': null}), owner: _owner)!;
      expect(none.mediaError, isNull);
      expect(ChzzkRoomParser.restriction(none), LiveRestriction.unplayable);
      expect(ChzzkRoomParser.restriction(_live(media: [_masterMedia])), LiveRestriction.none);
      expect(ChzzkRoomParser.restriction(_live(krOnly: true)), LiveRestriction.regionBlocked);
      expect(ChzzkRoomParser.restriction(_live(abroadBlind: true)), LiveRestriction.regionBlocked);
      expect(ChzzkRoomParser.restriction(_live(adult: true)), LiveRestriction.adult);
      expect(ChzzkRoomParser.restriction(_live(paid: true)), LiveRestriction.paid);
      expect(ChzzkRoomParser.restriction(_live(isLive: false)), isNull);
      expect(ChzzkRoomParser.restriction(null), isNull);
    });

    test('why it cannot be played, and what the room keeps', () {
      expect(ChzzkRoomParser.unavailable(null).message, 'not live');
      expect(ChzzkRoomParser.unavailable(_live(isLive: false)).message, 'not live');
      expect(ChzzkRoomParser.unavailable(_live(krOnly: true)).kind, ChzzkFailureKind.regionBlocked);
      expect(
        ChzzkRoomParser.unavailable(_live(adult: true)).kind,
        ChzzkFailureKind.needsLogin,
        reason: "it needs the platform's own age check",
      );
      expect(ChzzkRoomParser.unavailable(_live(paid: true)).message, 'paid live');
      expect(ChzzkRoomParser.unavailable(_live()).message, 'live without playback');
      final data = ChzzkRoomParser.roomData(_cid, _live(media: [_masterMedia]), issuedAt: DateTime.utc(2026));
      expect(data.media, hasLength(1));
      expect(data.unavailable, isNull);
      expect(data.channelId, _cid);
      final stuck = ChzzkRoomParser.roomData(_cid, _live(adult: true), issuedAt: DateTime.utc(2026));
      expect(stuck.media, isEmpty);
      expect(stuck.unavailable?.kind, ChzzkFailureKind.needsLogin);
      expect('$stuck', contains('0 masters'));
      expect('${ChzzkMedia('HLS', Uri.parse('https://t.akamaized.net/a.m3u8'))}', contains('t.akamaized.net'));
    });

    test('the room of a live, and the chat it opens', () {
      final live = ChzzkRoomParser.liveDetail(detail(), owner: _owner)!;
      final room = ChzzkRoomParser.room(_owner, live);
      expect(room.roomId, _cid);
      expect(room.content.title, '直播标题');
      expect(room.content.introduction, '频道简介', reason: "the description is the channel's");
      expect(room.anchor?.followerCount, 500, reason: "the followers are the channel's");
      expect(room.audience.onlineViewers, 120);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, ChzzkRoomParser.link(_cid));
      expect(
        ChzzkRoomParser.room(_owner, _live(area: '')).area?.areaName,
        ChzzkEndpoints.siteName,
        reason: 'no category is named CHZZK',
      );
      expect(ChzzkRoomParser.room(_owner, null).broadcast.liveStatus, LiveStatus.offline);
      expect(
        ChzzkRoomParser.room(_owner, _live(isLive: false)).broadcast.liveStatus,
        LiveStatus.offline,
        reason: 'an openLive channel whose live closed is offline',
      );
      expect(ChzzkRoomParser.danmakuArgs(_owner, live)!.chatChannelId, 'chat-1');
      expect(ChzzkRoomParser.danmakuArgs(_owner, _live(isLive: false)), isNull);
      expect(ChzzkRoomParser.danmakuArgs(_owner, _live(chatChannelId: null)), isNull);
      expect(ChzzkRoomParser.danmakuArgs(_owner, null), isNull);
    });
  });

  group('the links', () {
    test('only the channel pages of chzzk.naver.com are rooms', () {
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/live/$_cid'), _cid);
      expect(ChzzkRoomParser.roomIdFromUrl('http://chzzk.naver.com/$_cid'), _cid);
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/$_cid/videos'), _cid);
      expect(
        ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com//$_cid//'),
        _cid,
        reason: 'empty segments are ignored',
      );
      expect(
        ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/$_cid'.toUpperCase()),
        _cid,
        reason: 'the id and the host are accepted in any case',
      );
      expect(
        ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/$_cid/videos/1'),
        isNull,
        reason: 'at most one tab',
      );
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/video/12345'), isNull);
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/'), isNull);
      expect(ChzzkRoomParser.roomIdFromUrl('https://m.chzzk.naver.com/$_cid'), isNull, reason: 'only the exact host');
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com:443/live/$_cid'), _cid);
      expect(ChzzkRoomParser.roomIdFromUrl('https://u@chzzk.naver.com/$_cid'), isNull);
      expect(ChzzkRoomParser.roomIdFromUrl('ftp://chzzk.naver.com/$_cid'), isNull);
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/not-a-channel-id'), isNull);
      expect(ChzzkRoomParser.roomIdFromUrl('not a url'), isNull);
      expect(ChzzkRoomParser.link(_cid), 'https://chzzk.naver.com/live/$_cid');
    });
  });
}
