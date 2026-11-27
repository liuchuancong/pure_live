import 'package:flutter_test/flutter_test.dart';
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/modules/vod/widgets/vod_media_source.dart';

void main() {
  group('external audio failure classification', () {
    test('recognizes media_core and mpv external-audio failures', () {
      for (final message in const [
        'The external audio track could not be loaded',
        'The external audio track could not be selected',
        'The external audio track did not become playable',
        'audio-add failed for https://example.com/audio.m4s',
        'Failed to open audio track',
        'audio trick error',
      ]) {
        expect(isVodExternalAudioFailure(message), isTrue, reason: message);
      }
    });

    test('does not turn unrelated playback failures into a muxed retry', () {
      for (final message in const [
        'Connection reset by peer',
        'The video decoder is unavailable',
        'Permission denied',
        'Playback completed',
        '',
      ]) {
        expect(isVodExternalAudioFailure(message), isFalse, reason: message);
      }
    });
  });

  test('DASH keeps the highest-bandwidth standard audio and its headers', () {
    const low = VodDashAudio(id: 30216, url: 'https://example.com/low.m4s', bandwidth: 64000);
    const high = VodDashAudio(
      id: 30280,
      url: 'https://example.com/high.m4s',
      bandwidth: 192000,
      backupUrls: [
        'https://example.com/high-backup-1.m4s',
        'https://example.com/high-backup-1.m4s',
        '',
        'https://example.com/high-backup-2.m4s',
      ],
    );
    const info = VodPlayInfo(
      url: '',
      headers: {'Referer': 'https://www.bilibili.com'},
      videos: [
        VodDashVideo(id: 1, url: 'https://example.com/video.m4s', quality: 64, codecId: 7, codec: 'avc1.640028'),
      ],
      audios: [low, high],
      flac: VodDashAudio(id: 30251, url: 'https://example.com/lossless.m4s', bandwidth: 1000000),
    );

    final source = vodDashSourceOf(info, maxQuality: 64);
    expect(source, isA<CompositeMediaSource>());
    final composite = source! as CompositeMediaSource;
    expect(composite.audioTracks.single.uri, Uri.parse(high.url));
    expect(composite.audioTracks.single.headers?.values['Referer'], 'https://www.bilibili.com');
    expect(composite.videoTracks.single.codec, 'avc1.640028');
    expect(vodDashAudioUrls(info), [
      'https://example.com/high.m4s',
      'https://example.com/high-backup-1.m4s',
      'https://example.com/high-backup-2.m4s',
    ]);

    final backup = vodDashSourceOf(info, maxQuality: 64, audioUrl: vodDashAudioUrls(info)[1])! as CompositeMediaSource;
    expect(backup.audioTracks.single.uri, Uri.parse('https://example.com/high-backup-1.m4s'));
    expect(backup.videoTracks.single.uri, composite.videoTracks.single.uri);
    expect(backup.videoTracks.single.codec, composite.videoTracks.single.codec);
    expect(backup.videoTracks.single.bitrate, composite.videoTracks.single.bitrate);
    expect(backup.audioTracks.single.headers?.values['Referer'], 'https://www.bilibili.com');
  });
}
