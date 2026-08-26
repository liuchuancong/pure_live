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
      filePrefix: 'session-001',
      headers: const <String, String>{'user-agent': 'Pure Live Test UA', 'referer': 'https://example.test/room/1'},
    );

    expect(command, contains('-i "https://cdn.example/live.flv?token=a&expires=2"'));
    expect(command, contains('-map 0:v:0? -map 0:a:0?'));
    expect(command, contains('-user_agent "Pure Live Test UA"'));
    expect(command, contains('referer: https://example.test/room/1\r\n'));
    expect(command, contains('"$outputDir${Platform.pathSeparator}session-001_%06d.ts"'));
    expect(command, contains('-reconnect_on_network_error 1'));
    expect(command, contains('-reconnect_on_http_error 5xx'));
    expect(command, isNot(contains('-seekable 1')));
    expect(command, isNot(contains('-reconnect_at_eof')));
    expect(command, isNot(contains('-tls_verify 0')));
  });

  test('record command applies protocol-specific options', () {
    final rtsp = FFmpegCommandBuilder.buildRecordCommand(
      url: 'rtsp://camera.example/live',
      outputDir: Directory.systemTemp.path,
      segmentTime: 60,
      preferBestStream: false,
      rwTimeout: 12,
      threadQueueSize: 32,
    );
    final udp = FFmpegCommandBuilder.buildRecordCommand(
      url: 'udp://239.0.0.1:1234',
      outputDir: Directory.systemTemp.path,
      segmentTime: 60,
      preferBestStream: false,
      rwTimeout: 12,
      threadQueueSize: 999999,
    );

    expect(rtsp, contains('-rtsp_transport tcp'));
    expect(rtsp, isNot(contains('-reconnect ')));
    expect(udp, contains('-fifo_size 5000000 -overrun_nonfatal 1'));
    expect(udp, contains('-thread_queue_size 65536'));
  });

  test('record command strips injected header lines and never duplicates user-agent', () {
    final command = FFmpegCommandBuilder.buildRecordCommand(
      url: 'https://cdn.example/live.flv',
      outputDir: Directory.systemTemp.path,
      segmentTime: 60,
      preferBestStream: true,
      rwTimeout: 15,
      threadQueueSize: 1024,
      headers: const <String, String>{
        'User-Agent': 'Recorder UA',
        'Referer': 'https://example.test/\r\nCookie: injected',
        'Bad Header': 'ignored',
      },
    );

    expect(command, contains('-user_agent "Recorder UA"'));
    expect(command, contains('referer: https://example.test/ Cookie: injected'));
    expect(command, isNot(contains('bad header')));
    expect(RegExp('-user_agent').allMatches(command), hasLength(1));
  });

  test('audio relay also quotes a signed input URL', () {
    final command = FFmpegCommandBuilder.buildAudioStreamCommand(
      remoteStreamUrl: 'https://cdn.example/audio.m3u8?token=a&expires=2',
      port: 19090,
    );

    expect(command, contains('-i "https://cdn.example/audio.m3u8?token=a&expires=2"'));
    expect(command, isNot(contains('-tls_verify 0')));
  });
}
