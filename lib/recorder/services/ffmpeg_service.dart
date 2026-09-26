import 'package:dio/dio.dart';

import 'owned_record_input.dart';

import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart' hide Log;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/core/common/hls_source_query_policy.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/services/ffmpeg_hls_input_relay.dart';
import 'package:pure_live/recorder/services/ffmpeg_flv_input_relay.dart';
import 'package:pure_live/recorder/services/ffmpeg_tls_trust_store.dart';
import 'package:pure_live/recorder/services/recording_segment_clock.dart';

/// Converts FFmpegKit's progress timestamp into a live-session duration.
///
/// Some MPEG-TS/HLS inputs expose a sentinel or source PTS close to
/// `INT32_MAX` as the first statistics timestamp.  Treating that value as an
/// elapsed duration produces counters such as `596523:14:08`.  A live capture
/// cannot run materially ahead of its wall clock, so source/sentinel values
/// fall back to wall time while ordinary FFmpeg progress remains authoritative.
@visibleForTesting
int normalizeLiveRecordedSeconds({required int rawMilliseconds, required int wallSeconds}) {
  final wall = wallSeconds < 0 ? 0 : wallSeconds;
  if (rawMilliseconds <= 0) return 0;
  final rawSeconds = rawMilliseconds ~/ 1000;
  if (rawSeconds < 0) return 0;
  if (rawSeconds > wall + 15) return wall;
  return rawSeconds;
}

enum FFmpegFailureKind {
  storageFull,
  outputPath,
  command,
  httpAccess,
  transport,
  inputOpen,
  inputFormat,
  decoder,
  native,
}

class FFmpegFailureDiagnosis {
  const FFmpegFailureDiagnosis({required this.kind, required this.retryable});

  final FFmpegFailureKind kind;
  final bool retryable;
}

class FFmpegFailureClassifier {
  const FFmpegFailureClassifier._();

  static FFmpegFailureDiagnosis classify({required int code, required String logs}) {
    final value = logs.toLowerCase();
    if (_containsAny(value, const <String>[
      'no space left on device',
      'disk quota exceeded',
      'not enough space on the disk',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.storageFull, retryable: false);
    }
    if (_containsAny(value, const <String>[
      'error opening output',
      'unable to open output',
      'could not open output',
      'failed to open segment',
      'error writing trailer',
      'av_interleaved_write_frame',
      'read-only file system',
      'permission denied',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.outputPath, retryable: false);
    }
    if (_containsAny(value, const <String>[
      'server returned 401',
      'server returned 403',
      'server returned 404',
      'http error 401',
      'http error 403',
      'http error 404',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.httpAccess, retryable: true);
    }
    if (_containsAny(value, const <String>[
      'connection timed out',
      'timed out',
      'connection refused',
      'connection reset',
      'network is unreachable',
      'host is unreachable',
      'failed to resolve',
      'name or service not known',
      'tls handshake',
      'ssl handshake',
      'certificate verify failed',
      'input/output error',
      'i/o error',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.transport, retryable: true);
    }
    if (_containsAny(value, const <String>[
      'error opening input',
      'unable to open input',
      'failed to open input',
      'could not open input',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.inputOpen, retryable: true);
    }
    if (_containsAny(value, const <String>[
      'invalid data found when processing input',
      'could not find codec parameters',
      'no streams found',
      'moov atom not found',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.inputFormat, retryable: true);
    }
    if (_containsAny(value, const <String>['decoder', 'decode', 'codec', 'invalid nal'])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.decoder, retryable: true);
    }
    if (_containsAny(value, const <String>[
      'option not found',
      'unrecognized option',
      'error parsing options',
      'unknown protocol',
      'protocol not found',
      'muxer not found',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.command, retryable: false);
    }
    // "Invalid argument" is also FFmpeg's terminal errno for malformed or
    // expired inputs. Treat it as a command defect only when an option parser
    // marker proves that the generated command is invalid; otherwise let the
    // bounded retry path refresh the signed stream URL.
    return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.native, retryable: true);
  }

  static bool _containsAny(String value, List<String> markers) => markers.any(value.contains);
}

/// A live recorder has no natural successful EOF.  The only successful
/// terminal event is an explicit user stop; code 0/AVERROR_EOF from the input
/// means the CDN response ended and the controller must refresh the signed URL
/// instead of reporting that the room went offline.
class FFmpegTerminalDecision {
  const FFmpegTerminalDecision({required this.isComplete, required this.retryable, required this.unexpectedEof});

  final bool isComplete;
  final bool retryable;
  final bool unexpectedEof;

  static FFmpegTerminalDecision forSession({
    required int code,
    required bool manuallyStopped,
    required bool liveRecording,
    bool leaseRefresh = false,
    bool corruptOutput = false,
  }) {
    if (corruptOutput) {
      return const FFmpegTerminalDecision(isComplete: false, retryable: false, unexpectedEof: false);
    }
    if (manuallyStopped) {
      return const FFmpegTerminalDecision(isComplete: true, retryable: false, unexpectedEof: false);
    }
    if (liveRecording && leaseRefresh) {
      return const FFmpegTerminalDecision(isComplete: false, retryable: true, unexpectedEof: true);
    }
    if (liveRecording && (code == 0 || code == -541478725)) {
      return const FFmpegTerminalDecision(isComplete: false, retryable: true, unexpectedEof: true);
    }
    if (code == 0 || code == -541478725) {
      return const FFmpegTerminalDecision(isComplete: true, retryable: false, unexpectedEof: false);
    }
    return const FFmpegTerminalDecision(isComplete: false, retryable: true, unexpectedEof: false);
  }
}

class FFmpegRecordSession {
  FFmpegRecordSession({
    required this.taskId,
    required this.sessionId,
    required this.session,
    required this.liveRecording,
    this.inputRelay,
    this.flvInputRelay,
    this.ownedInput,
  });

  final String taskId;
  final int sessionId;
  final FFmpegSession session;
  final bool liveRecording;
  final FFmpegHlsInputRelay? inputRelay;
  final FFmpegFlvInputRelay? flvInputRelay;
  final OwnedRecordInput? ownedInput;
  Future<void>? stopRequest;
  bool forcedCancel = false;
  final DateTime createdAt = DateTime.now();
  final Completer<void> completion = Completer<void>();
  final List<String> _diagnosticLines = <String>[];
  var _diagnosticCharacters = 0;
  bool hasMediaIntegrityError = false;
  bool hasInputPacketError = false;
  bool hasInputCoverageGap = false;
  // Explicit HLS loss reports only: generic I/O, packet damage, or a skipped
  // duplicate moov are not evidence of missing media intervals.
  static final _missingHlsSegment = RegExp(
    r'(?:^|\])\s*(?:skipping [1-9]\d* segments ahead, expired from playlists|segment \d+ of playlist \d+ failed too many times, skipping)(?:\s|$)',
    multiLine: true,
    caseSensitive: false,
  );
  Stopwatch? _stopWatch;

  void markStopRequested() => _stopWatch ??= Stopwatch()..start();

  /// One immutable snapshot for terminal events and all diagnostic sinks.
  /// inputDrained means native ended after finish without forced cancel or a
  /// known pending AVC picture. It is not full decoding or byte-delivery proof.
  Map<String, Object?> terminalEvidence({String fallbackLogs = ''}) {
    final finishRequested =
        flvInputRelay?.finishRequested == true ||
        inputRelay?.finishRequested == true ||
        ownedInput?.finishRequested == true;
    final drainKind = flvInputRelay != null
        ? 'flv'
        : inputRelay?.drainOnStop == true || ownedInput != null
        ? 'hls'
        : 'none';
    return Map.unmodifiable({
      'manualStop': manualStop,
      'leaseRefresh': leaseRefresh,
      'stopRequested': _stopWatch != null,
      'stopElapsedMs': _stopWatch?.elapsedMilliseconds,
      'inputDrainKind': drainKind,
      'inputDrainBudgetMs': drainKind == 'flv'
          ? 3000
          : drainKind == 'hls'
          ? (ownedInput?.drainTimeout ?? inputRelay!.drainTimeout).inMilliseconds
          : 0,
      'inputFinishRequested': finishRequested,
      'forcedCancel': forcedCancel,
      'inputDrained': finishRequested && !forcedCancel && flvInputRelay?.hasPendingAccessUnit != true,
      if (flvInputRelay != null) 'flvAccessUnitPending': flvInputRelay!.hasPendingAccessUnit,
      'inputTailDiscarded':
          liveRecording && (ownedInput?.inputTailDiscarded == true || inputRelay?.inputTailDiscarded == true),
      'inputCoverageIncomplete': liveRecording && hasInputCoverageGap,
      'inputIntegrityError':
          liveRecording &&
          (hasInputPacketError ||
              flvInputRelay?.hasPendingAccessUnit == true ||
              FFmpegMediaIntegrity.hasPacketError(fallbackLogs)),
    });
  }

  bool manualStop = false;
  bool leaseRefresh = false;
  bool mediaStarted = false;
  int recordedSeconds = 0;
  int fileSize = 0;
  double bitrate = 0;
  double speed = 0;
  double fps = 0;
  DateTime lastUpdate = DateTime.now();

  void appendDiagnostic(String message, {int maxLines = 120, int maxCharacters = 12000}) {
    final sanitized = FFmpegService._sanitizeLogs(message).trim();
    if (sanitized.isEmpty) return;
    // Keep the integrity verdict even after the bounded diagnostic tail rolls
    // over. Some native builds return zero despite a demux/mux error (-xerror
    // alone was insufficient in the 0.11.1 Windows source-retention probe).
    hasMediaIntegrityError = hasMediaIntegrityError || FFmpegMediaIntegrity.hasError(sanitized);
    hasInputPacketError = hasInputPacketError || FFmpegMediaIntegrity.hasPacketError(sanitized);
    // Stop/lease draining may intentionally retire an unpublished tail. Do not
    // reinterpret those late messages as loss during active capture. Do not
    // infer this from terminal fallback text, whose timing is no longer known.
    if (liveRecording && !manualStop && !leaseRefresh && _stopWatch == null) {
      hasInputCoverageGap = hasInputCoverageGap || _missingHlsSegment.hasMatch(sanitized);
    }
    _diagnosticLines.add(sanitized);
    _diagnosticCharacters += sanitized.length;
    while (_diagnosticLines.length > maxLines || _diagnosticCharacters > maxCharacters) {
      _diagnosticCharacters -= _diagnosticLines.removeAt(0).length;
    }
  }

  String get diagnosticTail => _diagnosticLines.join('\n');
}

class FFmpegService {
  FFmpegService._internal()
    : _initializeOverride = null,
      _createSession = FFmpegKit.createSessionFromArguments,
      _cancelSession = FFmpegKit.cancel;

  @visibleForTesting
  FFmpegService.forTesting({
    required Future<void> Function() initialize,
    required this._createSession,
    required this._cancelSession,
  }) : _initializeOverride = initialize;

  final Future<void> Function()? _initializeOverride;
  final FFmpegSession Function(List<String>) _createSession;
  final void Function(FFmpegSession) _cancelSession;
  final Map<String, _RecordStartRequest> _starts = {};

  static final FFmpegService _instance = FFmpegService._internal();
  static FFmpegService get to => _instance;

  final Map<String, FFmpegRecordSession> _sessions = {};
  Future<void>? _initializing;
  bool _initialized = false;
  String? _trustedCaFile;

  static void initInIsolate(RootIsolateToken token) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }

  Future<void> initialize() async {
    await _ensureInitialized();
  }

  Future<void> start({
    required String taskId,
    required List<String> arguments,
    required void Function(FFmpegEvent event) onEvent,
    bool liveRecording = false,
    HlsSourceQueryPolicy? sourceQueryPolicy,
    HlsRelayDiagnostics? hlsDiagnostics,
    FlvRelayDiagnostics? flvDiagnostics,
    bool hlsPrefetch = false,
  }) => _start(
    taskId: taskId,
    arguments: arguments,
    onEvent: onEvent,
    liveRecording: liveRecording,
    sourceQueryPolicy: sourceQueryPolicy,
    hlsDiagnostics: hlsDiagnostics,
    flvDiagnostics: flvDiagnostics,
    hlsPrefetch: hlsPrefetch,
  );

  Future<void> startOwned({
    required String taskId,
    required OwnedRecordSource source,
    required RecordArgumentsBuilder buildArguments,
    required void Function(FFmpegEvent event) onEvent,
  }) => _start(
    taskId: taskId,
    arguments: const [],
    onEvent: onEvent,
    liveRecording: true,
    ownedSource: source,
    buildArguments: buildArguments,
  );

  Future<void> _start({
    required String taskId,
    required List<String> arguments,
    required void Function(FFmpegEvent event) onEvent,
    required bool liveRecording,
    HlsSourceQueryPolicy? sourceQueryPolicy,
    HlsRelayDiagnostics? hlsDiagnostics,
    FlvRelayDiagnostics? flvDiagnostics,
    bool hlsPrefetch = false,
    OwnedRecordSource? ownedSource,
    RecordArgumentsBuilder? buildArguments,
  }) async {
    // Reserve before initialization or remote allocation; stop and duplicate
    // start observe the same owner even before a native session exists.
    if (_starts.containsKey(taskId) || _sessions.containsKey(taskId)) {
      throw StateError('FFmpeg task is already active: $taskId');
    }
    final request = _RecordStartRequest();
    _starts[taskId] = request;
    FFmpegHlsInputRelay? inputRelay;
    FFmpegFlvInputRelay? flvInputRelay;
    OwnedRecordInput? ownedInput;
    RecordingClockReservation? clockOutput;
    try {
      await _ensureInitialized();
      request.check();
      late final List<String> inputArguments;
      if (ownedSource != null) {
        ownedInput = await ownedSource.createInput(request.cancel);
        request.check();
        if (ownedInput.isClosed) throw StateError('Recording input ended before native open');
        // Build against the actual private input, never a dummy URL or identity.
        arguments = buildArguments!(ownedInput.inputUri);
        inputArguments = ownedInput.replaceFirstInput(arguments);
      } else {
        if (arguments.isEmpty) throw ArgumentError('FFmpeg arguments must not be empty');
        inputRelay = await FFmpegHlsInputRelay.startForArguments(
          arguments,
          drainOnStop: liveRecording,
          sourceQueryPolicy: sourceQueryPolicy,
          diagnostics: hlsDiagnostics,
          enablePrefetch: hlsPrefetch,
        );
        request.check();
        flvInputRelay = liveRecording
            ? await FFmpegFlvInputRelay.startForArguments(arguments, diagnostics: flvDiagnostics)
            : null;
        request.check();
        inputArguments =
            flvInputRelay?.replaceFirstInput(arguments) ?? inputRelay?.replaceFirstInput(arguments) ?? arguments;
      }
      if (inputArguments.isEmpty) throw ArgumentError('FFmpeg arguments must not be empty');
      clockOutput = await RecordingClockReservation.acquire(arguments);
      final effectiveArguments = FFmpegTlsTrustStore.injectCaFile(inputArguments, caFile: _trustedCaFile);
      request.check();
      if (ownedInput?.isClosed == true) throw StateError('Recording input ended before native open');
      request.nativeStarted = true;
      await _execute(
        taskId: taskId,
        arguments: arguments,
        effectiveArguments: effectiveArguments,
        onEvent: onEvent,
        liveRecording: liveRecording,
        inputRelay: inputRelay,
        flvInputRelay: flvInputRelay,
        ownedInput: ownedInput,
      );
    } finally {
      try {
        await Future.wait<void>([
          if (ownedInput != null) Future.sync(ownedInput.close),
          if (inputRelay != null) Future.sync(inputRelay.close),
          if (flvInputRelay != null) Future.sync(flvInputRelay.close),
        ]);
      } finally {
        clockOutput?.release();
        if (identical(_starts[taskId], request)) _starts.remove(taskId);
        if (!request.done.isCompleted) request.done.complete();
      }
    }
  }

  Future<void> _execute({
    required String taskId,
    required List<String> arguments,
    required List<String> effectiveArguments,
    required void Function(FFmpegEvent event) onEvent,
    required bool liveRecording,
    FFmpegHlsInputRelay? inputRelay,
    FFmpegFlvInputRelay? flvInputRelay,
    OwnedRecordInput? ownedInput,
  }) async {
    late final FFmpegSession nativeSession;
    try {
      nativeSession = _createSession(effectiveArguments);
    } catch (_) {
      await inputRelay?.close();
      await flvInputRelay?.close();
      rethrow;
    }
    final session = FFmpegRecordSession(
      taskId: taskId,
      sessionId: nativeSession.getSessionId(),
      session: nativeSession,
      liveRecording: liveRecording,
      inputRelay: inputRelay,
      flvInputRelay: flvInputRelay,
      ownedInput: ownedInput,
    );
    _sessions[taskId] = session;

    void onCoverageIncomplete() {
      if (!identical(_sessions[taskId], session) ||
          !liveRecording ||
          session.manualStop ||
          session.leaseRefresh ||
          session._stopWatch != null ||
          session.hasInputCoverageGap) {
        return;
      }
      session.hasInputCoverageGap = true;
      _safeEmit(
        onEvent,
        FFmpegEvent(
          taskId: taskId,
          type: FFmpegEventType.inputCoverage,
          data: {'sessionId': session.sessionId, 'inputCoverageIncomplete': true},
        ),
      );
    }

    inputRelay?.onCoverageIncomplete = onCoverageIncomplete;
    ownedInput?.onCoverageIncomplete = onCoverageIncomplete;

    nativeSession.setLogCallback((entry) {
      if (!identical(_sessions[taskId], session)) return;
      final hadGap = session.hasInputCoverageGap;
      session.appendDiagnostic(entry.message);
      if (!hadGap && session.hasInputCoverageGap) {
        _safeEmit(
          onEvent,
          FFmpegEvent(
            taskId: taskId,
            type: FFmpegEventType.inputCoverage,
            data: {'sessionId': session.sessionId, 'inputCoverageIncomplete': true},
          ),
        );
      }
    });

    nativeSession.setStatisticsCallback((statistics) {
      if (!identical(_sessions[taskId], session)) return;
      final wallSeconds = DateTime.now().difference(session.createdAt).inSeconds;
      final recordedSeconds = session.liveRecording
          ? normalizeLiveRecordedSeconds(rawMilliseconds: statistics.time, wallSeconds: wallSeconds)
          : math.max(0, statistics.time ~/ 1000);
      final fileSize = statistics.size;
      session
        ..recordedSeconds = recordedSeconds > session.recordedSeconds ? recordedSeconds : session.recordedSeconds
        ..fileSize = fileSize > session.fileSize ? fileSize : session.fileSize
        // FFmpeg divides by the source timestamp, which live inputs can push
        // far ahead of wall time; the recorder measures file growth instead.
        ..bitrate = !session.liveRecording && statistics.bitrate > 0 ? statistics.bitrate : session.bitrate
        ..speed = statistics.speed > 0 ? statistics.speed : session.speed
        ..fps = statistics.videoFps > 0 ? statistics.videoFps : session.fps
        ..lastUpdate = DateTime.now();

      if (!session.mediaStarted && (statistics.time > 0 || statistics.size > 0 || statistics.videoFrameNumber > 0)) {
        session.mediaStarted = true;
        _safeEmit(
          onEvent,
          FFmpegEvent(taskId: taskId, type: FFmpegEventType.started, data: {'sessionId': session.sessionId}),
        );
      }

      _safeEmit(
        onEvent,
        FFmpegEvent(
          taskId: taskId,
          type: FFmpegEventType.progress,
          data: {
            'sessionId': session.sessionId,
            // Keep the event contract in milliseconds while shielding the
            // recorder controller from source-PTS/sentinel timestamps.
            'time': session.liveRecording ? recordedSeconds * 1000 : statistics.time,
            'size': statistics.size,
            'bitrate': session.liveRecording ? 0 : statistics.bitrate,
            'speed': statistics.speed,
            'fps': statistics.videoFps,
          },
        ),
      );
    });

    nativeSession.setCompleteCallback((completedSession) {
      try {
        final code = completedSession.getReturnCode();
        final manuallyStopped = session.manualStop;
        final leaseRefresh = session.leaseRefresh;
        final rawLogs = session.diagnosticTail.isNotEmpty ? session.diagnosticTail : (completedSession.getLogs() ?? '');
        final corruptOutput =
            arguments.contains('-xerror') && (session.hasMediaIntegrityError || FFmpegMediaIntegrity.hasError(rawLogs));
        final sessionAgeMilliseconds = DateTime.now().difference(session.createdAt).inMilliseconds;
        final terminal = FFmpegTerminalDecision.forSession(
          code: code,
          manuallyStopped: manuallyStopped,
          liveRecording: session.liveRecording,
          leaseRefresh: leaseRefresh,
          corruptOutput: corruptOutput,
        );

        final diagnosticLogs = _sanitizeLogs(rawLogs).toLowerCase();
        final logTail = _diagnosticTail(diagnosticLogs, maxCharacters: 1600);
        final lifecycleData = session.terminalEvidence(fallbackLogs: rawLogs);
        final lifecycleSummary = lifecycleData.entries.map((entry) => '${entry.key}=${entry.value}').join(' ');
        Log.i(
          'FFmpeg complete => taskId: $taskId; sessionId: ${session.sessionId}; '
          'code: $code; live: ${session.liveRecording}; leaseRefresh: $leaseRefresh; '
          'ageMs: $sessionAgeMilliseconds; $lifecycleSummary; diagnostics: $logTail',
        );
        // `dart:developer` reaches Android logcat in debug builds, while the
        // app logger may be disabled by the user's diagnostics preference.
        // The text is already URL/token/cookie-sanitized above.
        log(
          'terminal task=$taskId session=${session.sessionId} code=$code '
          'live=${session.liveRecording} media=${session.mediaStarted} '
          'leaseRefresh=$leaseRefresh ageMs=$sessionAgeMilliseconds '
          'seconds=${session.recordedSeconds} bytes=${session.fileSize} $lifecycleSummary\n$logTail',
          name: 'PureLiveRecorder',
        );
        if (kDebugMode) {
          debugPrint(
            'PureLiveRecorder terminal task=$taskId session=${session.sessionId} code=$code '
            'live=${session.liveRecording} media=${session.mediaStarted} '
            'seconds=${session.recordedSeconds} bytes=${session.fileSize} $lifecycleSummary\n$logTail',
          );
        }
        final diagnosis = FFmpegFailureClassifier.classify(code: code, logs: diagnosticLogs);
        final isComplete = terminal.isComplete;
        final errorData = <String, dynamic>{
          'sessionId': session.sessionId,
          'code': code,
          ...lifecycleData,
          'sessionAgeMs': sessionAgeMilliseconds,
          if (!isComplete) 'raw_logs': _diagnosticTail(diagnosticLogs),
          if (!isComplete)
            'failure_kind': corruptOutput
                ? 'outputIntegrity'
                : leaseRefresh
                ? 'leaseRefresh'
                : terminal.unexpectedEof
                ? 'unexpectedEof'
                : diagnosis.kind.name,
          if (!isComplete)
            'retryable': corruptOutput
                ? false
                : leaseRefresh || terminal.unexpectedEof
                ? terminal.retryable
                : diagnosis.retryable,
          if (terminal.unexpectedEof || leaseRefresh) 'silent': true,
        };
        if (!isComplete) {
          errorData['message'] = corruptOutput
              ? i18n('video_ffmpeg_failed')
              : terminal.unexpectedEof || leaseRefresh
              ? i18n('recorder_transport_failed')
              : _friendlyError(code, diagnosticLogs, diagnosis);
        }

        _safeEmit(
          onEvent,
          FFmpegEvent(
            taskId: taskId,
            type: isComplete ? FFmpegEventType.complete : FFmpegEventType.error,
            data: errorData,
          ),
        );
      } finally {
        if (identical(_sessions[taskId], session)) _sessions.remove(taskId);
        if (!session.completion.isCompleted) session.completion.complete();
        unawaited(session.inputRelay?.close());
        unawaited(session.flvInputRelay?.close());
      }
    });

    _safeEmit(
      onEvent,
      FFmpegEvent(taskId: taskId, type: FFmpegEventType.startAck, data: {'sessionId': session.sessionId}),
    );

    try {
      await nativeSession.executeAsync();
    } catch (error, stackTrace) {
      Log.e('FFmpeg execution failed before native completion: $error', stackTrace);
      if (identical(_sessions[taskId], session)) {
        final diagnosticLogs = _sanitizeLogs(error.toString()).toLowerCase();
        final diagnosis = FFmpegFailureClassifier.classify(code: -1, logs: diagnosticLogs);
        _sessions.remove(taskId);
        _safeEmit(
          onEvent,
          FFmpegEvent(
            taskId: taskId,
            type: FFmpegEventType.error,
            data: {
              'sessionId': session.sessionId,
              'code': -1,
              'manualStop': session.manualStop,
              'raw_logs': diagnosticLogs,
              'failure_kind': diagnosis.kind.name,
              'retryable': diagnosis.retryable,
              'message': _friendlyError(-1, diagnosticLogs, diagnosis),
            },
          ),
        );
      }
    } finally {
      if (identical(_sessions[taskId], session)) _sessions.remove(taskId);
      if (!session.completion.isCompleted) session.completion.complete();
      await session.inputRelay?.close();
      await session.flvInputRelay?.close();
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;

    final future = _initializeOverride != null
        ? _initializeOverride()
        : Future.wait<void>([
            FFmpegKitExtended.initialize(),
            FFmpegTlsTrustStore.ensureReady().then<void>((path) => _trustedCaFile = path),
          ]);
    _initializing = future;
    try {
      await future;
      _initialized = true;
    } finally {
      if (identical(_initializing, future)) _initializing = null;
    }
  }

  Future<void> stop(String taskId) async {
    final request = _starts[taskId];
    final session = _sessions[taskId];
    if (session != null) {
      session.manualStop = true;
      log('FFmpeg stop => $taskId (${session.sessionId})');
      await _requestSessionStop(session);
    } else if (request != null && !request.nativeStarted) {
      request.cancel.cancel('Recording stopped during input creation');
    }
    // Native termination and input cleanup are distinct. Late allocations and
    // asynchronous seat/relay cleanup must settle before releasing the attempt.
    if (request != null) await request.done.future;
  }

  /// Ends the current native input at a platform lease boundary. This is not a
  /// user stop: the controller receives a silent retryable terminal event,
  /// resolves a fresh signed URL and starts the next attempt immediately.
  Future<void> refreshLease(String taskId) async {
    final session = _sessions[taskId];
    if (session == null || session.manualStop || session.leaseRefresh) return;
    session.leaseRefresh = true;
    log('FFmpeg lease refresh => $taskId (${session.sessionId})');
    await _requestSessionStop(session);
  }

  Future<void> _requestSessionStop(FFmpegRecordSession session) => session.stopRequest ??= () async {
    session.markStopRequested();
    final owned = session.ownedInput;
    final relay = session.flvInputRelay;
    if (owned != null) {
      final drained = await FFmpegInputDrain.tryFinish(
        finishInput: owned.finish,
        completion: session.completion.future,
        deadline: owned.drainTimeout,
      );
      if (drained) return;
    } else if (relay != null) {
      final drained = await FFmpegInputDrain.tryFinish(
        finishInput: relay.finish,
        completion: session.completion.future,
      );
      if (drained) return;
    } else if (session.inputRelay?.drainOnStop == true) {
      final hls = session.inputRelay!;
      final drained = await FFmpegInputDrain.tryFinish(
        finishInput: hls.finish,
        completion: session.completion.future,
        deadline: hls.drainTimeout,
      );
      if (drained) return;
    }
    if (session.completion.isCompleted) return;
    session.forcedCancel = true;
    _cancelSession(session.session);
    try {
      await session.completion.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      Log.w('FFmpeg stop timeout => taskId: ${session.taskId}; sessionId: ${session.sessionId}');
    }
  }();

  FFmpegRecordSession? getSession(String taskId) => _sessions[taskId];
  bool isRunning(String taskId) => _starts.containsKey(taskId) || _sessions.containsKey(taskId);

  static void _safeEmit(void Function(FFmpegEvent event) onEvent, FFmpegEvent event) {
    try {
      onEvent(event);
    } catch (error, stackTrace) {
      Log.e('FFmpeg event listener failed: $error', stackTrace);
    }
  }

  static String _friendlyError(int code, String logs, FFmpegFailureDiagnosis diagnosis) {
    switch (diagnosis.kind) {
      case FFmpegFailureKind.storageFull:
        return i18n('recorder_storage_full');
      case FFmpegFailureKind.outputPath:
        return i18n('path_or_permission_error');
      case FFmpegFailureKind.command:
        return i18n('param_error');
      case FFmpegFailureKind.httpAccess:
        if (logs.contains('404')) return i18n('url_expired_404');
        if (logs.contains('403')) return i18n('url_forbidden_403');
        return i18n('recorder_input_open_failed');
      case FFmpegFailureKind.transport:
        if (logs.contains('timed out')) return i18n('timeout');
        return i18n('recorder_transport_failed');
      case FFmpegFailureKind.inputOpen:
        return i18n('recorder_input_open_failed');
      case FFmpegFailureKind.inputFormat:
        return i18n('recorder_input_format_failed');
      case FFmpegFailureKind.decoder:
        return i18n('recorder_decoder_failed');
      case FFmpegFailureKind.native:
        break;
    }
    final lines = logs.trim().split('\n');
    final lastLine = lines.isEmpty ? '' : lines.last.trim();
    return i18n('unknown_error', args: {'error_log': lastLine.isEmpty ? 'code $code' : lastLine});
  }

  static String _sanitizeLogs(String logs) {
    return logs
        .replaceAll(RegExp(r'(?:https?|rtmps?|rtsp|srt|udp|rtp)://[^\s]+', caseSensitive: false), '[stream-url]')
        .replaceAllMapped(
          RegExp(r'^(cookie|authorization):.*$', caseSensitive: false, multiLine: true),
          (match) => '${match.group(1)}: [redacted]',
        )
        .replaceAllMapped(
          RegExp(r'((?:access_)?token|sign|auth|key|wssecret|txsecret)=([^&\s]+)', caseSensitive: false),
          (match) => '${match.group(1)}=[redacted]',
        );
  }

  static String _diagnosticTail(String logs, {int maxCharacters = 12000}) {
    final value = logs.trim();
    if (value.length <= maxCharacters) return value;
    return value.substring(value.length - maxCharacters);
  }
}

/// A bounded EOF/drain attempt. A timeout bounds waiting, not the lifetime of
/// native output: callers still cancel/await the real session before cleanup.
class FFmpegInputDrain {
  const FFmpegInputDrain._();
  static Future<bool> tryFinish({
    required Future<void> Function() finishInput,
    required Future<void> completion,
    Duration deadline = const Duration(seconds: 3),
  }) async {
    try {
      await Future<void>.sync(finishInput).then((_) => completion).timeout(deadline);
      return true;
    } on Object {
      return false;
    }
  }
}

/// Exact media-error diagnostics, not a blanket rejection of warnings.
/// A pictureless access unit is a parser error even when native remux returns
/// zero; preserve its source rather than committing/deleting on exit code alone.
/// Remuxing is still stream copy; this is not full codec bitstream validation.
class FFmpegMediaIntegrity {
  const FFmpegMediaIntegrity._();

  // A drained/cancelled live input can report a plain demux I/O error without
  // damaging output. Only explicit packet/bitstream damage taints its source.
  static bool hasPacketError(String message) {
    final value = message.toLowerCase();
    return const [
      'packet corrupt (stream',
      'corrupt input packet in stream',
      'pes packet size mismatch',
      'missing picture in access unit with size',
      'error while decoding',
      'corrupt decoded frame',
    ].any(value.contains);
  }

  static bool hasError(String message) {
    final value = message.toLowerCase();
    return const [
      'packet corrupt (stream',
      'corrupt input packet in stream',
      'pes packet size mismatch',
      'missing picture in access unit with size',
      'error writing trailer',
      'error muxing a packet',
      'error during demuxing',
    ].any(value.contains);
  }
}

class _RecordStartRequest {
  final cancel = CancelToken();
  final done = Completer<void>();
  bool nativeStarted = false;
  void check() {
    if (cancel.isCancelled) throw cancel.cancelError!;
  }
}
