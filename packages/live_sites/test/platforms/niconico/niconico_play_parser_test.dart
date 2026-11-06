import 'dart:convert';

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_play_parser.dart';
import 'package:test/test.dart';

/// The seat's master.
final Uri _master = Uri.parse('https://${NiconicoEndpoints.mediaHost}/hls/playlists/master.m3u8?token=abc');

/// The instant the grant is read at.
final DateTime _now = DateTime.utc(2026, 10, 1, 12);

/// An HTTP date after [_now].
String _httpDate(DateTime at) =>
    '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][at.weekday % 7]}, '
    '${at.day.toString().padLeft(2, '0')} '
    '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][at.month - 1]} '
    '${at.year} '
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')} GMT';

Map<String, Object?> _cookie(
  String name,
  String path, {
  String value = 'token',
  Object? domain = 'nicovideo.jp',
  Object? secure = true,
  Object? expires,
}) => {'name': name, 'value': value, 'path': path, 'domain': domain, 'secure': secure, 'expires': ?expires};

/// The seat's `stream` message.
Map<String, dynamic> _stream({
  Object? protocol = 'hls',
  Object? uri = 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/master.m3u8?token=abc',
  Object? quality = 'abr',
  Object? availableQualities = const ['abr', 'super_high', 'high', 'audio_128'],
  Object? cookies,
}) => jsonDecode(
  jsonEncode({
    'protocol': protocol,
    'uri': uri,
    'quality': quality,
    'availableQualities': availableQualities,
    'cookies':
        cookies ??
        [
          _cookie('hls_playlist', '/hls/playlists'),
          _cookie('hls_segment', '/hls/segments', expires: _httpDate(DateTime.utc(2026, 10, 1, 14))),
          _cookie('hls_key', '/hls/keys', expires: _httpDate(DateTime.utc(2026, 10, 1, 13))),
        ],
  }),
) as Map<String, dynamic>;

NiconicoGrant _grant({Object? cookies, Object? quality, Object? availableQualities, DateTime? now}) =>
    NiconicoPlayParser.grant(
      _stream(
        cookies: cookies,
        quality: quality ?? 'abr',
        availableQualities: availableQualities ?? const ['abr', 'super_high', 'high', 'audio_128'],
      ),
      now: now ?? _now,
    );

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on NiconicoFailure catch (failure) {
    return failure.kind;
  }
}

NiconicoFailure _failure(void Function() read) {
  try {
    read();
  } on NiconicoFailure catch (failure) {
    return failure;
  }
  throw StateError('the message was accepted');
}

const String _masterBody = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-STREAM-INF:BANDWIDTH=6000000,AVERAGE-BANDWIDTH=5800000,RESOLUTION=1920x1080,CODECS="avc1.640028",FRAME-RATE=60
https://livedelivery.dlive.nicovideo.jp/hls/playlists/high.m3u8?token=one
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,CODECS="hvc1.1.6.L93.90"
medium.m3u8?token=two
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=640x360
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=0,RESOLUTION=320x180
tiny.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=1024x576
http://livedelivery.dlive.nicovideo.jp/hls/playlists/plain.m3u8
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="日语",URI="audio.m3u8"
''';

List<NiconicoVariant> _variants(String body) => NiconicoPlayParser.variants(body, source: _master);

void main() {
  group('the stream grant', () {
    test("the seat's master, its offered qualities and its cookies", () {
      final grant = _grant();
      expect(grant.uri, _master);
      expect(grant.quality, 'abr');
      expect(grant.availableQualities, ['abr', 'super_high', 'high'], reason: 'audio-only names are not watchable');
      expect(grant.cookies.map((cookie) => cookie.name), ['hls_playlist', 'hls_segment', 'hls_key']);
      expect(grant.cookies.first.path, '/hls/playlists');
      expect(grant.cookies.first.expires, isNull);
      expect(grant.isActive, isTrue);
      expect(grant.leaseExpiresAt, DateTime.utc(2026, 10, 1, 13), reason: "the soonest expiry is the grant's own");
      expect(grant.toString(), 'NiconicoGrant(${NiconicoEndpoints.mediaHost}, abr, 3 cookies)');
      expect(() => grant.availableQualities.add('x'), throwsUnsupportedError);
    });

    test('the protocol must be the one we can play', () {
      expect(
        _failure(() => NiconicoPlayParser.grant(_stream(protocol: 'http'), now: _now)).message,
        'stream: protocol http',
      );
      expect(
        _failure(() => NiconicoPlayParser.grant(_stream(protocol: null), now: _now)).message,
        'stream: protocol null',
      );
    });

    test("the master must be the media host's own playlist", () {
      const good = 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/master.m3u8?token=abc';
      expect(NiconicoPlayParser.grant(_stream(), now: _now).uri.toString(), good);
      for (final bad in [
        'http://livedelivery.dlive.nicovideo.jp/hls/playlists/master.m3u8',
        'https://live.nicovideo.jp/hls/playlists/master.m3u8',
        'https://livedelivery.dlive.nicovideo.jp:443/hls/playlists/master.m3u8',
        'https://someone@livedelivery.dlive.nicovideo.jp/hls/playlists/master.m3u8',
        'https://livedelivery.dlive.nicovideo.jp/hls/playlists/master.m3u8#f',
        'https://livedelivery.dlive.nicovideo.jp/hls/segments/master.m3u8',
        'https://livedelivery.dlive.nicovideo.jp/hls/playlists/master.flv',
        'https://LIVEDLIVERY.DLIVE.NICOVIDEO.JP/hls/playlists/master.m3u8',
        'not a uri',
        null,
        7,
      ]) {
        expect(
          _failure(() => NiconicoPlayParser.grant(_stream(uri: bad), now: _now)).message,
          'stream: unexpected uri',
          reason: '$bad',
        );
      }
      expect(
        _kindOf(
          () => NiconicoPlayParser.grant(
            _stream(
              uri:
                  '${'https://livedelivery.dlive.nicovideo.jp/hls/playlists/'}'
                  '${'a' * 8200}.m3u8',
            ),
            now: _now,
          ),
        ),
        NiconicoFailureKind.apiChanged,
        reason: 'a body that long is not read',
      );
    });

    test('the quality must be one the seat named, and the names must be plain', () {
      expect(
        _failure(() => NiconicoPlayParser.grant(_stream(quality: 'nope'), now: _now)).message,
        'stream: unexpected quality list',
      );
      expect(
        _failure(() => NiconicoPlayParser.grant(_stream(quality: null), now: _now)).message,
        'stream: unexpected quality list',
      );
      expect(
        _failure(() => NiconicoPlayParser.grant(_stream(quality: '超清'), now: _now)).message,
        'stream: unexpected quality list',
      );
      expect(
        _failure(() => NiconicoPlayParser.grant(_stream(availableQualities: const <String>[]), now: _now)).message,
        'stream: unexpected quality list',
      );
      expect(
        _failure(
          () => NiconicoPlayParser.grant(
            _stream(availableQualities: List<String>.generate(33, (index) => 'q$index')),
            now: _now,
          ),
        ).message,
        'stream: unexpected quality list',
      );
      expect(
        _failure(() => NiconicoPlayParser.grant(_stream(availableQualities: const ['abr', 'abr']), now: _now)).message,
        'stream: unexpected quality list',
        reason: 'a name twice is not a set of choices',
      );
      expect(
        _failure(() => NiconicoPlayParser.grant(_stream(availableQualities: const ['abr', 7]), now: _now)).message,
        'stream: unexpected quality list',
      );
      final audio = _grant(quality: 'audio_128', availableQualities: const ['abr', 'audio_128']);
      expect(audio.quality, 'audio_128', reason: "the seat's own choice is not second-guessed");
      expect(audio.availableQualities, ['abr'], reason: 'but the list a viewer picks from drops it');
    });

    test('a cookie is a secure nicovideo token under /hls/', () {
      for (final bad in [
        _cookie('hls_playlist', '/hls/playlists', secure: false),
        _cookie('hls_playlist', '/hls/playlists', domain: 'example.com'),
        _cookie('hls_playlist', '/hls/playlists', domain: 'live.nicovideo.jp'),
        _cookie('hls_playlist', '/other/playlists'),
        _cookie('hls_playlist', '/hls/playlists/../../etc'),
        _cookie('hls_playlist', 'hls/playlists'),
        _cookie('__Host-hls', '/hls/playlists'),
        _cookie('bad name', '/hls/playlists'),
        _cookie('hls_playlist', '/hls/playlists', value: 'a;b'),
        _cookie('hls_playlist', '/hls/playlists', value: 'a"b'),
        _cookie('hls_playlist', '/hls/playlists', value: r'a\b'),
        _cookie('hls_playlist', '/hls/playlists', value: 'a b'),
        _cookie('hls_playlist', '/hls/playlists', expires: 1800),
        _cookie('hls_playlist', '/hls/playlists', expires: 'tomorrow'),
        {'name': 'hls_playlist', 'value': 'x', 'path': '/hls/playlists', 'domain': 'nicovideo.jp'},
      ]) {
        expect(_kindOf(() => _grant(cookies: [bad])), NiconicoFailureKind.apiChanged, reason: '$bad');
      }
      expect(
        _failure(() => _grant(cookies: [_cookie('a', '/hls/x', expires: 'tomorrow')])).message,
        'stream: cookie a expires "tomorrow"',
      );
      expect(_failure(() => _grant(cookies: ['not a map'])).message, 'stream: cookie is not an object');
      expect(_failure(() => _grant(cookies: 'not a list')).message, 'stream: cookies');
      expect(
        _failure(
          () => _grant(
            cookies: [for (final index in List.generate(65, (index) => index)) _cookie('c$index', '/hls/p$index')],
          ),
        ).message,
        'stream: cookies',
      );
      expect(
        _failure(() => _grant(cookies: [_cookie('a', '/hls/x'), _cookie('a', '/hls/x')])).message,
        contains('stream: unexpected cookie a'),
        reason: 'the same name twice on one path is one cookie too many',
      );
      expect(
        _grant(cookies: [_cookie('a', '/hls/x'), _cookie('a', '/hls/y')]).cookies,
        hasLength(2),
        reason: 'the same name on two paths is two path-scoped cookies',
      );
    });

    test('a cookie already dead at the ask is dropped, not refused', () {
      final grant = _grant(
        cookies: [
          _cookie('live', '/hls/playlists', expires: _httpDate(DateTime.utc(2026, 10, 1, 13))),
          _cookie('gone', '/hls/segments', expires: _httpDate(DateTime.utc(2026, 10, 1, 11))),
          _cookie('exact', '/hls/keys', expires: _httpDate(_now)),
        ],
      );
      expect(grant.cookies.map((cookie) => cookie.name), ['live'], reason: 'an expiry equal to now is not after it');
      expect(grant.leaseExpiresAt, DateTime.utc(2026, 10, 1, 13));
    });

    test("the cookie header covers the target's path, longest first", () {
      final grant = _grant();
      expect(
        grant.cookieHeaderFor(Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/segments/one.ts'), now: _now),
        'hls_segment=token',
      );
      expect(
        grant.cookieHeaderFor(
          Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/playlists/medium.m3u8'),
          now: _now,
        ),
        'hls_playlist=token',
      );
      expect(
        grant.cookieHeaderFor(Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/playlists-x/a.m3u8'), now: _now),
        isNull,
        reason: "a sibling path is not under the cookie's path",
      );
      final nested = NiconicoPlayParser.grant(
        _stream(
          cookies: [
            _cookie('top', '/hls/playlists'),
            _cookie('deep', '/hls/playlists/medium'),
            _cookie('mid', '/hls/segments'),
          ],
        ),
        now: _now,
      );
      expect(
        nested.cookieHeaderFor(
          Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/playlists/medium/a.m3u8'),
          now: _now,
        ),
        'deep=token; top=token',
        reason: 'the most specific path leads, the rest keep the order received',
      );
    });

    test('a cookie past its expiry is not offered, and the grant keeps working without it', () {
      final grant = _grant();
      expect(
        grant.cookieHeaderFor(
          Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/keys/one.key'),
          now: DateTime.utc(2026, 10, 1, 13, 30),
        ),
        isNull,
      );
      expect(
        grant.cookieHeaderFor(
          Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/keys/one.key'),
          now: DateTime.utc(2026, 10, 1, 12, 30),
        ),
        'hls_key=token',
      );
    });

    test("only the master's own https origin gets cookies", () {
      final grant = _grant();
      for (final target in [
        'https://other.example.com/hls/playlists/a.m3u8',
        'http://livedelivery.dlive.nicovideo.jp/hls/playlists/a.m3u8',
        'https://someone@livedelivery.dlive.nicovideo.jp/hls/playlists/a.m3u8',
        'https://livedelivery.dlive.nicovideo.jp/hls/playlists/a.m3u8#f',
        'https://livedelivery.dlive.nicovideo.jp/other/a.m3u8',
      ]) {
        expect(grant.cookieHeaderFor(Uri.parse(target), now: _now), isNull, reason: target);
      }
    });

    test('a revoked grant says so and keeps no cookie', () {
      final grant = _grant()..revoke();
      expect(grant.isActive, isFalse);
      expect(grant.cookies, isEmpty);
      expect(grant.leaseExpiresAt, isNull);
      expect(
        _failure(() => grant.cookieHeaderFor(Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/playlists/a.m3u8')))
            .message,
        'the stream grant was revoked',
      );
      expect(
        _kindOf(
          () => NiconicoPlayParser.lines(grant, (
            url: 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/a.m3u8',
            width: 1,
            height: 1,
            bandwidth: 1,
            codec: null,
            frameRate: 0,
          ), roomId: 'so42'),
        ),
        NiconicoFailureKind.streamUnavailable,
      );
    });
  });

  group('the other seat messages', () {
    test('keepIntervalSec is a whole number of seconds the site means', () {
      expect(NiconicoPlayParser.seatInterval({'keepIntervalSec': 60}), 60);
      expect(NiconicoPlayParser.seatInterval({'keepIntervalSec': 1}), 1);
      expect(NiconicoPlayParser.seatInterval({'keepIntervalSec': 300}), 300);
      for (final bad in ['60', 0, 301, 1.5, null]) {
        expect(
          _failure(() => NiconicoPlayParser.seatInterval({'keepIntervalSec': bad})).message,
          'seat: keepIntervalSec $bad',
        );
      }
      expect(_failure(() => NiconicoPlayParser.seatInterval('not a map')).message, 'seat: keepIntervalSec null');
    });

    test('an error code says what kind of refusal it is', () {
      expect(
        {
          for (final code in [
            'NO_PERMISSION',
            'NOT_PLAYABLE',
            'TICKET_REQUIRED',
            'TOO_MANY_CONNECTIONS',
            'CONNECT_ERROR',
            'INVALID_STREAM_QUALITY',
            'INVALID_MESSAGE',
            'LIVE_STREAM_NOT_STARTED',
          ])
            code: NiconicoPlayParser.seatError({'code': code}).kind,
        },
        {
          'NO_PERMISSION': NiconicoFailureKind.needsLogin,
          'NOT_PLAYABLE': NiconicoFailureKind.needsLogin,
          'TICKET_REQUIRED': NiconicoFailureKind.needsLogin,
          'TOO_MANY_CONNECTIONS': NiconicoFailureKind.rateLimited,
          'CONNECT_ERROR': NiconicoFailureKind.rateLimited,
          'INVALID_STREAM_QUALITY': NiconicoFailureKind.apiChanged,
          'INVALID_MESSAGE': NiconicoFailureKind.apiChanged,
          'LIVE_STREAM_NOT_STARTED': NiconicoFailureKind.streamUnavailable,
        },
      );
      expect(NiconicoPlayParser.seatError({'code': 'NO_PERMISSION'}).message, 'seat error NO_PERMISSION');
      expect(NiconicoPlayParser.seatError(null).kind, NiconicoFailureKind.streamUnavailable);
      expect(NiconicoPlayParser.seatError(null).message, 'seat error unknown');
      expect(NiconicoPlayParser.seatError({'code': 7}).message, 'seat error 7');
    });

    test('a disconnect is the program ending', () {
      expect(NiconicoPlayParser.seatDisconnect({'reason': 'PROGRAM_ENDED'}).message, 'seat disconnect PROGRAM_ENDED');
      expect(NiconicoPlayParser.seatDisconnect({'reason': null}).message, 'seat disconnect null');
      expect(
        NiconicoPlayParser.seatDisconnect({}).message,
        'seat disconnect null',
        reason: 'a reason the map does not carry is written as the word null',
      );
      expect(NiconicoPlayParser.seatDisconnect('a string').message, 'seat disconnect');
      expect(NiconicoPlayParser.seatDisconnect({}).kind, NiconicoFailureKind.streamUnavailable);
    });
  });

  group('the master playlist', () {
    test('the status table', () {
      expect(
        {
          for (final status in [200, 401, 403, 404, 410, 429, 500, 302])
            status: _kindOf(() => NiconicoPlayParser.variants(_masterBody, source: _master, status: status)),
        },
        {
          200: null,
          401: NiconicoFailureKind.riskControl,
          403: NiconicoFailureKind.riskControl,
          404: NiconicoFailureKind.streamUnavailable,
          410: NiconicoFailureKind.streamUnavailable,
          429: NiconicoFailureKind.rateLimited,
          500: NiconicoFailureKind.network,
          302: NiconicoFailureKind.apiChanged,
        },
      );
      expect(
        _failure(() => NiconicoPlayParser.variants('x', source: _master, status: 302)).message,
        'master: HTTP 302 (x)',
      );
    });

    test('the video variants, best first', () {
      final variants = _variants(_masterBody);
      expect(
        [for (final variant in variants) (variant.height, variant.width, variant.bandwidth)],
        [(1080, 1920, 6000000), (720, 1280, 3000000), (360, 640, 1200000)],
        reason: 'no bandwidth, a zero bandwidth or a plain-HTTP variant is not offered',
      );
      expect(variants.first.url, 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/high.m3u8?token=one');
      expect(variants.first.codec, LiveStreamCodec.avc);
      expect(variants.first.frameRate, 60);
      expect(variants[1].codec, LiveStreamCodec.hevc);
      expect(variants[1].url, 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/medium.m3u8?token=two');
      expect(variants[1].frameRate, 0, reason: 'a variant naming no frame rate says zero');
      expect(variants.last.url, 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/low.m3u8');
      expect(variants.last.codec, isNull);
    });

    test('a variant naming no bandwidth is not offered', () {
      const body =
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:RESOLUTION=854x480\n'
          'no_bandwidth.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=640x360\n'
          'low.m3u8\n';
      expect(_variants(body).map((variant) => variant.height), [360]);
    });

    test("a relative variant never inherits the master's token", () {
      expect(_variants(_masterBody).last.url.contains('token'), isFalse);
      expect(_master.queryParameters['token'], 'abc');
    });

    test('a body that is not a master playlist', () {
      expect(_failure(() => _variants('no playlist here')).message, contains('master: not a playlist'));
      expect(_failure(() => _variants('#EXTM3U extra\n')).message, contains('master: not a playlist'));
      expect(
        _failure(() => _variants('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nseg.ts\n')).message,
        'master: no video variant',
        reason: 'a media playlist is a valid playlist with nothing to choose',
      );
      expect(_failure(() => _variants('#EXTM3U\n')).message, 'master: no video variant');
      expect(
        _variants('  #EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\na.m3u8\n'),
        hasLength(1),
        reason: 'the leading blank is trimmed before the header is read',
      );
    });

    test('a variant without a resolution aborts the master', () {
      const body =
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=6000000\nno_resolution.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=640x360\nlow.m3u8\n';
      expect(_failure(() => _variants(body)).kind, NiconicoFailureKind.apiChanged);
      expect(_failure(() => _variants(body)).message, 'master: variant without a resolution');
    });

    test('two variants naming one WxH@bandwidth abort the master', () {
      const body =
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=640x360\na.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=640x360\nb.m3u8\n';
      expect(_failure(() => _variants(body)).kind, NiconicoFailureKind.apiChanged);
      expect(_failure(() => _variants(body)).message, 'master: ambiguous quality selector 640x360@1000');
      const distinct =
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=640x360\na.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=2000,RESOLUTION=640x360\nb.m3u8\n';
      expect(_variants(distinct), hasLength(2), reason: 'a different bandwidth is a different selector');
    });

    test('the same height is ordered by width, then bandwidth', () {
      const body =
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1024x720\nb.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720\na.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=640x360\nc.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=640x360\nd.m3u8\n';
      expect(
        [for (final variant in _variants(body)) '${variant.width}x${variant.height}@${variant.bandwidth}'],
        ['1280x720@1000000', '1024x720@4000000', '640x360@900000', '640x360@500000'],
        reason: 'width breaks a height tie ahead of bandwidth; bandwidth breaks a width tie',
      );
    });
  });

  group('qualities, the pick and the line', () {
    test("one quality per variant, labelled the site's own W×H · bandwidth bps", () {
      final variants = _variants(_masterBody);
      final qualities = NiconicoPlayParser.qualities(variants);
      expect(
        [for (final quality in qualities) (quality.qualityId, quality.label, quality.platformOrder, quality.codec)],
        [
          ('1920x1080@6000000', '1920×1080 · 6000000 bps', 3, LiveStreamCodec.avc),
          ('1280x720@3000000', '1280×720 · 3000000 bps', 2, LiveStreamCodec.hevc),
          ('640x360@1200000', '640×360 · 1200000 bps', 1, null),
        ],
      );
      expect(NiconicoPlayParser.qualities(const []), isEmpty);
    });

    test("the pick is the named variant; an unknown id is the caller's mistake", () {
      final variants = _variants(_masterBody);
      expect(NiconicoPlayParser.pick(variants, '1280x720@3000000')?.height, 720);
      expect(NiconicoPlayParser.pick(variants, ' 1280x720@3000000 ')?.height, 720);
      expect(NiconicoPlayParser.pick(variants, null)?.height, 1080);
      expect(NiconicoPlayParser.pick(variants, '')?.height, 1080, reason: 'no preference is the best one');
      expect(() => NiconicoPlayParser.pick(variants, '999x999@1'), throwsArgumentError);
      expect(NiconicoPlayParser.pick(const [], '1280x720@3000000'), isNull);
    });

    test("the line is the variant's playlist with the grant's own cookies", () {
      final grant = _grant();
      final variant = _variants(_masterBody)[1];
      final line = NiconicoPlayParser.lines(grant, variant, roomId: ' so42 ', now: _now).single;
      expect(line.url, 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/medium.m3u8?token=two');
      expect(line.format, LiveStreamFormat.hls);
      expect(line.formatSource, LivePlayFormatSource.declared);
      expect(line.lineLabel, NiconicoEndpoints.mediaHost);
      expect(line.codec, LiveStreamCodec.hevc);
      final headers = line.headers.toMap();
      expect(headers['user-agent'], NiconicoEndpoints.userAgent);
      expect(headers['referer'], '${NiconicoEndpoints.origin}/watch/so42');
      expect(headers['cookie'], 'hls_playlist=token', reason: 'the playlist path has its own cookie');
      expect(line.geometry.width, 1280);
      expect(line.geometry.height, 720);
      expect(line.geometry.frameRate, isNull, reason: 'a variant naming no frame rate gives the player nothing');
      expect(line.geometry.bitrateKbps, 3000);
      expect(line.lease?.expiresAt, DateTime.utc(2026, 10, 1, 13));
      expect(line.lease?.refreshAt, DateTime.utc(2026, 10, 1, 12, 59));
      expect(line.lease?.requiresReconnect, isFalse);
    });

    test('a variant outside the cookie paths gets no cookie header', () {
      final grant = _grant(cookies: [_cookie('playlist', '/hls/playlists')]);
      final line = NiconicoPlayParser.lines(
        grant,
        (
          url: 'https://livedelivery.dlive.nicovideo.jp/other/a.m3u8',
          width: 640,
          height: 360,
          bandwidth: 1000,
          codec: null,
          frameRate: 30,
        ),
        roomId: 'so42',
        now: _now,
      ).single;
      expect(line.headers.toMap().containsKey('cookie'), isFalse);
      expect(line.lease, isNull, reason: 'a grant whose cookies never expire has no lease');
      expect(line.geometry.frameRate, 30);
    });

    test('a frame rate under one is not a frame rate', () {
      final line = NiconicoPlayParser.lines(
        _grant(),
        (
          url: 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/a.m3u8',
          width: 640,
          height: 360,
          bandwidth: 1234,
          codec: null,
          frameRate: 0.5,
        ),
        roomId: 'so42',
        now: _now,
      ).single;
      expect(line.geometry.frameRate, isNull);
      expect(line.geometry.bitrateKbps, 1, reason: 'the bandwidth is whole kilobits');
    });

    test('the lease renews a minute early, never in the past', () {
      expect(NiconicoPlayParser.lease(now: _now), isNull);
      final later = _now.add(const Duration(hours: 2));
      expect(
        NiconicoPlayParser.lease(now: _now, expiresAt: later)?.refreshAt,
        later.subtract(const Duration(minutes: 1)),
      );
      expect(NiconicoPlayParser.lease(now: _now, expiresAt: later)?.expiresAt, later);
      final dying = _now.add(const Duration(seconds: 30));
      expect(
        NiconicoPlayParser.lease(now: _now, expiresAt: dying)?.refreshAt,
        dying,
        reason: 'a lease already inside its lead is renewed at its end, not before now',
      );
    });
  });

  group('the HTTP date', () {
    test('RFC 1123 in GMT, and nothing else', () {
      expect(NiconicoPlayParser.parseHttpDate('Mon, 28 Sep 2026 18:41:00 GMT'), DateTime.utc(2026, 9, 28, 18, 41));
      expect(NiconicoPlayParser.parseHttpDate('  Sun, 01 Mar 2026 00:00:00 GMT  '), DateTime.utc(2026, 3));
      expect(NiconicoPlayParser.parseHttpDate('Fri, 13 Feb 2026 00:00:00 GMT'), DateTime.utc(2026, 2, 13));
      expect(NiconicoPlayParser.parseHttpDate('Mon, 30 Feb 2026 00:00:00 GMT'), isNull, reason: 'the 30th of February');
      expect(NiconicoPlayParser.parseHttpDate('Mon, 31 Apr 2026 00:00:00 GMT'), isNull);
      expect(
        NiconicoPlayParser.parseHttpDate('Mon, 1 Sep 2026 00:00:00 GMT'),
        isNull,
        reason: 'the day needs two digits',
      );
      expect(NiconicoPlayParser.parseHttpDate('Mon, 01 Sep 2026 24:00:00 GMT'), isNull);
      expect(NiconicoPlayParser.parseHttpDate('Mon, 01 Sep 2026 00:61:00 GMT'), isNull);
      expect(NiconicoPlayParser.parseHttpDate('Mon, 01 Sep 2026 00:00:00 UTC'), isNull);
      expect(NiconicoPlayParser.parseHttpDate('Xmon, 01 Sep 2026 00:00:00 GMT'), isNull);
      expect(NiconicoPlayParser.parseHttpDate('2026-09-28T18:41:00Z'), isNull);
    });

    test('the weekday word is not checked against the date', () {
      expect(
        NiconicoPlayParser.parseHttpDate('Tue, 28 Sep 2026 18:41:00 GMT'),
        DateTime.utc(2026, 9, 28, 18, 41),
        reason: '28 September 2026 is a Monday, and the gate only reads the shape',
      );
    });
  });
}
