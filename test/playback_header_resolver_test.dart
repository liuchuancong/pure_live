import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';

void main() {
  test('Douyu playback and recording share room-scoped anti-hotlink headers', () async {
    final playback = await PlaybackHeaderResolver.resolve(platform: 'DOUYU', roomId: '12345');
    final recording = await FFmpegHeaderFactory.build(platform: 'douyu', roomId: '12345');

    expect(playback, recording);
    expect(playback['origin'], 'https://www.douyu.com');
    expect(playback['referer'], 'https://www.douyu.com/12345');
    expect(playback['user-agent'], isNotEmpty);
    expect(playback['cookie'], contains('dy_did='));
    expect(playback['cookie'], contains('acf_did='));
  });

  test('YY gets browser origin headers and unknown platforms stay header-free', () async {
    final yy = await PlaybackHeaderResolver.resolve(platform: 'yy', roomId: '1');
    final unknown = await PlaybackHeaderResolver.resolve(platform: 'unknown', roomId: '1');

    expect(yy['origin'], 'https://www.yy.com');
    expect(yy['referer'], 'https://www.yy.com/');
    expect(yy['user-agent'], isNotEmpty);
    expect(unknown, isEmpty);
  });

  test('every built-in HTTP platform has a deterministic media origin profile', () async {
    final expectedOrigins = <String, String>{
      'bilibili': 'https://live.bilibili.com',
      'douyu': 'https://www.douyu.com',
      'huya': 'https://www.huya.com',
      'douyin': 'https://live.douyin.com',
      'kuaishou': 'https://live.kuaishou.com',
      'cc': 'https://cc.163.com',
      'twitch': 'https://www.twitch.tv',
      'soop': 'https://www.sooplive.co.kr',
      'yy': 'https://www.yy.com',
    };

    for (final entry in expectedOrigins.entries) {
      final headers = await PlaybackHeaderResolver.resolve(platform: entry.key, roomId: 'room 1');
      expect(headers['origin'], entry.value, reason: entry.key);
      expect(headers['referer'], isNotEmpty, reason: entry.key);
      expect(headers['user-agent'], isNotEmpty, reason: entry.key);
      expect(headers.keys, everyElement(matches(RegExp(r'^[a-z0-9-]+$'))), reason: entry.key);
      expect(headers.values, everyElement(isNot(contains('\n'))), reason: entry.key);
    }
  });
}
