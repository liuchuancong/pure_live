import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:test/test.dart';

LivePlayLine _line(String url, {Map<String, String> headers = const {}, DateTime? refreshAt}) => LivePlayLine.of(
  url: url,
  format: LiveStreamFormat.hls,
  formatSource: LivePlayFormatSource.declared,
  headers: headers,
  lease: refreshAt == null ? null : LivePlayLease.of(refreshAt: refreshAt, requiresReconnect: true),
);

void main() {
  group('isSamePlayPlan', () {
    test('the media already loaded is the same plan', () {
      expect(isSamePlayPlan([_line('https://a/master.m3u8')], [_line('https://a/master.m3u8')]), isTrue);
    });

    test('another address is a different plan', () {
      expect(isSamePlayPlan([_line('https://a/master.m3u8')], [_line('https://a/720.m3u8')]), isFalse);
    });

    test('the same address with other headers is a different request', () {
      final loaded = [
        _line('https://a/master.m3u8', headers: {'referer': 'https://a'}),
      ];
      final asked = [
        _line('https://a/master.m3u8', headers: {'referer': 'https://b'}),
      ];

      expect(isSamePlayPlan(loaded, asked), isFalse);
    });

    test('a line added or dropped is a different plan', () {
      expect(
        isSamePlayPlan([_line('https://a/1.m3u8')], [_line('https://a/1.m3u8'), _line('https://a/2.m3u8')]),
        isFalse,
      );
      expect(isSamePlayPlan(const <LivePlayLine>[], [_line('https://a/1.m3u8')]), isFalse);
    });

    test('the order the lines come in counts', () {
      expect(
        isSamePlayPlan(
          [_line('https://a/1.m3u8'), _line('https://a/2.m3u8')],
          [_line('https://a/2.m3u8'), _line('https://a/1.m3u8')],
        ),
        isFalse,
      );
    });

    test('a renewed lease on the same address is the same media', () {
      // The room re-arms the lease timer itself; the stream does not have to
      // be torn down to learn about a new deadline.
      final loaded = [_line('https://a/master.m3u8', refreshAt: DateTime.parse('2026-11-05T10:00:00Z'))];
      final asked = [_line('https://a/master.m3u8', refreshAt: DateTime.parse('2026-11-05T10:05:00Z'))];

      expect(isSamePlayPlan(loaded, asked), isTrue);
    });
  });
}
