import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_play_parser.dart';
import 'package:test/test.dart';

/// The master usher answered with.
final Uri _master = Uri.parse('https://stream-abc456.doujinx.twitch.tv/4242-abc-chunked/index-dvr.m3u8?token=t');

/// A master that lists every shape Twitch answers with.
const String _playlist = '''
#EXTM3U
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60 (Source)",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,FRAME-RATE=59.94,CODECS="avc1.64001F,mp4a.40.2",VIDEO="chunked"
index-dvr.m3u8?sig=1
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="720p30",NAME="720p",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1280x720,FRAME-RATE=30.000,CODECS="avc1.64001F",VIDEO="720p30"
720p30/index-dvr.m3u8?sig=2
#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=852x480,FRAME-RATE=30.000,CODECS="hvc1.1.6.L93.90",VIDEO="480p30"
https://stream-other.doujinx.twitch.tv/x/480p.m3u8?sig=3
#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=420x140,FRAME-RATE=30.000,VIDEO="160p"
file:/not/a/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=0,VIDEO="audio"
audio-only.m3u8?sig=5
''';

List<TwitchVariantGroup> _groups([String playlist = _playlist, Uri? master]) =>
    TwitchPlayParser.groups(playlist, master: master ?? _master);

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on TwitchFailure catch (failure) {
    return failure.kind;
  }
}

TwitchFailure _failure(void Function() read) {
  try {
    read();
  } on TwitchFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the usher answer', () {
    test('a 2xx passes whatever it carries', () {
      expect(_kindOf(() => TwitchPlayParser.usherStatus(200, '[]')), isNull);
      expect(_kindOf(() => TwitchPlayParser.usherStatus(204, 'not even json')), isNull);
    });

    test('the transport statuses come before the body', () {
      expect(_kindOf(() => TwitchPlayParser.usherStatus(503, '{}')), TwitchFailureKind.network);
      expect(_failure(() => TwitchPlayParser.usherStatus(503, '{}')).message, 'usher: HTTP 503');
      expect(_kindOf(() => TwitchPlayParser.usherStatus(429, '{}')), TwitchFailureKind.rateLimited);
    });

    test('a 404 is a channel that is not broadcasting', () {
      final failure = _failure(() => TwitchPlayParser.usherStatus(404, '[{"error_code":"404","error":"Not Found"}]'));
      expect(failure.kind, TwitchFailureKind.streamUnavailable);
      expect(failure.message, 'usher: HTTP 404 404 Not Found');
    });

    test('a 403 says whether the reason is geography or an account', () {
      expect(
        _failure(() => TwitchPlayParser.usherStatus(403, '[{"error_code":"403","error":"geo blocked"}]')).kind,
        TwitchFailureKind.regionBlocked,
      );
      expect(
        _failure(() => TwitchPlayParser.usherStatus(403, '[{"error_code":"GEO_RESTRICTED","error":"no"}]')).kind,
        TwitchFailureKind.regionBlocked,
        reason: 'the code counts as much as the message',
      );
      expect(
        _failure(() => TwitchPlayParser.usherStatus(403, '[{"error_code":"403","error":"login required"}]')).kind,
        TwitchFailureKind.needsLogin,
      );
      expect(
        _failure(() => TwitchPlayParser.usherStatus(403, '[]')).kind,
        TwitchFailureKind.needsLogin,
        reason: 'a 403 with nothing to say still needs an account',
      );
    });

    test('the integrity gate wins over the status', () {
      expect(
        _failure(() => TwitchPlayParser.usherStatus(400, '{"extensions":{"challenge":{"a":1}}}')).kind,
        TwitchFailureKind.riskControl,
      );
      expect(
        _failure(
          () => TwitchPlayParser.usherStatus(
            401,
            '[{"error_code":"401","error":"Failed To Load: failed integrity check"}]',
          ),
        ).kind,
        TwitchFailureKind.riskControl,
      );
      expect(
        _failure(() => TwitchPlayParser.usherStatus(418, '[{"error_code":"x","error":"Integrity Token Required"}]'))
            .kind,
        TwitchFailureKind.riskControl,
      );
    });

    test('any other status is a changed answer', () {
      expect(
        _failure(() => TwitchPlayParser.usherStatus(400, 'garbage')).message,
        'usher: HTTP 400',
        reason: 'a body that is no JSON has no code to name',
      );
      expect(
        _failure(() => TwitchPlayParser.usherStatus(422, '[{"error_code":"50000","error":"internal"}]')).message,
        'usher: HTTP 422 50000 internal',
      );
      expect(_kindOf(() => TwitchPlayParser.usherStatus(418, '[]')), TwitchFailureKind.apiChanged);
    });
  });

  group('the master playlist', () {
    test('one group per height, frame rate, bandwidth and video group, source first', () {
      final groups = _groups();
      expect(
        [for (final group in groups) (group.label, group.qualityId, group.urls.length)],
        [
          ('1080p60（原画）', '1080:60:6000000:chunked', 1),
          ('720p', '720:30:4000000:720p30', 1),
          ('480p', '480:30:1500000:480p30', 1),
          ('自动', '0:0:0:audio', 1),
        ],
        reason: 'a frame rate under 45 is not named, and 59.94 rounds to 60',
      );
      expect(groups.first.sort, 1 << 30, reason: "the broadcaster's own stream outranks any bandwidth");
      expect(groups[2].sort, 1500000);
      expect(groups.first.codec, LiveStreamCodec.avc);
      expect(groups[2].codec, LiveStreamCodec.hevc);
      expect(groups.first.bitrateKbps, 6000);
      expect(groups.last.bitrateKbps, isNull, reason: 'a zero bandwidth names no bitrate');
      expect(groups.last.height, 0);
      expect(groups.first.urls.single, 'https://stream-abc456.doujinx.twitch.tv/4242-abc-chunked/index-dvr.m3u8?sig=1');
      expect(groups.first.urls.single.contains('token'), isFalse, reason: 'no part of the master query is copied');
      expect(groups[2].urls.single, 'https://stream-other.doujinx.twitch.tv/x/480p.m3u8?sig=3');
    });

    test('a variant URI that is no stream is skipped', () {
      expect(_groups().any((group) => group.urls.any((url) => url.startsWith('file:'))), isFalse);
    });

    test('a group is the merge of every host that serves it', () {
      final groups = _groups(
        '#EXTM3U\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,FRAME-RATE=30,VIDEO="720p30"\n'
        'https://h1.doujinx.twitch.tv/a.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,FRAME-RATE=30,VIDEO="720p30"\n'
        'https://h2.doujinx.twitch.tv/a.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,FRAME-RATE=30,VIDEO="720p30"\n'
        'https://h1.doujinx.twitch.tv/a.m3u8\n',
      );
      expect(groups, hasLength(1));
      expect(groups.single.urls, [
        'https://h1.doujinx.twitch.tv/a.m3u8',
        'https://h2.doujinx.twitch.tv/a.m3u8',
      ], reason: 'a repeated URL is not a second line');
      expect(TwitchPlayParser.lines(groups.single, roomId: 'xqc'), hasLength(2));
    });

    test('a body that is not a playlist, and a playlist with nothing to play', () {
      expect(_failure(() => _groups('no header')).message, contains('usher: not a playlist'));
      expect(
        _failure(() => _groups('  #EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nseg.ts\n')).message,
        'usher: no variant',
        reason: 'a media playlist is a valid playlist with no variant',
      );
      expect(
        _failure(() => _groups('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\nfile:/x.m3u8\n')).message,
        'usher: no variant',
      );
    });

    test('the group id ignores the case of the video group', () {
      final groups = _groups(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360,VIDEO="Chunked"\nx.m3u8\n',
      );
      expect(groups.single.qualityId, '360:0:1000000:chunked');
      expect(groups.single.label, '360p（原画）');
    });
  });

  group('the qualities and the lines', () {
    test('the label is also the id Twitch stores', () {
      final qualities = TwitchPlayParser.qualities(_groups());
      expect(
        [for (final quality in qualities) (quality.label, quality.qualityId, quality.platformOrder)],
        [
          ('1080p60（原画）', '1080:60:6000000:chunked', 4),
          ('720p', '720:30:4000000:720p30', 3),
          ('480p', '480:30:1500000:480p30', 2),
          ('自动', '0:0:0:audio', 1),
        ],
      );
      expect(qualities.first.codec, LiveStreamCodec.avc);
      expect(TwitchPlayParser.qualities(const []), isEmpty);
    });

    test('one line per host, with the media headers and the geometry', () {
      final groups = _groups();
      final lines = TwitchPlayParser.lines(groups.first, roomId: ' Xqc ');
      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line.format, LiveStreamFormat.hls);
      expect(line.formatSource, LivePlayFormatSource.declared);
      expect(line.lineLabel, 'stream-abc456.doujinx.twitch.tv');
      expect(line.codec, LiveStreamCodec.avc);
      expect(line.lease, isNull, reason: 'these URLs outlive the access token; recovery re-reads the playlist');
      expect(line.headers.toMap(), TwitchPlayParser.mediaHeaders('Xqc'));
      expect(line.headers.toMap()['referer'], TwitchEndpoints.roomPageUrl('Xqc'));
      expect(line.headers.toMap().containsKey('cookie'), isFalse);
      expect(line.geometry.height, 1080);
      expect(line.geometry.frameRate, 60);
      expect(line.geometry.bitrateKbps, 6000);
    });

    test('an audio-only group carries no geometry', () {
      final audio = _groups().last;
      final line = TwitchPlayParser.lines(audio, roomId: 'a').single;
      expect(line.geometry.height, isNull);
      expect(line.geometry.frameRate, isNull);
      expect(line.geometry.bitrateKbps, isNull);
      expect(line.url, 'https://stream-abc456.doujinx.twitch.tv/4242-abc-chunked/audio-only.m3u8?sig=5');
    });

    test('media headers: the channel page as referer, the site when there is none', () {
      expect(TwitchPlayParser.mediaHeaders('').length, 3);
      expect(TwitchPlayParser.mediaHeaders(' Xqc ')['referer'], TwitchEndpoints.roomPageUrl('Xqc'));
      expect(TwitchPlayParser.mediaHeaders(' Xqc ')['referer'], TwitchEndpoints.roomPageUrl('Xqc'));
      expect(TwitchPlayParser.mediaHeaders('a')['user-agent'], TwitchEndpoints.userAgent);
      expect(TwitchPlayParser.mediaHeaders('a')['origin'], TwitchEndpoints.origin);
    });
  });

  group('re-finding a stored quality', () {
    test('the id, then the video group, then the label', () {
      final groups = _groups();
      expect(TwitchPlayParser.sameGroup(groups, '720:30:4000000:720p30')?.label, '720p');
      expect(
        TwitchPlayParser.sameGroup(groups, '720:30:9999999:720p30')?.label,
        '720p',
        reason: 'the bandwidth moved between playlists, the group did not',
      );
      expect(TwitchPlayParser.sameGroup(groups, '720:30:9999999:chunked')?.label, '1080p60（原画）');
      expect(
        TwitchPlayParser.sameGroup(groups, 'nothing'),
        isNull,
        reason: 'an id with no colon names no group, and no label was given',
      );
      expect(TwitchPlayParser.sameGroup(groups, null, label: '720p')?.qualityId, '720:30:4000000:720p30');
      expect(TwitchPlayParser.sameGroup(groups, null), isNull);
      expect(TwitchPlayParser.sameGroup(groups, '999:99:9:x', label: 'no such label'), isNull);
      expect(TwitchPlayParser.sameGroup(const [], '720:30:4000000:720p30'), isNull);
    });

    test('the names a playlist without a resolution falls back to', () {
      expect(TwitchPlayParser.qualityName(6000000, height: 0, frameRate: 0, source: false), '1080P');
      expect(TwitchPlayParser.qualityName(5000000, height: 0, frameRate: 0, source: false), '720P');
      expect(
        TwitchPlayParser.qualityName(2500000, height: 0, frameRate: 0, source: false),
        '480P',
        reason: 'the band edges are strict: 2 500 001 is the first 720P',
      );
      expect(TwitchPlayParser.qualityName(1200000, height: 0, frameRate: 0, source: false), '480P');
      expect(TwitchPlayParser.qualityName(600000, height: 0, frameRate: 0, source: false), '360P');
      expect(TwitchPlayParser.qualityName(500000, height: 0, frameRate: 0, source: false), '自动');
      expect(TwitchPlayParser.qualityName(9000000, height: 0, frameRate: 0, source: true), '原画');
      expect(TwitchPlayParser.qualityName(0, height: 360, frameRate: 44.9, source: false), '360p');
      expect(TwitchPlayParser.qualityName(0, height: 360, frameRate: 45, source: false), '360p45');
      expect(TwitchPlayParser.qualityName(0, height: 720, frameRate: 60, source: true), '720p60（原画）');
    });

    test('videoCodec reads the CODECS list', () {
      expect(TwitchPlayParser.videoCodec('mp4a.40.2,avc3.640033'), LiveStreamCodec.avc);
      expect(TwitchPlayParser.videoCodec('hev1.1.6.L93'), LiveStreamCodec.hevc);
      expect(TwitchPlayParser.videoCodec('av01.0.09M.08'), LiveStreamCodec.av1);
      expect(TwitchPlayParser.videoCodec('vp09.00.10.08'), LiveStreamCodec.vp9);
      expect(TwitchPlayParser.videoCodec('mp4a.40.2'), isNull);
      expect(TwitchPlayParser.videoCodec(''), isNull);
    });
  });
}
