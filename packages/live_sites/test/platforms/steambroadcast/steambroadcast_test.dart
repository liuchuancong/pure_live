// Platform tests follow the platform files' constructor-name style, and the
// fixtures keep their adjacent template strings tight.
// ignore_for_file: unnecessary_type_name_in_constructor, missing_whitespace_between_adjacent_strings

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
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_endpoints.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_http.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku_codec.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku_session.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_json.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';
import 'package:test/test.dart';

const String _live = '76561199485215572';
const String _other = '76561198373527746';
const String _offline = '76561197960287930';

String _json(Object? data) => jsonEncode(data);

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

Matcher _fails(SteambroadcastFailureKind kind) =>
    predicate((e) => e is SteambroadcastFailure && e.kind == kind, 'a ${kind.name} failure');

Uri get _masterUrl => Uri.parse(
  'https://cache9-lax2.steamcontent.com/broadcast/$_live/7299796105176582514/'
  'hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8?broadcast_origin=ext2-ord1.steamserver.net',
);

Map<String, Object?> _mpdFixture({
  Object? success = 'ready',
  Object? broadcastId = '4005242549293303728',
  Object? viewers = 3797,
  Object? hlsUrl,
  Object? cdnAuth,
  Object? title = '',
  Object? isReplay,
}) => {
  'success': success,
  'broadcastid': broadcastId,
  'is_replay': ?isReplay,
  'hls_url': hlsUrl ?? '$_masterUrl',
  'title': title,
  'num_viewers': viewers,
  'cdn_auth_url_parameters': cdnAuth,
};

Map<String, Object?> _infoFixture({
  Object? success = 1,
  Object? isOnline = true,
  Object? isReplay,
  String title = '',
  String appTitle = 'NTE: Neverness to Everness',
  String thumbnail = 'https://steambroadcast.akamaized.net/broadcast/$_live/4005242549293303728/thumbnail/',
  Object? viewers = 6862,
}) => {
  'success': success,
  'is_online': ?isOnline,
  'is_replay': ?isReplay,
  if (title.isNotEmpty) 'title': title,
  'app_title': appTitle,
  'thumbnail_url': thumbnail,
  'viewer_count': viewers,
};

/// A master with [variants] rungs and one audio rendition they share.
String _masterFixture(
  String steamId, {
  required int variants,
  String host = 'cache9-lax2.steamcontent.com',
  String codecs = 'avc1.640028,mp4a.40.2',
  bool withOrigin = true,
}) {
  final origin = withOrigin ? '?broadcast_origin=ext2-ord1.steamserver.net' : '';
  final rungs = [
    for (var index = 0; index < variants; index++)
      switch (index % 4) {
        0 => (7160000 - index, '1920x1080', '60.000'),
        1 => (3660000 - index, '1280x720', '30.000'),
        2 => (1660000 - index, '854x480', '30.000'),
        _ => (660000 - index, '640x360', '30.000'),
      },
  ];
  final media =
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Default",'
      'URI="https://$host/broadcast/$steamId/7299796105176582514/hls_manifest/0/$host/187000/audio.m3u8$origin"';
  String rung(int bandwidth, String resolution, String rate) =>
      '#EXT-X-STREAM-INF:BANDWIDTH=$bandwidth,RESOLUTION=$resolution,FRAME-RATE=$rate,CODECS="$codecs",AUDIO="aac"\n'
      'https://$host/broadcast/$steamId/7299796105176582514/hls_manifest/0/$host/$bandwidth/video.m3u8$origin';
  final rungLines = [for (final (bandwidth, resolution, rate) in rungs) rung(bandwidth, resolution, rate)];
  return ['#EXTM3U', '#EXT-X-VERSION:7', media, ...rungLines].join('\n');
}

String _avatarUrl(String steamId) => 'https://avatars.fastly.steamstatic.com/${steamId.padLeft(40, '0')}.jpg';

String _card(
  String steamId, {
  String type = 'NTE: Neverness to Everness: Broadcast',
  String game = 'NTE: Neverness to Everness',
  String author = 'PWM Game Manager',
  String avatar = '',
  String cover = '',
  String viewers = '6,763 viewers',
}) =>
    '''
<div class="Broadcast_Card apphub_Card interactable">
<a href="https://steamcommunity.com/broadcast/watch/$steamId">
<div class="apphub_CardContentType">$type</div>
<img class="apphub_CardContentPreviewImage" src="$cover">
<div class="apphub_CardContentViewers ellipsis">$viewers&nbsp;</div>
<div class="apphub_CardContentTitle ellipsis">$game</div>
<div class="apphub_CardContentAuthorName"><a href="https://steamcommunity.com/id/probrawlhallastream/">$author</a></div>
<div class="appHubIconHolder"><img src="$avatar"></div>
</a>
</div>''';

String _directoryFixture({required int page}) {
  final cards = page == 1
      ? '${_card(_live, avatar: _avatarUrl(_live), cover: 'https://steambroadcast.akamaized.net/broadcast/$_live/1/thumbnail/')}'
            '${_card(_other, type: 'Brawlhalla: Broadcast', game: 'Brawlhalla', author: 'ProBrawlhalla', viewers: '3,758 viewers')}'
      : _card(_live);
  return '$cards<form><input name="broadcastsoffset" value="${page * 10}">'
      '<input name="p" value="${page + 1}"></form>';
}

/// The site's answers: the directory, the detail answers of the two
/// broadcasters, a master, and the profile XML of two custom addresses.
final class _Answers {
  _Answers({this.statuses = const {}, this.mpd, this.info, this.master});

  /// Answers a path that starts with the key with this status instead.
  final Map<String, int> statuses;
  final Map<String, Object?>? mpd;
  final Map<String, Object?>? info;
  final String? master;

  LiveResponse answer(_Seen seen) {
    final url = seen.url;
    for (final entry in statuses.entries) {
      if (url.path.startsWith(entry.key)) return _resp(entry.value, '');
    }
    final path = url.path;
    if (path == '/apps/allcontenthome') {
      return _resp(200, _directoryFixture(page: int.parse(url.queryParameters['p']!)));
    }
    if (path.startsWith('/miniprofile/')) {
      return _resp(200, _json({'persona_name': 'PWM Game Manager', 'avatar_url': _avatarUrl(_live)}));
    }
    if (path == '/broadcast/watch/$_live') {
      return _resp(
        200,
        '<html><head><title>Steam Community :: PWM Game Manager :: Broadcast</title>'
        '<meta property="og:title" content="Steam Community :: PWM Game Manager :: Broadcast"></head>'
        '<body><div id="application_config" data-broadcastsinfo="${_json({'steamid': _live}).replaceAll('"', '&quot;')}">'
        '</div></body></html>',
      );
    }
    if (path == '/broadcast/getbroadcastmpd/') {
      return _resp(200, _json(mpd ?? _mpdFixture()));
    }
    if (path == '/broadcast/getbroadcastinfo/') {
      return _resp(200, _json(info ?? _infoFixture()));
    }
    if (path.endsWith('/master.m3u8')) {
      return _resp(200, master ?? _masterFixture(_live, variants: 1));
    }
    if (path == '/id/gabelogannewell/') {
      return _resp(200, '<profile><steamID64>$_offline</steamID64></profile>');
    }
    if (path == '/id/nobody/') {
      return _resp(200, '<response><error>The specified profile could not be found.</error></response>');
    }
    return _resp(404, 'nope');
  }
}

final class _Seen {
  _Seen(LiveRequest request) : url = request.url, headers = request.headers, cancel = request.cancelToken;

  final Uri url;
  final Map<String, String> headers;
  final CancelToken cancel;
}

final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

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

/// A transport that always breaks with [reason].
final class _FailingHttp implements LiveHttp {
  _FailingHttp(this.reason);

  final TransportFailure reason;

  @override
  Future<LiveResponse> send(LiveRequest request) async => throw reason;

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw reason;

  @override
  void close() {}
}

/// A timer that never goes off: the watches are kept by [FakeTimers] instead.
final class _IdleTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}

final class FakeTimers {
  final List<({Duration delay, void Function() callback})> after = [];

  SteambroadcastTimers get timers => (after: _after);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  void fire({int index = -1}) => after[index < 0 ? after.length - 1 : index].callback();
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<List<LiveMessage>> _next(Stream<LiveMessage> events, int count) {
  final seen = <LiveMessage>[];
  final done = Completer<void>();
  late final StreamSubscription<LiveMessage> subscription;
  subscription = events.listen((message) {
    seen.add(message);
    if (seen.length == count && !done.isCompleted) {
      done.complete();
      unawaited(subscription.cancel());
    }
  });
  return done.future.then((_) => seen);
}

({SteambroadcastSite site, _FakeHttp http}) _adapter({_Answers? answers}) {
  final http = _FakeHttp((answers ?? _Answers()).answer);
  return (site: SteambroadcastSite(http: SteambroadcastHttp(http)), http: http);
}

/// The chat log of broadcast 7001: getchatinfo of the current id answers the
/// template (any stale id HTTP 500), window 0 is the history, each later
/// window answers its lines and names `time + step`.
final class _ChatLog {
  _ChatLog({Map<int, List<Map<String, Object?>>>? lines, this.failWindows = false, this.staleId}) : lines = lines ?? {};

  final Map<int, List<Map<String, Object?>>> lines;
  final bool failWindows;
  final String? staleId;

  LiveResponse answer(_Seen seen) {
    final url = seen.url;
    switch (url.path) {
      case '/broadcast/getbroadcastmpd/':
        return _resp(200, _json(_mpdFixture(broadcastId: '7001', viewers: 2519)));
      case '/broadcast/getchatinfo/':
        final id = url.queryParameters['broadcastid'];
        if (id == staleId) return _resp(500, _json({'success': 2}));
        return id == '7001'
            ? _resp(
                200,
                _json({
                  'success': 1,
                  'view_url_template':
                      'https://steambroadcastchat.akamaized.net/chat/c$id/messages/{0}'
                      '?chat_origin=chat1.discovery.steamserver.net:8071',
                }),
              )
            : _resp(500, _json({'success': 2}));
      case '/broadcast/watch/$_live':
        return _resp(404, 'nope');
      default:
        if (failWindows) return _resp(404, '<html>gone</html>');
        final time = int.parse(url.pathSegments.last);
        if (time == 0) {
          return _resp(
            200,
            _json({
              'messages': [
                {'steamid': '100', 'persona_name': 'old', 'msg': 'history'},
              ],
              'next_request': 5000,
              'initial_delay': 300,
            }),
          );
        }
        return _resp(200, _json({'messages': lines[time] ?? <Object?>[], 'next_request': time + 500}));
    }
  }
}

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, SteambroadcastFailureKind kind) {
        try {
          SteambroadcastJson.checkBody('', 'x', status);
          fail('no throw for $status');
        } on SteambroadcastFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(400, SteambroadcastFailureKind.apiChanged);
      expectKind(422, SteambroadcastFailureKind.apiChanged);
      expectKind(401, SteambroadcastFailureKind.riskControl);
      expectKind(403, SteambroadcastFailureKind.riskControl);
      expectKind(404, SteambroadcastFailureKind.notFound);
      expectKind(429, SteambroadcastFailureKind.rateLimited);
      for (final status in [204, 302, 500, 503]) {
        expectKind(status, SteambroadcastFailureKind.network);
      }
      SteambroadcastJson.checkBody('', 'x', 200);
      expect(const SteambroadcastFailure(SteambroadcastFailureKind.network, 'x').isTransient, isTrue);
      expect(const SteambroadcastFailure(SteambroadcastFailureKind.rateLimited, 'x').isTransient, isTrue);
      expect(const SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, 'x').isTransient, isFalse);
      expect(
        const SteambroadcastFailure(SteambroadcastFailureKind.riskControl, 'refused').toLiveSiteError('steambroadcast'),
        isA<LiveSiteRateLimitError>(),
      );
      expect(
        const SteambroadcastFailure(SteambroadcastFailureKind.streamUnavailable, 'x').toLiveSiteError('steambroadcast'),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(
        const SteambroadcastFailure(SteambroadcastFailureKind.invalidArgument, 'x').toLiveSiteError('steambroadcast'),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('an answer over 4 MiB is api-changed, counted in UTF-8 bytes', () {
      expect(
        () => SteambroadcastJson.checkBody('x' * (4 * 1024 * 1024 + 1), 'x', 200),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(
        () => SteambroadcastJson.checkBody('é' * (2 * 1024 * 1024 + 1), 'x', 200),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      SteambroadcastJson.checkBody('é' * (2 * 1024 * 1024), 'x', 200);
    });

    test('a body must be a JSON object', () {
      expect(() => SteambroadcastJson.object('<html>', 'x', 200), throwsA(predicate((e) => '$e'.contains('not JSON'))));
      expect(
        () => SteambroadcastJson.object('[]', 'x', 200),
        throwsA(predicate((e) => '$e'.contains('not an object'))),
      );
      expect(SteambroadcastJson.object('{"a":1}', 'x', 200), {'a': 1});
    });

    test('texts are read strictly, counts leniently', () {
      expect(SteambroadcastJson.clean(' a  b\tc '), 'a b c');
      expect(() => SteambroadcastJson.clean('x' * 65537), throwsA(_fails(SteambroadcastFailureKind.apiChanged)));
      expect(SteambroadcastJson.lenientText(' Speed &amp; run '), 'Speed & run');
      expect(SteambroadcastJson.lenientText(7), '');
      expect(SteambroadcastJson.optionalText(null, 'x'), '');
      expect(() => SteambroadcastJson.optionalText(7, 'x'), throwsA(isA<SteambroadcastFailure>()));
      expect(() => SteambroadcastJson.requiredText('', 'x'), throwsA(isA<SteambroadcastFailure>()));
      expect(SteambroadcastJson.flag(true), isTrue);
      expect(SteambroadcastJson.flag(0), isFalse);
      expect(SteambroadcastJson.flag(2), isTrue);
      expect(SteambroadcastJson.viewers(0), 0);
      expect(SteambroadcastJson.viewers(3.7), 3);
      expect(SteambroadcastJson.viewers(' 16 '), 16);
      expect(SteambroadcastJson.viewers(-1), isNull);
      expect(SteambroadcastJson.viewers('many'), isNull);
      expect(SteambroadcastJson.snippet('a' * 100).length, 81, reason: '80 characters and the ellipsis');
    });
  });

  group('links', () {
    test('a steam id is read from a bare id, a watch link or a profile link', () {
      expect(SteambroadcastEndpoints.steamIdOf(' $_live '), _live);
      expect(SteambroadcastEndpoints.steamIdOf('https://steamcommunity.com/broadcast/watch/$_live'), _live);
      expect(SteambroadcastEndpoints.steamIdOf('https://steamcommunity.com/broadcast/watch/$_live?l=english'), _live);
      expect(SteambroadcastEndpoints.steamIdOf('https://STEAMCOMMUNITY.com//profiles//$_live'), _live);
      for (final bad in [
        'https://steamcommunity.com/profiles/7656119948521557',
        'https://steamcommunity.com/profiles/$_live/broadcasts',
        'https://www.steamcommunity.com/profiles/$_live',
        'https://steamcommunity.com/profiles/$_live#x',
        'https://steamcommunity.com/id/gabelogannewell',
        'https://evil.com/broadcast/watch/$_live',
        'https://user@steamcommunity.com/profiles/$_live',
        'not a link',
      ]) {
        expect(SteambroadcastEndpoints.steamIdOf(bad), isNull, reason: bad);
      }
      expect(SteambroadcastEndpoints.isSteamId(_live), isTrue);
      expect(SteambroadcastEndpoints.isSteamId('7656119837352774'), isFalse);
    });

    test('a custom address /id/<name> is recognized for one request', () {
      expect(
        SteambroadcastEndpoints.vanityOf('https://steamcommunity.com/id/probrawlhallastream/'),
        'probrawlhallastream',
      );
      expect(SteambroadcastEndpoints.vanityOf('https://steamcommunity.com/id/A_b-9?l=english'), 'A_b-9');
      for (final bad in [
        'https://steamcommunity.com/id/',
        'https://steamcommunity.com/id/a.b',
        'https://steamcommunity.com/id/${'a' * 65}',
        'https://steamcommunity.com/id/name/broadcasts',
        'https://store.steampowered.com/id/name',
        'https://www.steamcommunity.com/id/name',
        'gabelogannewell',
      ]) {
        expect(SteambroadcastEndpoints.vanityOf(bad), isNull, reason: bad);
      }
      expect(SteambroadcastEndpoints.watchIdOf('https://steamcommunity.com/broadcast/watch/$_live'), _live);
      expect(SteambroadcastEndpoints.watchIdOf('https://steamcommunity.com/profiles/$_live'), isNull);
    });

    test('the addresses are the recorded ones; the mini profile reads the account offset', () {
      expect(SteambroadcastEndpoints.link(_live), 'https://steamcommunity.com/broadcast/watch/$_live');
      expect(
        SteambroadcastEndpoints.profileUrl(_live).toString(),
        'https://steamcommunity.com/miniprofile/1524949844/json',
      );
      expect(
        SteambroadcastEndpoints.profileUrl(_offline).toString(),
        'https://steamcommunity.com/miniprofile/22202/json',
      );
      expect(SteambroadcastEndpoints.infoUrl(_live).queryParameters, {
        'steamid': _live,
        'broadcastid': '0',
        'location': '5',
      });
      expect(SteambroadcastEndpoints.mpdUrl(_live).queryParameters, {
        'broadcastid': '0',
        'steamid': _live,
        'viewertoken': '0',
        'sessionid': '',
      });
      expect(SteambroadcastEndpoints.directoryUrl(3).queryParameters['broadcastsoffset'], '20');
      expect(SteambroadcastEndpoints.directoryUrl(3).queryParameters['numperpage'], '10');
      expect(SteambroadcastEndpoints.vanityUrl('gabelogannewell').path, '/id/gabelogannewell/');
      expect(SteambroadcastEndpoints.roomHeaders(_live, json: true)['x-requested-with'], 'XMLHttpRequest');
      expect(SteambroadcastEndpoints.roomHeaders(_live).containsKey('x-requested-with'), isFalse);
      expect(SteambroadcastEndpoints.mediaHeaders(_live)['referer'], SteambroadcastEndpoints.link(_live));
    });
  });

  group('directory', () {
    test('the cards are read: type as title, the game, the author, viewers, avatars', () {
      final page = SteambroadcastRoomParser.directory(_directoryFixture(page: 1), page: 1);
      expect(page.broadcasts, hasLength(2));
      expect(page.hasMore, isTrue);
      final first = page.broadcasts.first;
      expect(first.steamId, _live);
      expect(first.title, 'NTE: Neverness to Everness', reason: 'the type without ": Broadcast"');
      expect(first.game, 'NTE: Neverness to Everness');
      expect(first.broadcaster, 'PWM Game Manager');
      expect(first.viewers, 6763);
      expect(first.cover, 'https://steambroadcast.akamaized.net/broadcast/$_live/1/thumbnail/');
      expect(
        first.avatar,
        'https://avatars.fastly.steamstatic.com/${_avatarUrl(_live).split('/').last.split('.').first}_full.jpg',
        reason: 'the 184 px size of a Steam avatar',
      );
      expect(page.broadcasts.last.title, 'Brawlhalla');
      expect(page.broadcasts.last.viewers, 3758);
      expect(page.broadcasts.last.state, SteambroadcastState.live);
    });

    test('a page without a next one, or without cards, has no more', () {
      expect(SteambroadcastRoomParser.directory(_directoryFixture(page: 1), page: 2).hasMore, isFalse);
      expect(SteambroadcastRoomParser.directory('<div></div>', page: 1).hasMore, isFalse);
      expect(
        SteambroadcastRoomParser.directory(
          '<form><input name="broadcastsoffset" value="10"><input name="p" value="2"></form>',
          page: 1,
        ).hasMore,
        isFalse,
        reason: 'no cards',
      );
    });

    test('cards: duplicates, thumbnail and avatar rules, a broken card skipped', () {
      const hash = 'ba2a49b5180c4f3449245bab40ea2a064898a013';
      const defaultHash = 'fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb';
      final page = SteambroadcastRoomParser.directory(
        [
          _card(_live, cover: 'https://steambroadcast.akamaized.net/broadcast/$_other/1/thumbnail/'),
          _card(_live, cover: 'https://steambroadcast.akamaized.net/broadcast/$_live/1/thumbnail/'),
          _card(
            _other,
            type: 'Brawlhalla',
            game: 'Brawlhalla',
            author: ' $_other ',
            avatar: 'https://avatars.akamai.steamstatic.com/$defaultHash.jpg',
          ),
          _card('76561198373527748', type: 'x' * 70000, viewers: ''),
          _card('76561198373527748', author: '', avatar: 'https://avatars.akamai.steamstatic.com/$hash.jpg'),
          _card(
            '76561198373527749',
            cover: 'http://steambroadcast.akamaized.net/broadcast/76561198373527749/t',
            viewers: '',
          ),
        ].join(),
        page: 1,
      );
      expect(page.broadcasts.map((broadcast) => broadcast.steamId), [
        _live,
        _other,
        '76561198373527748',
        '76561198373527749',
      ], reason: 'the 70000-character card only loses itself; the next card of its broadcaster counts');
      final [first, second, third, fourth] = page.broadcasts;
      expect(first.cover, '', reason: "another broadcaster's thumbnail");
      expect(second.title, 'Brawlhalla', reason: 'no content type: the game');
      expect(second.broadcaster, '', reason: 'a name that is only the id is none');
      expect(second.avatar, '', reason: "Steam's default avatar is none");
      expect(
        third.avatar,
        'https://avatars.akamai.steamstatic.com/${hash}_full.jpg',
        reason: 'the 32 px card avatar at the 184 px size',
      );
      expect(third.broadcaster, '', reason: 'an empty author is no name');
      expect(fourth.cover, '', reason: 'http is no thumbnail');
      expect(fourth.viewers, isNull, reason: 'no viewers written');
    });

    test("viewer counts and the search filter match the reference's", () {
      expect(SteambroadcastRoomParser.viewerCount('6,763 viewers'), 6763);
      expect(SteambroadcastRoomParser.viewerCount('42 VIEWERS'), 42);
      expect(SteambroadcastRoomParser.viewerCount('1_000 viewers'), 1000);
      expect(SteambroadcastRoomParser.viewerCount('viewers'), isNull);
      expect(SteambroadcastRoomParser.viewerCount('1234567890123 viewers'), isNull, reason: '13 digits');
      final broadcasts = SteambroadcastRoomParser.directory(_directoryFixture(page: 1), page: 1).broadcasts;
      expect(SteambroadcastRoomParser.filter(broadcasts, 'nte').map((broadcast) => broadcast.steamId), [_live]);
      expect(SteambroadcastRoomParser.filter(broadcasts, 'brawlhalla').map((broadcast) => broadcast.steamId), [
        _other,
      ], reason: 'the game matches');
      expect(SteambroadcastRoomParser.filter(broadcasts, '7656119948521').map((b) => b.steamId), [
        _live,
      ], reason: 'an id part');
      expect(SteambroadcastRoomParser.filter(broadcasts, 'pwm game').map((b) => b.steamId), [_live]);
      expect(SteambroadcastRoomParser.filter(broadcasts, 'zzqxnomatch'), isEmpty);
    });
  });

  group('room answers', () {
    const withMeta =
        '<html><head><title>Steam Community :: PWM Game Manager :: Broadcast</title>'
        '<meta property="og:title" content="Steam Community :: PWM Game Manager :: Broadcast">'
        '</head><body><div id="application_config" data-broadcastsinfo="{&quot;steamid&quot;:&quot;$_live&quot;}">'
        '</div></body></html>';

    test('the watch page names the broadcaster; its checks are strict', () {
      String name(String body, {String steamId = _live, int status = 200}) =>
          SteambroadcastRoomParser.broadcaster(body, steamId: steamId, status: status);
      expect(name(withMeta), 'PWM Game Manager');
      expect(
        name(withMeta.replaceFirst(RegExp('<meta[^>]*>'), '')),
        'PWM Game Manager',
        reason: 'the <title> fallback',
      );
      expect(name(withMeta.replaceAll('PWM Game Manager', _live)), '', reason: 'a name that is only the id is none');
      expect(
        () => name(withMeta.replaceFirst('data-broadcastsinfo=', 'data-other=')),
        throwsA(_fails(SteambroadcastFailureKind.notFound)),
      );
      expect(
        () => name(withMeta.replaceFirst('steamid&quot;:&quot;$_live', 'steamid&quot;:&quot;$_offline')),
        throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
        reason: 'another account',
      );
      expect(() => name(withMeta.replaceFirst('{', '{x')), throwsA(_fails(SteambroadcastFailureKind.apiChanged)));
      expect(() => name(withMeta, status: 403), throwsA(_fails(SteambroadcastFailureKind.riskControl)));
    });

    test('the mini profile names the broadcaster and takes the 184 px avatar', () {
      final profile = SteambroadcastRoomParser.profile(
        _json({
          'persona_name': ' PWM &amp; Co ',
          'avatar_url': 'https://avatars.fastly.steamstatic.com/ba2a49b5180c4f3449245bab40ea2a064898a013.jpg',
        }),
        steamId: _live,
      );
      expect(profile.name, 'PWM & Co');
      expect(
        profile.avatar,
        'https://avatars.fastly.steamstatic.com/ba2a49b5180c4f3449245bab40ea2a064898a013_full.jpg',
      );
      expect(
        SteambroadcastRoomParser.profile(_json({'persona_name': _live}), steamId: _live).name,
        '',
        reason: 'an account that does not exist names its id',
      );
      expect(
        SteambroadcastRoomParser.profile(_json({'persona_name': 'A', 'avatar_url': 7}), steamId: _live).avatar,
        '',
      );
      for (final answer in ['{}', '{"persona_name":null}', '[]', '<html>']) {
        expect(
          () => SteambroadcastRoomParser.profile(answer, steamId: _live),
          throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
          reason: answer,
        );
      }
    });

    test('getbroadcastinfo: live, replay, offline, and its strict success', () {
      final live = SteambroadcastRoomParser.info(
        _json(_infoFixture(title: ' Speed &amp; run ')),
        steamId: _live,
        profile: (name: 'N', avatar: 'https://a.test/a.jpg'),
      );
      expect(live.state, SteambroadcastState.live);
      expect(live.title, 'Speed & run', reason: 'the title before the game');
      expect(live.game, 'NTE: Neverness to Everness');
      expect(live.cover, startsWith('https://steambroadcast.akamaized.net/broadcast/$_live/'));
      expect(live.viewers, 6862);
      expect(live.restriction, isNull, reason: 'the answer does not say who may watch');
      expect(
        SteambroadcastRoomParser.info(_json(_infoFixture(isReplay: 1)), steamId: _live).state,
        SteambroadcastState.replay,
      );
      final offline = SteambroadcastRoomParser.info(_json(_infoFixture(success: 42)), steamId: _live);
      expect(offline.state, SteambroadcastState.offline);
      expect((offline.title, offline.game, offline.cover, offline.viewers), ('', '', '', null));
      for (final success in [2, 'x']) {
        expect(
          () => SteambroadcastRoomParser.info(_json(_infoFixture(success: success)), steamId: _live),
          throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
          reason: '$success',
        );
      }
      final notOnline = SteambroadcastRoomParser.info(_json(_infoFixture(isOnline: false)), steamId: _live);
      expect(notOnline.state, SteambroadcastState.offline);
      expect(notOnline.viewers, isNull);
      expect(
        SteambroadcastRoomParser.info(_json(_infoFixture(isOnline: null)), steamId: _live).state,
        SteambroadcastState.offline,
      );
      final malformed = SteambroadcastRoomParser.info(
        _json({
          ..._infoFixture(),
          'app_title': 7,
          'title': ['x'],
          'thumbnail_url': 5,
          'viewer_count': 'many',
        }),
        steamId: _live,
      );
      expect(
        (malformed.title, malformed.game, malformed.cover, malformed.viewers),
        ('', '', '', null),
        reason: 'fields that only fill the card are left empty when malformed',
      );
    });

    test('getbroadcastmpd: every success, the master and its CDN parameters', () {
      final live = SteambroadcastRoomParser.broadcast(
        _json(_mpdFixture()),
        steamId: _live,
        profile: (name: 'X', avatar: ''),
      );
      expect(live.state, SteambroadcastState.live);
      expect(live.restriction, LiveRestriction.none);
      expect(live.broadcastId, '4005242549293303728');
      expect(live.viewers, 3797);
      expect(live.master, _masterUrl);
      expect(live.mediaError, isNull);
      expect(live.masterChecked, isFalse, reason: 'checked on room entry only');
      expect(
        SteambroadcastRoomParser.broadcast(_json(_mpdFixture(success: 'READY')), steamId: _live).state,
        SteambroadcastState.live,
        reason: 'the success is read case-insensitively',
      );
      final subscribers = SteambroadcastRoomParser.broadcast(
        _json(_mpdFixture(success: 'missing_subscription')),
        steamId: _live,
      );
      expect(subscribers.state, SteambroadcastState.live);
      expect(subscribers.restriction, LiveRestriction.subscribersOnly);
      expect(subscribers.master, isNull, reason: 'no stream for this client');
      for (final flag in <Object>[1, true]) {
        final replay = SteambroadcastRoomParser.broadcast(_json(_mpdFixture(isReplay: flag)), steamId: _live);
        expect(replay.state, SteambroadcastState.replay, reason: '$flag');
        expect(replay.master, isNotNull);
      }
      expect(
        SteambroadcastRoomParser.broadcast(_json(_mpdFixture(success: 'user_restricted')), steamId: _live).state,
        SteambroadcastState.accountRestricted,
      );
      for (final success in ['unavailable', 'offline', 'not_live', 'no_broadcast']) {
        expect(
          SteambroadcastRoomParser.broadcast(_json(_mpdFixture(success: success)), steamId: _live).state,
          SteambroadcastState.offline,
          reason: success,
        );
      }
      expect(
        SteambroadcastRoomParser.broadcast(_json(_mpdFixture(success: 'waiting_to_start')), steamId: _live).state,
        SteambroadcastState.unknown,
      );
      expect(SteambroadcastRoomParser.broadcast(_json(_mpdFixture(broadcastId: 12)), steamId: _live).broadcastId, '12');
      expect(
        SteambroadcastRoomParser.broadcast(_json(_mpdFixture(broadcastId: 'x')), steamId: _live).broadcastId,
        isNull,
      );
      for (final answer in ['["ready"]', '<html>', '{}']) {
        expect(
          () => SteambroadcastRoomParser.broadcast(answer, steamId: _live),
          throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
          reason: answer,
        );
      }
    });

    test('an unusable hls_url or CDN parameters keep the state and carry a media error', () {
      SteambroadcastBroadcast withMpd(Map<String, Object?> changes) =>
          SteambroadcastRoomParser.broadcast(_json(_mpdFixture()..addAll(changes)), steamId: _live);
      const base =
          'https://cache9-lax2.steamcontent.com/broadcast/$_live/1/'
          'hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8?broadcast_origin=ext2-ord1.steamserver.net';
      for (final hlsUrl in [
        null,
        'http://cache9-lax2.steamcontent.com/broadcast/$_live/1/hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8?broadcast_origin=ext2-ord1.steamserver.net',
        'https://evil.com/broadcast/$_live/1/hls_manifest/0/evil.com/master.m3u8?broadcast_origin=ext2-ord1.steamserver.net',
        'https://cache9-lax2.steamcontent.com/other/path/master.m3u8?broadcast_origin=ext2-ord1.steamserver.net',
        'https://cache9-lax2.steamcontent.com/broadcast/$_live/1/hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8',
        'https://cache9-lax2.steamcontent.com/broadcast/$_live/1/hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8?broadcast_origin=x.test',
        'https://cache9-lax2.steamcontent.com/broadcast/$_offline/1/hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8?broadcast_origin=ext2-ord1.steamserver.net',
        'https://cache9-lax2.steamcontent.com/broadcast/$_live/0/hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8?broadcast_origin=ext2-ord1.steamserver.net',
      ]) {
        final broadcast = withMpd({'hls_url': hlsUrl});
        expect(broadcast.state, SteambroadcastState.live, reason: '$hlsUrl');
        expect(broadcast.master, isNull, reason: '$hlsUrl');
        expect(broadcast.mediaError, isA<SteambroadcastFailure>(), reason: '$hlsUrl');
        expect(broadcast.viewers, 3797, reason: '$hlsUrl');
      }
      expect(withMpd({'hls_url': ' $base '}).master, Uri.parse(base.trim()), reason: 'the text is cleaned first');
      expect(withMpd({'cdn_auth_url_parameters': null}).master, _masterUrl);
      expect(withMpd({'cdn_auth_url_parameters': ''}).master, _masterUrl);
      expect(withMpd({'cdn_auth_url_parameters': '  '}).master, _masterUrl);
      expect(withMpd({'cdn_auth_url_parameters': '&token=abc'}).master.toString(), endsWith('&token=abc'));
      expect(withMpd({'cdn_auth_url_parameters': '?token=abc&exp=1'}).master.toString(), endsWith('&token=abc&exp=1'));
      expect(withMpd({'cdn_auth_url_parameters': '&&a=1'}).master.toString(), endsWith('&a=1'));
      expect(withMpd({'cdn_auth_url_parameters': 'a=1&a=2'}).master.toString(), endsWith('&a=1&a=2'));
      for (final cdnAuth in ['broadcast_origin=x', 'a b=1', 'a=1#x', '&', 'a', 7]) {
        final broadcast = withMpd({'cdn_auth_url_parameters': cdnAuth});
        expect(broadcast.mediaError, isA<SteambroadcastFailure>(), reason: '$cdnAuth');
        expect(broadcast.master, isNull, reason: '$cdnAuth');
      }
    });

    test('the profile XML of a custom address', () {
      expect(
        SteambroadcastRoomParser.steamIdOfProfileXml('<profile><steamID64>$_offline</steamID64></profile>'),
        _offline,
      );
      expect(
        SteambroadcastRoomParser.steamIdOfProfileXml(
          '<response><error>The specified profile could not be found.</error></response>',
        ),
        isNull,
      );
      expect(
        () => SteambroadcastRoomParser.steamIdOfProfileXml('<html></html>'),
        throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
      );
      expect(
        () => SteambroadcastRoomParser.steamIdOfProfileXml('<profile><steamID64>123</steamID64></profile>'),
        throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
      );
      expect(
        () => SteambroadcastRoomParser.steamIdOfProfileXml('', status: 403),
        throwsA(_fails(SteambroadcastFailureKind.riskControl)),
      );
    });
  });

  group('HLS master', () {
    test('the check passes a master and names its codec; every alteration fails', () {
      expect(
        SteambroadcastRoomParser.checkMaster(_masterFixture(_live, variants: 1), master: _masterUrl, steamId: _live),
        LiveStreamCodec.avc,
      );
      expect(
        SteambroadcastRoomParser.checkMaster(
          _masterFixture(_live, variants: 1, codecs: 'hvc1.1.6.L93.B0'),
          master: _masterUrl,
          steamId: _live,
        ),
        LiveStreamCodec.hevc,
      );
      expect(
        SteambroadcastRoomParser.checkMaster(
          _masterFixture(_live, variants: 1, codecs: ''),
          master: _masterUrl,
          steamId: _live,
        ),
        isNull,
        reason: 'no codec named',
      );
      void check(String text, {String steamId = _live, Uri? master}) =>
          SteambroadcastRoomParser.checkMaster(text, master: master ?? _masterUrl, steamId: steamId);
      final lines = const LineSplitter().convert(_masterFixture(_live, variants: 1));
      final variant = lines.last;
      final master = _masterFixture(_live, variants: 1);
      expect(
        () => check(master, steamId: _offline),
        throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
        reason: 'another account',
      );
      expect(
        () => check(master, master: _masterUrl.replace(host: 'cache1-lax1.steamcontent.com')),
        throwsA(isA<SteambroadcastFailure>()),
        reason: 'another master host',
      );
      expect(
        () => check(variant.replaceFirst('cache9-lax2', 'example.com')),
        throwsA(isA<SteambroadcastFailure>()),
        reason: 'a variant on another host',
      );
      expect(
        () => check(master.replaceFirst('URI="https://cache9-lax2', 'URI="https://example.com')),
        throwsA(isA<SteambroadcastFailure>()),
        reason: 'a rendition on another host',
      );
      expect(
        () => check(_masterFixture(_live, variants: 1, withOrigin: false)),
        throwsA(isA<SteambroadcastFailure>()),
        reason: 'a variant without a broadcast_origin',
      );
      expect(
        () => check(master.replaceFirst('#EXT-X-STREAM-INF', '#EXT-X-CUE-OUT')),
        throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
        reason: 'no variant',
      );
      expect(() => check('<html></html>'), throwsA(_fails(SteambroadcastFailureKind.apiChanged)));
      expect(
        () => check(_masterFixture(_live, variants: 17)),
        throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
        reason: '17 variants',
      );
      expect(
        () => check('#EXTM3U\n${'#' * (1024 * 1024)}'),
        throwsA(predicate((e) => '$e'.contains('not an HLS master'))),
      );
    });

    test('the variants are named as Steam names them, best first, one per id', () {
      final variants = SteambroadcastRoomParser.variants(_masterFixture(_live, variants: 4), master: _masterUrl);
      expect(variants.map((variant) => variant.id), ['1080p60', '720p', '480p', '360p']);
      expect(
        variants.first,
        isA<SteambroadcastVariant>()
            .having((variant) => variant.width, 'width', 1920)
            .having((variant) => variant.height, 'height', 1080)
            .having((variant) => variant.frameRate, 'frameRate', 60)
            .having((variant) => variant.bandwidth, 'bandwidth', 7160000)
            .having((variant) => variant.codec, 'codec', LiveStreamCodec.avc),
      );
      expect(SteambroadcastRoomParser.variantId(1080, 60), '1080p60');
      expect(SteambroadcastRoomParser.variantId(720, 59.94), '720p60');
      expect(SteambroadcastRoomParser.variantId(720, 30), '720p');
      expect(SteambroadcastRoomParser.variantId(480, 0), '480p');
      for (final id in ['720p', '1080p60', 'auto', 'source', '720', 'p60', '0p']) {
        expect(SteambroadcastRoomParser.isVariantId(id), ['720p', '1080p60'].contains(id), reason: id);
      }
      final text = _masterFixture(_live, variants: 4);
      final lines = const LineSplitter().convert(text);
      final rung360 = lines[lines.length - 2];
      final duplicated = text.replaceFirst(rung360, rung360.replaceFirst('RESOLUTION=640x360', 'RESOLUTION=854x480'));
      expect(SteambroadcastRoomParser.variants(duplicated, master: _masterUrl).map((variant) => variant.id), [
        '1080p60',
        '720p',
        '480p',
      ], reason: 'the duplicated id keeps its highest bandwidth');
      expect(
        SteambroadcastRoomParser.variants(
          text.replaceFirst(',RESOLUTION=1920x1080', ''),
          master: _masterUrl,
        ).map((variant) => variant.id),
        ['720p', '480p', '360p'],
        reason: 'an unsized variant is left out',
      );
      expect(
        SteambroadcastRoomParser.variants(_masterFixture(_live, variants: 1), master: _masterUrl),
        isEmpty,
        reason: 'one variant is the adaptive quality itself',
      );
      expect(
        SteambroadcastRoomParser.variants(
          _masterFixture(_live, variants: 4).replaceFirst('GROUP-ID="aac"', 'GROUP-ID="x"'),
          master: _masterUrl,
        ),
        isEmpty,
        reason: 'a variant whose audio group the master does not carry is left out',
      );
    });
  });

  group('rooms', () {
    test('a live room: identity, content, audience, state and notice', () {
      final broadcast = SteambroadcastRoomParser.broadcast(
        _json(_mpdFixture()),
        steamId: _live,
        profile: (name: 'X', avatar: ''),
      ).withInfo(SteambroadcastRoomParser.info(_json(_infoFixture()), steamId: _live));
      final room = SteambroadcastRoomParser.room(broadcast);
      expect(room.platform, 'steambroadcast');
      expect(room.roomId, _live);
      expect(room.anchor?.anchorId, _live);
      expect(room.anchor?.name, 'X', reason: 'the mpd profile');
      expect(room.content.title, 'NTE: Neverness to Everness', reason: 'withInfo takes the info title');
      expect(room.content.coverUrl, startsWith('https://steambroadcast.akamaized.net/broadcast/$_live/'));
      expect(room.content.platformTags, ['NTE: Neverness to Everness'], reason: 'the game as the platform tag');
      expect(room.content.notice, SteambroadcastEndpoints.chatNotice);
      expect(room.audience.onlineViewers, 3797, reason: "getbroadcastmpd's viewers are the fresh ones");
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, SteambroadcastEndpoints.link(_live));
      final data = SteambroadcastRoomParser.roomData(broadcast);
      expect(data.state, SteambroadcastState.live);
      expect(data.qualities.map((quality) => quality.qualityId), ['auto'], reason: 'no checked master, no variants');
    });

    test('every state reads as the interface shows it', () {
      SteambroadcastBroadcast withSuccess(String success, {Object? isReplay}) => SteambroadcastRoomParser.broadcast(
        _json(_mpdFixture(success: success, isReplay: isReplay, hlsUrl: success == 'ready' ? null : '')),
        steamId: _live,
      );
      expect(SteambroadcastRoomParser.room(withSuccess('ready')).broadcast.liveStatus, LiveStatus.live);
      expect(SteambroadcastRoomParser.room(withSuccess('ready', isReplay: 1)).broadcast.liveStatus, LiveStatus.replay);
      expect(SteambroadcastRoomParser.room(withSuccess('offline')).broadcast.liveStatus, LiveStatus.offline);
      final restricted = SteambroadcastRoomParser.room(withSuccess('user_restricted'));
      expect(restricted.broadcast.liveStatus, LiveStatus.banned);
      expect(restricted.content.notice, SteambroadcastEndpoints.restrictedNotice);
      final subscribers = SteambroadcastRoomParser.room(withSuccess('missing_subscription'));
      expect(subscribers.broadcast.liveStatus, LiveStatus.live);
      expect(subscribers.broadcast.restriction, LiveRestriction.subscribersOnly);
      expect(subscribers.broadcast.isRestricted, isTrue);
      expect(
        SteambroadcastRoomParser.roomData(withSuccess('missing_subscription')).streamError,
        isA<SteambroadcastFailure>(),
      );
      expect(SteambroadcastRoomParser.room(withSuccess('waiting')).broadcast.liveStatus, LiveStatus.unknown);
      expect(SteambroadcastRoomParser.room(withSuccess('waiting')).content.notice, SteambroadcastEndpoints.chatNotice);
    });

    test('room data: why a room cannot be played', () {
      SteambroadcastFailure? error(
        SteambroadcastState state, {
        Uri? at,
        SteambroadcastFailure? media,
        LiveRestriction? restriction,
      }) => SteambroadcastRoomData(
        steamId: _live,
        state: state,
        master: at,
        mediaError: media,
        restriction: restriction,
      ).streamError;
      expect(error(SteambroadcastState.live, at: _masterUrl), isNull);
      expect(error(SteambroadcastState.replay, at: _masterUrl), isNull);
      expect(error(SteambroadcastState.live), isA<SteambroadcastFailure>(), reason: 'refresh: no checked master');
      expect(
        error(
          SteambroadcastState.live,
          at: _masterUrl,
          media: const SteambroadcastFailure(SteambroadcastFailureKind.notFound, 'gone'),
        ),
        isA<SteambroadcastFailure>(),
      );
      expect(
        error(SteambroadcastState.live, at: _masterUrl, restriction: LiveRestriction.subscribersOnly),
        isA<SteambroadcastFailure>(),
      );
      for (final state in [
        SteambroadcastState.offline,
        SteambroadcastState.accountRestricted,
        SteambroadcastState.unknown,
      ]) {
        expect(error(state, at: _masterUrl), isA<SteambroadcastFailure>(), reason: state.name);
      }
    });

    test('enrich fills what a room lacks from the card, but not the viewers after it ended', () {
      final card = SteambroadcastRoomParser.directory(_directoryFixture(page: 1), page: 1).broadcasts.first;
      final plain = SteambroadcastRoomParser.broadcast(_json(_mpdFixture(viewers: 7994)), steamId: _live);
      final entered = plain.enrich(card);
      expect(entered.viewers, 7994, reason: "the room's own viewers win");
      final ended = SteambroadcastBroadcast(
        steamId: _live,
        state: SteambroadcastState.offline,
        title: 'Own title',
      ).enrich(card);
      expect(ended.broadcaster, 'PWM Game Manager', reason: 'no name: the card');
      expect(ended.title, 'Own title');
      expect(ended.viewers, isNull, reason: 'the last card viewers are not kept after the broadcast ended');
      expect(
        SteambroadcastBroadcast(steamId: _live, state: SteambroadcastState.live).enrich(card).viewers,
        6763,
        reason: 'still live without a count of its own: the card',
      );
      final merged = plain.withInfo(SteambroadcastRoomParser.info(_json(_infoFixture()), steamId: _live));
      expect(merged.title, 'NTE: Neverness to Everness');
      expect(merged.game, 'NTE: Neverness to Everness');
      expect(merged.viewers, 7994, reason: "getbroadcastmpd's are fresher");
      final withoutViewers = SteambroadcastRoomParser.broadcast(
        _json(_mpdFixture(viewers: null)),
        steamId: _live,
      ).withInfo(SteambroadcastRoomParser.info(_json(_infoFixture()), steamId: _live));
      expect(withoutViewers.viewers, 6862);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final adapter = _adapter();
      final site = adapter.site;
      expect(site.manifest.id, 'steambroadcast');
      expect(site.manifest.localizedName('zh-CN', 'en-US'), 'Steam 直播');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveSiteCapability>(), isNull, reason: 'an unknown capability is null');
      await site.dispose();
    });

    test('a directory page carries its cards and the page echo decides hasMore', () async {
      final adapter = _adapter();
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final page = _right(await rooms.getRooms(const LivePageRequest()));
      expect(page.items.map((room) => room.roomId), [_live, _other]);
      expect(page.hasMore, isTrue);
      expect(page.items.first.broadcast.liveStatus, LiveStatus.live);
      expect(page.items.first.audience.onlineViewers, 6763);
      final request = adapter.http.sent.single;
      expect(request.url.path, '/apps/allcontenthome');
      expect(request.url.queryParameters['p'], '1');
      expect(request.headers['referer'], 'https://steamcommunity.com/?subsection=broadcasts');
      expect(
        _right(await rooms.getRooms(const LivePageRequest(page: 0))).items,
        isEmpty,
        reason: 'a page below 1 is empty without a request',
      );
      expect(adapter.http.sent, hasLength(1));
      expect(_leftOf(await rooms.getRooms(const LivePageRequest(page: 10001))), isA<LiveSiteInvalidArgument>());
    });

    test('the area is the trending broadcasts; the recommendations slice a page', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      expect(_right(await area.getAreas()).single.areaId, 'trending');
      expect(_right(await area.getAreas()).single.parentAreaName, 'Steam Broadcasts');
      expect(_right(await area.getAreaRooms(areaId: 'trending')).items, hasLength(2));
      expect(_leftOf(await area.getAreaRooms(areaId: 'dance')), isA<LiveSiteInvalidArgument>());
      expect(
        _leftOf(await area.getAreaRooms(areaId: 'trending', request: const LivePageRequest(page: 10001))),
        isA<LiveSiteInvalidArgument>(),
      );
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      expect(_right(await discovery.getRecommendedRooms()).items, hasLength(2));
      final sliced = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 1)));
      expect(sliced.items, hasLength(1));
      expect(sliced.hasMore, isTrue, reason: 'the page itself has a next one');
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 0))).items, isEmpty);
    });

    test('room entry asks four requests and carries the handles; an offline room asks two', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_live));
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/miniprofile/1524949844/json',
        '/broadcast/getbroadcastmpd/',
        '/broadcast/getbroadcastinfo/',
        '/broadcast/$_live/7299796105176582514/hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8',
      ]);
      expect(room.content.title, 'NTE: Neverness to Everness');
      expect(room.audience.onlineViewers, 3797, reason: "getbroadcastmpd's are the fresh ones");
      expect(room.runtime.danmakuHandle, const SteambroadcastDanmakuArgs(_live, broadcastId: '4005242549293303728'));
      final data = room.runtime.streamHandle! as SteambroadcastRoomData;
      expect(data.master, _masterUrl);
      expect(data.state, SteambroadcastState.live);
      expect(data.streamError, isNull);
      expect(adapter.http.sent.last.headers['referer'], SteambroadcastEndpoints.link(_live));

      final offline = _adapter(
        answers: _Answers(
          mpd: _mpdFixture(success: 'offline', broadcastId: 0, viewers: null, hlsUrl: ''),
          info: _infoFixture(success: 42),
        ),
      );
      final room2 = _right(await offline.site.capability<LiveRoomProvider>()!.getRoom(_offline));
      expect(offline.http.sent.map((seen) => seen.url.path), [
        '/miniprofile/22202/json',
        '/broadcast/getbroadcastmpd/',
      ], reason: 'an offline broadcast reads no info and no master');
      expect(room2.broadcast.liveStatus, LiveStatus.offline);
      expect(room2.audience.onlineViewers, isNull);
      expect(room2.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(
        room2.runtime.danmakuHandle,
        const SteambroadcastDanmakuArgs(_offline),
        reason: 'the chat discovers the offline broadcast when it asks',
      );
    });

    test('a restricted account is banned, subscribers only is live', () async {
      final adapter = _adapter(
        answers: _Answers(
          mpd: _mpdFixture(success: 'user_restricted', hlsUrl: ''),
        ),
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_live));
      expect(room.broadcast.liveStatus, LiveStatus.banned);
      expect(room.content.notice, SteambroadcastEndpoints.restrictedNotice);
      final subscribers = _adapter(
        answers: _Answers(
          mpd: _mpdFixture(success: 'missing_subscription', hlsUrl: ''),
        ),
      );
      final room2 = _right(await subscribers.site.capability<LiveRoomProvider>()!.getRoom(_live));
      expect(room2.broadcast.liveStatus, LiveStatus.live);
      expect(room2.broadcast.restriction, LiveRestriction.subscribersOnly);
    });

    test('the qualities and lines come from the entry, without another request', () async {
      final adapter = _adapter(answers: _Answers(master: _masterFixture(_live, variants: 4)));
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_live);
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _live));
      expect(qualities.map((quality) => quality.qualityId), ['auto', '1080p60', '720p', '480p', '360p']);
      expect(qualities.first.label, '自适应 HLS');
      final lines = _right(await playback.getLines(roomId: _live));
      expect(lines, hasLength(1));
      expect(lines.single.url, '$_masterUrl');
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.codec, LiveStreamCodec.avc);
      expect(lines.single.headers, isEmpty, reason: 'the CDN answers without them');
      expect(lines.single.lease, isNull, reason: 'no expiry in the address');
      final variant = _right(await playback.getLines(roomId: _live, quality: qualities[1]));
      expect(variant.single.lineLabel, '1080p60');
      expect(variant.single.url, '$_masterUrl', reason: 'the master restricted to a variant is not a line here');
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the checked master');
    });

    test('a fresh entry serves the playback of a room never entered', () async {
      final adapter = _adapter(answers: _Answers(master: _masterFixture(_live, variants: 4)));
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(_right(await playback.getQualities(roomId: _live)), hasLength(5));
      expect(adapter.http.sent.last.url.path, endsWith('/master.m3u8'));
      final offline = _adapter(
        answers: _Answers(
          mpd: _mpdFixture(success: 'offline', hlsUrl: ''),
        ),
      );
      expect(
        _leftOf(await offline.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _live)),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(_leftOf(await playback.getLines(roomId: 'not-a-steam-id')), isA<LiveSiteNotFound>());
    });

    test('a broken master becomes a media problem, not a failed room', () async {
      final adapter = _adapter(answers: _Answers(master: '<html>denied</html>'));
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_live));
      expect(room.broadcast.liveStatus, LiveStatus.live, reason: 'the room stands');
      final data = room.runtime.streamHandle! as SteambroadcastRoomData;
      expect(data.mediaError, isA<SteambroadcastFailure>());
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _live)),
        isA<LiveSiteParseError>(),
        reason: 'the master did not pass its check',
      );
    });

    test('search: id, watch link, profile link, vanity, keyword', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final byId = _right(await search.search(const LiveSearchRequest(query: _live, target: LiveSearchTarget.rooms)));
      expect((byId.items.single as RoomSearchResult).room.roomId, _live);
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/miniprofile/1524949844/json',
        '/broadcast/getbroadcastinfo/',
      ], reason: 'the refresh answers: no master');
      final byLink = _right(
        await search.search(
          const LiveSearchRequest(query: 'https://steamcommunity.com/profiles/$_live', target: LiveSearchTarget.rooms),
        ),
      );
      expect((byLink.items.single as RoomSearchResult).room.roomId, _live);
      final byWatch = _right(
        await search.search(
          const LiveSearchRequest(
            query: 'https://steamcommunity.com/broadcast/watch/$_live',
            target: LiveSearchTarget.rooms,
          ),
        ),
      );
      expect((byWatch.items.single as RoomSearchResult).room.roomId, _live);
      final byVanity = _right(
        await search.search(
          const LiveSearchRequest(
            query: 'https://steamcommunity.com/id/gabelogannewell/',
            target: LiveSearchTarget.rooms,
          ),
        ),
      );
      expect((byVanity.items.single as RoomSearchResult).room.roomId, _offline);
      expect(adapter.http.sent.last.url.path, '/broadcast/getbroadcastinfo/');
      expect(
        _right(
          await search.search(
            const LiveSearchRequest(query: 'https://steamcommunity.com/id/nobody/', target: LiveSearchTarget.rooms),
          ),
        ).items,
        isEmpty,
        reason: 'no such profile',
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: _live, target: LiveSearchTarget.rooms, page: 2)))
            .items,
        isEmpty,
      );
      final byKeyword = _right(
        await search.search(const LiveSearchRequest(query: 'Brawlhalla', target: LiveSearchTarget.rooms)),
      );
      expect((byKeyword.items.single as RoomSearchResult).room.roomId, _other);
      expect(byKeyword.hasMore, isNull, reason: 'a filtered page says nothing about pages');
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, pageSize: 101)))
            .items,
        isEmpty,
        reason: 'a page size over 100 gives nothing without a request',
      );
    });

    test('links resolve without a request, a custom address with one', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://steamcommunity.com/broadcast/watch/$_live'))),
        Uri.parse(SteambroadcastEndpoints.link(_live)),
      );
      expect(
        _right(await link.resolve(Uri.parse('https://steamcommunity.com/profiles/$_live'))),
        Uri.parse(SteambroadcastEndpoints.link(_live)),
      );
      expect(adapter.http.sent, isEmpty, reason: 'an id needs no request');
      expect(
        _right(await link.resolve(Uri.parse('https://steamcommunity.com/id/gabelogannewell/'))),
        Uri.parse(SteambroadcastEndpoints.link(_offline)),
      );
      expect(adapter.http.sent.single.url.path, '/id/gabelogannewell/');
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/x'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('https://steamcommunity.com/id/nobody/'))), isA<LiveSiteNotFound>());
    });

    test('statuses map at the Either boundary: refusals fold into rate limit', () async {
      for (final (status, matcher) in [
        (401, isA<LiveSiteRateLimitError>()),
        (403, isA<LiveSiteRateLimitError>()),
        (404, isA<LiveSiteNotFound>()),
        (429, isA<LiveSiteRateLimitError>()),
        (400, isA<LiveSiteParseError>()),
        (502, isA<LiveSiteNetworkError>()),
        (302, isA<LiveSiteNetworkError>()),
      ]) {
        final adapter = _adapter(answers: _Answers(statuses: {'/miniprofile/': status, '/broadcast/watch/': status}));
        expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_live)), matcher, reason: '$status');
        expect(adapter.http.sent.map((seen) => seen.url.path), [
          '/miniprofile/1524949844/json',
          '/broadcast/watch/$_live',
        ], reason: '$status: the profile failed, then its fallback, the watch page');
      }
      final network = SteambroadcastSite(http: SteambroadcastHttp(_FailingHttp(const TimeoutFailure('slow'))));
      expect(_leftOf(await network.capability<LiveRoomProvider>()!.getRoom(_live)), isA<LiveSiteNetworkError>());
    });

    test('the deadline is a network failure, and it cancels the request', () async {
      var cancelled = false;
      final http = _FakeHttp((seen) {
        unawaited(seen.cancel.whenCancel.then((_) => cancelled = true));
        final done = Completer<LiveResponse>();
        unawaited(seen.cancel.whenCancel.then((_) => done.completeError(const CancelledFailure())));
        return done.future;
      });
      final site = SteambroadcastSite(http: SteambroadcastHttp(http), deadline: const Duration(milliseconds: 30));
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom(_live)), isA<LiveSiteNetworkError>());
      expect(cancelled, isTrue, reason: 'the request is cancelled too');
    });

    test('the chat provider builds a session for an entered broadcast, offline one included', () async {
      final adapter = _adapter();
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: _live));
      expect(session, isA<SteambroadcastDanmakuSession>());
      await session.dispose();
      final idle = _adapter(
        answers: _Answers(
          mpd: _mpdFixture(success: 'offline', broadcastId: 0, viewers: null, hlsUrl: ''),
          info: _infoFixture(success: 42),
        ),
      );
      final offline = _right(await idle.site.capability<LiveDanmakuProvider>()!.createSession(roomId: _offline));
      expect(offline, isA<SteambroadcastDanmakuSession>());
      final seen = <LiveMessage>[];
      final done = offline.events.listen(seen.add).asFuture<void>();
      await done;
      expect(seen.single.type, LiveMessageType.system, reason: 'the chat ends when the broadcast is offline');
      await offline.dispose();
    });
  });

  group('chat protocol', () {
    test('getchatinfo: the recorded template; refusals and shapes that are not a chat log', () {
      const template =
          'https://steambroadcastchat.akamaized.net/chat/c1/messages/{0}'
          '?chat_origin=chat1.discovery.steamserver.net:8071';
      final chat = SteambroadcastDanmakuCodec.chat(
        _json({'success': 1, 'view_url_template': template}),
        broadcastId: '1',
      );
      expect(chat.broadcastId, '1');
      expect(
        chat.window(0).toString(),
        'https://steambroadcastchat.akamaized.net/chat/c1/messages/0?chat_origin=chat1.discovery.steamserver.net:8071',
      );
      expect(chat.window(414148761).pathSegments.last, '414148761');
      expect(
        SteambroadcastDanmakuCodec.chat(
          _json({'success': '1', 'view_url_template': 'https://steamcommunity.com/c/{0}'}),
          broadcastId: '1',
        ).template,
        isNotEmpty,
      );

      void refused(Object? body, int status, String detail) {
        expect(
          () => SteambroadcastDanmakuCodec.chat(body is String ? body : _json(body), broadcastId: '1', status: status),
          throwsA(isA<SteambroadcastFailure>().having((failure) => failure.message, 'detail', contains(detail))),
        );
      }

      refused({'success': 2}, 500, 'getchatinfo: HTTP 500 {"success":2}');
      refused('<html>denied</html>', 403, 'HTTP 403');
      refused('', 404, 'HTTP 404');
      refused('', 429, 'HTTP 429');
      refused('not json', 200, 'not JSON');
      refused([1], 200, 'not an object');
      refused({'success': 2}, 200, 'success 2');
      refused({'success': 1}, 200, 'view_url_template');
      refused({'success': 1, 'view_url_template': 7}, 200, 'view_url_template');
      refused(
        {'success': 1, 'view_url_template': 'https://steambroadcastchat.akamaized.net/chat/1/messages/0'},
        200,
        'no view_url_template',
      );
      for (final url in [
        'http://steambroadcastchat.akamaized.net/chat/1/messages/{0}',
        'https://evil.akamaized.net/chat/1/messages/{0}',
        'https://steambroadcastchat.akamaized.net.evil.test/chat/1/messages/{0}',
        'https://user@steambroadcastchat.akamaized.net/chat/1/messages/{0}',
        'https://steambroadcastchat.akamaized.net:8443/chat/1/messages/{0}',
        'https://steambroadcastchat.akamaized.net/chat/1/messages/{0}#x',
      ]) {
        refused({'success': 1, 'view_url_template': url}, 200, 'unexpected chat log');
      }
      for (final url in [
        'https://steambroadcastchat.akamaized.net/chat/1/messages/{0}?chat_origin=x.steamserver.net:8071',
        'https://SteamBroadcastChat.akamaized.net:443/chat/1/messages/{0}',
        'https://steambroadcast-chat2.akamaized.net/chat/1/messages/{0}',
        'https://broadcastchat7.discovery.steamserver.net/chat/1/messages/{0}',
        'https://steamcommunity.com/broadcast/chat/1/{0}',
        'https://cache1.steamcontent.com/chat/{0}',
        'https://community.fastly.steamstatic.com/chat/{0}',
      ]) {
        expect(
          SteambroadcastDanmakuCodec.chat(_json({'success': 1, 'view_url_template': url}), broadcastId: '1').template,
          url,
          reason: url,
        );
      }
      expect(
        SteambroadcastDanmakuCodec.chat(
          _json({'success': 1, 'view_url_template': 'https://steamcommunity.com/c/{0}/{0}'}),
          broadcastId: '1',
        ).window(5),
        Uri.parse('https://steamcommunity.com/c/5/{0}'),
        reason: 'only the first {0} is replaced',
      );
    });

    test('broadcast ids: digits, not 0, trimmed', () {
      expect(SteambroadcastDanmakuCodec.broadcastIdOf(' 3718707516587165478 '), '3718707516587165478');
      expect(SteambroadcastDanmakuCodec.broadcastIdOf('7'), '7');
      for (final value in [null, '', '0', '007', '-1', '1.5', 'abc', '1' * 21]) {
        expect(SteambroadcastDanmakuCodec.broadcastIdOf(value), isNull, reason: '$value');
      }
    });

    test('a window: the next window, initial_delay and the chat lines', () {
      Map<String, Object?> line(String text, {String steamId = '200', Object? name = 'viewer'}) => {
        'steamid': steamId,
        'persona_name': name,
        'msg': text,
      };
      final window = SteambroadcastDanmakuCodec.window(
        _json({
          'messages': [
            line('  hello  ', steamId: '42', name: ' Name '),
            line('ːsteamhappyː'),
            line('   '),
            {'steamid': '3', 'persona_name': 'n', 'msg': 12},
            {'steamid': 4, 'persona_name': 5, 'msg': 'numbers'},
            {'steamid': true, 'msg': 'no name'},
            'text',
            null,
          ],
          'next_request': 1500,
        }),
        time: 1000,
      );
      expect(window.next, 1500);
      expect(window.initialDelay, isNull);
      expect(
        window.messages.map(
          (message) => '${message.effectiveSender.userId}|${message.effectiveSender.userName}|${message.text}',
        ),
        ['42|Name|hello', '200|viewer|ːsteamhappyː', '4||numbers', '||no name'],
      );
      for (final message in window.messages) {
        expect(message.type, LiveMessageType.chat);
        expect(message.messageId, '', reason: 'Steam gives no id');
        expect(message.sentAt, isNull, reason: 'nor a time');
      }

      SteambroadcastChatWindow read(Map<String, Object?> body, {int time = 1000}) =>
          SteambroadcastDanmakuCodec.window(_json(body), time: time);
      expect(read({'next_request': '1500', 'initial_delay': '250'}).next, 1500);
      expect(read({'next_request': 1001, 'initial_delay': 250}).initialDelay, const Duration(milliseconds: 250));
      expect(read({'next_request': 1500, 'initial_delay': 0}).initialDelay, Duration.zero);
      for (final delay in [-1, 2.5, 'soon', null, true]) {
        expect(read({'next_request': 1500, 'initial_delay': delay}).initialDelay, isNull, reason: '$delay');
      }
      expect(read({'next_request': 1500, 'messages': 'none'}).messages, isEmpty);
      expect(read({'next_request': 7, 'messages': <Object?>[]}, time: 0).next, 7, reason: 'window 0: any next');
      for (final next in [null, 0, -5, 1000, 999, 1500.0, '15a', '', '1234567890123456', true]) {
        expect(
          () => read({'next_request': next}),
          throwsA(_fails(SteambroadcastFailureKind.apiChanged)),
          reason: '$next',
        );
      }
      expect(
        () => SteambroadcastDanmakuCodec.window('<html>gone</html>', time: 1000, status: 404),
        throwsA(_fails(SteambroadcastFailureKind.notFound)),
      );
      expect(() => SteambroadcastDanmakuCodec.window('{', time: 1), throwsA(isA<SteambroadcastFailure>()));
      expect(
        () => SteambroadcastDanmakuCodec.window('', time: 1, status: 502),
        throwsA(_fails(SteambroadcastFailureKind.network)),
      );
    });

    test("the audience: getbroadcastmpd's num_viewers, concurrent viewers", () {
      final message = SteambroadcastDanmakuCodec.audience(2519);
      expect(message.type, LiveMessageType.audienceUpdate);
      final update = message.payload! as LiveAudienceUpdate;
      expect(update.kind, LiveAudienceSignalKind.onlineViewers);
      expect(update.value, 2519);
    });

    test("the chat log's clock: as the web client times it, with the nudge and the bounds", () {
      final clock = SteambroadcastChatClock();
      expect((clock.isSynced, clock.window, clock.nudge), (false, 0, Duration.zero));
      Duration ms(int value) => Duration(milliseconds: value);
      expect(clock.sync(5000, ms(300), ms(100)), ms(300));
      expect((clock.isSynced, clock.window), (true, 5000));
      expect(clock.advance(5500, ms(450)), ms(450), reason: 'window 5000 was due at 400');
      expect(clock.advance(6000, ms(1500)), Duration.zero, reason: 'behind: at once');
      expect(clock.advance(6500, ms(1900)), Duration.zero);
      expect(clock.advance(7000, ms(1900)), ms(500));
      clock
        ..miss()
        ..miss();
      expect(clock.nudge, ms(20));
      expect(clock.advance(7500, ms(2400)), ms(520), reason: 'due at 400 + 2500 + 20');
      for (var i = 0; i < 200; i++) {
        clock.miss();
      }
      expect(clock.nudge, const Duration(seconds: 1), reason: 'bounded (the web client is not)');
      expect(clock.advance(1000000, ms(0)), const Duration(seconds: 60), reason: 'at most 60 s');
      expect(clock.sync(9000, const Duration(minutes: 5), ms(0)), const Duration(seconds: 60));
      expect(clock.sync(9000, ms(-5), ms(0)), Duration.zero);
      clock.resync();
      expect((clock.isSynced, clock.window, clock.nudge), (false, 0, const Duration(seconds: 1)));
      expect(SteambroadcastChatClock().advance(300, ms(10)), Duration.zero, reason: 'not set: sets it now');
    });

    test('the waits after failures: 500 ms, then 1, 2, 4, 8 s from the 8th', () {
      expect(
        [for (var failures = 1; failures <= 15; failures++) SteambroadcastDanmakuCodec.wait(failures)],
        [
          for (var i = 0; i < 7; i++) const Duration(milliseconds: 500),
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
          for (var i = 0; i < 5; i++) const Duration(seconds: 8),
        ],
      );
      expect(
        (
          SteambroadcastDanmakuCodec.resyncAfter,
          SteambroadcastDanmakuCodec.lookUpAfter,
          SteambroadcastDanmakuCodec.maxFailures,
        ),
        (4, 8, 15),
      );
    });
  });

  group('comment session', () {
    test('a session follows the chat log of the given broadcast: the history skipped, lines reported', () async {
      final timers = FakeTimers();
      final log = _ChatLog()
        ..lines[5500] = [
          {'steamid': '200', 'persona_name': 'viewer', 'msg': 'first'},
          {'steamid': '201', 'persona_name': 'B', 'msg': 'second'},
        ]
        ..lines[6000] = [
          {'steamid': '200', 'persona_name': 'viewer', 'msg': 'ːsteamhappyː'},
        ];
      final http = _FakeHttp(log.answer);
      final session = SteambroadcastDanmakuSession(
        args: const SteambroadcastDanmakuArgs(_live, broadcastId: '7001'),
        http: SteambroadcastHttp(http),
        timers: timers.timers,
        elapsed: _elapsed,
      );
      expect(await session.connect(), isNull);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      // Step 1: getchatinfo, then window 0 (the history, not reported).
      await _settle();
      timers.fire();
      await _settle();
      expect(seen, isEmpty, reason: 'window 0 is the history: it only sets the clock');
      expect(http.sent.map((seen) => seen.url.path), ['/broadcast/getchatinfo/', '/chat/c7001/messages/0']);
      expect(http.sent.first.headers['referer'], SteambroadcastEndpoints.link(_live));
      expect(http.sent.last.headers['origin'], SteambroadcastEndpoints.origin);
      // The clock is set: window 5000 is due 300 ms from now, each later one
      // 500 ms past its time.
      for (var index = 0; index < 3; index++) {
        timers.fire();
        await _settle();
      }
      expect(seen.map((message) => '${message.effectiveSender.userId}|${message.text}'), [
        '200|first',
        '201|second',
        '200|ːsteamhappyː',
      ]);
      expect(http.sent.last.url.path, '/chat/c7001/messages/6000');
      await subscription.cancel();
      await session.dispose();
      expect(await session.connect(), isA<LiveSiteUnsupported>(), reason: 'not reusable after dispose');
    });

    test('without a broadcast id the chat looks it up, and reports the viewers', () async {
      final timers = FakeTimers();
      final http = _FakeHttp(_ChatLog().answer);
      final session = SteambroadcastDanmakuSession(
        args: const SteambroadcastDanmakuArgs(_live),
        http: SteambroadcastHttp(http),
        timers: timers.timers,
        elapsed: _elapsed,
      );
      expect(await session.connect(), isNull);
      final next = _next(session.events, 1);
      await _settle();
      timers.fire();
      await _settle();
      expect(http.sent.map((seen) => seen.url.path), [
        '/broadcast/getbroadcastmpd/',
        '/broadcast/getchatinfo/',
        '/chat/c7001/messages/0',
      ]);
      final message = (await next).single;
      expect(message.type, LiveMessageType.audienceUpdate);
      expect(
        (message.payload! as LiveAudienceUpdate).value,
        2519,
        reason: "getbroadcastmpd's viewers, reported whenever it is asked",
      );
      await session.dispose();
    });

    test('an offline broadcaster ends the session with a terminal message', () async {
      final timers = FakeTimers();
      final http = _FakeHttp((seen) {
        if (seen.url.path == '/broadcast/getbroadcastmpd/') {
          return _resp(200, _json(_mpdFixture(success: 'offline', broadcastId: 0, viewers: null, hlsUrl: '')));
        }
        return _resp(404, 'nope');
      });
      final session = SteambroadcastDanmakuSession(
        args: const SteambroadcastDanmakuArgs(_live),
        http: SteambroadcastHttp(http),
        timers: timers.timers,
        elapsed: _elapsed,
      );
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      expect(await session.connect(), isNull);
      await _settle();
      timers.fire();
      await done;
      expect(http.sent.map((seen) => seen.url.path), ['/broadcast/getbroadcastmpd/']);
      expect(seen.single.type, LiveMessageType.system);
      expect(seen.single.text, 'Offline');
      await session.dispose();
    });

    test('an id that is no Steam id is refused before any request', () async {
      final http = _FakeHttp(_ChatLog().answer);
      final session = SteambroadcastDanmakuSession(
        args: const SteambroadcastDanmakuArgs('not-an-id', broadcastId: '7001'),
        http: SteambroadcastHttp(http),
        timers: FakeTimers().timers,
        elapsed: _elapsed,
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(http.sent, isEmpty);
      await session.dispose();
    });

    test('failures are retried; the eighth failure looks the chat up again; the sixteenth ends', () async {
      final timers = FakeTimers();
      final http = _FakeHttp(_ChatLog(failWindows: true).answer);
      final session = SteambroadcastDanmakuSession(
        args: const SteambroadcastDanmakuArgs(_live, broadcastId: '7001'),
        http: SteambroadcastHttp(http),
        timers: timers.timers,
        elapsed: _elapsed,
      );
      expect(await session.connect(), isNull);
      await _settle();
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      // Every window answer fails: 500 ms, then 1, 2, 4, 8 s from the 8th
      // failure, which looks the chat up again (getbroadcastmpd, getchatinfo).
      // The 16th failure ends the session.
      for (var attempt = 0; attempt < 16; attempt++) {
        timers.fire();
        await _settle();
      }
      final paths = http.sent.map((seen) => seen.url.path).toList();
      expect(paths.first, '/broadcast/getchatinfo/', reason: 'the arguments carry the broadcast id');
      expect(
        paths.where((path) => path == '/broadcast/getbroadcastmpd/'),
        hasLength(8),
        reason: 'the eighth failure looks the chat up again, and every later window too',
      );
      expect(paths.where((path) => path == '/broadcast/getchatinfo/'), hasLength(9));
      final waits = timers.after.map((wait) => wait.delay).toList();
      expect(waits.first, Duration.zero, reason: 'the first step runs at once');
      expect(
        waits.sublist(1, 8),
        List.filled(7, const Duration(milliseconds: 500)),
        reason: 'the first seven failures wait the retry delay',
      );
      expect(waits[8], const Duration(seconds: 1), reason: 'the eighth failure backs off a second');
      expect(waits[9], const Duration(seconds: 2));
      expect(waits[10], const Duration(seconds: 4));
      expect(waits[11], const Duration(seconds: 8));
      await done;
      expect(
        seen.where((message) => message.type == LiveMessageType.system),
        isNotEmpty,
        reason: 'the budget end is told as a terminal system message',
      );
      final before = http.sent.length;
      timers.fire();
      await _settle();
      expect(http.sent.length, before, reason: 'nothing is sent once the session ended');
      await session.dispose();
    });

    test('a refused getchatinfo forgets the broadcast id', () async {
      final timers = FakeTimers();
      final http = _FakeHttp(_ChatLog(staleId: '999').answer);
      final session = SteambroadcastDanmakuSession(
        args: const SteambroadcastDanmakuArgs(_live, broadcastId: '999'),
        http: SteambroadcastHttp(http),
        timers: timers.timers,
        elapsed: _elapsed,
      );
      expect(await session.connect(), isNull);
      final next = _next(session.events, 1);
      await _settle();
      timers.fire();
      await _settle();
      timers.fire();
      await _settle();
      expect(http.sent.map((seen) => seen.url.path), [
        '/broadcast/getchatinfo/',
        '/broadcast/getbroadcastmpd/',
        '/broadcast/getchatinfo/',
        '/chat/c7001/messages/0',
      ], reason: 'Steam refused 999, so the chat asked getbroadcastmpd for the current one');
      expect((await next).single.type, LiveMessageType.audienceUpdate);
      await session.dispose();
    });

    test('the waits follow the retry ladder, driven by the timers', () async {
      final timers = FakeTimers();
      final http = _FakeHttp(_ChatLog(failWindows: true).answer);
      final session = SteambroadcastDanmakuSession(
        args: const SteambroadcastDanmakuArgs(_live, broadcastId: '7001'),
        http: SteambroadcastHttp(http),
        timers: timers.timers,
        elapsed: _elapsed,
      );
      expect(await session.connect(), isNull);
      await _settle();
      final waits = <Duration>[];
      for (var failure = 0; failure < 4; failure++) {
        timers.fire();
        await _settle();
        waits.add(timers.after.last.delay);
      }
      expect(
        waits,
        List.filled(4, const Duration(milliseconds: 500)),
        reason: 'the first four failures wait the retry delay',
      );
      await session.dispose();
    });
  });
}

/// The session tests' monotonic clock: a counter that never moves, so every
/// window is answered before its time.
Duration _elapsed() => Duration.zero;
