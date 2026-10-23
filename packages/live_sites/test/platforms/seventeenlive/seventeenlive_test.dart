import 'dart:convert';
import 'dart:io' show gzip;

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_hot_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_http.dart';
import 'package:live_sites/src/platforms/seventeenlive/danmaku/seventeenlive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/seventeenlive/danmaku/seventeenlive_danmaku_session.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_json.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_play_parser.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_room_parser.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_site.dart';
import 'package:test/test.dart';

// The test doubles spell their class name in their one constructor; the
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One request as the fake transport records it.
typedef _Seen = ({String method, Uri url, Map<String, String> headers, String body});

/// The room of the tests: a `liveStreamID` as the platform writes it.
const String _room = '123456789';

/// The broadcaster's UUID, which names the pull streams.
const String _user = '0f6d3a1c-2b4e-5c7a-9d1f-3e5b7a9c1d2f';

/// Another room, for the rules that need a second one.
const String _other = '987654321';

/// The fixed clock of the frames: the capture hour of the platform's samples.
final DateTime _at = DateTime.utc(2026, 9, 30, 12);

String _json(Object? value) => jsonEncode(value);

/// An answer as the codec's reader takes it: a raw frame text.
String _frame(Object? value) => _json(value);

/// A live pull URL of [cdn] for the quality field [field].
String _pull(String cdn, String field) => 'https://$cdn-pull-rtmp-1.17app.co/live/$_user/$field.flv';

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $right'));

/// The stream object the platform answers: a section row, a search row or the
/// room itself, with the fields each of them carries.
Map<String, Object?> _streamJson({
  Object? liveId,
  String userId = _user,
  Object? owner = _room,
  String nick = 'Ann',
  String? openId,
  String title = 'Evening live',
  String avatar = 'https://cdn.17app.co/a.jpg',
  String cover = 'https://cdn.17app.co/c.jpg',
  String bio = 'hello',
  Object? followers = 321,
  Object? online = 144,
  Object? total = 900,
  int status = 2,
  Object? beginTime = 1759000000,
  Object? premium,
  Object? audioOnly = 0,
  Object? pull,
  Object? rtmpUrls,
}) => {
  'liveStreamID': liveId ?? int.parse(_room),
  'userID': userId,
  'status': status,
  'caption': title,
  'coverPhoto': cover,
  'audioOnly': ?audioOnly,
  'beginTime': ?beginTime,
  'premiumContent': ?premium,
  'liveViewerCount': ?online,
  'viewerCount': ?total,
  'userInfo': {
    'roomID': ?owner,
    'userID': userId,
    'displayName': nick,
    'openID': ?openId,
    'picture': avatar,
    'bio': bio,
    'followerCount': ?followers,
  },
  'pullURLsInfo': ?pull,
  'rtmpUrls': ?rtmpUrls,
};

/// `pullURLsInfo` of the given providers.
Map<String, Object?> _pullInfo(Object? providers) => {'rtmpURLs': providers};

/// A provider answering the quality fields [fields] (`{'url': '…'}`). Its URLs
/// name the CDN, which is all the parser reads of the provider.
Map<String, Object?> _provider(Map<String, String> fields) => {'providerId': 1, ...fields};

/// A sections answer: [sections] as its `sections`, with the page's [cursor].
String _sections(List<Object?> sections, {Object? cursor}) => _json({'sections': sections, 'cursor': ?cursor});

/// One section: `id` and the streams of its grids.
Map<String, Object?> _section(String id, List<Object?> streams) => {
  'id': id,
  'grids': [
    for (final stream in streams)
      if (stream == null) <String, Object?>{} else {'stream': stream},
  ],
};

/// The `lives/<id>` answer of [fields].
String _lives(Map<String, Object?> fields) => _json(fields);

/// The room answer of the tests: a live room with one Tencent provider and the
/// four qualities, each with a URL of its own.
String _roomAnswer({
  int status = 2,
  Object? premium,
  Object? pull,
  Object? rtmpUrls,
  Object? audioOnly = 0,
  Object? online = 144,
  Object? total = 900,
  bool noPull = false,
}) => _lives(
  _streamJson(
    status: status,
    premium: premium,
    audioOnly: audioOnly,
    online: online,
    total: total,
    pull: noPull ? null : (pull ?? _pullInfo([_provider(_fields('tencent'))])),
    rtmpUrls: rtmpUrls,
  ),
);

/// Every quality field of [SeventeenLiveEndpoints.qualityFields] with its own
/// pull URL on [cdn], as one provider answers them.
Map<String, String> _fields(String cdn) => {
  for (final entry in SeventeenLiveEndpoints.qualityFields.entries)
    for (final field in entry.value) field: _pull(cdn, '${entry.key}-$field'),
};

/// A gzip+base64 chat payload, as the website's `gzip_base64` writes one.
String _payload(Object? value) => base64.encode(gzip.encode(utf8.encode(jsonEncode(value))));

/// An Ably `MESSAGE` (15) frame of the room's channel holding [payloads].
String _messageFrame(List<Object?> payloads, {String channel = _room, Object? serial, Object? id}) => _frame({
  'action': 15,
  'channel': channel,
  'channelSerial': ?serial,
  'id': ?id,
  'timestamp': _at.millisecondsSinceEpoch,
  'messages': payloads,
});

/// One Ably message of a `MESSAGE` frame.
Map<String, Object?> _ablyMessage(Object? payload, {String? id, int? timestamp}) => {
  'data': _payload(payload),
  'id': ?id,
  'timestamp': ?timestamp,
};

/// The decoded payload of a comment, a gift, the live figures or a stream end.
Map<String, Object?> _comment({
  String content = 'hi',
  String text = 'hi',
  String name = 'Ann',
  String userId = 'u1',
  int? level,
  int? sendTime,
  String? color,
  String? nameColor,
  String? background,
  bool barrageStyle = false,
  int? point,
  bool? dirty,
  Object? picture,
  Object? badges,
}) => {
  'type': SeventeenLiveDanmakuCodec.commentType,
  'commentMsg': {
    'content': content,
    'comment': {'text': text, 'textColor': ?color},
    'displayUser': {'displayName': name, 'userID': userId, 'level': ?level, 'picture': ?picture},
    'sendTime': ?sendTime,
    'name': ?(nameColor == null ? null : {'textColor': nameColor}),
    'backgroundColor': ?background,
    'prefixBadges': ?badges,
    'barrageStyle': ?(barrageStyle ? true : null),
    'barrage': ?(point == null ? null : {'point': point}),
    'isDirty': ?dirty,
  },
};

Map<String, Object?> _giftMsg({
  String giftId = '2609_jp_cp_akanya',
  int? point,
  int? count,
  int? window,
  String? target,
}) => {
  'type': SeventeenLiveDanmakuCodec.giftType,
  'giftMsg': {
    'giftID': giftId,
    'point': ?point,
    'displayUser': {'displayName': 'Ann', 'userID': 'u1', 'level': 7},
    'giftMetas': [
      {
        'targetGiftID': ?target,
        'combo': {'count': ?count, 'validDurationMs': ?window},
      },
    ],
  },
};

Map<String, Object?> _figures({int? viewers, bool? mute}) => {
  'type': SeventeenLiveDanmakuCodec.liveType,
  'liveinfo': {'liveViewerCount': ?viewers, 'mute': ?mute},
};

/// An adapter over [onSend], with the transport it records on and a fixed clock.
({SeventeenLiveSite site, _FakeHttp http}) _adapter(
  LiveResponse Function(_Seen request) onSend, {
  bool Function()? preferH264,
}) {
  final http = _FakeHttp(onSend);
  return (site: SeventeenLiveSite(http: SeventeenLiveHttp(http), preferH264: preferH264), http: http);
}

/// The fake transport: every site and chat request goes through [onSend].
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

  final LiveResponse Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    sent.add((
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: request.body ?? utf8.decode(request.bodyBytes ?? const <int>[]),
    ));
    return onSend(sent.last);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

void main() {
  group('answers, ids and readers', () {
    test("a status names its own failure and the platform's own answer wins", () {
      expect(statusFailure(200, 'anything', 'lives/x'), isNull);
      // REG-17LIVE-004: an unknown room is HTTP 520 `stream not found`.
      expect(
        statusFailure(520, '{"errorMessage":"stream not found"}', 'lives/x')?.kind,
        SeventeenLiveFailureKind.notFound,
      );
      expect(statusFailure(404, '{}', 'lives/x')?.kind, SeventeenLiveFailureKind.notFound);
      expect(statusFailure(400, '{}', 'x')?.kind, SeventeenLiveFailureKind.apiChanged);
      // HTTP 420 `errorCode` 7 is a refused parameter, not a throttle.
      expect(statusFailure(420, '{"errorCode":7}', 'x')?.kind, SeventeenLiveFailureKind.apiChanged);
      expect(statusFailure(401, '{}', 'x')?.kind, SeventeenLiveFailureKind.riskControl);
      expect(statusFailure(403, '{}', 'x')?.kind, SeventeenLiveFailureKind.riskControl);
      expect(statusFailure(429, '{}', 'x')?.kind, SeventeenLiveFailureKind.rateLimited);
      expect(statusFailure(500, '{}', 'x')?.kind, SeventeenLiveFailureKind.network);
      // A redirect is never followed, so it is a network failure.
      expect(statusFailure(302, '{}', 'x')?.kind, SeventeenLiveFailureKind.network);
      expect(statusFailure(520, 'not json', 'x')?.kind, SeventeenLiveFailureKind.network);
      expect(errorMessage('{"errorMessage":"  padded  "}'), 'padded');
      expect(errorMessage('x' * 70000), isNull);
    });

    test('the failure kinds reach the closest contract error', () {
      const site = seventeenliveSiteId;
      for (final kind in SeventeenLiveFailureKind.values) {
        final error = SeventeenLiveFailure(kind, 'text').toLiveSiteError(site);
        expect(error.siteId, site);
        expect(error.message, 'text');
      }
      expect(
        const SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'x').toLiveSiteError(site),
        isA<LiveSiteParseError>(),
      );
      expect(
        const SeventeenLiveFailure(SeventeenLiveFailureKind.riskControl, 'x').toLiveSiteError(site),
        isA<LiveSiteRateLimitError>(),
      );
      expect(
        const SeventeenLiveFailure(SeventeenLiveFailureKind.chatRefused, 'x').toLiveSiteError(site),
        isA<LiveSiteUnsupported>(),
      );
      expect(
        const SeventeenLiveFailure(SeventeenLiveFailureKind.streamUnavailable, 'x').toLiveSiteError(site),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test("an answer is read once, and its size and shape are the platform's", () {
      expect(decode('{"a":1}', what: 'x'), {'a': 1});
      expect(() => decode('nope', what: 'x'), throwsA(predicate((e) => '$e'.contains('x: not JSON'))));
      expect(() => decode('{"a":"${'y' * 4200000}"}', what: 'x'), throwsA(predicate((e) => '$e'.contains('over'))));
      expect(() => decode('{}', what: 'x', status: 429), throwsA(isA<SeventeenLiveFailure>()));
      expect(() => object('[]', 'x'), throwsA(isA<SeventeenLiveFailure>()));
      expect(optionalObject('[]'), isNull);
      expect(optionalList(null), isEmpty);
    });

    test('a room id is 1 to 12 digits with no leading zero', () {
      for (final ok in [_room, '1', '987654321', ' 123456789 ']) {
        expect(SeventeenLiveRoomParser.normalizeRoomId(ok), ok.trim(), reason: ok);
      }
      for (final bad in ['', '0', '012345', 'a12345', '1234567890123', '1.5']) {
        expect(SeventeenLiveRoomParser.normalizeRoomId(bad), isNull, reason: bad);
      }
    });

    test('a directory cursor is refused before any request', () {
      SeventeenLiveRoomParser.checkCursor(null);
      for (final bad in ['', 'x' * 513, 'a\u0000b']) {
        expect(() => SeventeenLiveRoomParser.checkCursor(bad), throwsA(isA<SeventeenLiveFailure>()), reason: bad);
      }
      expect(() => SeventeenLiveRoomParser.checkCursor('x' * 512), returnsNormally);
    });

    test('a beginTime outside 2000–2100 is not read', () {
      expect(
        SeventeenLiveRoomParser.startTime(1759000000),
        DateTime.fromMillisecondsSinceEpoch(1759000000000, isUtc: true),
      );
      for (final bad in [null, '', 946684799, 4102444801, 1759000000.5, '1759000000', -1]) {
        expect(SeventeenLiveRoomParser.startTime(bad), isNull, reason: '$bad');
      }
    });

    test('a count and a text say what they mean', () {
      expect(count(0), 0);
      expect(count('12'), 12);
      expect(count(-1), isNull);
      expect(isBadCount(-1), isTrue);
      expect(isBadCount(null), isFalse);
      expect(isBadCount('x'), isTrue);
      expect(text('  hi  '), 'hi');
      expect(text(7), '');
      expect(isBadText(7), isTrue);
      expect(isBadText(''), isFalse);
      expect(isBadText('x' * 131073), isTrue);
      expect(requiredText(' name '), 'name');
      expect(requiredText('   '), isNull);
      expect(positiveId(123456789), '123456789');
      expect(positiveId(0), isNull);
      expect(integer('42'), 42);
    });

    test("only the platform's picture hosts over https are kept", () {
      for (final ok in [
        'https://cdn.17app.co/a.jpg',
        'https://assets-17app.akamaized.net/b.png',
        'http://cdn.17app.co/c.jpg',
        'a/b.png',
        '/THUMBNAIL_x.jpg',
      ]) {
        final url = image(ok);
        expect(url, startsWith('https://'), reason: ok);
      }
      expect(image('http://cdn.17app.co/c.jpg'), 'https://cdn.17app.co/c.jpg');
      expect(image('a/b.png'), 'https://cdn.17app.co/a/b.png');
      for (final bad in [
        '',
        'https://evil.com/a.jpg',
        'https://cdn.17app.co.evil.com/a.jpg',
        '../a.jpg',
        'https://user:***@cdn.17app.co/a.jpg',
        'https://cdn.17app.co/a.jpg#frag',
        'file:///a.jpg',
        7,
        'x' * 8193,
      ]) {
        expect(image(bad), '', reason: '$bad');
      }
    });

    test('the keyword rules of the search: a colon is text, a scheme is not', () {
      expect(SeventeenLiveRoomParser.isUrl('https://17.live/en/live/1'), isTrue);
      expect(SeventeenLiveRoomParser.isUrl('Re:Zero'), isFalse);
      expect(SeventeenLiveRoomParser.isUrl('  http://x'), isTrue);
      expect(SeventeenLiveRoomParser.searchKeyword('  Re:Zero  '), 'Re:Zero');
      expect(SeventeenLiveRoomParser.searchKeyword('x' * 50), 'x' * 50);
      expect(SeventeenLiveRoomParser.searchKeyword('y' * 120), 'y' * 100);
      // Cut at 100 code units, never between the halves of a surrogate pair.
      final pair = '${'z' * 99}\u{1F600}';
      expect(SeventeenLiveRoomParser.searchKeyword(pair), 'z' * 99);
      // A cut that lands right after a whole pair keeps it: 98 + 2 = 100 units.
      expect(SeventeenLiveRoomParser.searchKeyword('${'z' * 98}\u{1F600}x'), '${'z' * 98}\u{1F600}');
    });
  });

  group('sections directory', () {
    test('a live row is a card with the notice, the audience and the link', () {
      final page = SeventeenLiveRoomParser.sectionsPage(
        _sections([
          _section('Hot', [_streamJson()]),
        ], cursor: 'next'),
      );
      expect(page.rooms, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'next');
      final room = page.rooms.single;
      expect(room.platform, '17live');
      expect(room.roomId, _room);
      expect(room.content.title, 'Evening live');
      expect(room.content.coverUrl, 'https://cdn.17app.co/c.jpg');
      expect(room.content.notice, SeventeenLiveEndpoints.ageNotice);
      expect(room.anchor?.anchorId, _user);
      expect(room.anchor?.name, 'Ann');
      expect(room.anchor?.followerCount, 321);
      expect(room.area?.areaName, '');
      expect(room.audience.onlineViewers, 144);
      expect(room.audience.totalViewers, 900);
      expect(room.audience.primaryMetric?.name, 'onlineViewers');
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect(room.broadcast.isLiveNow, isTrue);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1759000000000, isUtc: true));
      expect(room.broadcast.effectiveRestriction, LiveRestriction.none);
      expect(room.links.webUrl, 'https://17.live/en/live/$_room');
    });

    test('an empty title is the name, an audio room names itself, no owner reads', () {
      final page = SeventeenLiveRoomParser.sectionsPage(
        _sections([
          _section('Hot', [_streamJson(title: '   ', audioOnly: 1, owner: null)]),
        ]),
      );
      expect(page.rooms.single.content.title, 'Ann');
      expect(page.rooms.single.area?.areaName, SeventeenLiveEndpoints.audioRoom);
    });

    test('banner, archive and vod sections are skipped', () {
      final page = SeventeenLiveRoomParser.sectionsPage(
        _sections([
          for (final id in SeventeenLiveEndpoints.skippedSections) _section(id, [_streamJson()]),
          _section('Live', [_streamJson()]),
        ]),
      );
      expect(page.rooms, hasLength(1));
    });

    test('a row that is not live, unreadable or repeated is not a card', () {
      final page = SeventeenLiveRoomParser.sectionsPage(
        _sections([
          _section('Live', [
            _streamJson(status: 0),
            _streamJson(status: 3),
            _streamJson(liveId: 0),
            _streamJson(owner: _other),
            _streamJson(nick: ''),
            _streamJson(userId: ''),
            _streamJson(followers: -1),
            <String, Object?>{},
            null,
            _streamJson(),
            _streamJson(),
          ]),
        ]),
      );
      expect(page.rooms, hasLength(1));
    });

    test('a section or grid of the wrong shape only loses itself', () {
      final page = SeventeenLiveRoomParser.sectionsPage(
        _sections([
          'not a section',
          {'id': 'Live', 'grids': 'not a list'},
          {
            'id': 'Live',
            'grids': [
              'not a grid',
              {'noStream': 1},
              {'stream': 'not a stream'},
            ],
          },
          _section('Live', [_streamJson()]),
        ]),
      );
      expect(page.rooms, hasLength(1));
    });

    test("the next cursor is empty, repeated or the answer's own", () {
      final rows = _sections([
        _section('Live', [_streamJson()]),
      ]);
      expect(SeventeenLiveRoomParser.sectionsPage(rows).nextCursor, isNull);
      expect(SeventeenLiveRoomParser.sectionsPage(rows).nextCursor, isNull);
      final withCursor = _sections([
        _section('Live', [_streamJson()]),
      ], cursor: 'p2');
      expect(SeventeenLiveRoomParser.sectionsPage(withCursor, cursor: 'p1').nextCursor, 'p2');
      // A cursor that repeats the one sent ends the list (the platform's own rule).
      expect(SeventeenLiveRoomParser.sectionsPage(withCursor, cursor: 'p2').nextCursor, isNull);
      expect(SeventeenLiveRoomParser.sectionsPage(withCursor, cursor: 'p2').hasMore, isFalse);
    });

    test('a cursor that cannot be sent is api-changed', () {
      for (final bad in [7, 'x' * 513, 'a\u0001b']) {
        expect(
          () => SeventeenLiveRoomParser.sectionsPage(_sections([], cursor: bad)),
          throwsA(isA<SeventeenLiveFailure>()),
          reason: '$bad',
        );
      }
      expect(() => SeventeenLiveRoomParser.sectionsPage('{}'), throwsA(isA<SeventeenLiveFailure>()));
      expect(
        () => SeventeenLiveRoomParser.sectionsPage(_json({'sections': 'no list'})),
        throwsA(isA<SeventeenLiveFailure>()),
      );
      expect(SeventeenLiveRoomParser.sectionsPage(_sections([])).rooms, isEmpty);
    });

    test('the region of an area is the code sent, Japan for none', () {
      expect(SeventeenLiveEndpoints.regionFor(null), 'JP');
      expect(SeventeenLiveEndpoints.regionFor('  '), 'JP');
      expect(SeventeenLiveEndpoints.regionFor('tw'), 'TW');
      expect(SeventeenLiveEndpoints.regionFor('HK'), 'HK');
      expect(SeventeenLiveEndpoints.regionFor('US'), isNull);
      expect(SeventeenLiveEndpoints.areas.map((area) => area.areaId), ['JP', 'TW', 'HK']);
      expect(SeventeenLiveEndpoints.areas.first.parentAreaId, SeventeenLiveEndpoints.categoryId);
      expect(SeventeenLiveEndpoints.areas.first.areaName, '日本');
      final adapter = _adapter((_) => _resp(200, '{}'));
      expect(adapter.site.regionOf('jp'), 'JP');
      expect(() => adapter.site.regionOf('LoL'), throwsA(isA<SeventeenLiveFailure>()));
    });

    test("the sections query is the website's own hot tab", () {
      expect(SeventeenLiveEndpoints.sectionsQuery(null), {'count': '20', 'typeTab': '2', 'region': 'JP', 'cursor': ''});
      expect(SeventeenLiveEndpoints.sectionsQuery('p2', regionCode: 'TW')['cursor'], 'p2');
      expect(SeventeenLiveEndpoints.sectionsQuery('p2', regionCode: 'TW')['region'], 'TW');
      expect(SeventeenLiveEndpoints.sections(cursor: 'p2').query, contains('cursor=p2'));
      expect(SeventeenLiveEndpoints.lives(_room).path, '/api/v1/lives/$_room');
      expect(SeventeenLiveEndpoints.search('Re:Zero').queryParameters['query'], 'Re:Zero');
    });
  });

  group('search answer', () {
    test('a row must name its owner room and be live', () {
      final rooms = SeventeenLiveRoomParser.searchRooms(
        _json([
          _streamJson(),
          _streamJson(owner: null),
          _streamJson(owner: _other),
          _streamJson(status: 0),
          _streamJson(liveId: -1),
          'not a row',
          _streamJson(),
        ]),
      );
      expect(rooms, hasLength(1));
      expect(rooms.single.roomId, _room);
      expect(rooms.single.content.notice, SeventeenLiveEndpoints.ageNotice);
    });

    test('a search answer that is not a list is api-changed', () {
      expect(() => SeventeenLiveRoomParser.searchRooms('{}'), throwsA(isA<SeventeenLiveFailure>()));
      expect(SeventeenLiveRoomParser.searchRooms('[]'), isEmpty);
      expect(() => SeventeenLiveRoomParser.searchRooms('[]', status: 520), throwsA(isA<SeventeenLiveFailure>()));
    });
  });

  group('restrictions and locks', () {
    test('premiumType reads as the website locks it', () {
      expect(SeventeenLiveRoomParser.restrictionOf(null), LiveRestriction.none);
      expect(SeventeenLiveRoomParser.restrictionOf('x'), isNull);
      expect(SeventeenLiveRoomParser.restrictionOf({'premiumType': 0}), LiveRestriction.none);
      expect(SeventeenLiveRoomParser.restrictionOf({}), LiveRestriction.none);
      expect(SeventeenLiveRoomParser.restrictionOf({'premiumType': 1}), LiveRestriction.paid);
      expect(SeventeenLiveRoomParser.restrictionOf({'premiumType': 2}), LiveRestriction.subscribersOnly);
      expect(SeventeenLiveRoomParser.restrictionOf({'premiumType': 3}), LiveRestriction.unplayable);
      expect(SeventeenLiveRoomParser.restrictionOf({'premiumType': 99}), LiveRestriction.unplayable);
      // A viewer who paid sees the live; an anonymous one never did.
      expect(
        SeventeenLiveRoomParser.restrictionOf({
          'premiumType': 2,
          'paymentInfo': {'paid': true},
        }),
        LiveRestriction.none,
      );
      expect(SeventeenLiveRoomParser.restrictionOf({'premiumType': '1'}), LiveRestriction.paid);
    });

    test('a locked live stays live, is marked, and names why it is not played', () {
      final room = SeventeenLiveRoomParser.enteredRoom(_roomAnswer(premium: {'premiumType': 2}), roomId: _room);
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.subscribersOnly);
      final data = room.runtime.streamHandle! as SeventeenLiveRoomData;
      expect(data.qualities, isEmpty);
      expect(data.unavailable?.kind, SeventeenLiveFailureKind.streamUnavailable);
      expect('${data.unavailable}', contains('army members'));
      expect('${SeventeenLiveRoomParser.lockedLive(_room, LiveRestriction.paid)}', contains('premium'));
      expect('${SeventeenLiveRoomParser.lockedLive(_room, LiveRestriction.unplayable)}', contains('unplayable'));
    });

    test('a lock that cannot be read leaves the live playable', () {
      final room = SeventeenLiveRoomParser.enteredRoom(_roomAnswer(premium: 'garbage'), roomId: _room);
      final data = room.runtime.streamHandle! as SeventeenLiveRoomData;
      expect(data.qualities, isNotEmpty);
      expect(data.unavailable, isNull);
    });
  });

  group('room answer', () {
    test('the answer must be this room, and its owner', () {
      expect(SeventeenLiveRoomParser.refreshRoom(_roomAnswer(), roomId: _room).roomId, _room);
      final crossed = _streamJson();
      (crossed['userInfo']! as Map<String, Object?>)['userID'] = 'other-uuid';
      // Another room, another owner, no owner, or a broadcaster that is not the
      // owner's own is not this room.
      for (final bad in [
        _lives(_streamJson(liveId: int.parse(_other))),
        _lives(_streamJson(owner: _other)),
        _lives(_streamJson(owner: null)),
        _lives(crossed),
        '{"not":"an object"}',
      ]) {
        expect(
          () => SeventeenLiveRoomParser.refreshRoom(bad, roomId: _room),
          throwsA(predicate((e) => '$e'.contains('lives/$_room'))),
        );
      }
      // A section row needs no owner, and an answer with one still reads there.
      final row = SeventeenLiveRoomParser.sectionsPage(
        _sections([
          _section('Live', [_streamJson(owner: null)]),
        ]),
      ).rooms;
      expect(row.single.roomId, _room);
    });

    test('a field that is not what the platform writes leaves the room standing', () {
      final room = SeventeenLiveRoomParser.refreshRoom(
        _lives(_streamJson(nick: '', followers: -1, online: 'many', total: null, title: '', openId: 'ann_open')),
        roomId: _room,
      );
      expect(room.anchor?.name, 'ann_open');
      expect(room.anchor?.followerCount, isNull);
      expect(room.audience.onlineViewers, isNull);
      expect(room.audience.totalViewers, isNull);
      expect(room.content.title, 'ann_open');
      expect(room.broadcast.isLiveNow, isTrue);
    });

    test('an unknown state is unknown, never offline', () {
      final room = SeventeenLiveRoomParser.refreshRoom(_roomAnswer(status: 3), roomId: _room);
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.unknown);
      expect(room.broadcast.isExplicitlyOfflineNow, isFalse);
      final entered = SeventeenLiveRoomParser.enteredRoom(_roomAnswer(status: 3), roomId: _room);
      final data = entered.runtime.streamHandle! as SeventeenLiveRoomData;
      expect(data.unavailable?.kind, SeventeenLiveFailureKind.apiChanged);
      expect('${data.unavailable}', contains('status 3'));
    });

    test('an offline room is entered and says it has nothing to play', () {
      final entered = SeventeenLiveRoomParser.enteredRoom(
        _roomAnswer(status: 0, online: null, total: null),
        roomId: _room,
      );
      expect(entered.broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(entered.audience.onlineViewers, isNull);
      final data = entered.runtime.streamHandle! as SeventeenLiveRoomData;
      expect(data.unavailable?.kind, SeventeenLiveFailureKind.streamUnavailable);
      expect('${data.unavailable}', contains('offline'));
      expect((entered.runtime.danmakuHandle! as SeventeenLiveDanmakuArgs).roomId, _room);
    });

    test('a live without a pull URL, and one with unreadable pull data', () {
      final none = SeventeenLiveRoomParser.enteredRoom(_roomAnswer(noPull: true), roomId: _room);
      expect('${(none.runtime.streamHandle! as SeventeenLiveRoomData).unavailable}', contains('no pull URL'));
      final broken = SeventeenLiveRoomParser.enteredRoom(
        _roomAnswer(pull: _pullInfo(['not a provider'])),
        roomId: _room,
      );
      final failure = (broken.runtime.streamHandle! as SeventeenLiveRoomData).unavailable!;
      expect(failure.kind, SeventeenLiveFailureKind.apiChanged);
      expect('$failure', contains('no readable pull URL'));
      final notList = SeventeenLiveRoomParser.enteredRoom(_roomAnswer(pull: {'rtmpURLs': 'nope'}), roomId: _room);
      expect('${(notList.runtime.streamHandle! as SeventeenLiveRoomData).unavailable}', contains('rtmpURLs'));
    });
  });

  group('qualities and lines', () {
    test('every field of every provider is a line, best first and named', () {
      final data =
          SeventeenLiveRoomParser.enteredRoom(_roomAnswer(), roomId: _room).runtime.streamHandle!
              as SeventeenLiveRoomData;
      expect(data.qualities.map((quality) => quality.qualityId), ['source', 'enhanced', 'hd', 'h264']);
      expect(data.qualities.map((quality) => quality.label), ['原画 · FLV', '增强高清 · FLV', '高清 · FLV', 'H.264 · FLV']);
      expect(data.qualities.map((quality) => quality.platformOrder), [500, 400, 300, 200]);
      expect(data.qualities.last.codec, LiveStreamCodec.avc);
      expect(data.qualities.first.codec, isNull);
      expect(data.lines['source'], hasLength(3));
      expect(data.lines['hd'], hasLength(3));
      expect(data.lines['h264'], hasLength(1));
      final line = data.lines['hd']!.first;
      expect(line.format, LiveStreamFormat.flv);
      expect(line.formatSource.name, 'declared');
      expect(line.lineLabel, 'tencent');
      expect(line.headers['referer'], 'https://17.live/en/live/$_room');
      expect(line.headers['user-agent'], SeventeenLiveEndpoints.userAgent);
      expect(line.lease, isNull);
      expect(line.singleUse, isFalse);
    });

    test('rtmpUrls is the fallback root and a URL is listed once', () {
      final url = _pull('tencent', 'only');
      final room = SeventeenLiveRoomParser.enteredRoom(
        _roomAnswer(
          noPull: true,
          rtmpUrls: [
            _provider({'url': url}),
            _provider({'webUrl': url, 'url264': url}),
          ],
        ),
        roomId: _room,
      );
      final data = room.runtime.streamHandle! as SeventeenLiveRoomData;
      expect(data.qualities.map((quality) => quality.qualityId), ['hd', 'h264']);
      expect(data.lines['hd'], hasLength(1));
    });

    test('the H.264 transcode is never read from a CDN that does not serve it', () {
      final room = SeventeenLiveRoomParser.enteredRoom(
        _roomAnswer(pull: _pullInfo([_provider(_fields('wansu'))])),
        roomId: _room,
      );
      final data = room.runtime.streamHandle! as SeventeenLiveRoomData;
      expect(data.qualities.map((quality) => quality.qualityId), ['source', 'enhanced', 'hd']);
      expect(data.lines.containsKey('h264'), isFalse);
    });

    test('a broken provider only loses itself, and a tail past the limit is noted', () {
      final skipped = <String>[];
      final providers = [
        'not a provider',
        _provider({'url': 'https://evil.com/a.flv'}),
        for (var index = 0; index < 15; index++) _provider({'url': _pull('tencent', 'extra$index')}),
      ];
      final streams = SeventeenLivePlayParser.streams(
        _streamJson(pull: _pullInfo(providers)) as Map<String, dynamic>,
        roomId: _room,
        skipped: skipped,
      );
      expect(skipped, contains('provider 0 is not an object'));
      // A URL that is not one of the platform's is dropped quietly, as the
      // reference dropped it: only a field that is not text at all is noted.
      expect(skipped.any((note) => note.contains('not text')), isFalse);
      expect(skipped.any((note) => note.contains('providers over')), isTrue);
      expect(streams.qualities.single.qualityId, 'hd');
      expect(streams.lines['hd'], hasLength(14));
      expect(SeventeenLivePlayParser.streams(<String, dynamic>{}, roomId: _room).qualities, isEmpty);
      final notList = <String, dynamic>{'rtmpUrls': 'nope'};
      final quiet = <String>[];
      expect(SeventeenLivePlayParser.streams(notList, roomId: _room, skipped: quiet).qualities, isEmpty);
      expect(quiet.single, contains('rtmpURLs is not a list'));
    });

    test('a pull URL is https on a pull host with an flv path', () {
      expect(SeventeenLivePlayParser.pullUrl(_pull('tencent', 'a')), Uri.parse(_pull('tencent', 'a')));
      // http is upgraded (33-3), an explicit port is kept.
      expect(
        '${SeventeenLivePlayParser.pullUrl('http://tencent-pull-rtmp-1.17app.co/live/x.a.flv')}',
        'https://tencent-pull-rtmp-1.17app.co/live/x.a.flv',
      );
      expect(
        '${SeventeenLivePlayParser.pullUrl('http://tencent-pull-rtmp-1.17app.co:8080/live/x.flv')}',
        'http://tencent-pull-rtmp-1.17app.co:8080/live/x.flv',
      );
      expect('${SeventeenLivePlayParser.pullUrl('http://tencent-pull-rtmp-1.17app.co:80/x.flv')}', startsWith('https'));
      for (final bad in [
        '',
        'https://tencent-pull-rtmp-1.17app.co/live/x.mp4',
        'https://tencent-push-1.17app.co/live/x.flv',
        'https://cdn.17app.co/live/x.flv',
        'https://user:***@tencent-pull-rtmp-1.17app.co/live/x.flv',
        'https://tencent-pull-rtmp-1.17app.co/live/x.flv#f',
        'https://tencent-pull-rtmp-1.17app.co/li ve/x.flv',
        'ftp://tencent-pull-rtmp-1.17app.co/live/x.flv',
        'x' * 70000,
      ]) {
        expect(SeventeenLivePlayParser.pullUrl(bad), isNull, reason: bad.substring(0, bad.length.clamp(0, 40)));
      }
    });

    test('preferH264 puts the transcode first and the default with it', () {
      final data =
          SeventeenLiveRoomParser.enteredRoom(_roomAnswer(), roomId: _room).runtime.streamHandle!
              as SeventeenLiveRoomData;
      expect(SeventeenLivePlayParser.playQualities(data).map((quality) => quality.qualityId), [
        'h264',
        'source',
        'enhanced',
        'hd',
      ]);
      expect(SeventeenLivePlayParser.playQualities(data, preferH264: false).map((quality) => quality.qualityId), [
        'source',
        'enhanced',
        'hd',
        'h264',
      ]);
      expect(SeventeenLivePlayParser.lines(data).first.url, _pull('tencent', 'h264-url264'));
      expect(
        SeventeenLivePlayParser.lines(data, preferH264: false).first.url,
        _pull('tencent', 'source-urlLowQuality'),
      );
    });

    test('a quality id is the platform one, the legacy 标准 included', () {
      expect(SeventeenLivePlayParser.qualityIdFromLegacy('standard'), SeventeenLiveEndpoints.sourceQualityId);
      expect(SeventeenLivePlayParser.qualityIdFromLegacy(' STANDARD '), 'source');
      expect(SeventeenLivePlayParser.qualityIdFromLegacy(' hd '), 'hd');
      expect(SeventeenLivePlayParser.qualityIdFromLegacy('other'), 'other');
      final data =
          SeventeenLiveRoomParser.enteredRoom(_roomAnswer(), roomId: _room).runtime.streamHandle!
              as SeventeenLiveRoomData;
      expect(SeventeenLivePlayParser.lines(data, quality: 'standard'), data.lines['source']);
      expect(() => SeventeenLivePlayParser.lines(data, quality: 'nope'), throwsA(isA<SeventeenLiveFailure>()));
    });

    test('a room with nothing to play reports why instead of an empty list', () {
      // An empty playback must carry its reason: the data of a room with nothing
      // to play cannot even be built without saying why.
      expect(() => SeventeenLiveRoomData(roomId: _room, userId: _user), throwsA(isA<AssertionError>()));
      final empty = SeventeenLiveRoomData(
        roomId: _room,
        userId: _user,
        unavailable: const SeventeenLiveFailure(SeventeenLiveFailureKind.streamUnavailable, 'no pull URL'),
      );
      expect(
        () => SeventeenLivePlayParser.playQualities(empty),
        throwsA(predicate((e) => '$e'.contains('no pull URL'))),
      );
      final offline = SeventeenLiveRoomData(
        roomId: _room,
        userId: _user,
        unavailable: const SeventeenLiveFailure(SeventeenLiveFailureKind.streamUnavailable, 'offline'),
      );
      expect(() => SeventeenLivePlayParser.playQualities(offline), throwsA(predicate((e) => '$e'.contains('offline'))));
    });
  });

  group('links', () {
    test('a room page, in any locale and on www, names the room', () {
      for (final ok in [
        'https://17.live/live/$_room',
        'https://17.live/en/live/$_room',
        'https://17.live/ja/profile/r/$_room',
        'https://www.17.live/zh-Hant/live/$_room',
        'https://WWW.17.Live:443/en/live/$_room/',
        'http://17.live/profile/r/$_room',
      ]) {
        expect(SeventeenLiveRoomParser.roomIdFromUrl(ok), _room, reason: ok);
      }
    });

    test('another host, path, user info or id is no room', () {
      for (final bad in [
        'https://example.com/live/$_room',
        'https://17.live/live/$_room/extra',
        'https://17.live/live/0',
        'https://17.live/',
        'https://17.live/en/profile/$_room',
        'https://user@17.live/live/$_room',
        'ftp://17.live/live/1',
        'not a url',
      ]) {
        expect(SeventeenLiveRoomParser.roomIdFromUrl(bad), isNull, reason: bad);
      }
      // An encoded `..` is not a path the reader ever sees: `Uri` resolves it
      // away while parsing, so the traversal collapses into the room behind it.
      expect(SeventeenLiveRoomParser.roomIdFromUrl('https://17.live/%2e%2e/live/1'), '1');
    });

    test('the resolver writes the canonical room page', () async {
      final adapter = _adapter((_) => _resp(200, '{}'));
      final links = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await links.resolve(Uri.parse('https://www.17.live/ja/profile/r/1234567'))),
        Uri.parse('https://17.live/en/live/1234567'),
      );
      expect(_leftOf(await links.resolve(Uri.parse('https://chzzk.naver.com/live/x'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await links.resolve(Uri.parse('https://17.live/en/'))), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty);
    });
  });

  group('adapter over the transport', () {
    test('the catalog is three regions and costs no request', () async {
      final adapter = _adapter((_) => _resp(200, '{}'));
      final areas = adapter.site.capability<LiveAreaProvider>()!;
      final list = _right(await areas.getAreas());
      expect(list.map((area) => area.areaId), ['JP', 'TW', 'HK']);
      expect(list.first.parentAreaName, SeventeenLiveEndpoints.categoryName);
      expect(adapter.http.sent, isEmpty);
      expect(adapter.site.manifest.id, '17live');
      expect(adapter.site.manifest.localizedName('zh-CN', 'en-US'), '17LIVE');
      expect(adapter.site.manifest.localizedDescription('zh-CN', 'en-US'), SeventeenLiveEndpoints.directoryScope);
      expect(adapter.site.capability<LiveHotProvider>(), isNull);
    });

    test('a region page asks that region and headers its catalog', () async {
      final adapter = _adapter(
        (request) => _resp(
          200,
          _sections([
            _section('Live', [_streamJson()]),
          ], cursor: 'p2'),
        ),
      );
      final areas = adapter.site.capability<LiveAreaProvider>()!;
      final page = _right(await areas.getAreaRooms(areaId: 'tw', request: LivePageRequest.of(pageSize: 1)));
      expect(page.items, hasLength(1));
      expect(page.nextCursor, 'p2');
      expect(page.hasMore, isTrue);
      final sent = adapter.http.sent.single;
      expect(sent.method, 'GET');
      expect(sent.url.host, SeventeenLiveEndpoints.apiHost);
      expect(sent.url.path, '/api/v1/sections');
      expect(sent.url.queryParameters['region'], 'TW');
      expect(sent.url.queryParameters['cursor'], '');
      expect(sent.headers['accept-language'], contains('ja-JP'));
      expect(sent.headers['referer'], 'https://17.live/');
    });

    test('an area the platform does not serve is refused before any request', () async {
      final adapter = _adapter((_) => _resp(200, '{}'));
      final areas = adapter.site.capability<LiveAreaProvider>()!;
      expect(_leftOf(await areas.getAreaRooms(areaId: 'LoL')), isA<LiveSiteInvalidArgument>());
      expect(adapter.http.sent, isEmpty);
    });

    test('a cursor is one request and a page number is a walk', () async {
      var asks = 0;
      final adapter = _adapter((request) {
        asks += 1;
        final after = request.url.queryParameters['cursor'];
        final base = after == null || after.isEmpty ? 0 : int.parse(after);
        return _resp(
          200,
          _sections([
            _section('Live', [for (var i = 1; i <= 2; i++) _streamJson(liveId: base + i, owner: null)]),
          ], cursor: '${base + 2}'),
        );
      });
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(LivePageRequest()));
      expect(first.items.map((room) => room.roomId), ['1', '2']);
      expect(first.hasMore, isTrue);
      expect(asks, 1);
      final second = _right(await rooms.getRooms(LivePageRequest.of(cursor: '2')));
      expect(second.items.map((room) => room.roomId), ['3', '4']);
      expect(second.hasMore, isTrue);
      expect(asks, 2);
      // A page number is walked from the first page: that many requests.
      asks = 0;
      final third = _right(await rooms.getRooms(LivePageRequest.of(page: 3)));
      expect(asks, 3);
      expect(third.items.map((room) => room.roomId), ['5', '6']);
      expect(third.nextCursor, '6');
    });

    test('a walk that ends early is an empty page, and a bad argument no request', () async {
      var asks = 0;
      final adapter = _adapter((_) {
        asks += 1;
        return _resp(
          200,
          _sections([
            _section('Live', [_streamJson()]),
          ]),
        );
      });
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      final page = _right(await discovery.getRecommendedRooms(request: LivePageRequest.of(page: 4)));
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(asks, 1);
      expect(
        _leftOf(await discovery.getRecommendedRooms(request: LivePageRequest.of(page: 21))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await discovery.getRecommendedRooms(request: LivePageRequest.of(cursor: ''))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await discovery.getRecommendedRooms(request: LivePageRequest.of(pageSize: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(asks, 1);
    });

    test('the page size cuts the rows the platform sent', () async {
      final adapter = _adapter(
        (_) => _resp(
          200,
          _sections([
            _section('Live', [for (var i = 1; i <= 5; i++) _streamJson(liveId: i, owner: null)]),
          ]),
        ),
      );
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      final page = _right(await discovery.getRecommendedRooms(request: LivePageRequest.of(pageSize: 2)));
      expect(page.items, hasLength(2));
      expect(page.hasMore, isFalse);
    });

    test('a room entry carries its playback and its chat channel', () async {
      final adapter = _adapter((request) {
        expect(request.headers['referer'], 'https://17.live/en/live/$_room');
        expect(request.headers['accept-language'], contains('en-US'));
        return _resp(200, _roomAnswer());
      });
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(' $_room '));
      expect(room.roomId, _room);
      expect(room.broadcast.isLiveNow, isTrue);
      final data = room.runtime.streamHandle! as SeventeenLiveRoomData;
      expect(data.roomId, _room);
      expect(data.userId, _user);
      expect(data.qualities, hasLength(4));
      expect((room.runtime.danmakuHandle! as SeventeenLiveDanmakuArgs).roomId, _room);
      expect(adapter.http.sent.single.url.path, '/api/v1/lives/$_room');
    });

    test('an id that is not a room id is refused without a request', () async {
      final adapter = _adapter((_) => _resp(200, '{}'));
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      expect(_leftOf(await rooms.getRoom('nope')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty);
    });

    test('a room the platform does not know is not-found, and a transport break is network', () async {
      final gone = _adapter((_) => _resp(520, '{"errorMessage":"stream not found"}'));
      expect(_leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom(_room)), isA<LiveSiteNotFound>());
      final gate = _adapter((_) => _resp(403, '{}'));
      expect(_leftOf(await gate.site.capability<LiveRoomProvider>()!.getRoom(_room)), isA<LiveSiteRateLimitError>());
      final broken = _FakeHttp((_) => throw const ConnectFailure('dns down'));
      final offline = SeventeenLiveSite(http: SeventeenLiveHttp(broken));
      expect(_leftOf(await offline.capability<LiveRoomProvider>()!.getRoom(_room)), isA<LiveSiteNetworkError>());
      expect(seventeenliveSiteId, '17live');
    });

    test('a refresh reads the same answer without streams and a status is never a guess', () async {
      final adapter = _adapter((_) => _resp(200, _roomAnswer(status: 0, online: null, total: null)));
      final room = await adapter.site.refresh(_room);
      expect(room.broadcast.isExplicitlyOfflineNow, isTrue);
      expect(room.runtime.streamHandle, isNull);
    });

    test('search reads a room id, a link and a keyword, one page only', () async {
      var mode = (asRoom: false, status: 200);
      final adapter = _adapter((request) {
        if (request.url.path.startsWith('/api/v1/lives/')) {
          return mode.status == 200 ? _resp(200, _roomAnswer()) : _resp(mode.status, '{"errorMessage":"other"}');
        }
        expect(request.url.path, '/api/v1/liveStreams/search');
        return _resp(200, _json([_streamJson()]));
      });
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      Future<LivePage<LiveSearchResult>> run(String query, {int page = 1, int pageSize = 20}) async {
        final either = await search.search(
          LiveSearchRequest.of(query: query, target: LiveSearchTarget.rooms, page: page, pageSize: pageSize),
        );
        return await _right(either);
      }

      // A room id and a room link are one room request.
      mode = (asRoom: true, status: 200);
      expect(((await run(_room)).items.single as RoomSearchResult).room.roomId, _room);
      expect(adapter.http.sent.single.url.path, '/api/v1/lives/$_room');
      adapter.http.sent.clear();
      expect((await run('https://www.17.live/ja/live/$_room')).items, hasLength(1));
      expect(adapter.http.sent.single.url.path, '/api/v1/lives/$_room');
      // A room that is not there is nothing, not a failure.
      adapter.http.sent.clear();
      mode = (asRoom: true, status: 404);
      expect((await run(_room)).items, isEmpty);
      mode = (asRoom: false, status: 200);
      // A keyword is searched, with its colon and cut to the limit.
      adapter.http.sent.clear();
      expect(((await run('Re:Zero')).items.single as RoomSearchResult).room.roomId, _room);
      expect(adapter.http.sent.single.url.queryParameters['query'], 'Re:Zero');
      adapter.http.sent.clear();
      await run('z' * 140);
      expect(adapter.http.sent.single.url.queryParameters['query'], 'z' * 100);
      // An address that is not a room, a blank keyword and another page ask for nothing.
      adapter.http.sent.clear();
      expect((await run('https://example.com/a')).items, isEmpty);
      expect((await run('   ')).items, isEmpty);
      expect((await run('anything', page: 2)).items, isEmpty);
      expect((await run('anything', pageSize: 0)).items, isEmpty);
      expect(adapter.http.sent, isEmpty);
      // The page size cuts the rows, and another target is unsupported.
      expect(
        _leftOf(await search.search(LiveSearchRequest.of(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
    });

    test('a bad search answer is a parse failure at the boundary', () async {
      final adapter = _adapter((_) => _resp(200, '{"not":"a list"}'));
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(
        _leftOf(await search.search(LiveSearchRequest.of(query: 'ann', target: LiveSearchTarget.rooms))),
        isA<LiveSiteParseError>(),
      );
    });
  });

  group('playback capability', () {
    test('the qualities come in the order the setting asks for', () async {
      final on = _adapter((_) => _resp(200, _roomAnswer()), preferH264: () => true);
      final playback = on.site.capability<LivePlaybackProvider>()!;
      expect(_right(await playback.getQualities(roomId: _room)).map((quality) => quality.qualityId), [
        'h264',
        'source',
        'enhanced',
        'hd',
      ]);
      final off = _adapter((_) => _resp(200, _roomAnswer()), preferH264: () => false);
      expect(
        _right(await off.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _room))
            .map((quality) => quality.qualityId),
        ['source', 'enhanced', 'hd', 'h264'],
      );
      // The default of the setting is on, as 3.x shipped it.
      final plain = _adapter((_) => _resp(200, _roomAnswer()));
      expect(plain.site.preferH264(), isTrue);
      expect(
        _right(await plain.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _room)).first.qualityId,
        'h264',
      );
    });

    test('lines come from the answer held, and an unknown quality enters again', () async {
      var asks = 0;
      final adapter = _adapter((_) {
        asks += 1;
        return _resp(200, _roomAnswer());
      });
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _room));
      expect(asks, 1);
      final source = qualities.firstWhere((quality) => quality.qualityId == 'source');
      expect(_right(await playback.getLines(roomId: _room, quality: source)), hasLength(3));
      expect(asks, 1);
      // The legacy 标准 id is the same quality: no new request.
      expect(
        _right(
          await playback.getLines(
            roomId: _room,
            quality: LivePlayQuality.of(label: '标准 · FLV', qualityId: 'standard'),
          ),
        ),
        hasLength(3),
      );
      expect(asks, 1);
      // A quality the held answer does not know is recovery: the room is entered
      // again, and refused when the fresh answer still has it not.
      expect(
        _leftOf(
          await playback.getLines(
            roomId: _room,
            quality: LivePlayQuality.of(label: 'x', qualityId: 'nope'),
          ),
        ),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(asks, 2);
      // Null quality is the default one the caller was shown.
      asks = 0;
      expect(_right(await playback.getLines(roomId: _room)), hasLength(1));
      expect(asks, 0);
    });

    test('an offline or locked room names why instead of handing out nothing', () async {
      var asks = 0;
      final adapter = _adapter((_) {
        asks += 1;
        return _resp(200, _roomAnswer(status: 0));
      });
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(_leftOf(await playback.getQualities(roomId: _room)), isA<LiveSiteContentUnavailable>());
      expect(asks, 1);
      expect(_leftOf(await playback.getLines(roomId: _room)), isA<LiveSiteContentUnavailable>());
      expect(asks, 1);
      final locked = _adapter((_) => _resp(200, _roomAnswer(premium: {'premiumType': 1})));
      final error = _leftOf(await locked.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _room));
      expect(error, isA<LiveSiteContentUnavailable>());
      expect(error.message, contains('premium'));
    });
  });

  group('chat protocol', () {
    test('the token answer names the push service it gave the room to', () {
      expect(
        SeventeenLiveDanmakuCodec.grant(
          _json({
            'provider': 1,
            'token': 'x.abc',
            'permissions': ['*'],
          }),
        ),
        'x.abc',
      );
      expect(
        () => SeventeenLiveDanmakuCodec.grant(_json({'provider': 2, 'token': 'x.abc'})),
        throwsA(predicate((e) => '$e'.contains('provider 2'))),
      );
      expect(
        () => SeventeenLiveDanmakuCodec.grant(_json({'token': 'x.abc'})),
        throwsA(predicate((e) => '$e'.contains('provider missing'))),
      );
      expect(
        () => SeventeenLiveDanmakuCodec.grant(_json({'provider': 1, 'token': 'not ascii\u00a0'})),
        throwsA(predicate((e) => '$e'.contains('no token'))),
      );
      expect(() => SeventeenLiveDanmakuCodec.grant('{}', status: 420), throwsA(isA<SeventeenLiveFailure>()));
      expect(() => SeventeenLiveDanmakuCodec.grant('nope'), throwsA(isA<SeventeenLiveFailure>()));
      expect(SeventeenLiveDanmakuCodec.grant(_json({'provider': 1, 'token': 'x' * 4096})).length, 4096);
      expect(
        () => SeventeenLiveDanmakuCodec.grant(_json({'provider': 1, 'token': 'x' * 4097})),
        throwsA(isA<SeventeenLiveFailure>()),
      );
    });

    test('the handshake URL puts the token first and the resume next', () {
      final uri = SeventeenLiveDanmakuCodec.withToken(
        SeventeenLiveDanmakuCodec.endpoints.first,
        'abc.123',
        resume: 'key:1',
      );
      expect(uri.scheme, 'wss');
      expect(uri.host, '17media.realtime.ably.net');
      expect(uri.queryParameters.keys.take(3), ['access_token', 'resume', 'format']);
      expect(uri.queryParameters['heartbeats'], 'true');
      expect(uri.queryParameters['v'], '3');
      expect(
        SeventeenLiveDanmakuCodec.withToken(SeventeenLiveDanmakuCodec.endpoints.first, 'tok').queryParameters.keys,
        ['access_token', 'format', 'heartbeats', 'v'],
      );
      expect(SeventeenLiveDanmakuCodec.endpoints.map((endpoint) => endpoint.host), hasLength(4));
      expect(SeventeenLiveDanmakuCodec.endpoints.last.host, SeventeenLiveDanmakuCodec.fallbackHosts.last);
      expect(SeventeenLiveDanmakuCodec.handshakeHeaders['origin'], SeventeenLiveEndpoints.origin);
      expect(SeventeenLiveDanmakuCodec.authHeaders['content-type'], 'application/json');
    });

    test("the attach, the resume attach and the AUTH frame are the website's own", () {
      expect(SeventeenLiveDanmakuCodec.attach(_room), '{"action":10,"channel":"$_room"}');
      expect(jsonDecode(SeventeenLiveDanmakuCodec.attach(_room, channelSerial: 's:1', resume: true)), {
        'action': 10,
        'channel': _room,
        'channelSerial': 's:1',
        'flags': 32,
      });
      expect(jsonDecode(SeventeenLiveDanmakuCodec.attach(_room, resume: true)), {
        'action': 10,
        'channel': _room,
        'flags': 32,
      });
      expect(jsonDecode(SeventeenLiveDanmakuCodec.reauthorize('tok.x')), {
        'action': 17,
        'auth': {'accessToken': 'tok.x'},
      });
    });

    test('a frame is read by its action, and another channel holds nothing', () {
      const room = _room;
      for (final junk in [
        null,
        7,
        'not json',
        '[1,2]',
        <int>[0],
      ]) {
        expect(SeventeenLiveDanmakuCodec.decode(junk, roomId: room).signal, SeventeenLiveSignal.none);
      }
      expect(SeventeenLiveDanmakuCodec.decode(_frame({'action': 0}), roomId: room).signal, SeventeenLiveSignal.none);
      expect(
        SeventeenLiveDanmakuCodec.decode(_frame({'action': 16, 'channel': room}), roomId: room).signal,
        SeventeenLiveSignal.none,
      );
      expect(
        SeventeenLiveDanmakuCodec.decode(
          _frame({'action': 15, 'channel': 'other', 'messages': <Object?>[]}),
          roomId: room,
        ).entries,
        isEmpty,
      );
      // Bytes are UTF-8 text (malformed bytes become U+FFFD).
      expect(
        SeventeenLiveDanmakuCodec.decode(utf8.encode(_frame({'action': 17})), roomId: room).signal,
        SeventeenLiveSignal.reauthorize,
      );
      expect(SeventeenLiveDanmakuCodec.decode(const <int>[0xff, 0xfe], roomId: room).signal, SeventeenLiveSignal.none);
    });

    test('CONNECTED names the connection it can resume', () {
      final frame = SeventeenLiveDanmakuCodec.decode(
        _frame({
          'action': 4,
          'connectionId': 'c.1',
          'connectionDetails': {'connectionKey': 'key:1', 'connectionStateTtl': 120000, 'maxIdleInterval': 15000},
        }),
        roomId: _room,
      );
      expect(frame.signal, SeventeenLiveSignal.connected);
      expect(frame.connection, const SeventeenLiveConnectionDetails(id: 'c.1', key: 'key:1'));
      // Defaults when the answer says nothing usable.
      final bare = SeventeenLiveDanmakuCodec.decode(
        _frame({
          'action': 4,
          'connectionId': 'c.1',
          'connectionDetails': {'connectionKey': 'key:1', 'connectionStateTtl': -1, 'maxIdleInterval': 'x'},
        }),
        roomId: _room,
      );
      expect(bare.connection, const SeventeenLiveConnectionDetails(id: 'c.1', key: 'key:1'));
      expect(SeventeenLiveDanmakuCodec.decode(_frame({'action': 4}), roomId: _room).connection, isNull);
      // A resume that failed says so with its error.
      final refused = SeventeenLiveDanmakuCodec.decode(
        _frame({
          'action': 4,
          'error': {'code': 80018, 'statusCode': 401, 'message': 'invalid connection key'},
        }),
        roomId: _room,
      );
      expect(
        refused.error,
        const SeventeenLiveAblyError(code: 80018, statusCode: 401, message: 'invalid connection key'),
      );
      expect(refused.error?.isTokenError, isFalse);
      expect(const SeventeenLiveAblyError(code: 40142).isTokenError, isTrue);
      expect(const SeventeenLiveAblyError(code: 40150).isTokenError, isFalse);
    });

    test('ATTACHED carries the serial and the resume and backlog flags', () {
      SeventeenLiveDanmakuFrame read(int flags) => SeventeenLiveDanmakuCodec.decode(
        _frame({'action': 11, 'channel': _room, 'flags': flags, 'channelSerial': 's:9'}),
        roomId: _room,
      );
      final plain = read(0);
      expect(plain.signal, SeventeenLiveSignal.attached);
      expect(plain.channelSerial, 's:9');
      expect(plain.resumed, isFalse);
      expect(plain.backlog, isFalse);
      expect(read(4).resumed, isTrue);
      expect(read(2).backlog, isTrue);
      expect(read(6).backlog, isTrue);
      expect(read(6).resumed, isTrue);
      // A channel of no serial, and a flag that is not a number.
      expect(
        SeventeenLiveDanmakuCodec.decode(_frame({'action': 11, 'channel': _room}), roomId: _room).channelSerial,
        isNull,
      );
      expect(
        SeventeenLiveDanmakuCodec.decode(_frame({'action': 11, 'channel': _room, 'flags': 'x'}), roomId: _room).resumed,
        isFalse,
      );
      expect(
        SeventeenLiveDanmakuCodec.decode(_frame({'action': 13, 'channel': _room}), roomId: _room).signal,
        SeventeenLiveSignal.detached,
      );
      expect(
        SeventeenLiveDanmakuCodec.decode(
          _frame({'action': 14, 'channel': _room, 'channelSerial': 's:2'}),
          roomId: _room,
        ).channelSerial,
        's:2',
      );
      expect(
        SeventeenLiveDanmakuCodec.decode(
          _frame({
            'action': 6,
            'error': {'code': 40140},
          }),
          roomId: _room,
        ).signal,
        SeventeenLiveSignal.disconnected,
      );
      // ERROR names the connection when it names no channel, the channel when
      // it names this one, and nothing for another.
      expect(
        SeventeenLiveDanmakuCodec.decode(_frame({'action': 9}), roomId: _room).signal,
        SeventeenLiveSignal.connectionError,
      );
      expect(SeventeenLiveDanmakuCodec.decode(_frame({'action': 9}), roomId: _room).error?.code, 0);
      expect(
        SeventeenLiveDanmakuCodec.decode(_frame({'action': 9, 'channel': _room}), roomId: _room).signal,
        SeventeenLiveSignal.channelError,
      );
      expect(
        SeventeenLiveDanmakuCodec.decode(_frame({'action': 9, 'channel': 'other'}), roomId: _room).signal,
        SeventeenLiveSignal.none,
      );
    });

    test('a message payload is gzipped base64 JSON, and nothing else', () {
      expect(SeventeenLiveDanmakuCodec.payload(_payload({'type': 3})), {'type': 3});
      expect(SeventeenLiveDanmakuCodec.payload(null), isNull);
      expect(SeventeenLiveDanmakuCodec.payload(''), isNull);
      expect(SeventeenLiveDanmakuCodec.payload('not base64!'), isNull);
      expect(SeventeenLiveDanmakuCodec.payload(base64.encode(gzip.encode(utf8.encode('[1,2]')))), isNull);
      expect(SeventeenLiveDanmakuCodec.payload(base64.encode(utf8.encode('{"type":3}'))), isNull);
    });

    test('a comment is a chat line with its name, colour, level and badges', () {
      final frame = SeventeenLiveDanmakuCodec.decode(
        _messageFrame([
          _ablyMessage(
            _comment(
              level: 7,
              sendTime: 1759000000000,
              color: '#FF00FF00',
              nameColor: '#00FF00',
              picture: 'p.jpg',
              badges: [
                {'URL': 'https://cdn.17app.co/b1.png', 'styleID': 's1'},
                {'URL': 'https://cdn.17app.co/b1.png', 'styleID': 's1'},
                {'URL': 'https://evil.com/b2.png'},
                {'styleID': 'no picture'},
              ],
            ),
            id: 'm1',
          ),
        ]),
        roomId: _room,
      );
      expect(frame.entries.single.id, 'm1');
      final message = frame.messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hi');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userLevel, '7');
      expect(message.effectiveColor, const LiveMessageColor(0, 255, 0));
      expect(message.sender?.nameColor, const LiveMessageColor(0, 255, 0));
      expect(message.sender?.badges, hasLength(1));
      expect(message.sender?.badges.single.url, 'https://cdn.17app.co/b1.png');
      expect(message.messageId, 'm1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1759000000000));
      expect(message.replayed, isFalse);
    });

    test('a hidden comment, a blank one and an unknown type show nothing', () {
      for (final hidden in [
        _comment(dirty: true),
        _comment(content: '   ', text: '   '),
        {'type': 3},
        {'type': 3, 'commentMsg': 'not a map'},
        {'type': 999},
        {'type': 'x'},
        <String, Object?>{},
      ]) {
        expect(SeventeenLiveDanmakuCodec.message(hidden), isNull, reason: '$hidden');
      }
      expect(SeventeenLiveDanmakuCodec.entry({'type': 7}).messages, isEmpty);
      // The text falls back to comment.text, and the name to openID.
      final named = SeventeenLiveDanmakuCodec.message({
        'type': 3,
        'commentMsg': {
          'content': '',
          'comment': {'text': ' from the body '},
          'displayUser': {'openID': 'open_ann'},
        },
      });
      expect(named?.text, 'from the body');
      expect(named?.sender?.userName, 'open_ann');
    });

    test('a paid barrage is a super chat besides its line, a free one is not', () {
      final entry = SeventeenLiveDanmakuCodec.entry(
        _comment(barrageStyle: true, point: 30, picture: 'p.jpg'),
        id: 'm2',
        now: _at,
      );
      expect(entry.messages, hasLength(2));
      expect(entry.messages.first.type, LiveMessageType.chat);
      final superChat = entry.messages.last;
      expect(superChat.type, LiveMessageType.superChat);
      expect(superChat.payload, isA<LiveSuperChatMessage>());
      final data = superChat.payload! as LiveSuperChatMessage;
      expect(data.price.amount, 30);
      expect(data.price.displayText, '30 coins');
      expect(data.userName, 'Ann');
      expect(data.faceUrl, 'https://cdn.17app.co/THUMBNAIL_p.jpg');
      expect(data.startTime, _at);
      expect(data.endTime, _at.add(SeventeenLiveDanmakuCodec.superChatDuration));
      expect(data.messageId, 'm2');
      // A barrage with no coins, no style or no point at all stays a chat line.
      for (final plain in [_comment(barrageStyle: true, point: 0), _comment(point: 30), _comment(barrageStyle: true)]) {
        expect(SeventeenLiveDanmakuCodec.superChat(plain), isNull, reason: '$plain');
      }
      // The line's own time starts the barrage, and the colour is its background.
      final timed = SeventeenLiveDanmakuCodec.entry(
        _comment(barrageStyle: true, point: 5, sendTime: 1759000000000, background: '#FF112233'),
        now: _at,
      );
      final paid = timed.messages.last.payload! as LiveSuperChatMessage;
      expect(paid.startTime, DateTime.fromMillisecondsSinceEpoch(1759000000000));
      expect(paid.display.backgroundColor, '#112233');
      expect(paid.display.backgroundBottomColor, '#112233');
    });

    test('a gift is one gift of one send, unnamed but for its id', () {
      final message = SeventeenLiveDanmakuCodec.gift(
        _giftMsg(point: 0, count: 3, window: 5000, target: '2609_jp_cp_akanya'),
        id: 'g1',
      );
      expect(message?.type, LiveMessageType.gift);
      expect(message?.text, '2609_jp_cp_akanya ×1');
      expect(message?.sender?.userName, 'Ann');
      expect(message?.sender?.userLevel, '7');
      final gift = message!.payload! as LiveGift;
      expect(gift.giftId, '2609_jp_cp_akanya');
      expect(gift.name, '');
      expect(gift.count, 1);
      expect(gift.value.unit, LiveGiftUnit.free);
      expect(gift.value.unitPrice, isNull);
      expect(gift.combo.comboTotal, 3);
      expect(gift.combo.comboKey, '');
      // A paid gift carries its point as its value; no point says nothing.
      expect(
        (SeventeenLiveDanmakuCodec.gift(_giftMsg(point: 120))!.payload! as LiveGift).value.unit,
        LiveGiftUnit.point,
      );
      final giftValue = SeventeenLiveDanmakuCodec.gift(_giftMsg(point: 120))!.payload! as LiveGift;
      expect(giftValue.value.unitPrice, 120);
      expect(giftValue.value.totalValue, 120);
      expect((SeventeenLiveDanmakuCodec.gift(_giftMsg())!.payload! as LiveGift).value.unit, LiveGiftUnit.other);
      expect(
        (SeventeenLiveDanmakuCodec.gift(_giftMsg(point: -1))!.payload! as LiveGift).value.unit,
        LiveGiftUnit.other,
      );
      // No gift id, no gift message.
      expect(SeventeenLiveDanmakuCodec.gift({'type': 13}), isNull);
      expect(
        SeventeenLiveDanmakuCodec.gift({
          'type': 13,
          'giftMsg': {'giftID': ' '},
        }),
        isNull,
      );
      // The combo entry of another gift is not the one asked.
      final other = SeventeenLiveDanmakuCodec.gift(_giftMsg(count: 9, target: 'other'))!;
      expect((other.payload! as LiveGift).combo.comboTotal, 9);
    });

    test('the live figures are an audience update and a mute turn', () {
      final figures = SeventeenLiveDanmakuCodec.entry(_figures(viewers: 300), id: 'f1');
      expect(figures.muted, isNull);
      final message = figures.messages.single;
      expect(message.type, LiveMessageType.audienceUpdate);
      expect(message.payload, isA<LiveAudienceUpdate>());
      expect((message.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.onlineViewers);
      expect((message.payload! as LiveAudienceUpdate).value, 300);
      expect(SeventeenLiveDanmakuCodec.entry(_figures(viewers: 0, mute: true)).muted, isTrue);
      expect(SeventeenLiveDanmakuCodec.entry(_figures(viewers: 0, mute: false)).muted, isFalse);
      expect(SeventeenLiveDanmakuCodec.message(_figures(viewers: -1)), isNull);
      expect(SeventeenLiveDanmakuCodec.message(_figures()), isNull);
      expect(SeventeenLiveDanmakuCodec.message(_figures(viewers: 1))?.payload, isNotNull);
      expect(SeventeenLiveDanmakuCodec.muteNotice(muted: true).text, SeventeenLiveDanmakuCodec.mutedNotice);
      expect(SeventeenLiveDanmakuCodec.muteNotice(muted: false).text, SeventeenLiveDanmakuCodec.unmutedNotice);
      expect(SeventeenLiveDanmakuCodec.muteNotice(muted: false).payload, LiveNoticeKind.system);
    });

    test('a stream end, a missing id and the backlog of a resume', () {
      expect(SeventeenLiveDanmakuCodec.entry({'type': 5}).ended, isTrue);
      expect(SeventeenLiveDanmakuCodec.entry({'type': 5}).messages, isEmpty);
      // A message without its own id gets the frame's id and its index.
      final frame = SeventeenLiveDanmakuCodec.decode(
        _messageFrame([_ablyMessage(_comment()), _ablyMessage(_comment())], id: 'f9'),
        roomId: _room,
      );
      expect(frame.entries.map((entry) => entry.id), ['f9:0', 'f9:1']);
      // Before an ATTACHED that announced a backlog: replayed up to the attach.
      final backlog = SeventeenLiveDanmakuCodec.decode(
        _messageFrame([
          _ablyMessage(_comment(), id: 'a', timestamp: _at.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch),
          _ablyMessage(_comment(), id: 'b', timestamp: _at.add(const Duration(seconds: 1)).millisecondsSinceEpoch),
        ]),
        roomId: _room,
        now: _at,
        backlogBefore: _at,
      );
      expect(backlog.entries.first.replayed, isTrue);
      expect(backlog.entries.first.messages.single.replayed, isTrue);
      expect(backlog.entries.last.replayed, isFalse);
      expect(backlog.entries.last.messages.single.replayed, isFalse);
      // The reader stamps a plain local DateTime, so compare the instants.
      expect(backlog.entries.first.publishedAt!.toUtc(), _at.subtract(const Duration(seconds: 5)));
      // A message with no time of its own cannot end the backlog.
      final untimed = SeventeenLiveDanmakuCodec.decode(
        _messageFrame([_ablyMessage(_comment(), id: 'a')]),
        roomId: _room,
        now: _at,
        backlogBefore: _at,
      );
      expect(untimed.entries.single.replayed, isFalse);
      expect(untimed.entries.single.publishedAt, DateTime.fromMillisecondsSinceEpoch(_at.millisecondsSinceEpoch));
    });

    test('the colours and the background are what the website can paint', () {
      expect(SeventeenLiveDanmakuCodec.color('#FF00FF00'), const LiveMessageColor(0, 255, 0));
      expect(SeventeenLiveDanmakuCodec.color('00ff00'), const LiveMessageColor(0, 255, 0));
      expect(SeventeenLiveDanmakuCodec.color(null), LiveMessageColor.white);
      expect(SeventeenLiveDanmakuCodec.color('green'), LiveMessageColor.white);
      expect(SeventeenLiveDanmakuCodec.color(7), LiveMessageColor.white);
      // The name colour is `name.textColor` read as [color] reads a text colour.
      // Every byte of the fixture is named: the shared `numberToColor` packs a
      // colour through a hex string that has lost its leading zeroes, so a red
      // byte of zero (`#0000FF`) is not the colour it spells.
      expect(SeventeenLiveDanmakuCodec.nameColor({'textColor': '#FF0000'}), const LiveMessageColor(255, 0, 0));
      expect(SeventeenLiveDanmakuCodec.nameColor({'textColor': 'zzz'}), isNull);
      expect(SeventeenLiveDanmakuCodec.nameColor(null), isNull);
      expect(SeventeenLiveDanmakuCodec.backgroundColor('#FF112233'), '#112233');
      expect(SeventeenLiveDanmakuCodec.backgroundColor('aabbcc'), '#AABBCC');
      expect(SeventeenLiveDanmakuCodec.backgroundColor('nope'), '');
      expect(SeventeenLiveDanmakuCodec.timeMillis(0), isNull);
      expect(SeventeenLiveDanmakuCodec.timeMillis('1759000000000'), isNull);
      expect(SeventeenLiveDanmakuCodec.timeMillis(SeventeenLiveDanmakuCodec.maxMillis + 1), isNull);
      expect(
        SeventeenLiveDanmakuCodec.badges({
          'prefixBadges': [
            for (var i = 0; i < 40; i++) {'URL': 'a/$i.png'},
          ],
        }),
        hasLength(SeventeenLiveDanmakuCodec.badgeLimit),
      );
      expect(
        SeventeenLiveDanmakuCodec.badges({
          'prefixBadge': {'URL': 'a.png'},
          'middleBadge': {'URL': 'b.png'},
          'roleBadge': {'URL': 'c.png'},
        }).map((badge) => badge.url),
        ['https://cdn.17app.co/a.png', 'https://cdn.17app.co/b.png', 'https://cdn.17app.co/c.png'],
      );
    });
  });

  group('chat session over the transport', () {
    test('the room id is the channel and needs no room request', () async {
      final adapter = _adapter((_) => _resp(200, _json({'provider': 2, 'token': 'x.abc'})));
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final failure = _leftOf(await danmaku.createSession(roomId: ' $_room '));
      expect(failure, isA<LiveSiteUnsupported>());
      expect(failure.message, contains('provider 2'));
      final sent = adapter.http.sent.single;
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/v1/messenger/auth');
      expect(sent.body, '{}');
      expect(sent.headers['content-type'], 'application/json');
      expect(sent.headers['referer'], 'https://17.live/');
    });

    test('an id that is not a room id starts nothing', () async {
      final adapter = _adapter((_) => _resp(200, '{}'));
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      expect(_leftOf(await danmaku.createSession(roomId: '0abc')), isA<LiveSiteInvalidArgument>());
      expect(adapter.http.sent, isEmpty);
    });

    test('a token request that breaks reports it', () async {
      final broken = _FakeHttp((_) => throw const ConnectFailure('dns down'));
      final session = SeventeenLiveDanmakuSession(
        args: const SeventeenLiveDanmakuArgs(roomId: _room),
        http: SeventeenLiveHttp(broken),
      );
      final failure = await session.connect();
      expect(failure, isA<LiveSiteNetworkError>());
      await session.dispose();
      expect(await session.connect(), isA<LiveSiteError>());
    });

    test("the watchdog is the server's own beat and the client sends none", () {
      expect(SeventeenLiveDanmakuCodec.heartbeatInterval, const Duration(seconds: 15));
      expect(SeventeenLiveDanmakuCodec.inactivityTimeout, const Duration(seconds: 25));
      expect(SeventeenLiveDanmakuCodec.joinTimeout, const Duration(seconds: 10));
      expect(SeventeenLiveDanmakuCodec.maxRefusals, 3);
      expect(SeventeenLiveDanmakuSession.maxReconnectAttempts, 8);
      expect(seventeenLiveBroadcastEnded, 'Broadcast ended');
      expect(
        SeventeenLiveDanmakuCodec.defaultConnectionStateTtl + SeventeenLiveDanmakuCodec.heartbeatInterval,
        const Duration(seconds: 135),
      );
    });

    test('a room entry hands its channel over without a token request', () async {
      final adapter = _adapter((_) => _resp(200, _roomAnswer()));
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_room));
      expect((room.runtime.danmakuHandle! as SeventeenLiveDanmakuArgs).roomId, _room);
      expect(adapter.http.sent.map((request) => request.method), ['GET']);
    });
  });
}
