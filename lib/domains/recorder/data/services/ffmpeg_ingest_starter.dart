import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart' hide Log, Session;
import 'package:media_core_ingest/media_core_ingest.dart';

/// Runs ingest remuxes on the same FFmpegKit build the recorder already uses.
///
/// The ingest package starts no process by itself, so this is the app's only
/// obligation: turn an argument list into something with an exit code and a stop
/// button. Keeping it here means playback never links a second FFmpeg.
IngestFfmpegStarter get ffmpegKitIngestStarter => _start;

Future<IngestFfmpegProcess> _start(List<String> arguments) async {
  final FFmpegSession session = FFmpegKit.createSessionFromArguments(arguments);
  return _FfmpegKitProcess(session);
}

final class _FfmpegKitProcess implements IngestFfmpegProcess {
  _FfmpegKitProcess(this._session) {
    _exit = _awaitExit();
  }

  final FFmpegSession _session;
  late final Future<int> _exit;
  bool _stopped = false;

  @override
  Future<int> get exitCode => _exit;

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _session.cancel();
  }

  /// FFmpegKit reports completion through the session state, not a future.
  Future<int> _awaitExit() async {
    while (true) {
      final SessionState state = _session.getState();
      if (state == SessionState.completed || state == SessionState.failed) {
        return _session.getReturnCode();
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}
