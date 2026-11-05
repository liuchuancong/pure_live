import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_json.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_room_parser.dart';
import 'package:test/test.dart';

const String _id = 'tester_1';

/// The broadcaster's number (`bjInfo.idx`), which is also the chat channel.
const int _index = 60321;

/// An IVS playlist address of this platform.
String _ivs(String path) => 'https://d123.ivs.live-video.net/iv/v1/playlist/$path.m3u8?token=abc';

Uri _masterUrl() => Uri.parse(_ivs('master'));

Map<String, dynamic> _profile([Map<String, Object?>? override]) => {
  'id': _id,
  'idx': _index,
  'nick': '主播甲',
  'channelTitle': '频道名',
  'channelDesc': '频道介绍',
  'channelBannerUrl': 'https://img.pandalive.co.kr/banner.jpg',
  'thumbUrl': 'https://img.pandalive.co.kr/avatar.jpg',
  'fanCnt': 900,
  ...?override,
};

Map<String, dynamic> _media([Map<String, Object?>? override]) => {
  'userId': _id,
  'userIdx': _index,
  'isLive': true,
  'title': '直播标题',
  'userNick': '主播甲',
  'userImg': 'https://img.pandalive.co.kr/live_avatar.jpg',
  'thumbUrl': 'https://img.pandalive.co.kr/live_cover.jpg',
  'category': 'game',
  'user': 30,
  'playCnt': 4000,
  'fanCnt': 1000,
  'startTime': '2026-09-28 02:00:35',
  'type': 'free',
  ...?override,
};

PandaliveMember _member({
  Map<String, dynamic>? media,
  Map<String, dynamic>? profile,
  String userId = _id,
  int index = _index,
}) => PandaliveMember(userId: userId, userIndex: index, profile: profile ?? _profile(), media: media);

/// A `live/index` style page of [rows] asked at [page] of [size].
String _page(List<Object?> rows, {int page = 1, int size = 30, int? total, int? offset}) => jsonEncode({
  'result': true,
  'page': {'offset': offset ?? (page - 1) * size, 'limit': size, 'page': page, 'total': ?total},
  'list': rows,
});

/// A `live/play` answer.
String _play({Object? media, Object? playlist, bool result = true, Object? code, Object? channel, Object? token}) =>
    jsonEncode({
      'result': result,
      if (code != null) 'errorData': {'code': code},
      'media': ?media,
      'PlayList': ?playlist,
      'channel': ?channel,
      'token': ?token,
    });

/// An IVS master with one variant per entry of [variants].
String _manifest(List<String> variants) => ['#EXTM3U', ...variants].join('\n');

String _streamInf({
  required int height,
  int bandwidth = 2000000,
  double? frameRate,
  String? codecs = 'avc1.640028',
  String? video,
  String path = 'v',
}) =>
    '#EXT-X-STREAM-INF:BANDWIDTH=$bandwidth'
    '${frameRate == null ? '' : ',FRAME-RATE=$frameRate'}'
    '${video == null ? '' : ',VIDEO="$video"'}'
    '${codecs == null ? '' : ',CODECS="$codecs"'}'
    ',RESOLUTION=1280x$height\n${path.contains('://') ? path : _ivs(path)}';

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on PandaliveFailure catch (failure) {
    return failure.kind;
  }
}

PandaliveFailure _failure(void Function() answer) {
  try {
    answer();
  } on PandaliveFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the envelope of an API answer', () {
    test('the status table leaves 400 to the body', () {
      expect(_kindOf(() => PandaliveJson.checkStatus(200, 'x')), isNull);
      expect(_kindOf(() => PandaliveJson.checkStatus(400, 'x')), isNull, reason: 'a refusal says why in its body');
      expect(_kindOf(() => PandaliveJson.checkStatus(401, 'x')), PandaliveFailureKind.riskControl);
      expect(_kindOf(() => PandaliveJson.checkStatus(403, 'x')), PandaliveFailureKind.riskControl);
      expect(_kindOf(() => PandaliveJson.checkStatus(404, 'x')), PandaliveFailureKind.notFound);
      expect(_kindOf(() => PandaliveJson.checkStatus(429, 'x')), PandaliveFailureKind.rateLimited);
      expect(_kindOf(() => PandaliveJson.checkStatus(500, 'x')), PandaliveFailureKind.network);
      expect(_kindOf(() => PandaliveJson.checkStatus(302, 'x')), PandaliveFailureKind.network);
      expect(_kindOf(() => PandaliveJson.checkBody('x' * 50, 'x', 200, limit: 49)), PandaliveFailureKind.apiChanged);
      expect(_failure(() => PandaliveJson.checkBody('x' * 50, 'x', 200, limit: 49)).message, contains('over 49'));
    });

    test('the result flag is the envelope', () {
      expect(PandaliveRoomParser.answer('{"result":true}', what: 'x'), {'result': true});
      expect(
        _kindOf(() => PandaliveRoomParser.answer('{"result":"true"}', what: 'x')),
        PandaliveFailureKind.apiChanged,
      );
      expect(_kindOf(() => PandaliveRoomParser.answer('{}', what: 'x')), PandaliveFailureKind.apiChanged);
      expect(_kindOf(() => PandaliveRoomParser.answer('[]', what: 'x')), PandaliveFailureKind.apiChanged);
      expect(_kindOf(() => PandaliveRoomParser.answer('not json', what: 'x')), PandaliveFailureKind.apiChanged);
      expect(PandaliveRoomParser.ok('{"result":true,"a":1}', what: 'x')['a'], 1);
      expect(
        _kindOf(() => PandaliveRoomParser.ok('{"result":false}', what: 'x')),
        PandaliveFailureKind.apiChanged,
        reason: 'a refusal with no code changed the API',
      );
      expect(
        PandaliveRoomParser.refusalCode({
          'errorData': {'code': 'castEnd'},
        }),
        'castEnd',
      );
      expect(PandaliveRoomParser.refusalCode({'errorData': 'x'}), isEmpty, reason: 'errorData is not always an object');
      expect(PandaliveRoomParser.refusalCode({}), isEmpty);
    });

    test('a refusal is read by its message first, then its code', () {
      Map<String, dynamic> data([Map<String, Object?>? override]) => {
        'result': false,
        'message': '别的拒绝',
        'errorData': {'code': 'castEnd'},
        ...?override,
      };
      final missing = PandaliveRoomParser.refusal(
        data({
          'message': '유저 정보가 없습니다',
          'errorData': {'code': 'castEnd'},
        }),
        what: 'member/bj',
      );
      expect(missing.kind, PandaliveFailureKind.notFound, reason: 'the text wins over the code');
      expect(missing.message, 'member/bj: no such broadcaster');
      expect(PandaliveRoomParser.refusal(data(), what: 'x').kind, PandaliveFailureKind.streamUnavailable);
      expect(PandaliveRoomParser.refusal(data(), what: 'x').message, 'x: castEnd');
      final bare = PandaliveRoomParser.refusal(data({'errorData': null}), what: 'x');
      expect(bare.kind, PandaliveFailureKind.apiChanged);
      expect(bare.message, 'x refused: 别的拒绝');
    });
  });

  group("the readers of this platform's fields", () {
    test('flags are written four ways', () {
      for (final value in [true, 'Y', 'y', 1]) {
        expect(PandaliveJson.flag(value), isTrue, reason: '$value');
      }
      for (final value in [false, 'N', 'n', 0]) {
        expect(PandaliveJson.flag(value), isFalse, reason: '$value');
      }
      for (final value in ['yes', 2, null, '']) {
        expect(PandaliveJson.flag(value), isNull, reason: '$value');
      }
    });

    test('numbers, texts and pictures', () {
      expect(PandaliveJson.integer(' 12 '), 12);
      expect(PandaliveJson.integer(1.5), isNull);
      expect(PandaliveJson.count(0), 0, reason: 'nobody watching is a figure');
      expect(PandaliveJson.count(-1), isNull);
      expect(PandaliveJson.positive(0), isNull);
      expect(PandaliveJson.text(' a '), 'a');
      expect(PandaliveJson.text(7), isEmpty);
      expect(PandaliveJson.firstText(['', '  ', '甲', '乙']), '甲');
      expect(PandaliveJson.image('https://img.pandalive.co.kr/a.jpg'), 'https://img.pandalive.co.kr/a.jpg');
      expect(PandaliveJson.image('https://img.pandalive.co.kr/a.jpg?q=1'), 'https://img.pandalive.co.kr/a.jpg?q=1');
      expect(PandaliveJson.image('http://img.pandalive.co.kr/a.jpg'), isEmpty, reason: 'only https');
      expect(PandaliveJson.image('https://cdn.example.com/a.jpg'), isEmpty, reason: "only this platform's host");
      expect(PandaliveJson.image('https://pandalive.co.kr/a.jpg'), isEmpty, reason: 'a subdomain, not the apex');
      expect(PandaliveJson.image('https://u@img.pandalive.co.kr/a.jpg'), isEmpty);
      expect(PandaliveJson.image(' a '), isEmpty);
      expect(PandaliveJson.image('https://img.pandalive.co.kr/${'a' * 8200}'), isEmpty, reason: 'over 8192 is nothing');
    });

    test('a time is Korean, without a zone', () {
      expect(PandaliveJson.koreanTime('2026-09-28 02:00:35'), DateTime.utc(2026, 9, 27, 17, 0, 35));
      expect(PandaliveJson.koreanTime(' 2026-09-28 02:00:35 '), DateTime.utc(2026, 9, 27, 17, 0, 35));
      expect(PandaliveJson.koreanTime('0000-00-00 00:00:00'), isNull, reason: "the platform's empty time");
      expect(PandaliveJson.koreanTime('2026-02-30 02:00:35'), isNull, reason: 'an impossible day');
      expect(PandaliveJson.koreanTime('2026-9-28 2:0:5'), isNull, reason: 'the shape is fixed');
      expect(PandaliveJson.koreanTime('1999-12-31 23:59:59'), isNull, reason: 'nothing before 2000 is a broadcast');
      expect(PandaliveJson.koreanTime(1760000000), isNull);
      expect(PandaliveJson.koreanTime('2026-09-28T02:00:35'), isNull);
    });
  });

  group('restrictions, notices and the state of an on-air broadcast', () {
    test('the flags say who may watch, in order', () {
      expect(
        PandaliveRoomParser.restrictionOf(_media({'isAdult': true, 'isPw': true, 'type': 'fan'})),
        LiveRestriction.adult,
      );
      expect(PandaliveRoomParser.restrictionOf(_media({'isPw': 'Y', 'type': 'fan'})), LiveRestriction.password);
      expect(PandaliveRoomParser.restrictionOf(_media({'type': 'fan'})), LiveRestriction.subscribersOnly);
      expect(PandaliveRoomParser.restrictionOf(_media({'type': 'free'})), LiveRestriction.none);
      expect(
        PandaliveRoomParser.restrictionOf(_media({'type': 'other'})),
        isNull,
        reason: 'an unknown type says nothing',
      );
      expect(PandaliveRoomParser.restrictionOf(_media()), LiveRestriction.none);
    });

    test("each restriction is said once, in the room's own words", () {
      expect(PandaliveRoomParser.noticeOf(LiveRestriction.adult), PandaliveEndpoints.adultNotice);
      expect(PandaliveRoomParser.noticeOf(LiveRestriction.password), PandaliveEndpoints.passwordNotice);
      expect(PandaliveRoomParser.noticeOf(LiveRestriction.subscribersOnly), PandaliveEndpoints.fansNotice);
      expect(PandaliveRoomParser.noticeOf(LiveRestriction.none), PandaliveEndpoints.chatNotice);
      expect(PandaliveRoomParser.noticeOf(null), PandaliveEndpoints.chatNotice);
      expect(PandaliveRoomParser.noticeOf(LiveRestriction.needsLogin), PandaliveEndpoints.restrictedNotice);
      expect(
        PandaliveRoomParser.restrictionError(LiveRestriction.adult, 'live/play: needAdult').message,
        'live/play: needAdult (adult)',
      );
    });

    test('a refusal names a restriction before the flags do', () {
      expect(PandaliveRoomParser.refusalRestriction('needAdult', null), LiveRestriction.adult);
      expect(PandaliveRoomParser.refusalRestriction('needPassword', null), LiveRestriction.password);
      expect(PandaliveRoomParser.refusalRestriction('password', null), LiveRestriction.password);
      expect(
        PandaliveRoomParser.refusalRestriction('needLogin', _media({'isPw': true})),
        LiveRestriction.password,
        reason: 'an anonymous viewer of a password room is refused needLogin',
      );
      expect(
        PandaliveRoomParser.refusalRestriction('needLogin', _media({'type': 'free'})),
        LiveRestriction.needsLogin,
        reason: 'a free room really does need a login',
      );
      expect(PandaliveRoomParser.refusalRestriction('needLogin', _media()), LiveRestriction.needsLogin);
      expect(PandaliveRoomParser.refusalRestriction('castEnd', _media()), LiveRestriction.unplayable);
      expect(PandaliveRoomParser.refusalRestriction('', _media({'isAdult': true})), LiveRestriction.adult);
    });

    test('a recording played again is a replay', () {
      expect(PandaliveRoomParser.isRerun(_media({'onAirType': 'rec'})), isTrue);
      expect(PandaliveRoomParser.isRerun(_media({'liveType': 'rec'})), isTrue);
      expect(PandaliveRoomParser.isRerun(_media()), isFalse);
      expect(PandaliveRoomParser.onAirStatus(_media({'onAirType': 'rec'})), LiveStatus.replay);
      expect(PandaliveRoomParser.onAirStatus(_media()), LiveStatus.live);
    });

    test('the category code becomes an area, translated', () {
      final area = PandaliveRoomParser.areaOf('GAME');
      expect(area?.areaId, 'game', reason: 'the id is the code as written by the platform, lower-cased');
      expect(area?.areaName, '游戏');
      expect(PandaliveRoomParser.areaOf('unknown_code')?.areaName, 'unknown_code', reason: 'an unknown code is kept');
      expect(PandaliveRoomParser.areaOf(''), isNull);
      expect(PandaliveRoomParser.areaOf('game')?.parentAreaId, PandaliveEndpoints.siteId);
      expect(PandaliveRoomParser.areaOf('game')?.parentAreaName, 'PandaTV');
    });
  });

  group('the cards', () {
    test('a live card is the broadcast, not the channel', () {
      final card = PandaliveRoomParser.liveCard(_media({'user': '30', 'playCnt': '4,000'}))!;
      expect(card.roomId, _id);
      expect(card.content.title, '直播标题');
      expect(card.content.coverUrl, 'https://img.pandalive.co.kr/live_cover.jpg');
      expect(card.content.notice, PandaliveEndpoints.chatNotice);
      expect(card.anchor?.name, '主播甲');
      expect(card.anchor?.avatarUrl, 'https://img.pandalive.co.kr/live_avatar.jpg');
      expect(card.anchor?.followerCount, 1000);
      expect(card.area?.areaName, '游戏');
      expect(card.audience.onlineViewers, 30);
      expect(card.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(card.broadcast.liveStatus, LiveStatus.live);
      expect(card.broadcast.startedAt, DateTime.utc(2026, 9, 27, 17, 0, 35));
      expect(card.links.webUrl, 'https://www.pandalive.co.kr/play/$_id');
      expect(
        PandaliveRoomParser.liveCard(_media({'title': ''}))!.content.title,
        '主播甲',
        reason: 'with no broadcast title the nick names the card',
      );
      expect(
        PandaliveRoomParser.liveCard(_media({'isLive': 'N'})),
        isNull,
        reason: 'the directory lists what is on air',
      );
      expect(PandaliveRoomParser.liveCard(_media({'isLive': 'Y'})), isNotNull, reason: 'a text flag is still true');
      expect(PandaliveRoomParser.liveCard(_media({'userId': 'bad id!'})), isNull, reason: 'no usable id, no card');
      expect(PandaliveRoomParser.liveCard(_media({'userId': null})), isNull);
      expect(
        PandaliveRoomParser.liveCard(_media({'ivsThumbnail': 'https://img.pandalive.co.kr/ivs.jpg', 'thumbUrl': null}))!
            .content
            .coverUrl,
        'https://img.pandalive.co.kr/ivs.jpg',
      );
      expect(PandaliveRoomParser.liveCard(_media({'userImg': ''}))!.anchor?.avatarUrl, isNull);
      expect(PandaliveRoomParser.liveCard(_media({'isAdult': true}))!.broadcast.restriction, LiveRestriction.adult);
      expect(PandaliveRoomParser.liveCard(_media({'isAdult': true}))!.content.notice, PandaliveEndpoints.adultNotice);
    });

    test('a broadcaster card is the person, live or not', () {
      expect(PandaliveRoomParser.profileCard({'blockService': true, 'userId': _id, 'userIdx': _index}), isNull);
      expect(PandaliveRoomParser.profileCard({'userId': _id}), isNull, reason: 'a row without a number is not a card');
      expect(PandaliveRoomParser.profileCard({'userId': 'bad id!', 'userIdx': _index}), isNull);
      final offline = PandaliveRoomParser.profileCard({
        'userId': _id,
        'userIdx': _index,
        'userNick': '甲',
        'thumbUrl': 'https://img.pandalive.co.kr/a.jpg',
      })!;
      expect(offline.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.content.title, '甲', reason: 'without a broadcast the nick is the title');
      expect(offline.content.notice, PandaliveEndpoints.chatNotice);
      expect(offline.audience.onlineViewers, isNull);
      expect(offline.anchor?.avatarUrl, 'https://img.pandalive.co.kr/a.jpg');
      expect(
        PandaliveRoomParser.profileCard({
          'userId': _id,
          'userIdx': _index,
          'media': _media({'userId': 'other'}),
        }),
        isNull,
        reason: "a broadcast of another broadcaster is not this row's",
      );
      final ended = PandaliveRoomParser.profileCard({
        'userId': _id,
        'userIdx': _index,
        'userNick': '甲',
        'media': _media({'isLive': false, 'user': 9}),
      })!;
      expect(ended.broadcast.liveStatus, LiveStatus.offline);
      expect(ended.audience.onlineViewers, isNull, reason: 'an ended broadcast is not counted');
      expect(ended.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(ended.broadcast.restriction, isNull, reason: 'a room that is not on air names no restriction');
      expect(ended.broadcast.startedAt, isNull);
      final unknown = PandaliveRoomParser.profileCard({
        'userId': _id,
        'userIdx': _index,
        'media': _media({'isLive': 'maybe'}),
      })!;
      expect(unknown.broadcast.liveStatus, LiveStatus.unknown);
      expect(
        PandaliveRoomParser.profileCard({
          'userId': _id,
          'userIdx': _index,
          'media': _media({'isLive': 'Y'}),
        })!.broadcast.liveStatus,
        LiveStatus.live,
      );
      expect(
        PandaliveRoomParser.profileCard({
          'userId': _id,
          'userIdx': _index,
          'media': _media({'isLive': 'N'}),
        })!.anchor?.liveStatus,
        LiveStatus.offline,
      );
    });

    test('a broadcast belongs to its broadcaster, any case, and to its number', () {
      expect(PandaliveRoomParser.owns(_media({'userId': _id.toUpperCase()}), _id), isTrue);
      expect(PandaliveRoomParser.owns(_media(), _id, _index), isTrue);
      expect(PandaliveRoomParser.owns(_media({'userIdx': _index + 1}), _id, _index), isFalse);
      expect(PandaliveRoomParser.owns(_media({'userIdx': 0}), _id, _index), isFalse);
      expect(PandaliveRoomParser.owns(_media({'userId': null}), _id), isFalse);
    });
  });

  group('member/bj, the channel of a broadcaster', () {
    String body([Map<String, Object?>? override]) =>
        jsonEncode({'result': true, 'bjInfo': _profile(), 'media': _media(), ...?override});

    test('the channel must be the one that was asked for', () {
      final member = PandaliveRoomParser.member(body(), userId: _id.toUpperCase());
      expect(member.userId, _id.toUpperCase(), reason: 'the id is kept as it was asked');
      expect(member.userIndex, _index);
      expect(member.media, isNotNull);
      expect(PandaliveRoomParser.member(body({'media': null}), userId: _id).media, isNull);
      expect(
        _kindOf(() => PandaliveRoomParser.member(body({'bjInfo': null}), userId: _id)),
        PandaliveFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => PandaliveRoomParser.member(
            body({
              'bjInfo': _profile({'id': 'other'}),
            }),
            userId: _id,
          ),
        ).message,
        contains('bjInfo of other for'),
      );
      expect(
        _kindOf(
          () => PandaliveRoomParser.member(
            body({
              'bjInfo': _profile({'idx': 0}),
            }),
            userId: _id,
          ),
        ),
        PandaliveFailureKind.apiChanged,
        reason: 'without a number the chat channel cannot be named',
      );
      expect(
        _failure(
          () => PandaliveRoomParser.member(
            body({
              'media': _media({'userId': 'other'}),
            }),
            userId: _id,
          ),
        ).message,
        contains('media of other for'),
      );
      expect(
        _kindOf(() => PandaliveRoomParser.member(body({'media': 'x'}), userId: _id)),
        PandaliveFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => PandaliveRoomParser.member(
            jsonEncode({'result': false, 'message': '유저 정보가 없습니다'}),
            userId: _id,
            status: 400,
          ),
        ),
        PandaliveFailureKind.notFound,
      );
    });

    test('listed live is what the platform says, and an unknown flag still counts', () {
      expect(PandaliveRoomParser.listedLive(_member(media: _media())), isTrue);
      expect(PandaliveRoomParser.listedLive(_member(media: _media({'isLive': 'Y'}))), isTrue);
      expect(PandaliveRoomParser.listedLive(_member(media: _media({'isLive': null}))), isTrue);
      expect(PandaliveRoomParser.listedLive(_member(media: _media({'isLive': false}))), isFalse);
      expect(PandaliveRoomParser.listedLive(_member()), isFalse);
    });

    test('a channel room is the profile, offline', () {
      final room = PandaliveRoomParser.profileRoom(_member());
      expect(room.content.title, '频道名');
      expect(room.content.coverUrl, 'https://img.pandalive.co.kr/banner.jpg');
      expect(room.content.introduction, '频道介绍');
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.avatarUrl, 'https://img.pandalive.co.kr/avatar.jpg');
      expect(room.anchor?.followerCount, 900);
      expect(room.anchor?.liveStatus, LiveStatus.offline);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(
        PandaliveRoomParser.profileRoom(_member(profile: _profile({'channelTitle': '', 'channelDesc': ''})))
            .content
            .title,
        '主播甲',
      );
      expect(
        PandaliveRoomParser.profileRoom(_member(profile: _profile({'channelDesc': '   '}))).content.introduction,
        isNull,
        reason: 'a blank description is no description',
      );
    });

    test('a broadcast room prefers what the broadcast says', () {
      final room = PandaliveRoomParser.mediaRoom(_member(), _media(), notice: 'n', restriction: LiveRestriction.none);
      expect(room.content.title, '直播标题');
      expect(room.content.notice, 'n');
      expect(room.content.introduction, '频道介绍', reason: 'the description only ever comes from the channel');
      expect(room.content.coverUrl, 'https://img.pandalive.co.kr/live_cover.jpg');
      expect(room.anchor?.avatarUrl, 'https://img.pandalive.co.kr/live_avatar.jpg');
      expect(room.anchor?.followerCount, 1000, reason: 'the broadcast counts its own fans');
      expect(room.audience.onlineViewers, 30);
      expect(room.audience.totalViewers, 4000);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 27, 17, 0, 35));
      final playable = PandaliveRoomParser.mediaRoom(
        _member(),
        _media({'thumbUrl': null, 'ivsThumbnail': 'https://img.pandalive.co.kr/ivs.jpg'}),
        notice: 'n',
        playable: true,
      );
      expect(
        playable.content.coverUrl,
        'https://img.pandalive.co.kr/ivs.jpg',
        reason: 'a playable broadcast shows its IVS snapshot',
      );
      expect(
        PandaliveRoomParser.mediaRoom(
          _member(),
          _media({'thumbUrl': null, 'ivsThumbnail': 'https://img.pandalive.co.kr/ivs.jpg'}),
          notice: 'n',
        ).content.coverUrl,
        'https://img.pandalive.co.kr/banner.jpg',
        reason: 'without a snapshot an unplayable one falls to the banner, never to the IVS picture',
      );
      expect(
        PandaliveRoomParser.mediaRoom(
          _member(profile: _profile({'nick': ''})),
          _media({'userNick': '乙', 'fanCnt': null}),
          notice: 'n',
        ).anchor?.followerCount,
        900,
      );
      expect(
        PandaliveRoomParser.mediaRoom(
          _member(profile: _profile({'nick': ''})),
          _media({'title': null, 'userNick': '乙'}),
          notice: 'n',
        ).content.title,
        '频道名',
      );
    });

    test('a refresh is the profile room or the broadcast, by its flags', () {
      expect(PandaliveRoomParser.refreshRoom(_member()).broadcast.liveStatus, LiveStatus.offline);
      final live = PandaliveRoomParser.refreshRoom(_member(media: _media({'isAdult': true})));
      expect(live.broadcast.liveStatus, LiveStatus.live);
      expect(live.broadcast.restriction, LiveRestriction.adult);
      expect(live.content.notice, PandaliveEndpoints.adultNotice);
      expect(
        PandaliveRoomParser.refreshRoom(_member(media: _media({'type': 'fan'}))).broadcast.restriction,
        LiveRestriction.subscribersOnly,
      );
    });
  });

  group('live/play, the second request of an entry', () {
    test('a refusal is kept for the caller instead of thrown', () {
      final play = PandaliveRoomParser.play(_play(result: false, code: 'castEnd'), member: _member());
      expect(play.code, 'castEnd');
      expect(play.media, isNull);
      expect(play.isLive, isFalse);
      expect(PandaliveRoomParser.play(_play(result: false), member: _member()).code, isEmpty);
      final accepted = PandaliveRoomParser.play(
        _play(
          media: _media(),
          playlist: {
            'hls': [
              {'url': _ivs('master')},
            ],
          },
        ),
        member: _member(),
      );
      expect(accepted.code, isNull);
      expect(accepted.isLive, isTrue);
      expect(accepted.master, _masterUrl());
      expect(accepted.chatChannel, isNull);
    });

    test("the media must be this broadcaster's, and a live answer needs a playlist", () {
      expect(_kindOf(() => PandaliveRoomParser.play(_play(), member: _member())), PandaliveFailureKind.apiChanged);
      expect(
        _failure(() => PandaliveRoomParser.play(_play(media: _media({'userId': 'other'})), member: _member())).message,
        contains('media of other for'),
      );
      expect(
        _kindOf(() => PandaliveRoomParser.play(_play(media: _media({'userIdx': 1})), member: _member())),
        PandaliveFailureKind.apiChanged,
        reason: 'a broadcast of the same id but another number is not this one',
      );
      expect(
        _kindOf(() => PandaliveRoomParser.play(_play(media: _media({'isLive': false})), member: _member())),
        isNull,
        reason: 'not live needs no playlist',
      );
      expect(PandaliveRoomParser.play(_play(media: _media({'isLive': false})), member: _member()).isLive, isFalse);
      expect(
        _failure(() => PandaliveRoomParser.play(_play(media: _media()), member: _member())).message,
        contains('no PlayList'),
      );
      expect(PandaliveRoomParser.play(_play(media: _media({'isLive': 'N'})), member: _member()).isLive, isFalse);
    });

    test("the chat grant is the answer's, or the broadcaster's number", () {
      final granted = PandaliveRoomParser.play(
        _play(media: _media(), playlist: {'hls': <Object?>[]}, channel: ' 777 ', token: ' jwt '),
        member: _member(),
      );
      expect(PandaliveRoomParser.chatGrantOf(_member(), granted)!.channel, '777');
      expect(PandaliveRoomParser.chatGrantOf(_member(), granted)!.token, 'jwt');
      expect(
        PandaliveRoomParser.chatGrantOf(
          _member(),
          PandaliveRoomParser.play(
            _play(media: _media(), playlist: {'hls': <Object?>[]}),
            member: _member(),
          ),
        )!.token,
        isNull,
        reason: 'an answer without a token still has a channel',
      );
      expect(
        PandaliveRoomParser.chatGrantOf(
          _member(),
          PandaliveRoomParser.play(
            _play(media: _media(), playlist: {'hls': <Object?>[]}, channel: 'abc'),
            member: _member(),
          ),
        )!.channel,
        '$_index',
        reason: "a channel that is not a number is the broadcaster's own number",
      );
      expect(
        PandaliveRoomParser.chatGrantOf(
          _member(),
          PandaliveRoomParser.play(
            _play(media: _media(), playlist: {'hls': <Object?>[]}, channel: 9),
            member: _member(),
          ),
        )!.channel,
        '$_index',
      );
      expect(
        PandaliveRoomParser.chatGrantOf(
          _member(),
          PandaliveRoomParser.play(_play(result: false, code: 'needLogin'), member: _member()),
        ),
        isNull,
      );
      expect(
        PandaliveRoomParser.chatGrantOf(
          _member(),
          PandaliveRoomParser.play(_play(media: _media({'isLive': false})), member: _member()),
        ),
        isNull,
      );
    });

    test('the first usable IVS master of hls3, hls2, hls', () {
      Uri? of(Map<String, Object?> playlist) => PandaliveRoomParser.masterUrl(PandaliveJson.object(playlist, 'x'));
      expect(of({}), isNull, reason: 'no list at all is not an error, it is nothing to play');
      expect(of({'hls': <Object?>[]}), isNull);
      expect(
        of({
          'hls': [
            {'url': ''},
            {'other': 1},
          ],
        }),
        isNull,
        reason: 'an entry without a url says nothing',
      );
      expect(
        of({
          'hls': [
            {'url': _ivs('a')},
          ],
        }),
        Uri.parse(_ivs('a')),
      );
      expect(
        of({
          'hls': [
            {'url': 'https://cdn.example.com/a.m3u8'},
          ],
          'hls2': [
            {'url': _ivs('b')},
          ],
        }),
        isNotNull,
        reason: 'a foreign master is passed over for the next list',
      );
      expect(
        of({
          'hls3': [
            {'url': _ivs('high')},
          ],
          'hls': [
            {'url': _ivs('low')},
          ],
        }).toString(),
        contains('high'),
      );
      expect(_failure(() => of({'hls': 'not a list'})).message, contains('PlayList.hls'));
      expect(
        _failure(
          () => of({
            'hls': ['not an object'],
          }),
        ).message,
        contains('item'),
      );
      expect(
        _failure(
          () => of({
            'hls': [
              {'url': 'ftp://d1.ivs.live-video.net/a.m3u8'},
            ],
          }),
        ).message,
        contains('is not an IVS playlist'),
      );
      expect(
        _failure(
          () => of({
            'hls': [
              for (var i = 0; i < 17; i++) {'url': _ivs('p$i')},
            ],
          }),
        ).message,
        contains('PlayList.hls'),
      );
      expect(_kindOf(() => PandaliveRoomParser.mediaUrl('https://d1.ivs.live-video.net/a.m3u8')), isNull);
      for (final url in [
        '',
        'https://d1.ivs.live-video.net/a.m3u8 x',
        'https://d1.ivs.live-video.net/a.mp4',
        'http://d1.ivs.live-video.net/a.m3u8',
        'https://live-video.net/a.m3u8',
        'https://u@e.ivs.live-video.net/a.m3u8',
        'https://d1.ivs.live-video.net/a.m3u8#f',
        'https://d1.ivs.live-video.net/${'a' * 65600}.m3u8',
      ]) {
        expect(PandaliveRoomParser.mediaUrl(url), isNull, reason: url.length > 60 ? 'a very long address' : url);
      }
    });

    test('what room entry keeps for the player', () {
      ({LiveRoom room, PandaliveFailure? unavailable}) entry(PandalivePlay play, {PandaliveMember? member}) =>
          PandaliveRoomParser.playRoom(member ?? _member(media: _media()), play);
      final ended = entry(const PandalivePlay.refused('castEnd'));
      expect(ended.room.broadcast.liveStatus, LiveStatus.offline);
      expect(ended.unavailable?.message, 'live/play: castEnd');
      final adult = entry(const PandalivePlay.refused('needAdult'));
      expect(adult.room.broadcast.liveStatus, LiveStatus.live, reason: 'the room is on air, we just cannot watch');
      expect(adult.room.broadcast.restriction, LiveRestriction.adult);
      expect(adult.room.content.notice, PandaliveEndpoints.adultNotice);
      expect(adult.unavailable?.message, 'live/play: needAdult (adult)');
      final bare = entry(const PandalivePlay.refused(''));
      expect(bare.unavailable?.message, 'live/play: refused (unplayable)');
      expect(entry(const PandalivePlay.refused('needLogin')).room.broadcast.restriction, LiveRestriction.needsLogin);
      final notLive = entry(PandaliveRoomParser.play(_play(media: _media({'isLive': false})), member: _member()));
      expect(notLive.room.broadcast.liveStatus, LiveStatus.offline);
      expect(notLive.unavailable?.message, 'live/play: not live');
      final noHls = entry(
        PandaliveRoomParser.play(
          _play(media: _media(), playlist: {'hls': <Object?>[]}),
          member: _member(),
        ),
      );
      expect(noHls.room.broadcast.liveStatus, LiveStatus.live);
      expect(noHls.room.broadcast.restriction, LiveRestriction.unplayable);
      expect(noHls.unavailable?.message, 'live/play: no HLS');
      final playable = entry(
        PandaliveRoomParser.play(
          _play(
            media: _media(),
            playlist: {
              'hls': [
                {'url': _ivs('master')},
              ],
            },
          ),
          member: _member(),
        ),
      );
      expect(playable.room.broadcast.restriction, LiveRestriction.none);
      expect(playable.unavailable, isNull, reason: 'the master has the last word');
    });
  });

  group('the pages', () {
    test('the paging must be the page that was asked for', () {
      (List<Object?>, bool, int?) of(Map<String, dynamic> data, {int page = 2, int size = 30}) =>
          PandaliveRoomParser.rows(data, page: page, size: size, what: 'live/index');
      expect(
        of(PandaliveJson.object(jsonDecode(_page(const <Object?>[], page: 2, total: 100)), 'x')).$2,
        isTrue,
        reason: 'thirty read of a hundred is not the end, even when the page came back empty',
      );
      final ok = PandaliveJson.object(jsonDecode(_page([_media()], page: 2, total: 100)), 'x');
      expect(of(ok).$1, hasLength(1));
      expect(of(ok).$3, 100);
      expect(of(ok).$2, isTrue);
      List<Map<String, dynamic>> full() => [
        for (var i = 0; i < 30; i++) _media({'userId': 'user_$i'}),
      ];
      expect(
        of(PandaliveJson.object(jsonDecode(_page(full(), page: 2, total: 60)), 'x')).$2,
        isFalse,
        reason: 'the rows read so far reach the total',
      );
      expect(
        of(PandaliveJson.object(jsonDecode(_page(full(), page: 2, total: 61)), 'x')).$2,
        isTrue,
        reason: 'one row short of the total still has a next page',
      );
      expect(_failure(() => of({'page': null})).message, contains('for offset 30, limit 30'));
      expect(
        _failure(
          () => of({
            'page': {'offset': 0, 'limit': 30, 'page': 2, 'total': 9},
          }),
        ).message,
        contains('offset 30'),
      );
      expect(
        _failure(
          () => of({
            'page': {'offset': 30, 'limit': 20, 'page': 2, 'total': 9},
          }),
        ).message,
        contains('page'),
      );
      expect(
        _failure(
          () => of({
            'page': {'offset': 30, 'limit': 30, 'page': 3, 'total': 9},
          }),
        ).message,
        contains('page'),
      );
      expect(
        _failure(
          () => of({
            'page': {'offset': 30, 'limit': 30, 'page': 2},
          }),
        ).message,
        contains('total'),
      );
      expect(
        _failure(
          () => of({
            'page': {'offset': 30, 'limit': 30, 'page': 2, 'total': -1},
          }),
        ).message,
        contains('total'),
      );
      expect(
        _failure(
          () => of({
            'page': {'offset': 30, 'limit': 30, 'page': 2, 'total': 9},
            'list': <Object?>{},
          }),
        ).message,
        contains('64 rows'),
      );
      expect(
        _failure(
          () => of({
            'page': {'offset': 30, 'limit': 30, 'page': 2, 'total': 9},
            'list': [for (var i = 0; i < 65; i++) _media()],
          }),
        ).message,
        contains('64 rows'),
      );
    });

    test('a page of live cards is read row by row, one per broadcaster', () {
      final body = _page([
        _media(),
        _media({'userId': _id.toUpperCase(), 'title': '重复的'}),
        _media({'userId': 'other_1'}),
        _media({'isLive': false}),
        {'no_user': 1},
        'not a row',
      ], total: 30);
      final page = PandaliveRoomParser.livePage(body, page: 1);
      expect(page.rooms.map((room) => room.roomId), [_id, 'other_1']);
      expect(page.hasMore, isTrue, reason: 'six rows read of the thirty the page claims');
      expect(page.total, 30);
      expect(
        _kindOf(() => PandaliveRoomParser.livePage(jsonEncode({'result': false, 'message': 'x'}), page: 1)),
        PandaliveFailureKind.apiChanged,
      );
      expect(_kindOf(() => PandaliveRoomParser.livePage('{}', page: 1, status: 500)), PandaliveFailureKind.network);
    });

    test('a page of broadcasters keeps the offline ones', () {
      final body = _page(
        [
          {'userId': _id, 'userIdx': _index, 'userNick': '甲'},
          {
            'userId': 'other_1',
            'userIdx': 7,
            'media': _media({'userId': 'other_1', 'userIdx': 7}),
          },
          {'userId': 'bad id!', 'userIdx': 7},
          {'blockService': true, 'userId': 'x', 'userIdx': 8},
        ],
        size: 10,
        total: 40,
      );
      final page = PandaliveRoomParser.broadcasterPage(body, page: 1, size: 10);
      expect(page.rooms.map((room) => room.roomId), [_id, 'other_1']);
      expect(page.rooms.first.broadcast.liveStatus, LiveStatus.offline);
      expect(page.rooms[1].broadcast.liveStatus, LiveStatus.live);
      expect(page.hasMore, isTrue);
      expect(page.total, 40);
    });
  });

  group('the IVS master and its qualities', () {
    final issued = DateTime.utc(2026, 10, 1, 4);

    List<PandaliveStream> read(List<String> variants, {Uri? master}) => PandaliveRoomParser.qualities(
      _manifest(variants),
      master: master ?? _masterUrl(),
      userId: _id,
      issuedAt: issued,
    );

    test('the master answer is read whole, or not at all', () {
      expect(PandaliveRoomParser.master('#EXTM3U'), '#EXTM3U');
      expect(_failure(() => PandaliveRoomParser.master('x', status: 404)).kind, PandaliveFailureKind.streamUnavailable);
      expect(_failure(() => PandaliveRoomParser.master('x', status: 404)).message, contains('HTTP 404'));
      expect(_failure(() => PandaliveRoomParser.master('x', status: 400)).message, contains('HTTP 400'));
      expect(_kindOf(() => PandaliveRoomParser.master('x', status: 403)), PandaliveFailureKind.riskControl);
      expect(
        _kindOf(() => PandaliveRoomParser.master('x' * (PandaliveEndpoints.manifestLimit + 1))),
        PandaliveFailureKind.apiChanged,
      );
      expect(PandaliveEndpoints.manifestLimit, 1024 * 1024);
    });

    test('one stream per video variant, best first', () {
      final streams = read([
        _streamInf(height: 720, bandwidth: 1000000, path: 'a'),
        _streamInf(height: 1080, bandwidth: 3000000, frameRate: 59.94, path: 'b'),
        _streamInf(height: 1080, frameRate: 59.94, path: 'c'),
        _streamInf(height: 360, bandwidth: 500000, path: 'd', video: 'chunked'),
      ]);
      expect(streams.map((entry) => entry.quality.qualityId), ['360p', '1080p60', '1080p60_3', '720p']);
      expect(streams.first.quality.label, '原画', reason: 'the source rendition is named, not numbered');
      expect(streams[1].quality.label, '1080p60');
      expect(streams.first.quality.platformOrder, 4, reason: 'best first, and the order counts down');
      expect(streams[1].quality.platformOrder, 3);
      expect(streams[1].quality.codec, LiveStreamCodec.avc);
      expect(
        streams.first.line.url,
        'https://d123.ivs.live-video.net/iv/v1/playlist/d.m3u8?token=abc',
        reason: 'a relative variant is resolved against the master',
      );
      expect(streams.first.line.format, LiveStreamFormat.hls);
      expect(streams.first.line.lineLabel, PandaliveEndpoints.lineLabel);
      expect(streams.first.line.headers['referer'], 'https://www.pandalive.co.kr/play/$_id');
      expect(streams.first.line.headers['origin'], PandaliveEndpoints.origin);
      expect(streams.first.line.lease?.refreshAt, issued.add(const Duration(minutes: 30)));
      expect(
        streams.first.line.lease?.requiresReconnect,
        isTrue,
        reason: 'a new playlist must be swapped in by reconnecting',
      );
      expect(streams.first.line.lease?.expiresAt, isNull, reason: 'the token is opaque, so its end is unknown');
      expect(streams.first.line.geometry.height, 360);
      expect(streams.first.line.geometry.frameRate, isNull);
      expect(streams.first.line.geometry.bitrateKbps, 500);
      expect(streams[1].line.geometry.frameRate, 60);
      expect(streams[1].line.geometry.width, isNull, reason: 'the master names no width');
      expect(
        PandaliveRoomParser.qualities(
          _manifest([_streamInf(height: 1080, codecs: 'hvc1.1.6.L93.90', path: 'e')]),
          master: _masterUrl(),
          userId: _id,
          issuedAt: issued,
        ).single.quality.codec,
        LiveStreamCodec.hevc,
      );
    });

    test('what a variant can lose, and what the master cannot survive', () {
      expect(
        read([_streamInf(height: 720, path: 'a'), _streamInf(height: 0, bandwidth: 9, path: 'z')])
            .map((entry) => entry.quality.qualityId),
        ['720p'],
        reason: 'a variant with no resolution is left out without a word',
      );
      expect(
        read([_streamInf(height: 720, path: 'a'), _streamInf(height: 100000, path: 'b')])
            .map((entry) => entry.quality.qualityId),
        ['720p'],
      );
      expect(
        _failure(() => read(['#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280x720,FRAME-RATE=300\nb.m3u8'])).message,
        contains('frame rate 300'),
        reason: 'a master whose only variant runs at three hundred frames has nothing left',
      );
      expect(
        read([
          _streamInf(height: 720, path: 'a'),
          '#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280x720,FRAME-RATE=300\nb.m3u8',
        ]).map((entry) => entry.quality.qualityId),
        ['720p'],
        reason: 'among usable variants an impossible frame rate only loses itself',
      );
      expect(
        _failure(() => read(['#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280x720\n'])).message,
        contains('no video variant'),
        reason: 'a tag with no address is not a variant the reader counts as broken',
      );
      expect(
        _failure(() => read([_streamInf(height: 720, path: 'https://cdn.example.com/a.m3u8')])).message,
        contains('not an IVS playlist'),
      );
      expect(
        _kindOf(
          () => PandaliveRoomParser.qualities(
            '#EXTM3U\n#EXTINF:4\nx.ts\n#EXT-X-ENDLIST',
            master: _masterUrl(),
            userId: _id,
            issuedAt: issued,
          ),
        ),
        PandaliveFailureKind.apiChanged,
        reason: 'a media playlist is not a master',
      );
      expect(
        _failure(
          () => PandaliveRoomParser.qualities(
            _manifest([_streamInf(height: 720, path: 'a')]),
            master: Uri.parse('https://cdn.example.com/a.m3u8'),
            userId: _id,
            issuedAt: issued,
          ),
        ).message,
        contains('is not an IVS playlist'),
      );
    });

    test('the lease, the legacy ids and the line of a quality', () {
      final lease = PandaliveRoomParser.lease(DateTime.utc(2026));
      expect(lease.refreshAt, DateTime.utc(2026).add(const Duration(minutes: 30)));
      expect(lease.requiresReconnect, isTrue);
      for (final (legacy, now) in [
        ('1080p30', '1080p'),
        (' 720p30_2 ', '720p_2'),
        ('1080p60', '1080p60'),
        ('720p', '720p'),
        ('auto', 'auto'),
        ('p30', 'p30'),
      ]) {
        expect(PandaliveRoomParser.qualityIdFromLegacy(legacy), now, reason: legacy);
      }
      final streams = read([_streamInf(height: 720, path: 'a'), _streamInf(height: 360, path: 'b')]);
      final data = PandaliveStreamData(userId: _id, userIndex: _index, entries: streams);
      expect(PandaliveRoomParser.line(data, streams.first.quality).url, streams.first.line.url);
      expect(
        PandaliveRoomParser.line(data, LivePlayQuality.of(label: '720p', qualityId: '720p30')).url,
        streams.first.line.url,
        reason: 'an older preference is read as the new id',
      );
      expect(
        _failure(() => PandaliveRoomParser.line(data, LivePlayQuality.of(label: '480p', qualityId: '480p'))).message,
        contains('quality 480p is not offered'),
      );
      expect(
        _kindOf(() => PandaliveRoomParser.line(data, LivePlayQuality.of(label: 'x'))),
        PandaliveFailureKind.streamUnavailable,
        reason: 'a quality with no id names nothing',
      );
      final empty = PandaliveStreamData(
        userId: _id,
        userIndex: _index,
        unavailable: const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'live/play: no HLS'),
      );
      expect(empty.qualities, isEmpty);
      expect(
        _failure(() => PandaliveRoomParser.line(empty, LivePlayQuality.of(label: 'x', qualityId: '720p'))).message,
        'live/play: no HLS',
      );
      expect(
        () => PandaliveStreamData(userId: _id, userIndex: _index),
        throwsA(isA<AssertionError>()),
        reason: 'an empty playback must say why',
      );
    });
  });
}
