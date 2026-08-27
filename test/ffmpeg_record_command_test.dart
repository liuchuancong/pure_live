import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_command_builder.dart';

void main() {
  test('recording passes signed URLs, headers and output paths as exact native arguments', () {
    final outputDir = '${Directory.systemTemp.path}${Platform.pathSeparator}Pure Live Records';
    final arguments = FFmpegCommandBuilder.buildRecordArguments(
      url: 'https://cdn.example/live.flv?token=a&expires=2',
      outputDir: outputDir,
      segmentTime: 600,
      preferBestStream: true,
      rwTimeout: 15,
      threadQueueSize: 1024,
      filePrefix: 'session-001',
      headers: const <String, String>{'user-agent': 'Pure Live Test UA', 'referer': 'https://example.test/room/1'},
    );

    expect(_valueAfter(arguments, '-i'), 'https://cdn.example/live.flv?token=a&expires=2');
    expect(_valuesAfter(arguments, '-map'), <String>['0:v:0?', '0:a:0?']);
    expect(_valueAfter(arguments, '-user_agent'), 'Pure Live Test UA');
    expect(_valueAfter(arguments, '-headers'), 'referer: https://example.test/room/1\r\n');
    expect(arguments.last, '$outputDir${Platform.pathSeparator}session-001_%06d.ts');
    expect(_valueAfter(arguments, '-reconnect_on_network_error'), '1');
    expect(_valueAfter(arguments, '-reconnect_on_http_error'), '5xx');
    expect(arguments, isNot(contains('-seekable')));
    expect(arguments, isNot(contains('-reconnect_at_eof')));
    expect(arguments, isNot(contains('-tls_verify')));
    expect(arguments.any((argument) => argument.startsWith('"') || argument.endsWith('"')), isFalse);
  });

  test('recording applies protocol-specific options and clamps native values', () {
    final rtsp = FFmpegCommandBuilder.buildRecordArguments(
      url: 'rtsp://camera.example/live',
      outputDir: Directory.systemTemp.path,
      segmentTime: 60,
      preferBestStream: false,
      rwTimeout: 12,
      threadQueueSize: 32,
    );
    final udp = FFmpegCommandBuilder.buildRecordArguments(
      url: 'udp://239.0.0.1:1234',
      outputDir: Directory.systemTemp.path,
      segmentTime: 60,
      preferBestStream: false,
      rwTimeout: 12,
      threadQueueSize: 999999,
    );

    expect(_valueAfter(rtsp, '-rtsp_transport'), 'tcp');
    expect(rtsp, isNot(contains('-reconnect')));
    expect(_valueAfter(udp, '-fifo_size'), '5000000');
    expect(_valueAfter(udp, '-overrun_nonfatal'), '1');
    expect(_valueAfter(udp, '-thread_queue_size'), '65536');
  });

  test('header sanitizing blocks line injection and emits one user-agent argument', () {
    final arguments = FFmpegCommandBuilder.buildRecordArguments(
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

    expect(_valueAfter(arguments, '-user_agent'), 'Recorder UA');
    expect(_valueAfter(arguments, '-headers'), 'referer: https://example.test/ Cookie: injected\r\n');
    expect(arguments.where((argument) => argument == '-user_agent'), hasLength(1));
    expect(arguments.join('\n').toLowerCase(), isNot(contains('bad header')));
  });

  test('audio relay preserves a signed input URL as one argument', () {
    final arguments = FFmpegCommandBuilder.buildAudioStreamArguments(
      remoteStreamUrl: 'https://cdn.example/audio.m3u8?token=a&expires=2',
      port: 19090,
    );

    expect(_valueAfter(arguments, '-i'), 'https://cdn.example/audio.m3u8?token=a&expires=2');
    expect(arguments, isNot(contains('-tls_verify')));
  });

  test('display formatting does not alter the native argument vector', () {
    final arguments = <String>['-i', 'https://cdn.example/live.flv?a=1&b=2', 'C:\\Pure Live\\out.ts'];
    final formatted = FFmpegCommandBuilder.formatArguments(arguments);

    expect(formatted, contains('"https://cdn.example/live.flv?a=1&b=2"'));
    expect(arguments, <String>['-i', 'https://cdn.example/live.flv?a=1&b=2', 'C:\\Pure Live\\out.ts']);
  });
}

String _valueAfter(List<String> arguments, String option) {
  final index = arguments.indexOf(option);
  expect(index, greaterThanOrEqualTo(0), reason: option);
  expect(index + 1, lessThan(arguments.length), reason: option);
  return arguments[index + 1];
}

List<String> _valuesAfter(List<String> arguments, String option) {
  final values = <String>[];
  for (var index = 0; index < arguments.length - 1; index++) {
    if (arguments[index] == option) values.add(arguments[index + 1]);
  }
  return values;
}
