import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_command_builder.dart';

void main() {
  test('record command quotes signed URLs and output paths and tolerates missing tracks', () {
    final outputDir = '${Directory.systemTemp.path}${Platform.pathSeparator}Pure Live Records';
    final command = FFmpegCommandBuilder.buildRecordCommand(
      url: 'https://cdn.example/live.flv?token=a&expires=2',
      outputDir: outputDir,
      segmentTime: 600,
      preferBestStream: true,
      rwTimeout: 15,
      threadQueueSize: 1024,
      headers: const <String, String>{'user-agent': 'Pure Live Test UA', 'referer': 'https://example.test/room/1'},
    );

    expect(command, contains('-i "https://cdn.example/live.flv?token=a&expires=2"'));
    expect(command, contains('-map 0:v:0? -map 0:a:0?'));
    expect(command, contains('-user_agent "Pure Live Test UA"'));
    expect(command, contains('referer: https://example.test/room/1\r\n'));
    expect(command, contains('"$outputDir${Platform.pathSeparator}%Y%m%d_%H%M%S.ts"'));
  });

  test('audio relay also quotes a signed input URL', () {
    final command = FFmpegCommandBuilder.buildAudioStreamCommand(
      remoteStreamUrl: 'https://cdn.example/audio.m3u8?token=a&expires=2',
      port: 19090,
    );

    expect(command, contains('-i "https://cdn.example/audio.m3u8?token=a&expires=2"'));
  });
}
