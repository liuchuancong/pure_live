import 'package:dio/dio.dart';
import 'package:pure_live/core/site/fc2live/fc2_api.dart';
import 'package:pure_live/core/site/fc2live/fc2_control_session.dart';

import 'ffmpeg_hls_input_relay.dart';
import 'owned_record_input.dart';
import 'recorder_proxy_routing.dart';

typedef Fc2RelayFactory = Future<FFmpegHlsInputRelay?> Function(
  Uri source, {
  required bool recording,
  required String Function(Uri) findProxy,
  required String channelId,
});

typedef Fc2SessionOpener = Future<Fc2ControlSession> Function(
  String channelId, {
  Fc2Api? api,
  required String Function(Uri) findProxy,
  CancelToken? cancel,
});

/// Private loopback input retaining the FC2 control WebSocket until its native
/// playback or recording consumer has completely released the HLS relay.
final class Fc2HlsInput implements OwnedRecordInput {
  Fc2HlsInput._(this._session, this._relay);

  Fc2ControlSession? _session;
  FFmpegHlsInputRelay? _relay;
  Future<void>? _closing;
  bool _closed = false;
  bool _finished = false;
  bool _tailDiscarded = false;
  Duration _lastDrainTimeout = Duration.zero;

  static Future<Fc2HlsInput> open(
    String channelId, {
    required bool recording,
    Fc2Api? api,
    String Function(Uri) findProxy = resolveRecorderProxyDirective,
    CancelToken? cancel,
    Fc2SessionOpener openSession = Fc2ControlSession.open,
    Fc2RelayFactory? createRelay,
  }) async {
    if (cancel?.isCancelled == true) throw const Fc2Exception(Fc2Failure.cancelled);
    final session = await openSession(channelId, api: api, findProxy: findProxy, cancel: cancel);
    if (cancel?.isCancelled == true) {
      await session.close();
      throw const Fc2Exception(Fc2Failure.cancelled);
    }
    try {
      final relay = await (createRelay ?? _startRelay)(
        session.master,
        recording: recording,
        findProxy: findProxy,
        channelId: session.channelId,
      );
      if (relay == null) throw const Fc2Exception(Fc2Failure.schema);
      if (cancel?.isCancelled == true) {
        await relay.close();
        throw const Fc2Exception(Fc2Failure.cancelled);
      }
      return Fc2HlsInput._(session, relay);
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  static Future<FFmpegHlsInputRelay?> _startRelay(
    Uri source, {
    required bool recording,
    required String Function(Uri) findProxy,
    required String channelId,
  }) => FFmpegHlsInputRelay.startForArguments(
    [
      '-rw_timeout',
      '20000000',
      '-headers',
      Fc2Api.mediaHeaders(channelId).entries.map((entry) => '${entry.key}: ${entry.value}\r\n').join(),
      '-i',
      source.toString(),
    ],
    force: true,
    drainOnStop: recording,
    findProxy: findProxy,
  );

  FFmpegHlsInputRelay get _active {
    final relay = _relay;
    if (_closed || relay == null) throw StateError('FC2 HLS input is closed');
    return relay;
  }

  @override
  Uri get inputUri => _active.inputUri;

  @override
  bool get isClosed => _closed || (_session?.isClosed ?? true);

  @override
  Duration get drainTimeout => _relay?.drainTimeout ?? _lastDrainTimeout;

  @override
  bool get finishRequested => _relay?.finishRequested ?? _finished;

  @override
  bool get inputTailDiscarded => _relay?.inputTailDiscarded ?? _tailDiscarded;

  @override
  set onCoverageIncomplete(void Function()? listener) {
    _active.onCoverageIncomplete = listener;
  }

  @override
  List<String> replaceFirstInput(Iterable<String> arguments) => _active.replaceFirstInput(arguments);

  @override
  Future<void> finish() => _active.finish();

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    final relay = _relay;
    final session = _session;
    try {
      if (relay != null) {
        _finished = relay.finishRequested;
        _tailDiscarded = relay.inputTailDiscarded;
        _lastDrainTimeout = relay.drainTimeout;
        _relay = null;
        await relay.close();
        _finished = relay.finishRequested;
        _tailDiscarded = relay.inputTailDiscarded;
      }
    } finally {
      _session = null;
      await session?.close();
    }
  }
}
