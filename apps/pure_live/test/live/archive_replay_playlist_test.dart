import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/archive/archive_replay_download.dart';

/// The m3u8 reader the archive replay download runs on: master and media
/// playlists, relative segment addresses, encryption and duration reads.
void main() {
  group('a media playlist', () {
    const base = 'https://cdn.example.com/replay/1080p.m3u8';
    late ArchiveReplayPlaylist playlist;

    setUp(() {
      playlist = ArchiveReplayPlaylist.parse(
        '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:9.6,
seg-0.ts
#EXTINF:10.0,
seg-1.ts
#EXTINF:4.2,
seg-2.ts
''',
        Uri.parse(base),
      );
    });

    test('is not a master playlist', () {
      expect(playlist.isMaster, isFalse);
      expect(playlist.variant, isNull);
    });

    test('lists its segments resolved against the document address', () {
      expect(playlist.segments, hasLength(3));
      expect(playlist.segments[0], Uri.parse('https://cdn.example.com/replay/seg-0.ts'));
      expect(playlist.segments[2], Uri.parse('https://cdn.example.com/replay/seg-2.ts'));
    });

    test('sums the EXTINF seconds', () {
      expect(playlist.totalSeconds, closeTo(23.8, 0.001));
    });

    test('reads plain as plain', () {
      expect(playlist.encrypted, isFalse);
    });
  });

  test('a master playlist answers with its highest-bandwidth variant alone', () {
    final playlist = ArchiveReplayPlaylist.parse(
      '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=1280x720
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=4128000,RESOLUTION=1920x1080
high.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2560000
mid.m3u8
''',
      Uri.parse('https://cdn.example.com/replay/master.m3u8'),
    );
    expect(playlist.isMaster, isTrue);
    expect(playlist.variant, Uri.parse('https://cdn.example.com/replay/high.m3u8'));
    expect(playlist.segments, isEmpty);
  });

  test('an encryption key the playlist asks for is reported, not honoured', () {
    final playlist = ArchiveReplayPlaylist.parse(
      '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.key",IV=0x1
#EXTINF:10.0,
seg-0.ts
''',
      Uri.parse('https://cdn.example.com/replay/live.m3u8'),
    );
    expect(playlist.encrypted, isTrue);
    // The segments are still listed: the caller decides what to do.
    expect(playlist.segments, hasLength(1));
  });

  test('a METHOD=NONE key line stays plain', () {
    final playlist = ArchiveReplayPlaylist.parse(
      '''
#EXTM3U
#EXT-X-KEY:METHOD=NONE
#EXTINF:10.0,
seg-0.ts
''',
      Uri.parse('https://cdn.example.com/replay/live.m3u8'),
    );
    expect(playlist.encrypted, isFalse);
  });

  test('segment addresses next to sub-playlist paths resolve in place', () {
    final playlist = ArchiveReplayPlaylist.parse(
      '''
#EXTINF:10.0,
../other/take/seg-0.ts
''',
      Uri.parse('https://cdn.example.com/replay/2024/1080p.m3u8'),
    );
    // `../` climbs out of `2024/` first, URI semantics as everywhere else.
    expect(playlist.segments.single, Uri.parse('https://cdn.example.com/replay/other/take/seg-0.ts'));
  });

  test('an fMP4 playlist is reported as a shape the join cannot rebuild', () {
    final playlist = ArchiveReplayPlaylist.parse(
      '''
#EXTM3U
#EXT-X-MAP:URI="init.mp4"
#EXTINF:6.0,
seg-0.m4s
#EXTINF:6.0,
seg-1.m4s
''',
      Uri.parse('https://cdn.example.com/replay/1080p.m3u8'),
    );
    // Without the initialisation segment the media segments open nowhere.
    expect(playlist.unsupported, isTrue);
    expect(playlist.encrypted, isFalse);
  });

  test('a byte-range playlist is reported the same way', () {
    final playlist = ArchiveReplayPlaylist.parse(
      '''
#EXTM3U
#EXTINF:10.0,
#EXT-X-BYTERANGE:1000@0
all.ts
#EXTINF:10.0,
#EXT-X-BYTERANGE:1000@1000
all.ts
''',
      Uri.parse('https://cdn.example.com/replay/1080p.m3u8'),
    );
    // Every line names the same file; fetching each whole would write it twice.
    expect(playlist.unsupported, isTrue);
  });

  test('a plain transport-stream playlist is a shape the join can rebuild', () {
    final playlist = ArchiveReplayPlaylist.parse(
      '''
#EXTM3U
#EXTINF:10.0,
seg-0.ts
''',
      Uri.parse('https://cdn.example.com/replay/1080p.m3u8'),
    );
    expect(playlist.unsupported, isFalse);
  });

  test('garbage reads as an empty plain playlist, not a crash', () {
    final playlist = ArchiveReplayPlaylist.parse('', Uri.parse('https://cdn.example.com/x.m3u8'));
    expect(playlist.isMaster, isFalse);
    expect(playlist.segments, isEmpty);
    expect(playlist.encrypted, isFalse);
    expect(playlist.totalSeconds, 0);
  });
}
