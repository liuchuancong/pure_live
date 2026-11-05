import 'dart:convert';

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_play_parser.dart';
import 'package:test/test.dart';

/// The signed master the channel answer points at.
final Uri _master = Uri.https('ab12cd.live-video.net', '/v2/master.m3u8', {'token': 'head.payload.sig'});

/// A master with named video renditions, tiers of the same height, and three
/// variants that must not survive.
const String _playlist = '''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="high",NAME="1080p60",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=6000000,AVERAGE-BANDWIDTH=5500000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.640028,mp4a.40.2",VIDEO="high"
1080/playlist.m3u8?sig=a
#EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1280x720,FRAME-RATE=60.000,CODECS="avc1.640028"
720.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=1280x720,CODECS="hvc1.1.6.L93.90"
720_low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=854x480
http://plain.ivs.video/nope.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=0x0
broken.m3u8
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="English",URI="audio.m3u8"
''';

List<KickVariant> _variants(String body, {Uri? master, int status = 200}) =>
    KickPlayParser.variants(body, master: master ?? _master, status: status);

/// A JWT-shaped `?token=` whose payload says [exp].
Uri _tokened(Object? exp) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': exp}))).replaceAll('=', '');
  return Uri.https('ab12cd.live-video.net', '/v2/master.m3u8', {'token': 'head.$payload.sig'});
}

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
  group('the master playlist', () {
    test('a refused or gone master is the broadcast ending, not the channel', () {
      expect(
        {
          for (final status in [200, 204, 302, 401, 403, 404, 429, 500])
            status: _kindOf(() => _variants(_playlist, status: status)),
        },
        {
          200: null,
          204: null,
          302: KickFailureKind.apiChanged,
          401: KickFailureKind.riskControl,
          403: KickFailureKind.streamUnavailable,
          404: KickFailureKind.streamUnavailable,
          429: KickFailureKind.rateLimited,
          500: KickFailureKind.network,
        },
        reason: 'IVS answers 403 when the token dies and 404 when the broadcast ended',
      );
      expect(_failure(() => _variants(_playlist, status: 403)).message, 'master playlist: HTTP 403');
      expect(
        _failure(() => _variants(_playlist, status: 418)).message,
        startsWith('master playlist: HTTP 418 (#EXTM3U '),
        reason: 'an unexplained status writes the body snippet, whitespace collapsed',
      );
      expect(_failure(() => _variants('x' * (KickPlayParser.responseLimit + 1))).message, 'master playlist: too large');
    });

    test('the header must be the first line, and no variant may lack its URL', () {
      expect(_failure(() => _variants('no header')).message, contains('master playlist: not a playlist'));
      expect(_failure(() => _variants('#EXTM3U extra\n')).message, contains('not a playlist'));
      const doubled =
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=2,RESOLUTION=640x360\na.m3u8\n';
      expect(_failure(() => _variants(doubled)).message, 'master playlist: a variant without a URL');
      const trailing = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\n';
      expect(_failure(() => _variants(trailing)).message, 'master playlist: a variant without a URL');
      const withComment =
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\n'
          '#EXT-X-KEY:METHOD=NONE\na.m3u8\n';
      expect(_variants(withComment), hasLength(1), reason: 'a comment between the tag and its URL is allowed');
      expect(
        _failure(() => _variants('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nseg.ts\n')).message,
        startsWith('master playlist: no variant'),
        reason: 'a media playlist is a valid playlist with nothing to choose',
      );
    });

    test('the variants, best first, named as the master names them', () {
      final variants = _variants(_playlist);
      expect(
        [for (final variant in variants) (variant.name, variant.height, variant.bandwidth)],
        [('1080p60', 1080, 6000000), ('720p60', 720, 4000000), ('720p', 720, 500000)],
        reason: 'the height outweighs any bandwidth, and a tier without a frame rate is its own name',
      );
      expect(variants.map((variant) => variant.codec), [
        LiveStreamCodec.avc,
        LiveStreamCodec.avc,
        LiveStreamCodec.hevc,
      ]);
      expect(variants.first.width, 1920);
      expect(variants.first.frameRate, 60);
      expect(variants[1].frameRate, 60);
      expect(variants.last.frameRate, 0);
      expect(variants.first.url, 'https://ab12cd.live-video.net/v2/1080/playlist.m3u8?sig=a');
      expect(variants.last.url, 'https://ab12cd.live-video.net/v2/720_low.m3u8');
      expect(variants.first.url.contains('token'), isFalse, reason: 'a variant never inherits the master token');
    });

    test('one name keeps the better bandwidth, whichever line came first', () {
      final up = _variants(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720\na.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720\nb.m3u8\n',
      );
      expect(up, hasLength(1));
      expect(
        (up.single.name, up.single.bandwidth, up.single.url),
        ('720p', 2000000, 'https://ab12cd.live-video.net/v2/b.m3u8'),
        reason: 'the richer line replaces the thinner one',
      );
      final down = _variants(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720\na.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720\nb.m3u8\n',
      );
      expect(
        (down.single.bandwidth, down.single.url),
        (3000000, 'https://ab12cd.live-video.net/v2/a.m3u8'),
        reason: 'an equal name with less bandwidth is left out',
      );
    });

    test('a master with nothing playable says so, and the host is not re-checked', () {
      expect(
        _failure(
          () => _variants(
            '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\n'
            'http://ab12cd.live-video.net/a.m3u8\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=1\nno_resolution.m3u8\n',
          ),
        ).message,
        startsWith('master playlist: no variant'),
        reason: 'plain HTTP cannot be played, and a variant without a resolution has no geometry',
      );
      expect(
        _variants(
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\n'
          'https://elsewhere.example.test/a.m3u8\n',
        ),
        hasLength(1),
        reason: 'the channel answer already gated the IVS host, so the parser does not look again',
      );
    });
  });

  group('qualities, the pick and the line', () {
    test('the rendition name is both the label and the id', () {
      final qualities = KickPlayParser.qualities(_variants(_playlist));
      expect(
        [for (final quality in qualities) (quality.qualityId, quality.label, quality.platformOrder, quality.codec)],
        [
          ('1080p60', '1080p60', 3, LiveStreamCodec.avc),
          ('720p60', '720p60', 2, LiveStreamCodec.avc),
          ('720p', '720p', 1, LiveStreamCodec.hevc),
        ],
        reason: 'a re-read master names the same qualities, so a saved choice survives',
      );
      expect(KickPlayParser.qualities(const []), isEmpty);
    });

    test('the pick is the named tier, or the best, or nothing', () {
      final variants = _variants(_playlist);
      expect(KickPlayParser.pick(variants, '720p')?.height, 720);
      expect(KickPlayParser.pick(variants, ' 720p ')?.bandwidth, 500000);
      expect(KickPlayParser.pick(variants, '480p')?.name, '1080p60');
      expect(KickPlayParser.pick(variants, '480p', fallback: false), isNull);
      expect(KickPlayParser.pick(variants, null)?.name, '1080p60');
      expect(KickPlayParser.pick(variants, '  ')?.name, '1080p60');
      expect(KickPlayParser.pick(const [], '720p'), isNull);
    });

    test('the line carries the media headers, the master host and the geometry', () {
      final expires = DateTime.utc(2026, 10, 1, 12);
      final line = KickPlayParser.lines(
        _variants(_playlist).first,
        slug: 'Xqc',
        master: _master,
        expiresAt: expires,
        now: expires.subtract(const Duration(hours: 2)),
      ).single;
      expect(line.url, 'https://ab12cd.live-video.net/v2/1080/playlist.m3u8?sig=a');
      expect(line.format, LiveStreamFormat.hls);
      expect(line.formatSource, LivePlayFormatSource.declared);
      expect(line.lineLabel, 'ab12cd.live-video.net');
      expect(line.codec, LiveStreamCodec.avc);
      expect(line.headers.toMap(), KickEndpoints.mediaHeaders('Xqc'));
      expect(line.headers.toMap()['referer'], '${KickEndpoints.roomPageUrl('xqc')}/');
      expect(line.geometry.width, 1920);
      expect(line.geometry.height, 1080);
      expect(line.geometry.frameRate, 60);
      expect(line.geometry.bitrateKbps, 6000);
      expect(line.lease?.expiresAt, expires);
      expect(line.lease?.refreshAt, expires.subtract(const Duration(minutes: 1)));
    });

    test('a thin frame rate and a sub-kilobit bandwidth write nothing', () {
      final line = KickPlayParser.lines(
        (
          name: 'x',
          width: 0,
          height: 0,
          frameRate: 0.5,
          bandwidth: 999,
          codec: null,
          url: 'https://ab12cd.live-video.net/v2/x.m3u8',
        ),
        slug: 'a',
        master: _master,
        now: DateTime.utc(2026),
      ).single;
      expect(line.geometry.frameRate, isNull);
      expect(line.geometry.bitrateKbps, 0);
      expect(line.lease, isNull, reason: 'no expiry named means no lease');
      expect(line.headers.toMap().containsKey('cookie'), isFalse);
    });

    test('the lease is a minute early and never in the past', () {
      final now = DateTime.utc(2026, 10, 1, 12);
      expect(KickPlayParser.lease(now: now), isNull);
      final later = now.add(const Duration(hours: 1));
      expect(KickPlayParser.lease(now: now, expiresAt: later)?.refreshAt, later.subtract(const Duration(minutes: 1)));
      final dying = now.add(const Duration(seconds: 30));
      expect(KickPlayParser.lease(now: now, expiresAt: dying)?.refreshAt, dying);
      expect(KickPlayParser.lease(now: now, expiresAt: dying)?.expiresAt, dying);
    });
  });

  group('the playback token', () {
    test("the expiry is the JWT payload's exp", () {
      final token = _tokened(1760000000);
      expect(KickPlayParser.tokenExpiry(token), DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000, isUtc: true));
      expect(KickPlayParser.tokenExpiry(_master), isNull, reason: 'not three parts, not a JWT');
      expect(KickPlayParser.tokenExpiry(_tokened(0)), isNull);
      expect(KickPlayParser.tokenExpiry(_tokened(-5)), isNull);
      expect(KickPlayParser.tokenExpiry(_tokened(8640000001)), isNull, reason: 'that is milliseconds, not seconds');
      expect(KickPlayParser.tokenExpiry(Uri.https('a.live-video.net', '/m.m3u8')), isNull);
      expect(
        KickPlayParser.tokenExpiry(Uri.https('a.live-video.net', '/m.m3u8', {'token': 'head.!!!not base64!!!.sig'})),
        isNull,
      );
      final list = base64Url.encode(utf8.encode('[1,2]')).replaceAll('=', '');
      expect(
        KickPlayParser.tokenExpiry(Uri.https('a.live-video.net', '/m.m3u8', {'token': 'head.$list.sig'})),
        isNull,
        reason: 'a payload that is not an object names no expiry',
      );
      final text = base64Url.encode(utf8.encode('"hello"')).replaceAll('=', '');
      expect(KickPlayParser.tokenExpiry(Uri.https('a.live-video.net', '/m.m3u8', {'token': 'head.$text.sig'})), isNull);
      final broken = base64Url.encode(utf8.encode('{not json')).replaceAll('=', '');
      expect(
        KickPlayParser.tokenExpiry(Uri.https('a.live-video.net', '/m.m3u8', {'token': 'head.$broken.sig'})),
        isNull,
      );
      final text2 = base64Url.encode(utf8.encode(jsonEncode({'exp': '1760000000'}))).replaceAll('=', '');
      expect(
        KickPlayParser.tokenExpiry(Uri.https('a.live-video.net', '/m.m3u8', {'token': 'head.$text2.sig'})),
        isNotNull,
        reason: 'the site writes numbers as strings even inside a token',
      );
    });

    test('the token expiry drives the lines of a real master', () {
      final token = _tokened(1760000000);
      final variants = _variants(_playlist, master: token);
      final line = KickPlayParser.lines(
        variants.first,
        slug: 'a',
        master: token,
        expiresAt: KickPlayParser.tokenExpiry(token),
        now: DateTime.utc(2026, 10),
      ).single;
      expect(line.lease?.expiresAt, DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000, isUtc: true));
      expect(line.url, contains('sig=a'), reason: 'the variant keeps its own query');
    });

    test('videoCodec reads the CODECS list', () {
      expect(KickPlayParser.videoCodec('avc3.640033,mp4a.40.2'), LiveStreamCodec.avc);
      expect(KickPlayParser.videoCodec('hev1.1.6.L93.90'), LiveStreamCodec.hevc);
      expect(KickPlayParser.videoCodec('av01.0.09M.08'), LiveStreamCodec.av1);
      expect(KickPlayParser.videoCodec('vp9.0.0M.10'), LiveStreamCodec.vp9);
      expect(KickPlayParser.videoCodec('mp4a.40.2'), isNull);
      expect(KickPlayParser.videoCodec(null), isNull);
    });
  });
}
