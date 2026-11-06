import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_play_parser.dart';
import 'package:test/test.dart';

/// An HLS master variant of [height] at [fps], declared [codec].
YoutubeVariant _variant({int? height, double fps = 0, LiveStreamCodec? codec = LiveStreamCodec.avc}) => (
  url: 'https://a.googlevideo.com/videoplayback/v.m3u8',
  width: null,
  height: height,
  fps: fps,
  codec: codec,
  bandwidth: null,
);

/// A progressive `formats[]` entry of [height].
Map<String, dynamic> _format({required String itag, int? height, String? label, double? fps, String? mime}) => {
  'itag': itag,
  'height': ?height,
  'qualityLabel': ?label,
  'fps': ?fps,
  'mimeType': ?mime,
};

void main() {
  group('the quality labels', () {
    test('a quality names its codec and its protocol', () {
      final qualities = YoutubePlayParser.qualities(
        variants: [_variant(height: 1080), _variant(height: 720, codec: null)],
        progressive: [_format(itag: '18', height: 360, label: '360p', mime: 'video/mp4; codecs="avc1.640028"')],
        dashManifestUrl: 'https://manifest.googlevideo.com/api/manifest/dash/x',
      );
      expect(qualities.map((quality) => quality.label), [
        '1080p · H264 · HLS',
        '720p · HLS',
        '360p · H264 · HTTP',
        'DASH 自动 · DASH',
      ]);
      expect(qualities.first.platformOrder, 4);
      expect(qualities.last.platformOrder, 1);
    });

    test('the automatic sources carry their protocol alone', () {
      final qualities = YoutubePlayParser.qualities(
        variants: const [],
        hlsManifestUrl: 'https://manifest.googlevideo.com/api/manifest/hls_playlist/x',
        dashManifestUrl: 'https://manifest.googlevideo.com/api/manifest/dash/x',
      );
      expect(qualities.map((quality) => quality.label), ['HLS 自动 · HLS', 'DASH 自动 · DASH']);
    });
  });

  group('the ordering', () {
    test('height ranks before the protocol', () {
      final qualities = YoutubePlayParser.qualities(
        variants: [_variant(height: 720)],
        progressive: [
          _format(itag: '137', height: 1080, label: '1080p60', fps: 60, mime: 'video/mp4; codecs="avc1.640028"'),
        ],
      );
      expect(qualities.map((quality) => quality.label), ['1080p60 · H264 · HTTP', '720p · H264 · HLS']);
    });

    test('one height ranks HLS above progressive above DASH', () {
      final qualities = YoutubePlayParser.qualities(
        variants: [_variant(height: 720, fps: 60)],
        progressive: [
          _format(itag: '22', height: 720, label: '720p', fps: 30, mime: 'video/mp4; codecs="avc1.640028"'),
        ],
        dashManifestUrl: 'https://manifest.googlevideo.com/api/manifest/dash/x',
      );
      expect(qualities.map((quality) => quality.label), ['720p · H264 · HLS', '720p · H264 · HTTP', 'DASH 自动 · DASH']);
    });
  });
}
