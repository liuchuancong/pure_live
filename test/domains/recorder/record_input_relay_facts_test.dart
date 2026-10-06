import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/stream/ffmpeg_flv_input_relay.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

/// Pins that the recorder's input relays engage from the site's declared
/// [LiveStreamFacts], the same authoritative signal playback's
/// `resolveIngestPlan` uses, instead of guessing from the URL shape alone.
void main() {
  List<String> args(String url) => ['-i', url];

  group('FLV relay engages on declared container, not the suffix', () {
    test('declared FLV with no .flv suffix still relays', () async {
      final relay = await FFmpegFlvInputRelay.startForArguments(
        args('https://cdn.example.com/live/room'),
        declaredFlv: true,
      );
      addTearDown(() async => relay?.close());
      expect(relay, isNotNull, reason: 'site declared this line is FLV; recording must apply the FLV relay');
    });

    test('undeclared non-.flv URL is left alone', () async {
      final relay = await FFmpegFlvInputRelay.startForArguments(args('https://cdn.example.com/live/room.m3u8'));
      expect(relay, isNull);
    });

    test('undeclared .flv suffix keeps the legacy behavior', () async {
      final relay = await FFmpegFlvInputRelay.startForArguments(args('https://cdn.example.com/live/room.flv'));
      addTearDown(() async => relay?.close());
      expect(relay, isNotNull);
    });
  });

  group('HLS relay follows the declared format and rewrite need', () {
    const manifestRewrite = (format: LiveStreamFormat.hls, codec: null, unresolvedChildren: true);
    const plainFlv = (format: LiveStreamFormat.flv, codec: 'avc', unresolvedChildren: false);

    test('declared manifest with unresolved children relays even on a desktop host', () async {
      final relay = await FFmpegHlsInputRelay.startForArguments(
        args('https://tc.example.com/live/movie/playlist.m3u8'),
        facts: manifestRewrite,
      );
      addTearDown(() async => relay?.close());
      expect(
        relay,
        isNotNull,
        reason: 'unresolvedChildren forces the loopback rewrite, matching playback manifestRelay',
      );
    });

    test('declared non-manifest is never treated as a playlist', () async {
      final relay = await FFmpegHlsInputRelay.startForArguments(
        args('https://example.com/live/index.m3u8'),
        facts: plainFlv,
      );
      expect(
        relay,
        isNull,
        reason: 'the site declared FLV, so the HLS rewrite relay must not engage regardless of the suffix',
      );
    });

    test('no facts fall back to the URL shape', () async {
      final manifest = await FFmpegHlsInputRelay.startForArguments(
        args('https://example.com/live/index.m3u8'),
        force: true,
      );
      addTearDown(() async => manifest?.close());
      expect(manifest, isNotNull);

      final plain = await FFmpegHlsInputRelay.startForArguments(args('https://example.com/live/room.flv'));
      expect(plain, isNull);
    });
  });
}
