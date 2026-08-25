import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/twitch/twitch_site.dart';

void main() {
  test('Twitch pairs each variant URI with its own stream attributes', () {
    const playlist = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=8200000,RESOLUTION=1920x1080,FRAME-RATE=60.000,VIDEO="chunked",CODECS="avc1.64002A,mp4a.40.2"
https://cdn.test/source/index.m3u8?token=a
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,FRAME-RATE=30.000,VIDEO="720p30"
720/index.m3u8
# unrelated metadata must not shift the BANDWIDTH/URL pairing
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio"
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=640x360,FRAME-RATE=30.000,VIDEO="360p30"
360/index.m3u8
''';

    final qualities = TwitchSite.parseMasterPlaylist(
      playlist,
      masterUri: Uri.parse('https://usher.ttvnw.net/api/channel/hls/demo.m3u8'),
    );

    expect(qualities.map((quality) => quality.quality), ['1080p60 (Source)', '720p', '360p']);
    expect(qualities.map((quality) => quality.sort), [8200000, 3000000, 900000]);
    expect(qualities[1].data, ['https://usher.ttvnw.net/api/channel/hls/720/index.m3u8']);
    expect(qualities.map((quality) => quality.selectionId).toSet(), hasLength(3));
  });
}
