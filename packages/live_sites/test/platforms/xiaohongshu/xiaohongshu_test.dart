import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_http.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_json.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_link.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_room_parser.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';
import 'package:test/test.dart';

/// A live room's id, an ended one's, and a third room a page may recommend.
const String _live = '570459564696889177';
const String _ended = '570305058583373361';
const String _other = '570341209400361612';

String _json(Object? data) => jsonEncode(data);

String _flv(String roomId, String host, [String query = '']) =>
    'https://$host.xhscdn.com/live/$roomId.flv${query.isEmpty ? '' : '?$query'}';

String _hls(String roomId) => 'https://live-source-play.xhscdn.com/live/$roomId.m3u8';

List<Map<String, String>> _h264Rows(String roomId) => [
  {
    'master_url': _flv(roomId, 'live-source-play', 'wsSecret=abc&wsTime=1234'),
    'quality_type': 'HD',
    'quality_type_name': '原画',
  },
  {'master_url': _flv(roomId, 'live-source-play-bak-tx'), 'quality_type': 'HD', 'quality_type_name': '原画'},
  {'master_url': _flv(roomId, 'live-source-play-hw'), 'quality_type': 'HD', 'quality_type_name': '原画'},
  {'master_url': _hls(roomId), 'quality_type': 'HD', 'quality_type_name': '原画'},
];

Map<String, dynamic> _pullConfig({String roomId = _live}) => {'h264': _h264Rows(roomId), 'width': 1080};

/// `roomInfo` of a live page, fresh per call so a test may bend any field.
Map<String, dynamic> _info({String roomId = _live}) => {
  'roomId': roomId,
  'status': 2,
  'monetizeType': 0,
  'joinLimitTypes': <dynamic>[0],
  'roomTitle': '晚间直播',
  'roomCover': 'https://pic.xhscdn.com/cover.png',
  'displayViewerCount': '300万+',
  'pullConfig': _json(_pullConfig(roomId: roomId)),
};

Map<String, dynamic> _host() => {'nickName': '主播甲', 'avatar': 'https://pic.xhscdn.com/a.png'};

/// The hydration state of a live share page.
Map<String, dynamic> _state() => {
  'pageStatus': 'success',
  'liveStatus': 'success',
  'roomData': {'roomInfo': _info(), 'hostInfo': _host()},
};

/// The hydration state of an ended share page: no `roomId` of its own, and
/// a recommended next room that must be ignored.
Map<String, dynamic> _endedState() {
  final info = _info(roomId: _ended)
    ..['status'] = 3
    ..remove('roomId')
    ..remove('pullConfig')
    ..remove('displayViewerCount');
  return {
    'pageStatus': 'success',
    'liveStatus': 'end',
    'roomData': {'roomInfo': info, 'hostInfo': _host()},
    'nextRoomInfo': {
      'roomInfo': {'roomId': _other, 'pullConfig': _json(_pullConfig(roomId: _other))},
    },
  };
}

/// A share page holding [state]; the state is followed by `;`, as the web
/// page writes it.
String _pageHtml(Map<String, dynamic> state) =>
    '<html><head><title>直播</title></head><body>'
    '<script>window.__INITIAL_STATE__=${_json({'liveStream': state})};</script>'
    '</body></html>';

XiaohongshuPage _parse(Map<String, dynamic> state, {String roomId = _live, int status = 200, String? body}) =>
    XiaohongshuRoomParser.room(body ?? _pageHtml(state), requestedId: roomId, status: status);

/// `roomInfo` of [state], as a fresh map to bend.
Map<String, dynamic> _roomInfo(Map<String, dynamic> state) =>
    (state['roomData'] as Map<String, dynamic>)['roomInfo'] as Map<String, dynamic>;

/// [state] with its `pullConfig` rewritten by [edit] (re-encoded).
Map<String, dynamic> _editStreams(Map<String, dynamic> state, void Function(Map<String, dynamic> config) edit) {
  final info = _roomInfo(state);
  final config = _jsonDecode(info['pullConfig'] as String);
  edit(config);
  info['pullConfig'] = _json(config);
  return state;
}

Map<String, dynamic> _jsonDecode(String text) => jsonDecode(text) as Map<String, dynamic>;

/// Row [index] of the `h264` list of a decoded `pullConfig`.
Map<String, dynamic> _row(Map<String, dynamic> config, int index) =>
    (config['h264'] as List<dynamic>)[index] as Map<String, dynamic>;

Matcher _fails(XiaohongshuFailureKind kind) =>
    throwsA(predicate((error) => error is XiaohongshuFailure && error.kind == kind));

LiveResponse _resp(int status, String body, {Map<String, String> headers = const {}}) =>
    LiveResponse(statusCode: status, headers: headers, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request) : url = request.url;
  final Uri url;
}

final class _FakeHttp implements LiveHttp {
  new(this.onSend);
  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final seen = _Seen(request);
    sent.add(seen);
    return await onSend(seen);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// The answers of the site: the live page, the ended page, 404 elsewhere on
/// the share host, and a short link that lands on the live page.
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  if (path == '/livestream/$_live') return _resp(200, _pageHtml(_state()));
  if (path == '/livestream/$_ended') return _resp(200, _pageHtml(_endedState()));
  if (request.url.host == 'xhslink.com') {
    return _resp(302, 'moved', headers: {'location': XiaohongshuEndpoints.roomUrl(_live).toString()});
  }
  if (path.startsWith('/livestream/')) return _resp(404, 'not found');
  return _resp(200, '<html><body>not a room</body></html>');
}

({XiaohongshuSite site, _FakeHttp http}) _adapter({LiveResponse Function(_Seen request)? onSend}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: XiaohongshuSite(http: XiaohongshuHttp(http)), http: http);
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

void main() {
  group('readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, XiaohongshuFailureKind kind) {
        try {
          XiaohongshuJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on XiaohongshuFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, XiaohongshuFailureKind.riskControl);
      expectKind(403, XiaohongshuFailureKind.riskControl);
      expectKind(406, XiaohongshuFailureKind.riskControl);
      expectKind(404, XiaohongshuFailureKind.notFound);
      expectKind(429, XiaohongshuFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, XiaohongshuFailureKind.network);
      }
      XiaohongshuJson.checkStatus(200, 'x');
    });

    test('objects and short texts are read strictly', () {
      expect(XiaohongshuJson.object({'a': 1}, 'x'), {'a': 1});
      expect(() => XiaohongshuJson.object(42, 'x'), _fails(XiaohongshuFailureKind.apiChanged));
      expect(XiaohongshuJson.text(null, 'x'), isNull);
      expect(XiaohongshuJson.text('ok', 'x'), 'ok');
      expect(() => XiaohongshuJson.text(42, 'x'), _fails(XiaohongshuFailureKind.apiChanged));
      expect(() => XiaohongshuJson.text('x' * 4097, 'x'), _fails(XiaohongshuFailureKind.apiChanged));
    });

    test('a count is an integer of zero or more, or its text', () {
      expect(XiaohongshuJson.count(2), 2);
      expect(XiaohongshuJson.count(' 2 '), 2);
      expect(XiaohongshuJson.count(0), 0);
      expect(XiaohongshuJson.count(-1), isNull);
      expect(XiaohongshuJson.count('live'), isNull);
      expect(XiaohongshuJson.count(true), isNull);
      expect(XiaohongshuJson.count('01234567890'), isNull, reason: 'nine digits at most');
    });

    test('a failure kind maps onto the boundary error it names', () {
      LiveSiteError map(XiaohongshuFailureKind kind) => XiaohongshuFailure(kind, 'x').toLiveSiteError('xiaohongshu');
      expect(map(XiaohongshuFailureKind.notFound), isA<LiveSiteNotFound>());
      expect(map(XiaohongshuFailureKind.apiChanged), isA<LiveSiteParseError>());
      expect(map(XiaohongshuFailureKind.network), isA<LiveSiteNetworkError>());
      expect(map(XiaohongshuFailureKind.riskControl), isA<LiveSiteRateLimitError>());
      expect(map(XiaohongshuFailureKind.rateLimited), isA<LiveSiteRateLimitError>());
      expect(map(XiaohongshuFailureKind.streamUnavailable), isA<LiveSiteContentUnavailable>());
      expect(map(XiaohongshuFailureKind.needsLogin), isA<LiveSiteAuthenticationError>());
      expect(map(XiaohongshuFailureKind.regionBlocked), isA<LiveSiteContentUnavailable>());
      expect(map(XiaohongshuFailureKind.invalidArgument), isA<LiveSiteInvalidArgument>());
      expect(const XiaohongshuFailure(XiaohongshuFailureKind.network, 'x').isTransient, isTrue);
      expect(const XiaohongshuFailure(XiaohongshuFailureKind.rateLimited, 'x').isTransient, isTrue);
      expect(const XiaohongshuFailure(XiaohongshuFailureKind.notFound, 'x').isTransient, isFalse);
    });
  });

  group('hydration', () {
    test('bare undefined outside strings becomes null, a title keeps the word', () {
      final state = _state();
      _roomInfo(state)['roomTitle'] = r'undefined \ "undefined"';
      final page =
          '<script>window.__INITIAL_STATE__={"global":{"jsAssetsList":undefined,"tiers":[undefined]},'
          '"liveStream":${_json(state)}}</script>';
      expect(_parse(state, body: page).room.content.title, r'undefined \ "undefined"');
    });

    for (final source in [
      'undefinedCall()',
      'undefinedSuffix',
      '(undefined)',
      '(()=>undefined)()',
      'NaN',
      'Infinity',
    ]) {
      test('an expression that is not JSON is api-changed: $source', () {
        final page = '<script>window.__INITIAL_STATE__={"global":$source,"liveStream":${_json(_state())}}</script>';
        expect(() => _parse(_state(), body: page), _fails(XiaohongshuFailureKind.apiChanged));
      });
    }

    for (final (name, page) in [
      ('no hydration script', '直播已结束'),
      ('an executable state', '<script>window.__INITIAL_STATE__=alert(1)</script>'),
      ('a null liveStream', '<script>window.__INITIAL_STATE__={"liveStream":undefined}</script>'),
      ('two hydration scripts', _pageHtml(_state()) + _pageHtml(_state())),
      ('an oversize page', _pageHtml(_state()) + 'a' * (XiaohongshuEndpoints.responseLimit + 1)),
    ]) {
      test('api-changed: $name (${page.length} characters)', () {
        expect(() => _parse(_state(), body: page), _fails(XiaohongshuFailureKind.apiChanged));
      });
    }

    test('an oversize page is counted in UTF-8 bytes', () {
      final page = '${_pageHtml(_state())}<!--${'页' * (XiaohongshuEndpoints.responseLimit ~/ 3)}-->';
      expect(page.length, lessThan(XiaohongshuEndpoints.responseLimit));
      expect(() => _parse(_state(), body: page), _fails(XiaohongshuFailureKind.apiChanged));
    });
  });

  group('share page', () {
    test('a live room carries its card, its state and the notice lines', () {
      final page = _parse(_state());
      final room = page.room;
      expect(room.roomId, _live);
      expect(room.platform, 'xiaohongshu');
      expect(room.links.webUrl, XiaohongshuEndpoints.roomUrl(_live).toString());
      expect(room.content.title, '晚间直播');
      expect(room.content.coverUrl, 'https://pic.xhscdn.com/cover.png');
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.avatarUrl, 'https://pic.xhscdn.com/a.png');
      expect(room.anchor?.anchorId, '', reason: 'the page names no streamer id the adapter may follow');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.broadcast.startedAt, isNull, reason: 'the share page has no start time');
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(room.audience.onlineViewers, isNull, reason: 'the display count is text, never an audience');
      expect(page.data.access, XiaohongshuAccess.public);
      expect(page.data.live, isTrue);
      expect(page.data.displayViewers, '300万+');
      expect(
        room.content.notice,
        '${XiaohongshuRoomParser.roomScopeNotice}\n${XiaohongshuRoomParser.displayViewersNotice('300万+')}',
      );
    });

    test('an ended room is offline, its recommended next room is ignored', () {
      final page = _parse(_endedState(), roomId: _ended);
      expect(page.room.broadcast.liveStatus, LiveStatus.offline);
      expect(page.room.broadcast.restriction, isNull, reason: 'an ended broadcast carries none');
      expect(page.data.live, isFalse);
      expect(page.data.pullConfig, isNull);
      expect(page.room.content.notice, XiaohongshuRoomParser.roomScopeNotice);
      expect(() => XiaohongshuRoomParser.playable(page.data), _fails(XiaohongshuFailureKind.streamUnavailable));
    });

    test('a state other than 2 and 3 stays unknown, whatever liveStatus says', () {
      final state = _state();
      _roomInfo(state)['status'] = 9;
      final page = _parse(state);
      expect(page.room.broadcast.liveStatus, LiveStatus.unknown);
      expect(page.data.live, isNull);
      expect(page.data.pullConfig, isNull);
      expect(() => XiaohongshuRoomParser.playable(page.data), _fails(XiaohongshuFailureKind.streamUnavailable));
    });

    test('a title holding "直播已结束" does not change the state', () {
      final state = _state();
      _roomInfo(state)['roomTitle'] = '直播已结束';
      expect(_parse(state).room.broadcast.liveStatus, LiveStatus.live);
    });

    test('the values written as strings are accepted too', () {
      final state = _state();
      _roomInfo(state)['pullConfig'] = jsonDecode(_roomInfo(state)['pullConfig'] as String);
      _roomInfo(state)
        ..['status'] = '2'
        ..['monetizeType'] = '0'
        ..['joinLimitTypes'] = '[0]';
      final page = _parse(state);
      expect(page.room.broadcast.liveStatus, LiveStatus.live);
      expect(page.data.access, XiaohongshuAccess.public);
      expect(XiaohongshuRoomParser.playable(page.data), hasLength(4));
    });

    test('pageStatus "error" is not-found, another one is api-changed', () {
      final errorState = _state()
        ..['pageStatus'] = 'error'
        ..['errorMessage'] = '未找到直播间，请稍后再试';
      try {
        _parse(errorState, roomId: _other);
        fail('no throw');
      } on XiaohongshuFailure catch (failure) {
        expect(failure.kind, XiaohongshuFailureKind.notFound);
        expect(failure.message, contains('未找到直播间，请稍后再试'));
      }
      final silentState = _state()..['pageStatus'] = 'error';
      expect(() => _parse(silentState, roomId: _other), _fails(XiaohongshuFailureKind.notFound));
      final oddState = _state()..['pageStatus'] = 'redirect';
      expect(() => _parse(oddState), _fails(XiaohongshuFailureKind.apiChanged));
    });

    test('a room id that is not one is refused before parsing', () {
      for (final id in ['', '0', '../123', ' 123', '123?', '123/4', '123\n', '123456789012345678901']) {
        expect(() => _parse(_state(), roomId: id), throwsArgumentError, reason: id);
      }
    });

    test('a live page must name exactly the room asked for', () {
      for (final id in <Object?>[null, int.parse(_live), _other]) {
        final state = _state();
        _roomInfo(state)['roomId'] = id;
        expect(() => _parse(state), _fails(XiaohongshuFailureKind.apiChanged), reason: '$id');
      }
    });

    test('an ended page naming another room is not accepted', () {
      final state = _endedState();
      _roomInfo(state)['roomId'] = _live;
      expect(() => _parse(state, roomId: _ended), _fails(XiaohongshuFailureKind.apiChanged));
    });

    test('a live page must have a room id, and the status must agree with liveStatus', () {
      final noId = _state();
      _roomInfo(noId).remove('roomId');
      expect(() => _parse(noId), _fails(XiaohongshuFailureKind.apiChanged));
      final mismatch = _state()..['liveStatus'] = 'end';
      expect(() => _parse(mismatch), _fails(XiaohongshuFailureKind.apiChanged));
      final ended = _endedState()..['liveStatus'] = 'success';
      expect(() => _parse(ended, roomId: _ended), _fails(XiaohongshuFailureKind.apiChanged));
    });

    test('fields of the wrong shape are api-changed', () {
      Object? edit(Map<String, dynamic> state, String key, Object? value) => _roomInfo(state)[key] = value;
      for (final (name, changes) in [
        ('roomData not an object', (Map<String, dynamic> state) => state['roomData'] = <Object?>[]),
        (
          'hostInfo missing',
          (Map<String, dynamic> state) => (state['roomData'] as Map<String, dynamic>).remove('hostInfo'),
        ),
        ('a negative status', (Map<String, dynamic> state) => edit(state, 'status', -1)),
        ('status true', (Map<String, dynamic> state) => edit(state, 'status', true)),
        ('joinLimitTypes "0"', (Map<String, dynamic> state) => edit(state, 'joinLimitTypes', '0')),
        ('joinLimitTypes [-1]', (Map<String, dynamic> state) => edit(state, 'joinLimitTypes', [-1])),
        ('17 join limits', (Map<String, dynamic> state) => edit(state, 'joinLimitTypes', List.filled(17, 0))),
        ('monetizeType false', (Map<String, dynamic> state) => edit(state, 'monetizeType', false)),
        ('a numeric title', (Map<String, dynamic> state) => edit(state, 'roomTitle', 42)),
        ('an overlong title', (Map<String, dynamic> state) => edit(state, 'roomTitle', 'x' * 4097)),
      ]) {
        final state = _state();
        changes(state);
        expect(() => _parse(state), _fails(XiaohongshuFailureKind.apiChanged), reason: name);
      }
    });

    for (final (status, kind) in [
      (302, XiaohongshuFailureKind.network),
      (401, XiaohongshuFailureKind.riskControl),
      (403, XiaohongshuFailureKind.riskControl),
      (404, XiaohongshuFailureKind.notFound),
      (429, XiaohongshuFailureKind.rateLimited),
      (503, XiaohongshuFailureKind.network),
    ]) {
      test('HTTP $status is not a page state', () {
        expect(() => XiaohongshuRoomParser.room('', requestedId: _live, status: status), _fails(kind));
      });
    }
  });

  group('restriction', () {
    // The kinds are the web page's enums (monetizeType Free 0, Paid 1;
    // joinLimitTypes GroupChat 1, Family 2, IpFence 4).
    for (final (name, monetize, limits, restriction, playKind) in [
      ('paid', 1, const [0], LiveRestriction.paid, XiaohongshuFailureKind.streamUnavailable),
      ('another paid kind', 3, const [0], LiveRestriction.paid, XiaohongshuFailureKind.streamUnavailable),
      ('group chat', 0, const [1], LiveRestriction.private, XiaohongshuFailureKind.streamUnavailable),
      ('family', 0, const [2], LiveRestriction.private, XiaohongshuFailureKind.streamUnavailable),
      ('IP fence', 0, const [4], LiveRestriction.regionBlocked, XiaohongshuFailureKind.regionBlocked),
      ('a future limit', 0, const [32], LiveRestriction.unplayable, XiaohongshuFailureKind.streamUnavailable),
      (
        'a future limit and a fence',
        0,
        const [0, 32, 4],
        LiveRestriction.regionBlocked,
        XiaohongshuFailureKind.regionBlocked,
      ),
      ('paid and fenced', 1, const [4, 1], LiveRestriction.paid, XiaohongshuFailureKind.streamUnavailable),
    ]) {
      test('$name: live with its restriction; no stream is read, playing says why', () {
        final state = _state();
        final info = state['roomData'] as Map<String, dynamic>;
        info['roomInfo'] = {
          ...info['roomInfo'] as Map<String, dynamic>,
          'monetizeType': monetize,
          'joinLimitTypes': limits,
          'pullConfig': 'broken preview',
        };
        final page = _parse(state);
        expect(page.data.access, XiaohongshuAccess.restricted);
        expect(page.data.restriction, restriction);
        expect(page.data.pullConfig, isNull, reason: 'no stream is kept for a restricted room');
        expect(
          page.room.broadcast.liveStatus,
          LiveStatus.live,
          reason: 'the room is live; it is the stream that is closed',
        );
        expect(page.room.broadcast.restriction, restriction);
        expect(page.room.content.notice, contains(XiaohongshuRoomParser.restrictedNotice));
        expect(() => XiaohongshuRoomParser.playable(page.data), _fails(playKind));
      });
    }

    for (final (name, key) in [
      ('monetizeType missing', 'monetizeType'),
      ('joinLimitTypes missing', 'joinLimitTypes'),
    ]) {
      test('$name: access not known; playing needs an account', () {
        final state = _state();
        _roomInfo(state).remove(key);
        final page = _parse(state);
        expect(page.data.access, XiaohongshuAccess.unknown);
        expect(page.data.restriction, isNull);
        expect(page.data.pullConfig, isNull);
        expect(page.room.broadcast.restriction, isNull);
        expect(page.room.content.notice, contains(XiaohongshuRoomParser.unknownAccessNotice));
        expect(page.room.content.notice, isNot(contains(XiaohongshuRoomParser.restrictedNotice)));
        expect(() => XiaohongshuRoomParser.playable(page.data), _fails(XiaohongshuFailureKind.needsLogin));
      });
    }

    test('an ended room carries no restriction on the card, even a restricted one', () {
      final state = _endedState();
      _roomInfo(state)['monetizeType'] = 1;
      final page = _parse(state, roomId: _ended);
      expect(page.data.restriction, LiveRestriction.paid);
      expect(page.room.broadcast.restriction, isNull);
    });

    for (final (name, pull) in [
      ('no pullConfig', null),
      ('an empty pullConfig', ''),
      ('no rows', _json({'h264': <Object?>[], 'h265': <Object?>[], 'width': 1080})),
      ('no codec lists', _json({'width': 1080})),
    ]) {
      test('a live public room with $name is unplayable', () {
        final state = _state();
        final info = state['roomData'] as Map<String, dynamic>;
        final roomInfo = {...info['roomInfo'] as Map<String, dynamic>};
        if (pull == null) {
          roomInfo.remove('pullConfig');
        } else {
          roomInfo['pullConfig'] = pull;
        }
        info['roomInfo'] = roomInfo;
        final page = _parse(state);
        expect(page.room.broadcast.liveStatus, LiveStatus.live);
        expect(page.room.broadcast.restriction, LiveRestriction.unplayable);
        expect(page.data.restriction, LiveRestriction.none);
        expect(() => XiaohongshuRoomParser.playable(page.data), _fails(XiaohongshuFailureKind.streamUnavailable));
      });
    }

    test('a pullConfig that cannot be read is not called unplayable: playing tells why', () {
      final state = _state();
      _roomInfo(state)['pullConfig'] = '{';
      final page = _parse(state);
      expect(page.room.broadcast.restriction, LiveRestriction.none);
      expect(() => XiaohongshuRoomParser.playable(page.data), _fails(XiaohongshuFailureKind.apiChanged));
    });

    for (final (name, value) in [
      ('a number', 42),
      ('over 65536 characters', ' ' * 65537),
      ('an unreadable JSON string', '{'),
    ]) {
      // The page is read; playback fails instead (3.x failed the whole page).
      test('a broken pullConfig ($name) fails playing, not reading', () {
        final state = _state();
        _roomInfo(state)['pullConfig'] = value;
        final page = _parse(state);
        expect(page.room.broadcast.liveStatus, LiveStatus.live);
        expect(() => XiaohongshuRoomParser.playable(page.data), _fails(XiaohongshuFailureKind.apiChanged));
      });
    }
  });

  group('streams', () {
    List<XiaohongshuStream> streamsOf(Map<String, dynamic> state) => XiaohongshuRoomParser.playable(_parse(state).data);

    test('the addresses are read in page order, one quality per quality_type', () {
      final state = _state();
      final streams = streamsOf(state);
      expect(streams.map((stream) => stream.codec), everyElement('h264'));
      expect(streams.map((stream) => '${stream.url}'), [
        _flv(_live, 'live-source-play', 'wsSecret=abc&wsTime=1234'),
        _flv(_live, 'live-source-play-bak-tx'),
        _flv(_live, 'live-source-play-hw'),
        _hls(_live),
      ]);
      final qualities = XiaohongshuRoomParser.qualities(streams);
      expect(qualities.single.label, '原画');
      expect(qualities.single.qualityId, 'HD');
    });

    test('the lines: H.264 first, FLV first within a codec, headers, no lease', () {
      final state = _state();
      final lines = XiaohongshuRoomParser.lines(_parse(state).data, null);
      expect(lines.map((line) => line.lineLabel), [
        'flv:live-source-play',
        'flv:live-source-play-bak-tx',
        'flv:live-source-play-hw',
        'hls:live-source-play',
      ]);
      expect(lines.map((line) => line.format), [
        LiveStreamFormat.flv,
        LiveStreamFormat.flv,
        LiveStreamFormat.flv,
        LiveStreamFormat.hls,
      ]);
      for (final line in lines) {
        expect(line.formatSource, LivePlayFormatSource.inferred);
        expect(line.codec, LiveStreamCodec.avc);
        expect(line.lease, isNull, reason: 'plain addresses without a signature');
        expect(line.headers, XiaohongshuEndpoints.headers);
        expect(line.headers.keys, isNot(contains('cookie')));
        expect(Uri.parse(line.url).path, anyOf('/live/$_live.m3u8', '/live/$_live.flv'));
      }
    });

    test('H.265 addresses join the quality as hevc lines after the H.264 ones', () {
      final state = _editStreams(_state(), (config) {
        config['h265'] = [
          {
            'master_url': '${_flv(_live, 'live-source-play', 'wsSecret=abc&wsTime=1234')}&codec=hevc',
            'quality_type': 'HD',
            'quality_type_name': '原画',
          },
          {
            'master_url': '${_flv(_live, 'live-source-play-hw')}?codec=hevc',
            'quality_type': 'HD',
            'quality_type_name': '原画',
          },
        ];
      });
      final streams = streamsOf(state);
      expect(XiaohongshuRoomParser.qualities(streams), hasLength(1));
      final lines = XiaohongshuRoomParser.lines(_parse(state).data, null);
      expect(lines.map((line) => (line.lineLabel, line.codec)), [
        ('flv:live-source-play', LiveStreamCodec.avc),
        ('flv:live-source-play-bak-tx', LiveStreamCodec.avc),
        ('flv:live-source-play-hw', LiveStreamCodec.avc),
        ('hls:live-source-play', LiveStreamCodec.avc),
        ('flv:live-source-play:hevc', LiveStreamCodec.hevc),
        ('flv:live-source-play-hw:hevc', LiveStreamCodec.hevc),
      ]);
    });

    test('several quality types stay apart, in address order, each named by the page', () {
      final state = _editStreams(_state(), (config) {
        final h264 = config['h264'] as List<dynamic>;
        config['h265'] = [
          {...h264[1] as Map<String, dynamic>, 'quality_type': 'SD', 'quality_type_name': '标清'},
        ];
      });
      final qualities = XiaohongshuRoomParser.qualities(streamsOf(state));
      expect(qualities.map((quality) => (quality.label, quality.qualityId)), [('原画', 'HD'), ('标清', 'SD')]);
      final lines = XiaohongshuRoomParser.lines(_parse(state).data, qualities.last);
      expect(lines, hasLength(1));
      expect(lines.single.lineLabel, 'flv:live-source-play-bak-tx:hevc');
      expect(lines.single.codec, LiveStreamCodec.hevc);
    });

    test('repeated hosts get numbered line labels', () {
      final state = _editStreams(_state(), (config) {
        final repeated = _row(config, 0);
        (config['h264'] as List<dynamic>).add({...repeated, 'master_url': '${repeated['master_url']}&backup=1'});
      });
      final lines = XiaohongshuRoomParser.lines(_parse(state).data, null);
      expect(lines.map((line) => line.lineLabel), [
        'flv:live-source-play',
        'flv:live-source-play-bak-tx',
        'flv:live-source-play-hw',
        'flv:live-source-play#2',
        'hls:live-source-play',
      ]);
    });

    test("3.x's quality ids map to the ids now, and still play", () {
      for (final (legacy, now) in [
        ('h264:HD', 'HD'),
        ('h265:HD', 'HD'),
        (' H264:SD ', 'SD'),
        ('h265:SD', 'SD'),
        ('HD', 'HD'),
        ('h266:HD', 'h266:HD'),
        ('原画 · H264', '原画 · H264'),
      ]) {
        expect(XiaohongshuEndpoints.qualityIdFromLegacy(legacy), now, reason: legacy);
        expect(XiaohongshuEndpoints.qualityIdFromLegacy(now), now, reason: 'applied again: $now');
      }
      final state = _state();
      final lines = XiaohongshuRoomParser.lines(
        _parse(state).data,
        const LivePlayQuality(label: '原画 · H264', qualityId: 'h264:HD'),
      );
      expect(lines, hasLength(4));
    });

    test('a quality the addresses no longer have is stream-unavailable', () {
      final state = _state();
      for (final id in ['h264:SD', 'SD']) {
        expect(
          () => XiaohongshuRoomParser.lines(_parse(state).data, LivePlayQuality(label: '原画', qualityId: id)),
          _fails(XiaohongshuFailureKind.streamUnavailable),
          reason: id,
        );
      }
    });

    test('an address outside the room contract is left out; all of them is api-changed', () {
      for (final url in [
        'https://xhscdn.com.evil.test/live/$_live.flv',
        'https://127.0.0.1/live/$_live.flv',
        'https://live-source-play.xhscdn.com/live/$_ended.flv',
        'https://u:p@live-source-play.xhscdn.com/live/$_live.flv',
        'https://live-source-play.xhscdn.com:8443/live/$_live.flv',
        'https://live-source-play.xhscdn.com/live/$_live.flv#x',
        'file:///live/$_live.flv',
        'https://live-source-play.xhscdn.com/live/$_live.png',
        'https://live-source-play.xhscdn.com/live/$_live.flv?${'x' * 4096}',
      ]) {
        final state = _editStreams(_state(), (config) => _row(config, 1)['master_url'] = url);
        final streams = streamsOf(state);
        expect(streams.map((stream) => '${stream.url}'), isNot(contains(url)), reason: url);
        expect(streams, hasLength(3), reason: url);
        final allBad = _editStreams(_state(), (config) {
          for (final row in (config['h264'] as List).cast<Map<String, dynamic>>()) {
            row['master_url'] = url;
          }
        });
        expect(() => streamsOf(allBad), _fails(XiaohongshuFailureKind.apiChanged), reason: url);
      }
    });

    test('a row with a missing or ill-typed field is left out', () {
      for (final (name, edit) in [
        ('no address', (Map<String, dynamic> row) => row.remove('master_url')),
        ('a numeric address', (Map<String, dynamic> row) => row['master_url'] = 42),
        ('an empty quality', (Map<String, dynamic> row) => row['quality_type'] = ''),
        ('no label', (Map<String, dynamic> row) => row.remove('quality_type_name')),
        ('an empty label', (Map<String, dynamic> row) => row['quality_type_name'] = ''),
        ('a long quality', (Map<String, dynamic> row) => row['quality_type'] = 'Q' * 65),
        ('a long label', (Map<String, dynamic> row) => row['quality_type_name'] = 'L' * 129),
      ]) {
        final state = _editStreams(_state(), (config) => edit(_row(config, 0)));
        expect(streamsOf(state), hasLength(3), reason: name);
      }
    });

    test('a row that is not an object is left out; the other codec still plays', () {
      final state = _editStreams(_state(), (config) {
        config['h265'] = [(config['h264'] as List<dynamic>)[1]];
        config['h264'] = [42, 'row', null];
      });
      final streams = streamsOf(state);
      expect(streams.single.codec, 'h265');
      final lines = XiaohongshuRoomParser.lines(_parse(state).data, null);
      expect(lines.single.lineLabel, 'flv:live-source-play-bak-tx:hevc');
      expect(lines.single.codec, LiveStreamCodec.hevc);
    });

    test('exact repeats are one address; at most 32 rows per codec', () {
      final state = _editStreams(_state(), (config) {
        final first = _row(config, 0);
        (config['h264'] as List<dynamic>).add({...first});
      });
      expect(streamsOf(state), hasLength(4), reason: 'the repeated row is the same address');
      final over = _editStreams(_state(), (config) {
        config['h264'] = List.filled(33, _row(config, 0));
      });
      expect(() => streamsOf(over), _fails(XiaohongshuFailureKind.apiChanged));
    });
  });

  group('links', () {
    test('room ids, deep links and share pages name a room without a request', () {
      expect(XiaohongshuLink.roomIdFrom(' $_live '), _live);
      expect(XiaohongshuLink.roomIdFrom('xhsdiscover://live_audience?room_id=$_live&source=share'), _live);
      expect(XiaohongshuLink.roomIdFrom('https://www.xiaohongshu.com/livestream/$_live'), _live);
      expect(XiaohongshuLink.roomIdFrom('主播昵称'), isNull);
      expect(XiaohongshuLink.roomIdFrom('0'), isNull);
    });

    test('a deep link names only its room; flvUrl is a preload hint', () {
      expect(
        XiaohongshuLink.deepLinkRoomId(
          'xhsdiscover://live_audience?room_id=$_live&source=share&flvUrl=http%3A%2F%2F127.0.0.1%2Fprivate',
        ),
        _live,
      );
      expect(XiaohongshuLink.deepLinkRoomId('XHSDISCOVER://LIVE_AUDIENCE?room_id=$_live&source=share'), _live);
      expect(XiaohongshuLink.deepLinkRoomId('xhsdiscover://live_audience?source=a&room_id=$_live&source=b'), _live);
      expect(XiaohongshuLink.deepLinkRoomId('xhsdiscover://live_audience?room_id=$_live'), _live);
      for (final link in [
        'xhsdiscover://live_audience?source=share',
        'xhsdiscover://live_audience?room_id=$_live&room_id=42&source=share',
        'xhsdiscover://live_audience?room_id=0&source=share',
        'xhsdiscover://live_audience?room_id=&source=share',
        'xhsdiscover://live_audience/path?room_id=$_live&source=share',
        'xhsdiscover://live_audience?room_id=$_live&source=share#fragment',
        'xhsdiscover://live_audience:8080?room_id=$_live&source=share',
        'xhsdiscover://other?room_id=$_live&source=share',
      ]) {
        expect(XiaohongshuLink.deepLinkRoomId(link), isNull, reason: link);
        expect(XiaohongshuLink.roomIdFrom(link), isNull, reason: link);
      }
    });

    test('a share page alias names its room', () {
      for (final url in [
        'https://www.xiaohongshu.com/livestream/$_live',
        'https://xiaohongshu.com/livestream/$_live',
        'http://www.xiaohongshu.com:80/livestream/$_live/',
        'https://www.xiaohongshu.com:443/hina/livestream/$_live',
        'https://www.xiaohongshu.com/hina/livestream/$_live/123?room_id=42',
        'https://www.xiaohongshu.com/livestream/dynpath9oMyTyTC/$_live?xsec_token=fixture#ignored',
        'https://www.xiaohongshu.com/livestream/$_live?share_id=fixture',
      ]) {
        expect(XiaohongshuLink.webRoomId(url), _live, reason: url);
      }
    });

    test('not a share page', () {
      for (final url in [
        'https://www.xiaohongshu.com/',
        'https://www.xiaohongshu.com/user/profile/$_live',
        'https://www.xiaohongshu.com/explore/$_live',
        'https://www.xiaohongshu.com.evil.test/livestream/$_live',
        'https://www.xiaohongshu.com:8787/livestream/$_live',
        'https://user@www.xiaohongshu.com/livestream/$_live',
        'ftp://www.xiaohongshu.com/livestream/$_live',
        'https://www.xiaohongshu.com/livestream/$_live/.',
        'https://www.xiaohongshu.com/livestream/42/../$_live',
        'https://www.xiaohongshu.com/livestream/%35$_live',
        r'https://www.xiaohongshu.com/livestream/42\../' + _live,
        'https://www.xiaohongshu.com/livestream/dynpathBAD/$_live',
        'https://www.xiaohongshu.com/livestream/arbitrary/$_live',
        'https://www.xiaohongshu.com/livestream/$_live/extra',
        'https://www.xiaohongshu.com/hina/livestream/0/123',
        'https://www.xiaohongshu.com/hina/livestream/$_live/123/extra',
        'https://live.bilibili.com/123',
        'https://[broken',
        '',
      ]) {
        expect(XiaohongshuLink.webRoomId(url), isNull, reason: url);
      }
    });

    test('short links are xhslink.com codes only', () {
      expect(XiaohongshuLink.shortLink('https://xhslink.com/m/18ox3lAz')?.toString(), 'https://xhslink.com/m/18ox3lAz');
      expect(XiaohongshuLink.shortLink('http://xhslink.com/zfknEQ/'), isNotNull);
      expect(XiaohongshuLink.shortLink('https://xhslink.com/o/AbC123'), isNotNull, reason: 'the app shares /o/');
      expect(XiaohongshuLink.shortLink('https://xhslink.com/abcd/AbC123/'), isNotNull, reason: 'four letters');
      for (final url in [
        'https://www.xhslink.com/m/abc',
        'https://xhslink.com.evil.test/m/abc',
        'https://xhslink.com/m/abc/../def',
        'https://xhslink.com:8443/m/abc',
        'ftp://xhslink.com/m/abc',
        'https://xhslink.com/abcde/xyz',
        'https://xhslink.com/o1/AbC123',
        'https://xhslink.com/o/AbC123/extra',
        'https://xhslink.com/o/m/AbC123',
        'https://example.com/o/AbC123',
      ]) {
        expect(XiaohongshuLink.shortLink(url), isNull, reason: url);
      }
    });

    test('share texts: deep links not glued to another URL, prose cut off', () {
      expect(XiaohongshuLink.shareTextRoomIds('直播入口：xhsdiscover://live_audience?room_id=$_live&source=share，复制'), [
        _live,
      ]);
      expect(XiaohongshuLink.shareTextRoomIds('xhsdiscover://live_audience?room_id=$_live&source=share).'), [_live]);
      expect(
        XiaohongshuLink.shareTextRoomIds(
          'https://example.com/?target=xhsdiscover://live_audience?room_id=$_live&source=share '
          'ftp://xhsdiscover://live_audience?room_id=$_live&source=share',
        ),
        isEmpty,
      );
    });

    test('the room a landing page names is read best effort', () {
      expect(XiaohongshuRoomParser.roomIdInPage(_pageHtml(_state())), _live);
      expect(XiaohongshuRoomParser.roomIdInPage(_pageHtml(_endedState())), isNull, reason: 'an ended page names none');
      expect(XiaohongshuRoomParser.roomIdInPage('<html><body>not a room</body></html>'), isNull);
      expect(XiaohongshuRoomParser.roomIdInPage('<script>window.__INITIAL_STATE__=alert(1)</script>'), isNull);
    });
  });

  group('adapter wiring', () {
    test('the manifest, the lifecycle and the capabilities of a link-only site', () async {
      final adapter = _adapter();
      final site = adapter.site;
      expect(site.manifest.id, 'xiaohongshu');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      // The reference has neither an area API nor danmaku.
      expect(site.capability<LiveAreaProvider>(), isNull);
      expect(site.capability<LiveDanmakuProvider>(), isNull);
      expect(identical(site.capability<LiveRoomProvider>(), site.capability<LiveRoomProvider>()), isTrue);
      await site.dispose();
    });

    test('an entry is the room with its stream data', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_live));
      expect(adapter.http.sent.single.url, XiaohongshuEndpoints.roomUrl(_live));
      expect(adapter.http.sent.single.url.host, 'www.xiaohongshu.com');
      expect(room.roomId, _live);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.streamHandle, isA<XiaohongshuRoomData>());
      final data = room.runtime.streamHandle! as XiaohongshuRoomData;
      expect(data.roomId, _live);
      expect(data.live, isTrue);
      expect(data.access, XiaohongshuAccess.public);
    });

    test('an id that is not a room id is not-found without a request', () async {
      final adapter = _adapter();
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('abc')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty);
    });

    test('the directory and the recommendations are empty, without a request', () async {
      final adapter = _adapter();
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final page = _right(await rooms.getRooms(const LivePageRequest()));
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      final recommended = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 3)));
      expect(recommended.items, isEmpty);
      expect(recommended.hasMore, isFalse);
      expect(adapter.http.sent, isEmpty, reason: 'no public list is reachable anonymously');
      expect(_leftOf(await rooms.getRooms(const LivePageRequest(page: 0))), isA<LiveSiteInvalidArgument>());
      expect(
        _leftOf(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(adapter.http.sent, isEmpty);
    });

    test('a search finds the room an id, a share page or a deep link names', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      for (final query in [
        _live,
        ' $_live ',
        'https://www.xiaohongshu.com/livestream/$_live?xsec_token=abc',
        'xhsdiscover://live_audience?room_id=$_live&source=share',
      ]) {
        final page = await search.search(LiveSearchRequest(query: query, target: LiveSearchTarget.rooms));
        expect((_right(page).items.single as RoomSearchResult).room.roomId, _live, reason: query);
      }
      expect(adapter.http.sent, hasLength(4), reason: 'one page each');
    });

    test('a search finds nothing for prose, later pages and missing rooms', () async {
      var notFound = false;
      final adapter = _adapter(
        onSend: (request) {
          if (notFound) return _resp(404, 'gone');
          return _ordinary(request);
        },
      );
      final search = adapter.site.capability<LiveSearchProvider>()!;
      for (final query in ['主播昵称', '看直播 https://www.xiaohongshu.com/livestream/$_live', '']) {
        expect(
          _right(await search.search(LiveSearchRequest(query: query, target: LiveSearchTarget.rooms))).items,
          isEmpty,
          reason: query,
        );
      }
      expect(adapter.http.sent, isEmpty, reason: 'no request for anything that names no room');
      expect(
        _right(await search.search(const LiveSearchRequest(query: _live, target: LiveSearchTarget.rooms, page: 2)))
            .items,
        isEmpty,
      );
      expect(adapter.http.sent, isEmpty, reason: 'pages after the first give nothing');
      notFound = true;
      expect(
        _right(await search.search(const LiveSearchRequest(query: _live, target: LiveSearchTarget.rooms))).items,
        isEmpty,
        reason: 'a room that does not exist is no result',
      );
      expect(adapter.http.sent, hasLength(1));
    });

    test('a search failure other than not-found is thrown', () async {
      final adapter = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(
        _leftOf(
          await adapter.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: _live, target: LiveSearchTarget.rooms),
          ),
        ),
        isA<LiveSiteRateLimitError>(),
      );
    });

    test('a short link is followed to the room it lands on', () async {
      final adapter = _adapter();
      final page = await adapter.site.capability<LiveSearchProvider>()!.search(
        const LiveSearchRequest(query: 'https://xhslink.com/m/18ox3lAz', target: LiveSearchTarget.rooms),
      );
      expect((_right(page).items.single as RoomSearchResult).room.roomId, _live);
      expect(adapter.http.sent.map((seen) => seen.url.host), ['xhslink.com', 'www.xiaohongshu.com']);
    });

    test('a short link followed from its landing page, or nowhere, is handled', () async {
      // The landing page carries the state; no Location is left.
      final landed = _adapter(
        onSend: (request) => switch (request.url.host) {
          'xhslink.com' => _resp(200, _pageHtml(_state())),
          _ => _ordinary(request),
        },
      );
      final found = await landed.site.capability<LiveSearchProvider>()!.search(
        const LiveSearchRequest(query: 'https://xhslink.com/o/AbC123', target: LiveSearchTarget.rooms),
      );
      expect((_right(found).items.single as RoomSearchResult).room.roomId, _live);

      // A note page names no room: no result, no page request.
      final note = _adapter(
        onSend: (request) =>
            request.url.host == 'xhslink.com' ? _resp(200, '<html><body>a note</body></html>') : _ordinary(request),
      );
      expect(
        _right(
          await note.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: 'https://xhslink.com/m/gone', target: LiveSearchTarget.rooms),
          ),
        ).items,
        isEmpty,
      );
      expect(note.http.sent, hasLength(1), reason: 'the short link alone');

      // A short link that cannot be followed in time is no room.
      final slow = _adapter(
        onSend: (request) =>
            request.url.host == 'xhslink.com' ? throw const ConnectFailure('no answer') : _ordinary(request),
      );
      expect(
        _right(
          await slow.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: 'https://xhslink.com/m/slow', target: LiveSearchTarget.rooms),
          ),
        ).items,
        isEmpty,
      );
    });

    test('the qualities and lines come from the entry, without a request', () async {
      final adapter = _adapter();
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_live);
      final before = adapter.http.sent.length;
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _live));
      expect(qualities.single.qualityId, 'HD');
      expect(qualities.single.label, '原画');
      final lines = _right(await playback.getLines(roomId: _live));
      expect(lines, hasLength(4));
      expect(lines.first.lineLabel, 'flv:live-source-play');
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the addresses');
    });

    test('a searched room is a card: playback reads the page again', () async {
      final adapter = _adapter();
      await adapter.site.capability<LiveSearchProvider>()!.search(
        const LiveSearchRequest(query: _live, target: LiveSearchTarget.rooms),
      );
      final before = adapter.http.sent.length;
      final lines = _right(await adapter.site.capability<LivePlaybackProvider>()!.getLines(roomId: _live));
      expect(lines, hasLength(4));
      expect(adapter.http.sent.length, before + 1, reason: 'the card carried no stream data');
    });

    test('a room that cannot play says why at the boundary', () async {
      final adapter = _adapter();
      final ended = _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _ended));
      expect(ended, isA<LiveSiteContentUnavailable>());
      expect('$ended', contains('has ended'));
      final restricted = _adapter(
        onSend: (request) {
          final state = _state();
          _roomInfo(state)['monetizeType'] = 1;
          return _resp(200, _pageHtml(state));
        },
      );
      expect(
        _leftOf(await restricted.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _live)),
        isA<LiveSiteContentUnavailable>(),
      );
      final fenced = _adapter(
        onSend: (request) {
          final state = _state();
          _roomInfo(state)['joinLimitTypes'] = [4];
          return _resp(200, _pageHtml(state));
        },
      );
      expect(
        _leftOf(await fenced.site.capability<LivePlaybackProvider>()!.getLines(roomId: _live)),
        isA<LiveSiteContentUnavailable>(),
      );
      final unknownAccess = _adapter(
        onSend: (request) {
          final state = _state();
          _roomInfo(state).remove('monetizeType');
          return _resp(200, _pageHtml(state));
        },
      );
      expect(
        _leftOf(await unknownAccess.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _live)),
        isA<LiveSiteAuthenticationError>(),
      );
    });

    test('an entered ended room refuses playback without a request', () async {
      final adapter = _adapter();
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_ended);
      final before = adapter.http.sent.length;
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _ended)),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(adapter.http.sent.length, before, reason: 'the entry already said the room is over');
    });

    test('a status the gate refuses is mapped', () async {
      final refused = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(_leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom(_live)), isA<LiveSiteRateLimitError>());
      final down = _adapter(onSend: (_) => _resp(500, 'boom'));
      expect(_leftOf(await down.site.capability<LiveRoomProvider>()!.getRoom(_live)), isA<LiveSiteNetworkError>());
      final broken = _adapter(onSend: (_) => _resp(200, '<html>直播已结束</html>'));
      expect(_leftOf(await broken.site.capability<LiveRoomProvider>()!.getRoom(_live)), isA<LiveSiteParseError>());
    });

    test('a link is canonicalized without a request; a short link is followed', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://www.xiaohongshu.com/livestream/$_live'))),
        XiaohongshuEndpoints.roomUrl(_live),
      );
      expect(
        _right(await link.resolve(Uri.parse('https://www.xiaohongshu.com/hina/livestream/$_live/share'))).path,
        '/livestream/$_live',
      );
      expect(
        _right(await link.resolve(Uri.parse('xhsdiscover://live_audience?room_id=$_live&source=share'))),
        XiaohongshuEndpoints.roomUrl(_live),
      );
      expect(adapter.http.sent, isEmpty, reason: 'an address that names its room needs no request');
      expect(
        _right(await link.resolve(Uri.parse('https://xhslink.com/m/18ox3lAz'))),
        XiaohongshuEndpoints.roomUrl(_live),
      );
      expect(adapter.http.sent.single.url.host, 'xhslink.com');
    });

    test('a link of another site is unsupported, an own one without a room is not-found', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(_leftOf(await link.resolve(Uri.parse('https://live.bilibili.com/123'))), isA<LiveSiteUnsupported>());
      expect(
        _leftOf(await link.resolve(Uri.parse('https://www.xiaohongshu.com/explore/$_live'))),
        isA<LiveSiteNotFound>(),
      );
      expect(
        _leftOf(await link.resolve(Uri.parse('xhsdiscover://live_audience?source=share'))),
        isA<LiveSiteNotFound>(),
      );
      final note = _adapter(
        onSend: (request) =>
            request.url.host == 'xhslink.com' ? _resp(200, '<html><body>a note</body></html>') : _ordinary(request),
      );
      expect(
        _leftOf(await note.site.capability<LiveLinkResolver>()!.resolve(Uri.parse('https://xhslink.com/m/gone'))),
        isA<LiveSiteNotFound>(),
      );
    });
  });
}
