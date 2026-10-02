// Shared bounded native observations for recording clock probes only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';

import 'frame_hash_timeline.dart';

List<String> buildClockDecodeArguments(String input, String label, {String pixelFormat = 'yuv420p'}) {
  final match = RegExp(r'^(video|audio)(?:_(\d{1,2}))?$').firstMatch(label);
  if (match == null) throw ArgumentError.value(label, 'label');
  final video = match[1] == 'video';
  final index = int.parse(match[2] ?? '0');
  if (index > 63) throw ArgumentError.value(index, 'stream ordinal');
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(pixelFormat)) throw ArgumentError.value(pixelFormat, 'pixelFormat');
  return [
    '-v',
    'error',
    '-threads',
    '4',
    '-i',
    input,
    '-map',
    '0:${video ? 'v' : 'a'}:$index',
    '-xerror',
    if (video) ...[
      '-c:v',
      'rawvideo',
      '-pix_fmt',
      pixelFormat,
      '-fps_mode',
      'passthrough',
    ] else ...[
      '-c:a',
      'pcm_s16le',
    ],
    '-threads',
    '4',
    '-enc_time_base',
    'demux',
    '-f',
    'framemd5',
    '-',
  ];
}

Future<Map<String, dynamic>> probeClockMediaFile(File input) async {
  final process = await Process.start(Platform.environment['PURELIVE_FFPROBE']!, [
    '-v',
    'error',
    '-show_streams',
    '-show_format',
    '-of',
    'json',
    input.path,
  ]);
  var ended = false;
  Future<String> collect(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > 1024 * 1024) throw StateError('Stream metadata budget');
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  try {
    final result = await Future.wait<Object>([process.exitCode, collect(process.stdout), collect(process.stderr)])
        .timeout(const Duration(seconds: 30));
    ended = true;
    expect(result[0], 0);
    expect((result[2] as String).trim(), isEmpty);
    return jsonDecode(result[1] as String) as Map<String, dynamic>;
  } finally {
    if (!ended) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}

Future<Map<String, Object?>> runClockNative(
  FFmpegManager manager,
  String id,
  List<String> args, {
  bool live = false,
}) async {
  final evidence = <String, Object?>{};
  final ended = Completer<void>();
  final subscription = manager.stream.listen((event) {
    if (event.taskId == id && [FFmpegEventType.complete, FFmpegEventType.error].contains(event.type)) {
      evidence.addAll({
        'type': event.type.name,
        for (final key in ['code', 'manualStop', 'forcedCancel', 'inputIntegrityError', 'inputCoverageIncomplete'])
          if (event.data.containsKey(key)) key: event.data[key],
      });
      if (!ended.isCompleted) ended.complete();
    }
  });
  try {
    await manager.start(taskId: id, arguments: args, liveRecording: live).timeout(const Duration(seconds: 60));
    await ended.future.timeout(const Duration(seconds: 5));
    expect(evidence['type'], 'complete');
    expect(evidence['code'], 0);
    expect(manager.isRunning(id), false);
    return evidence;
  } finally {
    if (manager.isRunning(id)) await manager.stop(id).timeout(const Duration(seconds: 30));
    await subscription.cancel();
  }
}

Future<Map<String, FrameHashTimeline>> decodeClockMedia(
  File input,
  Directory output,
  String label,
  List<String> media, {
  Map<String, String> pixelFormats = const {},
}) async {
  final results = <String, FrameHashTimeline>{};
  for (final kind in media) {
    final process = await Process.start(
      Platform.environment['PURELIVE_FFMPEG']!,
      buildClockDecodeArguments(input.path, kind, pixelFormat: pixelFormats[kind] ?? 'yuv420p'),
    );
    var ended = false;
    Future<String> collect(Stream<List<int>> stream) async {
      final bytes = <int>[];
      await for (final chunk in stream) {
        if (bytes.length + chunk.length > 4 * 1024 * 1024) throw StateError('Decode evidence budget');
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    }

    try {
      final decoded = await Future.wait<Object>([process.exitCode, collect(process.stdout), collect(process.stderr)])
          .timeout(const Duration(seconds: 30));
      ended = true;
      await File(p.join(output.path, '$label-$kind.framemd5')).writeAsString(decoded[1] as String);
      await File(p.join(output.path, '$label-$kind.stderr')).writeAsString(decoded[2] as String);
      expect(decoded[0], 0);
      expect((decoded[2] as String).trim(), isEmpty);
      results[kind] = FrameHashTimeline.parse(decoded[1] as String);
    } finally {
      if (!ended) {
        process.kill();
        await process.exitCode.timeout(const Duration(seconds: 5));
      }
    }
  }
  return results;
}
