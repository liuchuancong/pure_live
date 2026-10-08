import 'package:pure_live/domains/recorder/data/services/owned_record_input.dart';

import 'dart:async';

import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_service.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';
import 'package:pure_live/core/stream/ffmpeg_flv_input_relay.dart';
import 'package:pure_live/shared/platforms/live_site.dart' show LiveStreamFacts;

class FFmpegManager {
  FFmpegManager._internal() : _ffmpeg = FFmpegService.to;

  FFmpegManager.forTesting(FFmpegService service) : _ffmpeg = service;

  static final FFmpegManager _instance = FFmpegManager._internal();

  static FFmpegManager get to => _instance;

  final StreamController<FFmpegEvent> _eventController = StreamController<FFmpegEvent>.broadcast();

  Stream<FFmpegEvent> get stream => _eventController.stream;

  final FFmpegService _ffmpeg;

  Future<void>? _initializeFuture;

  Future<void> initialize() {
    final inFlight = _initializeFuture;
    if (inFlight != null) return inFlight;

    late final Future<void> initialization;
    initialization = _ffmpeg.initialize().catchError((Object error, StackTrace stackTrace) {
      // A transient native-library or filesystem failure must not poison the
      // singleton for the remainder of the process. A later recording action
      // gets one fresh attempt while concurrent callers still share this one.
      if (identical(_initializeFuture, initialization)) {
        _initializeFuture = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _initializeFuture = initialization;
    return initialization;
  }

  Future<void> start({
    required String taskId,
    required List<String> arguments,
    bool liveRecording = false,
    HlsSourceQueryPolicy? sourceQueryPolicy,
    HlsRelayDiagnostics? hlsDiagnostics,
    FlvRelayDiagnostics? flvDiagnostics,
    bool hlsPrefetch = false,
    LiveStreamFacts? facts,
  }) async {
    // The service reserves the attempt before initializing. Waiting here would
    // leave a stop request with no owner and allow a late start after user exit.
    await _ffmpeg.start(
      taskId: taskId,
      arguments: arguments,
      liveRecording: liveRecording,
      sourceQueryPolicy: sourceQueryPolicy,
      hlsDiagnostics: hlsDiagnostics,
      flvDiagnostics: flvDiagnostics,
      hlsPrefetch: hlsPrefetch,
      facts: facts,
      onEvent: (event) {
        if (!_eventController.isClosed) {
          _eventController.add(event);
        }
      },
    );
  }

  Future<void> startOwned({
    required String taskId,
    required OwnedRecordSource source,
    required RecordArgumentsBuilder buildArguments,
  }) => _ffmpeg.startOwned(
    taskId: taskId,
    source: source,
    buildArguments: buildArguments,
    onEvent: (event) {
      if (!_eventController.isClosed) _eventController.add(event);
    },
  );

  Future<void> stop(String taskId) => _ffmpeg.stop(taskId);

  Future<void> refreshLease(String taskId) async {
    await initialize();
    await _ffmpeg.refreshLease(taskId);
  }

  bool isRunning(String taskId) {
    return _ffmpeg.isRunning(taskId);
  }

  FFmpegRecordSession? getSession(String taskId) {
    return _ffmpeg.getSession(taskId);
  }
}
