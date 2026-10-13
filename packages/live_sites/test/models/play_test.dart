import 'package:live_sites/live_sites.dart';
import 'package:test/test.dart';

void main() {
  group('inferStreamFormat', () {
    test('maps suffixes', () {
      expect(inferStreamFormat('https://cdn.example.com/live/abc.m3u8'), LiveStreamFormat.hls);
      expect(inferStreamFormat('https://cdn.example.com/live/abc.flv'), LiveStreamFormat.flv);
      expect(inferStreamFormat('https://cdn.example.com/live/abc.mpd'), LiveStreamFormat.dash);
      expect(inferStreamFormat('https://cdn.example.com/live/abc.ts'), LiveStreamFormat.mpegts);
      expect(inferStreamFormat('https://cdn.example.com/vod/abc.mp4'), LiveStreamFormat.mp4);
    });

    test('is case-insensitive and ignores query strings', () {
      expect(inferStreamFormat('https://cdn.example.com/LIVE/ABC.M3U8?token=x'), LiveStreamFormat.hls);
    });

    test('maps schemes', () {
      expect(inferStreamFormat('udp://@239.1.1.1:1234'), LiveStreamFormat.udp);
      expect(inferStreamFormat('rtp://239.1.1.1:1234'), LiveStreamFormat.rtp);
      expect(inferStreamFormat('rtsp://cam.example.com/stream'), LiveStreamFormat.rtsp);
      expect(inferStreamFormat('rtmp://push.example.com/live/key'), LiveStreamFormat.rtmp);
      expect(inferStreamFormat('rtmps://push.example.com/live/key'), LiveStreamFormat.rtmp);
    });

    test('maps udpxy relay paths to mpegts', () {
      expect(inferStreamFormat('http://proxy.example.com/udp/239.1.1.1:1234'), LiveStreamFormat.mpegts);
      expect(inferStreamFormat('http://proxy.example.com/rtp/239.1.1.1:1234'), LiveStreamFormat.mpegts);
    });

    test('returns null when the URL says nothing (never fabricates other)', () {
      expect(inferStreamFormat('https://cdn.example.com/live/123'), isNull);
      expect(inferStreamFormat(''), isNull);
    });
  });
}
