import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_manifest.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_json.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_room_parser.dart';
import 'package:test/test.dart';

/// A broadcast id: 5–18 digits without a leading zero.
const String _liveId = '1234567890123456';

const String _author = '9876543210';

/// The HLS playlist of this broadcast on JD Cloud's live CDN.
String _hls({String live = _liveId, String host = 'live.jdcloud.com'}) => 'https://$host/live/$live/$live.m3u8';

/// The FLV stream of this broadcast, sharing the playlist's key by default.
String _flv({String live = _liveId, String key = _liveId, String host = 'live.jdcloud.com'}) =>
    'https://$host/live/$live/$key.flv';

/// A replay's recording on JD Cloud's video service.
String _recording({String host = 'video.300hu.com'}) => 'https://$host/vod/$_liveId/$_liveId.m3u8';

/// A `data` envelope answer.
String _api(Object? data, {Object? code = 0, Object? subCode = 0, Object? echo}) =>
    jsonEncode({'code': code, 'subCode': subCode, 'echo': ?echo, 'data': data});

/// A `liveListWithTabToM` answer.
String _directory(List<Object?> rows, {Object? count = 30}) => _api({'list': rows, 'currentCount': count});

Map<String, Object?> _data([Map<String, Object?>? override]) => {
  'id': _liveId,
  'liveId': _liveId,
  'authorId': _author,
  'userName': '京东自营店',
  'title': '直播卖货',
  'userPic': 'https://img.jdcloud.com/avatar.jpg',
  'indexImage': 'https://img.360buyimg.com/cover.jpg',
  'pv': 4000,
  'status': 1,
  ...?override,
};

Map<String, Object?> _entry([Map<String, Object?>? override]) => {'templateType': 1, 'data': _data(override)};

/// The inner `data` map of a play answer.
Map<String, Object?> _play([Map<String, Object?>? override]) => {
  'liveId': _liveId,
  'status': 1,
  'secret': 0,
  'blurredImg': 'https://img.360buyimg.com/blurred.jpg',
  'h5VideoUrl': _hls(),
  'videoUrl': _flv(),
  ...?override,
};

String _playOf([Map<String, Object?>? override]) => _api(_play(override));

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on JdliveFailure catch (failure) {
    return failure.kind;
  }
}

JdliveFailure _failure(void Function() answer) {
  try {
    answer();
  } on JdliveFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the envelope and the readers', () {
    test('the status table', () {
      expect(_kindOf(() => JdliveJson.checkStatus(200, what: 'x')), isNull);
      expect(_kindOf(() => JdliveJson.checkStatus(400, what: 'x')), JdliveFailureKind.apiChanged);
      expect(_kindOf(() => JdliveJson.checkStatus(422, what: 'x')), JdliveFailureKind.apiChanged);
      expect(_kindOf(() => JdliveJson.checkStatus(401, what: 'x')), JdliveFailureKind.riskControl);
      expect(_kindOf(() => JdliveJson.checkStatus(403, what: 'x')), JdliveFailureKind.riskControl);
      expect(_kindOf(() => JdliveJson.checkStatus(404, what: 'x')), JdliveFailureKind.notFound);
      expect(_kindOf(() => JdliveJson.checkStatus(429, what: 'x')), JdliveFailureKind.rateLimited);
      expect(_kindOf(() => JdliveJson.checkStatus(500, what: 'x')), JdliveFailureKind.network);
      expect(_kindOf(() => JdliveJson.checkStatus(302, what: 'x')), JdliveFailureKind.network);
    });

    test('code, subCode and data', () {
      expect(JdliveJson.data(_api({'a': 1}), status: 200, what: 'x'), {'a': 1});
      expect(JdliveJson.data(_api({'a': 1}, code: '0'), status: 200, what: 'x'), {
        'a': 1,
      }, reason: 'the code may be written as text');
      expect(
        _failure(() => JdliveJson.data(_api({}, code: 2, echo: '接口不存在'), status: 200, what: 'x')).message,
        'x: code 2 接口不存在',
      );
      expect(
        _kindOf(() => JdliveJson.data(_api({}, code: null), status: 200, what: 'x')),
        JdliveFailureKind.apiChanged,
        reason: 'a missing code is written as the empty text, which is not 0',
      );
      expect(
        _failure(() => JdliveJson.data(_api({}, subCode: 404), status: 200, what: 'x')).message,
        contains('subCode 404'),
      );
      expect(
        _kindOf(() => JdliveJson.data(_api({}, subCode: 404), status: 200, what: 'x')),
        JdliveFailureKind.notFound,
        reason: 'the platform says the subject is gone in its own way',
      );
      expect(_kindOf(() => JdliveJson.data(_api('x'), status: 200, what: 'x')), JdliveFailureKind.apiChanged);
      expect(_kindOf(() => JdliveJson.data('[]', status: 200, what: 'x')), JdliveFailureKind.apiChanged);
      expect(_kindOf(() => JdliveJson.data('nope', status: 200, what: 'x')), JdliveFailureKind.apiChanged);
      expect(
        _kindOf(() => JdliveJson.data(_api({}), status: 404, what: 'x')),
        JdliveFailureKind.notFound,
        reason: 'the transport is asked before the envelope',
      );
      expect(
        _kindOf(() => JdliveJson.data(_api({'a': '漢' * 1500000}), status: 200, what: 'x')),
        JdliveFailureKind.apiChanged,
        reason: 'the four megabyte cap is in UTF-8 bytes',
      );
    });

    test('the field readers', () {
      expect(JdliveJson.integer(7), 7);
      expect(JdliveJson.integer(7.0), 7);
      expect(JdliveJson.integer(7.5), isNull);
      expect(JdliveJson.integer(' 7 '), 7);
      expect(JdliveJson.integer(true), isNull);
      expect(JdliveJson.count(-1), isNull);
      expect(JdliveJson.count('0'), 0);
      expect(JdliveJson.text(7), '7');
      expect(JdliveJson.text(null), isEmpty);
      expect(JdliveJson.optionalText(' a \n b ', 'x'), 'a b');
      expect(JdliveJson.optionalText(null, 'x'), isEmpty);
      expect(
        _kindOf(() => JdliveJson.optionalText(7, 'x')),
        JdliveFailureKind.apiChanged,
        reason: 'a number where a list entry should have text is a changed answer',
      );
      expect(_kindOf(() => JdliveJson.optionalText('x' * 65537, 'x')), JdliveFailureKind.apiChanged);
      expect(JdliveJson.snippet('a\n b'), 'a b');
    });

    test("the catalog has one area and the states are the play answer's", () {
      final area = JdliveRoomParser.area();
      expect(area.areaId, JdliveEndpoints.areaId);
      expect(area.areaName, '精选直播购物');
      expect(area.parentAreaId, isNull, reason: 'the one area has no parent');
      expect(area.platform, jdliveSiteId);
      expect(JdliveRoomParser.state(1), JdliveState.live);
      expect(JdliveRoomParser.state('1'), JdliveState.live);
      expect(JdliveRoomParser.state(0), JdliveState.preview);
      expect(JdliveRoomParser.state(2), JdliveState.offline);
      expect(JdliveRoomParser.state(3), JdliveState.replay);
      expect(JdliveRoomParser.state(10), JdliveState.paused);
      expect(JdliveRoomParser.state(11), JdliveState.paused);
      expect(JdliveRoomParser.state(9), JdliveState.unknown);
      expect(JdliveRoomParser.state(null), JdliveState.unknown);
    });
  });

  group('the featured list', () {
    ({List<JdliveBroadcast> rooms, int nextCount, bool hasMore}) read(String body, {int after = 0}) =>
        JdliveRoomParser.directory(body, after: after);

    test('only the broadcast entries, once each', () {
      final answer = _directory([
        _entry(),
        {
          'templateType': 2,
          'data': {'id': '777'},
        },
        _entry({'liveId': '99999'}),
        _entry({'id': '12', 'liveId': '12'}),
        _entry({'authorId': 'other_author'}),
        'not an entry',
      ]);
      final page = read(answer);
      expect(page.rooms.map((room) => room.liveId), [_liveId]);
      expect(page.rooms.single.authorId, _author);
      expect(page.rooms.single.nick, '京东自营店');
      expect(page.rooms.single.title, '直播卖货');
      expect(page.rooms.single.cover, 'https://img.360buyimg.com/cover.jpg');
      expect(page.rooms.single.totalViews, 4000);
      expect(page.rooms.single.state, JdliveState.live);
      expect(page.rooms.single.restriction, isNull, reason: 'a list never says why a broadcast cannot be watched');
      expect(page.rooms.single.hasPlayAnswer, isFalse);
      expect(page.nextCount, 30);
      expect(page.hasMore, isTrue);
    });

    test('names may be blank, but a broken entry is counted', () {
      final blank = read(
        _directory([
          _entry({'userName': null, 'title': null, 'pv': -1}),
        ]),
      ).rooms.single;
      expect(blank.totalViews, isNull, reason: 'a negative view count is no count');
      expect(blank.nick, isEmpty);
      expect(blank.title, isEmpty);
      expect(
        read(_directory([_entry()])).rooms.single.avatar,
        isEmpty,
        reason: "an image off JD's own host is no image",
      );
      expect(
        _failure(
          () => read(
            _directory([
              _entry({'userName': 7}),
            ]),
          ),
        ).message,
        contains('unreadable entries, no broadcast'),
      );
      expect(
        read(
          _directory([
            _entry({'userName': 7}),
            _entry(),
          ]),
        ).rooms,
        hasLength(1),
        reason: 'one broken entry only loses itself',
      );
      expect(_kindOf(() => read(_api({'list': 'x'}))), JdliveFailureKind.apiChanged);
      expect(_kindOf(() => read(_api({'currentCount': 10}))), JdliveFailureKind.apiChanged);
      expect(_failure(() => read(_directory([_entry()], count: null))).message, contains('currentCount is'));
      expect(
        read(_directory([_entry()], count: 5), after: 5).hasMore,
        isFalse,
        reason: 'the list is already at its end',
      );
      expect(read(_directory(const [], count: 10)).hasMore, isFalse, reason: 'an empty page stops the walk');
      expect(read(_directory(const [], count: 10)).nextCount, 10);
    });
  });

  group('the play answer', () {
    JdliveBroadcast play([Map<String, Object?>? override]) => JdliveRoomParser.play(_playOf(override), liveId: _liveId);

    test('the answer must be about the broadcast that was asked for', () {
      expect(play().liveId, _liveId);
      expect(play().hls.toString(), _hls());
      expect(play().flv.toString(), _flv());
      expect(play().background, 'https://img.360buyimg.com/blurred.jpg');
      expect(play().restriction, LiveRestriction.none);
      expect(play().hasPlayAnswer, isTrue);
      expect(play().title, isEmpty, reason: 'the play answer names nothing; a follow keeps its own');
      expect(
        _failure(() => JdliveRoomParser.play(_playOf({'liveId': '7777777'}), liveId: _liveId)).message,
        contains('asked $_liveId, got 7777777'),
      );
      expect(play({'blurredImg': 'ftp://x/y.jpg'}).background, isEmpty);
      expect(play({'blurredImg': 'https://evil.example/y.jpg'}).background, isEmpty);
    });

    test("the media must be this broadcast's own JD Cloud streams", () {
      expect(
        play({'h5VideoUrl': null, 'videoUrl': _flv()}).flv.toString(),
        _flv(),
        reason: 'FLV alone is enough to watch',
      );
      expect(
        play({'videoUrl': null, 'pcVideoUrl': _flv()}).flv.toString(),
        _flv(),
        reason: 'pcVideoUrl is the fallback',
      );
      expect(
        play({'videoUrl': 'x', 'pcVideoUrl': _flv()}).flv.toString(),
        _flv(),
        reason: 'a bad first is passed over',
      );
      expect(
        play({'videoUrl': _flv(key: 'otherkey')}).flv,
        isNull,
        reason: "an FLV of another stream key is not this playlist's stream",
      );
      expect(
        play({'h5VideoUrl': null, 'videoUrl': _flv(key: 'otherkey')}).flv.toString(),
        _flv(key: 'otherkey'),
        reason: 'without a playlist the key has nothing to agree with',
      );
      for (final url in [
        'http://live.jdcloud.com/live/$_liveId/$_liveId.m3u8',
        'https://live.jdcloud.com:8443/live/$_liveId/$_liveId.m3u8',
        'https://u@live.jdcloud.com/live/$_liveId/$_liveId.m3u8',
        'https://live.jdcloud.com/live/$_liveId/$_liveId.m3u8#f',
        'https://live.jdcloud.com/vod/$_liveId/$_liveId.m3u8',
        'https://live.jdcloud.com/live/$_liveId/$_liveId.flv',
        'https://evil.example/live/$_liveId/$_liveId.m3u8',
        'https://live.jdcloud.com/live/$_liveId a/$_liveId.m3u8',
        'https://live.jdcloud.com/live/${'x' * 8200}/${'x' * 8200}.m3u8',
        7,
      ]) {
        expect(play({'h5VideoUrl': url}).hls, isNull, reason: '$url');
      }
      expect(
        play({'status': 1, 'h5VideoUrl': null, 'videoUrl': null}).restriction,
        LiveRestriction.unplayable,
        reason: 'a live broadcast with no address cannot be watched',
      );
      expect(play({'status': 1}).streamError, isNull);
    });

    test('a replay is the recording on the video service', () {
      expect(play({'status': 3, 'h5VideoUrl': _recording()}).recording.toString(), _recording());
      expect(
        play({'status': 3, 'h5VideoUrl': _hls(), 'videoUrl': _recording()}).recording.toString(),
        _recording(),
        reason: 'the fields are tried in order',
      );
      expect(play({'status': 3, 'h5VideoUrl': 'https://live.jdcloud.com/live/a/a.m3u8'}).recording, isNull);
      expect(
        play({'status': 3, 'h5VideoUrl': _hls()}).restriction,
        LiveRestriction.unplayable,
        reason: 'a replay with no recording cannot be watched',
      );
      expect(play({'status': 3, 'h5VideoUrl': _recording()}).restriction, LiveRestriction.none);
      expect(play({'status': 3, 'h5VideoUrl': _recording()}).hls, isNull, reason: "a replay's media is not a live HLS");
      expect(play({'status': 0}).restriction, LiveRestriction.none);
      expect(play({'status': 0}).streamError?.message, contains('is preview'));
      expect(play({'secret': 1, 'status': 0}).restriction, LiveRestriction.appOnly);
      expect(play({'secret': 1}).appOnly, isTrue, reason: 'app-only holds whatever the state is');
      expect(play({'secret': 1}).streamError?.message, contains('JD app only (secret)'));
    });
  });

  group('the playlist check', () {
    final expected = Uri.parse(_hls());
    String playlist(List<String> lines) => ['#EXTM3U', ...lines].join('\n');

    test("every reference must be this stream's own", () {
      expect(
        () => JdliveRoomParser.checkPlaylist(
          playlist(['#EXT-X-STREAM-INF:BANDWIDTH=1000,URI="$_liveId-extra.m3u8"', _flv()]),
          expected: expected,
        ),
        returnsNormally,
        reason: 'a child may extend the stream key and may be relative',
      );
      expect(
        _failure(
          () => JdliveRoomParser.checkPlaylist(
            playlist(['#EXT-X-MEDIA:URI="https://evil.example/a.m3u8"']),
            expected: expected,
          ),
        ).message,
        contains('foreign'),
      );
      expect(
        _failure(() => JdliveRoomParser.checkPlaylist(playlist(['../../other/$_liveId.m3u8']), expected: expected))
            .message,
        contains('foreign'),
        reason: 'a child that leaves /live/ is not one',
      );
      expect(
        _failure(() => JdliveRoomParser.checkPlaylist(playlist(['other.m3u8']), expected: expected)).message,
        contains('foreign'),
        reason: 'the file must carry the stream key',
      );
      expect(
        _failure(() => JdliveRoomParser.checkPlaylist('#EXTM3U', expected: expected)).message,
        contains('no media reference'),
      );
      expect(
        _failure(() => JdliveRoomParser.checkPlaylist('#EXTM3U\n# a comment', expected: expected)).message,
        contains('no media reference'),
      );
    });

    test('a playlist that is not one, or is too big, is a changed stream', () {
      expect(
        _failure(() => JdliveRoomParser.checkPlaylist('nope', expected: expected)).message,
        contains('not an HLS playlist'),
      );
      expect(
        _failure(() => JdliveRoomParser.checkPlaylist('', expected: expected)).message,
        contains('not an HLS playlist'),
      );
      expect(
        _kindOf(
          () => JdliveRoomParser.checkPlaylist(
            '#EXTM3U\n${'x' * (JdliveEndpoints.playlistLimit + 1)}',
            expected: expected,
          ),
        ),
        JdliveFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => JdliveRoomParser.checkPlaylist('#EXTM3U', expected: expected, status: 404)),
        JdliveFailureKind.streamUnavailable,
        reason: 'the CDN does not have this stream',
      );
      expect(
        _kindOf(() => JdliveRoomParser.checkPlaylist('#EXTM3U', expected: expected, status: 429)),
        JdliveFailureKind.rateLimited,
      );
      expect(
        _kindOf(() => JdliveRoomParser.checkPlaylist('#EXTM3U', expected: expected, status: 500)),
        JdliveFailureKind.network,
      );
      expect(
        _failure(() => JdliveRoomParser.checkPlaylist('#EXTM3U\nx.m3u8', expected: expected, status: 400)).message,
        contains('HTTP 400'),
        reason: 'the status is read before the body',
      );
    });
  });

  group('rooms, qualities and lines', () {
    JdliveBroadcast both() => JdliveRoomParser.play(_playOf(), liveId: _liveId);
    final card = JdliveRoomParser.directory(_directory([_entry()]), after: 0).rooms.single;

    test('the room is the broadcast, and its audience is cumulative', () {
      final full = JdliveRoomParser.room(card);
      expect(full.roomId, _liveId);
      expect(full.anchor?.anchorId, _author);
      expect(full.anchor?.name, '京东自营店');
      expect(full.content.title, '直播卖货');
      expect(full.content.coverUrl, 'https://img.360buyimg.com/cover.jpg');
      expect(full.content.notice, JdliveEndpoints.chatNotice);
      expect(full.area?.areaId, JdliveEndpoints.areaId);
      expect(full.audience.totalViewers, 4000);
      expect(full.audience.primaryMetric, LiveAudienceMetricType.totalViewers);
      expect(full.broadcast.liveStatus, LiveStatus.live);
      expect(full.links.webUrl, 'https://lives.jd.com/#/$_liveId');
      expect(JdliveRoomParser.room(card).runtime.danmakuHandle, isNull, reason: 'no data was asked for');
      expect(JdliveRoomParser.room(card, withData: true).runtime.danmakuHandle, isA<JdliveDanmakuArgs>());
      expect(
        JdliveRoomParser.room(
          const JdliveBroadcast(liveId: _liveId, state: JdliveState.live, appOnly: true),
          withData: true,
        ).runtime.danmakuHandle,
        isNull,
        reason: 'an app-only broadcast opens no chat',
      );
      expect(
        JdliveRoomParser.room(const JdliveBroadcast(liveId: _liveId, state: JdliveState.live, appOnly: true))
            .content
            .notice,
        JdliveEndpoints.restrictedNotice,
      );
      expect(
        JdliveRoomParser.room(const JdliveBroadcast(liveId: _liveId, state: JdliveState.replay)).broadcast.liveStatus,
        LiveStatus.replay,
      );
      expect(
        JdliveRoomParser.room(const JdliveBroadcast(liveId: _liveId, state: JdliveState.preview)).broadcast.liveStatus,
        LiveStatus.offline,
      );
      expect(
        JdliveRoomParser.room(const JdliveBroadcast(liveId: _liveId, state: JdliveState.paused)).broadcast.liveStatus,
        LiveStatus.unknown,
        reason: 'a pause is not an end',
      );
      expect(
        JdliveRoomParser.room(const JdliveBroadcast(liveId: _liveId, state: JdliveState.unknown))
            .audience
            .primaryMetric,
        LiveAudienceMetricType.unknown,
      );
    });

    test('a play answer borrows only what it lacks', () {
      const empty = JdliveBroadcast(liveId: _liveId, state: JdliveState.live, restriction: LiveRestriction.none);
      final merged = empty.enrich(card);
      expect(merged.nick, '京东自营店');
      expect(merged.cover, 'https://img.360buyimg.com/cover.jpg');
      expect(merged.totalViews, 4000);
      expect(merged.background, isEmpty, reason: 'the card has no blurred frame to give');
      expect(merged.state, JdliveState.live);
      expect(merged.restriction, LiveRestriction.none);
      final own = both().enrich(card);
      expect(own.title, '直播卖货', reason: 'a field the answer lacks is taken from the card');
      expect(own.hls.toString(), _hls());
      expect(card.enrich(both()).title, '直播卖货');
    });

    test('why a broadcast cannot be watched', () {
      expect(
        const JdliveBroadcast(liveId: _liveId, state: JdliveState.live).streamError?.message,
        contains('live without media'),
      );
      expect(
        const JdliveBroadcast(liveId: _liveId, state: JdliveState.replay).streamError?.message,
        contains('replay without a recording'),
      );
      expect(
        const JdliveBroadcast(
          liveId: _liveId,
          state: JdliveState.live,
          appOnly: true,
          restriction: LiveRestriction.appOnly,
        ).streamError?.message,
        contains('JD app only'),
        reason: 'app-only is asked before the state',
      );
      expect(
        const JdliveBroadcast(liveId: _liveId, state: JdliveState.offline).streamError?.message,
        contains('is offline'),
      );
      expect(both().streamError, isNull);
      expect(
        JdliveRoomParser.play(_playOf({'status': 3, 'h5VideoUrl': _recording()}), liveId: _liveId).streamError,
        isNull,
      );
    });

    test('the qualities that have an address, and their lines', () {
      final qualities = JdliveRoomParser.qualities(both());
      expect(qualities.map((quality) => quality.qualityId), [JdliveEndpoints.hlsId, JdliveEndpoints.flvId]);
      expect(qualities.map((quality) => quality.label), ['HLS（推荐）', 'FLV 原始线路']);
      expect(qualities.map((quality) => quality.platformOrder), [0, 1]);
      expect(
        JdliveRoomParser.qualities(JdliveRoomParser.play(_playOf({'videoUrl': null}), liveId: _liveId))
            .map((quality) => quality.qualityId),
        [JdliveEndpoints.hlsId],
        reason: 'a quality without an address is not offered',
      );
      final replay = JdliveRoomParser.play(_playOf({'status': 3, 'h5VideoUrl': _recording()}), liveId: _liveId);
      expect(JdliveRoomParser.qualities(replay).single.qualityId, JdliveEndpoints.replayId);
      expect(JdliveRoomParser.qualities(replay).single.label, JdliveEndpoints.replayLabel);
      expect(JdliveRoomParser.qualities(replay).single.platformOrder, 2);
      final line = JdliveRoomParser.line(both(), JdliveEndpoints.hlsId);
      expect(line.url, _hls());
      expect(line.format, LiveStreamFormat.hls);
      expect(line.lineLabel, 'live.jdcloud.com');
      expect(line.headers['referer'], isNotEmpty);
      expect(line.lease, isNull, reason: 'the addresses carry no signature or expiry');
      expect(JdliveRoomParser.line(both(), JdliveEndpoints.flvId).format, LiveStreamFormat.flv);
      expect(JdliveRoomParser.line(replay, JdliveEndpoints.replayId).url, _recording());
      expect(
        _failure(() => JdliveRoomParser.line(both(), 'auto')).message,
        contains('quality "auto" is not a JD Live quality'),
      );
      expect(
        _failure(() => JdliveRoomParser.line(both(), 'auto')).kind,
        JdliveFailureKind.invalidArgument,
        reason: 'asking for a quality the platform never has is a caller error',
      );
      expect(
        _failure(
          () => JdliveRoomParser.line(
            JdliveRoomParser.play(_playOf({'videoUrl': null}), liveId: _liveId),
            JdliveEndpoints.flvId,
          ),
        ).message,
        contains('no flv'),
      );
      expect(
        _kindOf(() => JdliveRoomParser.line(replay, JdliveEndpoints.hlsId)),
        JdliveFailureKind.streamUnavailable,
        reason: 'a replay has no live playlist to play',
      );
    });
  });
}
