import 'dart:convert';

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_play_parser.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';
import 'package:test/test.dart';

/// When the live detail was answered (the lease is measured from this).
final DateTime _issued = DateTime.utc(2026, 9, 27, 10);

/// A token expiry twelve hours after [_issued].
final int _exp = _issued.millisecondsSinceEpoch ~/ 1000 + 43200;

/// The instant [_exp] names.
final DateTime _expires = DateTime.fromMillisecondsSinceEpoch(_exp * 1000, isUtc: true);

/// The HLS master, tokened as the platform writes it.
final Uri _hlsMaster = Uri.parse(
  'https://livecloudchzzk.akamaized.net/chzzk/clip/123/master.m3u8?hdnts=exp=$_exp~max-bps=0~content_id=abc',
);

/// The low-latency master of the same live.
final Uri _llhlsMaster = Uri.parse(
  'https://livecloudchzzk.akamaized.net/chzzk/clip/123llhls/master.m3u8?hdnts=exp=$_exp~max-bps=0~content_id=abc',
);

String _json(Object? value) => jsonEncode(value);

String _mediaJson(List<Object?> items) => _json({'media': items});

Map<String, Object?> _item(String protocol, String id, Object? path) => {
  'protocol': protocol,
  'mediaId': id,
  'path': path,
};

List<ChzzkVariant> _variants(String playlist, {String id = 'HLS', Uri? master}) =>
    ChzzkPlayParser.variants(playlist, media: ChzzkMedia(id, master ?? _hlsMaster), issuedAt: _issued);

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on ChzzkFailure catch (failure) {
    return failure.kind;
  }
}

ChzzkFailure _failure(void Function() read) {
  try {
    read();
  } on ChzzkFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the media list of a live detail', () {
    test('an absent field is no master at all', () {
      expect(ChzzkPlayParser.media(null), isEmpty);
      expect(ChzzkPlayParser.media(''), isEmpty);
      expect(ChzzkPlayParser.media(_mediaJson(<Object?>[])), isEmpty);
    });

    test('the value must be a JSON string of its own', () {
      expect(
        _failure(() => ChzzkPlayParser.media({'media': <Object?>[]})).message,
        'livePlaybackJson: not a JSON string',
      );
      expect(
        _failure(() => ChzzkPlayParser.media('x' * (ChzzkEndpoints.responseLimit + 1))).message,
        'livePlaybackJson: not a JSON string',
      );
      expect(_failure(() => ChzzkPlayParser.media('not json')).message, 'livePlaybackJson: not JSON');
      expect(_failure(() => ChzzkPlayParser.media('[1,2]')).message, 'livePlaybackJson: expected an object');
      expect(
        _failure(() => ChzzkPlayParser.media(_json({'code': 200}))).message,
        'livePlaybackJson.media: expected a list',
      );
    });

    test('sixteen masters is the most this adapter asks for', () {
      expect(
        _failure(
          () => ChzzkPlayParser.media(
            _mediaJson(List.generate(17, (index) => _item('HLS', 'HLS', 'https://a.akamaized.net/$index.m3u8'))),
          ),
        ).message,
        'livePlaybackJson: 17 media',
      );
      expect(
        ChzzkPlayParser.media(
          _mediaJson(
            List.generate(
              16,
              (index) => _item('HLS', index.isEven ? 'HLS' : 'LLHLS', 'https://a.akamaized.net/$index.m3u8'),
            ),
          ),
        ),
        hasLength(16),
      );
    });

    test('only the HLS and LLHLS items of protocol HLS are masters', () {
      final masters = ChzzkPlayParser.media(
        _mediaJson([
          _item('HLS', 'HLS', 'https://a.akamaized.net/hls/master.m3u8'),
          _item('HLS', 'LLHLS', 'https://a.akamaized.net/llhls/master.m3u8'),
          _item('DASH', 'DASH', 'https://a.akamaized.net/dash/manifest.mpd'),
          _item('HLS', 'TH HLS', 'https://a.akamaized.net/third.m3u8'),
          _item('HLS', 'HLS', 'https://a.akamaized.net/hls/master.m3u8'),
        ]),
      );
      expect(masters.map((item) => item.id), ['HLS', 'LLHLS'], reason: 'a repeated address is one master');
      expect(masters.first.url.toString(), 'https://a.akamaized.net/hls/master.m3u8');
      expect(
        ChzzkPlayParser.media(_mediaJson([_item('DASH', 'DASH', 'https://a.akamaized.net/x.mpd')])),
        isEmpty,
        reason: 'nothing usable and nothing broken is an empty answer, not a changed one',
      );
    });

    test('an unusable item is skipped, and one good master still stands', () {
      final masters = ChzzkPlayParser.media(
        _mediaJson([
          _item('HLS', 'HLS', 'http://a.akamaized.net/plain.m3u8'),
          _item('HLS', '', 'https://a.akamaized.net/no-id.m3u8'),
          _item('', 'HLS', 'https://a.akamaized.net/no-protocol.m3u8'),
          'not an object',
          _item('HLS', 'LLHLS', 'https://a.akamaized.net/good.m3u8'),
        ]),
      );
      expect(masters.map((item) => item.id), ['LLHLS']);
      expect(
        _failure(
          () => ChzzkPlayParser.media(
            _mediaJson([_item('HLS', 'HLS', 7), _item('HLS', 'HLS', 'https://evil.com/a.akamaized.net/x.m3u8')]),
          ),
        ).message,
        'livePlaybackJson: 2 unusable media, no usable master',
      );
    });

    test('the master address gate', () {
      ChzzkMedia? one(Object? path) {
        final masters = ChzzkPlayParser.media(_mediaJson([_item('HLS', 'HLS', path)]));
        return masters.isEmpty ? null : masters.single;
      }

      // One broken item beside a good one: it is dropped, and the live stays playable.
      bool drops(Object? path) {
        final masters = ChzzkPlayParser.media(
          _mediaJson([_item('HLS', 'HLS', path), _item('HLS', 'LLHLS', 'https://a.akamaized.net/good.m3u8')]),
        );
        return masters.length == 1 && masters.single.id == 'LLHLS';
      }

      expect(one('https://a.akamaized.net/x.m3u8'), isNotNull);
      expect(one('https://akamaized.net/x.m3u8'), isNotNull, reason: 'the bare CDN host is allowed');
      expect(one('HTTPS://A.AKAMAIZED.NET/x.m3u8'), isNotNull, reason: 'the host arrives lower-cased');
      expect(one('https://a.akamaized.net/x.m3u8?token=ok'), isNotNull);
      for (final bad in [
        'http://a.akamaized.net/x.m3u8',
        'https://user@a.akamaized.net/x.m3u8',
        'https://a.akamaized.net/x.m3u8#f',
        'https://a.akamaized.net/x m3u8',
        'https://evil.com/a.akamaized.net/x.m3u8',
        'https://a.akamaized.ne/x.m3u8',
        '',
        null,
        7,
        'https://a.akamaized.net/${'x' * ChzzkEndpoints.maxPathLength}',
      ]) {
        expect(drops(bad), isTrue, reason: '$bad');
      }
    });
  });

  group('the master answer', () {
    test('a gone master is the stream being gone, not the room', () {
      expect(_failure(() => ChzzkPlayParser.master('x', what: 'master', status: 404)).message, 'master: HTTP 404');
      expect(
        _kindOf(() => ChzzkPlayParser.master('x', what: 'master', status: 404)),
        ChzzkFailureKind.streamUnavailable,
      );
      expect(
        {
          for (final status in [200, 204, 400, 401, 403, 429, 500, 302])
            status: _kindOf(() => ChzzkPlayParser.master('body', what: 'm', status: status)),
        },
        {
          200: null,
          204: ChzzkFailureKind.network,
          400: ChzzkFailureKind.apiChanged,
          401: ChzzkFailureKind.riskControl,
          403: ChzzkFailureKind.riskControl,
          429: ChzzkFailureKind.rateLimited,
          500: ChzzkFailureKind.network,
          302: ChzzkFailureKind.network,
        },
        reason: 'only 200 is an answer here, and a 404 of a master is not the room being gone',
      );
      expect(
        _failure(() => ChzzkPlayParser.master('x' * (ChzzkEndpoints.responseLimit + 1), what: 'm')).message,
        'm: answer over ${ChzzkEndpoints.responseLimit} characters',
      );
    });
  });

  group('the variants of a master', () {
    final playlist =
        '''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-STREAM-INF:BANDWIDTH=4000000,AVERAGE-BANDWIDTH=3800000,RESOLUTION=1280x720,FRAME-RATE=60.000,CODECS="avc1.640028"
video/720.m3u8?hdntl=exp=$_exp-ak-data1=x
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360,CODECS="mp4a.40.2"
audio/low.m3u8?hdntl=exp=$_exp
#EXT-X-STREAM-INF:BANDWIDTH=900000
audio-only.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=426x240
file:/not/a/stream.m3u8
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="Sound",URI="audio-only.m3u8"
''';

    test('the video variants, resolved against the master', () {
      final variants = _variants(playlist);
      expect(variants, hasLength(2), reason: 'a variant with no resolution is the audio-only track');
      expect(variants.first.mediaId, 'HLS');
      expect(
        variants.first.url,
        'https://livecloudchzzk.akamaized.net/chzzk/clip/123/video/720.m3u8?hdntl=exp=$_exp-ak-data1=x',
      );
      expect(variants.first.height, 720);
      expect(variants.first.frameRate, 60);
      expect(variants.first.bandwidth, 4000000);
      expect(variants.first.codec, LiveStreamCodec.avc);
      expect(variants.last.height, 360);
      expect(variants.last.frameRate, 0, reason: 'a variant naming no frame rate says zero');
      expect(variants.last.codec, isNull, reason: 'an audio CODECS list names no video codec');
      expect(
        variants.first.url.contains('hdnts'),
        isFalse,
        reason: 'a relative variant never inherits the master token',
      );
      expect(variants.first.lease?.expiresAt, _expires);
    });

    test('an absolute variant keeps its own address', () {
      final variants = _variants(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280x720\n'
        'https://other.akamaized.net/keep.m3u8?hdntl=exp=$_exp\n',
      );
      expect(variants.single.url, 'https://other.akamaized.net/keep.m3u8?hdntl=exp=$_exp');
    });

    test('a body that is not a playlist, and a playlist with nothing to play', () {
      expect(_failure(() => _variants('not a playlist')).message, 'HLS master: not a playlist');
      expect(
        _failure(() => _variants('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nseg.ts\n')).message,
        'HLS master: no video variant',
        reason: 'a media playlist is a valid playlist with nothing to choose',
      );
      expect(
        _failure(() => _variants('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=0x0\na.m3u8\n')).message,
        'HLS master: no video variant',
      );
      expect(
        _variants('  #EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\na.m3u8\r\n'),
        hasLength(1),
        reason: 'the header is trimmed, CRLF and leading blanks included',
      );
    });

    test('the LLHLS master names itself, and its token is a path element', () {
      final variants = _variants(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\n'
        '/clip/123llhls/hdntl=exp=$_exp-ak-data1=x/playlist.m3u8\n',
        id: 'LLHLS',
        master: _llhlsMaster,
      );
      expect(variants.single.mediaId, 'LLHLS');
      expect(variants.single.lease?.expiresAt, _expires);
    });
  });

  group('the qualities and the lines', () {
    List<ChzzkVariant> both() => [
      ..._variants(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1280x720,FRAME-RATE=60.000,CODECS="avc1.640028"\n'
        'video/720.m3u8?hdntl=exp=$_exp\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360,CODECS="hvc1.1.6.L93.90"\n'
        'video/360.m3u8?hdntl=exp=$_exp\n',
      ),
      ..._variants(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1280x720,FRAME-RATE=60.000\n'
        'video/720.m3u8?hdntl=exp=$_exp\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=1280x720\n'
        'video/720s.m3u8?hdntl=exp=$_exp\n',
        id: 'LLHLS',
        master: _llhlsMaster,
      ),
    ];

    test('one quality per height and frame-rate tier, best first', () {
      final qualities = ChzzkPlayParser.qualities(both());
      expect(
        [for (final quality in qualities) (quality.qualityId, quality.label, quality.platformOrder, quality.codec)],
        [
          ('720p60', '720p60 · HLS', 3, LiveStreamCodec.avc),
          ('720p', '720p · HLS', 2, null),
          ('360p', '360p · HLS', 1, LiveStreamCodec.hevc),
        ],
        reason: '50 fps or more becomes the 60 tier; the rank is height first, then bandwidth',
      );
      expect(_failure(() => ChzzkPlayParser.qualities(const [])).message, 'no video variant');
    });

    test("the lines of a quality, deduplicated, in the masters' order", () {
      final variants = both();
      final all = ChzzkPlayParser.lines(variants);
      expect(all, hasLength(4), reason: 'each master answers its own address, so nothing is really repeated');
      expect(all.map((line) => line.lineLabel), ['HLS', 'HLS', 'LLHLS', 'LLHLS']);
      expect(all.map((line) => line.format).toSet(), {LiveStreamFormat.hls});
      expect(all.first.formatSource, LivePlayFormatSource.declared);
      expect(all.first.headers.toMap(), ChzzkEndpoints.mediaHeaders);
      expect(all.first.geometry.height, 720);
      expect(all.first.geometry.frameRate, 60);
      expect(all.first.geometry.bitrateKbps, 4000);
      expect(all[2].url, contains('/clip/123llhls/'), reason: 'the LLHLS variant resolves against its own master');
      expect(ChzzkPlayParser.lines(variants, quality: '720p60').map((line) => line.lineLabel), ['HLS', 'LLHLS']);
      expect(ChzzkPlayParser.lines(variants, quality: ''), hasLength(4));
      expect(ChzzkPlayParser.lines(variants, quality: ' 360p '), hasLength(1));
      expect(ChzzkPlayParser.lines(variants, quality: '1080p'), isEmpty);
    });

    test('two masters on one address hand out that line once', () {
      final shared = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\na.m3u8?hdntl=exp=$_exp\n';
      final variants = [..._variants(shared), ..._variants(shared, id: 'LLHLS')];
      expect(variants, hasLength(2));
      expect(ChzzkPlayParser.lines(variants), hasLength(1), reason: 'the same URL is one line');
    });

    test('a variant with no frame rate or bandwidth writes nothing there', () {
      final line = ChzzkPlayParser.lines(
        _variants('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=0,RESOLUTION=640x360\na.m3u8\n'),
      ).single;
      expect(line.geometry.frameRate, isNull);
      expect(line.geometry.bitrateKbps, isNull);
      expect(line.geometry.height, 360);
    });

    test('codecOf reads the CODECS list', () {
      expect(ChzzkPlayParser.codecOf('avc1.640028,mp4a.40.2'), LiveStreamCodec.avc);
      expect(ChzzkPlayParser.codecOf('hvc1.1.6.L93.90'), LiveStreamCodec.hevc);
      expect(ChzzkPlayParser.codecOf('av01.0.09M.08'), LiveStreamCodec.av1);
      expect(ChzzkPlayParser.codecOf('vp09.00.10.08'), LiveStreamCodec.vp9);
      expect(ChzzkPlayParser.codecOf('mp4a.40.2'), isNull);
      expect(ChzzkPlayParser.codecOf(null), isNull);
    });
  });

  group('the Akamai tokens', () {
    test('the master expiry is the hdnts token', () {
      expect(ChzzkPlayParser.masterExpiry(_hlsMaster), _expires);
      expect(ChzzkPlayParser.masterExpiry(Uri.parse('https://a.akamaized.net/m.m3u8?other=1')), isNull);
      expect(
        ChzzkPlayParser.masterExpiry(Uri.parse('https://a.akamaized.net/m.m3u8?hdnts=start~exp=$_exp~x')),
        isNotNull,
        reason: 'the exp is read after a tilde as well as at the start',
      );
      expect(ChzzkPlayParser.masterExpiry(Uri.parse('https://a.akamaized.net/m.m3u8?hdnts=exp=$_exp')), isNotNull);
      expect(
        ChzzkPlayParser.masterExpiry(Uri.parse('https://a.akamaized.net/m.m3u8?hdnts=exp=12345678')),
        isNull,
        reason: 'eight digits is not a Unix seconds token',
      );
      expect(
        ChzzkPlayParser.masterExpiry(Uri.parse('https://a.akamaized.net/m.m3u8?hdnts=%FF')),
        isNull,
        reason: 'an undecodable query is no token',
      );
    });

    test('a variant token wins over the master, and the lead is at most a quarter', () {
      final variant = Uri.parse('https://a.akamaized.net/chzzk/clip/123/video/720.m3u8?hdntl=exp=${_exp + 3600}');
      expect(
        ChzzkPlayParser.lease(variant, master: _hlsMaster, issuedAt: _issued)?.expiresAt,
        DateTime.fromMillisecondsSinceEpoch((_exp + 3600) * 1000, isUtc: true),
      );
      final lease = ChzzkPlayParser.lease(variant, master: _hlsMaster, issuedAt: _issued)!;
      expect(lease.requiresReconnect, isTrue, reason: 'every HLS segment is a new request');
      expect(lease.refreshAt, lease.expiresAt!.subtract(ChzzkEndpoints.leaseLead));
      expect(
        ChzzkPlayParser.lease(
          Uri.parse('https://a.akamaized.net/chzzk/clip/123/video/720.m3u8'),
          master: _hlsMaster,
          issuedAt: _issued,
        )?.expiresAt,
        _expires,
        reason: 'without its own token a variant lives as long as the master',
      );
      final shortExpiry = DateTime.fromMillisecondsSinceEpoch(
        (_issued.millisecondsSinceEpoch ~/ 1000 + 40) * 1000,
        isUtc: true,
      );
      final short = ChzzkPlayParser.lease(
        Uri.parse(
          'https://a.akamaized.net/chzzk/clip/123/video/720.m3u8?hdntl=exp=${_issued.millisecondsSinceEpoch ~/ 1000 + 40}',
        ),
        master: _hlsMaster,
        issuedAt: _issued,
      )!;
      expect(short.expiresAt, shortExpiry);
      expect(
        short.refreshAt,
        shortExpiry.subtract(const Duration(seconds: 10)),
        reason: 'a 40-second token is renewed a quarter of its life before, not the full lead',
      );
      expect(
        ChzzkPlayParser.lease(
          Uri.parse(
            'https://a.akamaized.net/chzzk/clip/123/video/720.m3u8?hdntl=exp=${_issued.millisecondsSinceEpoch ~/ 1000}',
          ),
          master: Uri.parse('https://a.akamaized.net/m.m3u8'),
          issuedAt: _issued,
        ),
        isNull,
        reason: 'a token already dead at issue is no lease',
      );
      expect(
        ChzzkPlayParser.lease(
          Uri.parse('https://a.akamaized.net/chzzk/clip/123/video/720.m3u8'),
          master: Uri.parse('https://a.akamaized.net/m.m3u8'),
          issuedAt: _issued,
        ),
        isNull,
      );
    });

    test('freshness of the lines and of the masters', () {
      final lines = ChzzkPlayParser.lines(
        _variants('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\na.m3u8?hdntl=exp=$_exp\n'),
      );
      final refresh = lines.single.lease!.refreshAt;
      expect(ChzzkPlayParser.linesFresh(lines, refresh.subtract(const Duration(seconds: 1))), isTrue);
      expect(ChzzkPlayParser.linesFresh(lines, refresh), isFalse, reason: 'due is not fresh');
      expect(ChzzkPlayParser.linesFresh(const [], _issued), isTrue);
      expect(
        ChzzkPlayParser.linesFresh([
          LivePlayLine.of(
            url: 'https://a.akamaized.net/x/a.m3u8',
            format: LiveStreamFormat.hls,
            formatSource: LivePlayFormatSource.declared,
          ),
        ], _issued),
        isTrue,
        reason: 'a line with no lease never needs re-resolving',
      );
      expect(ChzzkPlayParser.mastersFresh([ChzzkMedia('HLS', _hlsMaster)], _issued), isTrue);
      expect(
        ChzzkPlayParser.mastersFresh([ChzzkMedia('HLS', _hlsMaster)], _expires.subtract(const Duration(minutes: 5))),
        isFalse,
        reason: 'inside the lead the master must be asked again',
      );
      expect(
        ChzzkPlayParser.mastersFresh([ChzzkMedia('HLS', Uri.parse('https://a.akamaized.net/m.m3u8'))], _issued),
        isTrue,
        reason: 'a master that names no expiry is treated as fresh',
      );
      expect(ChzzkPlayParser.mastersFresh(const [], _issued), isTrue);
    });
  });
}
