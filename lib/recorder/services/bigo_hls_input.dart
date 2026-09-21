import 'package:dio/dio.dart';
import 'package:pure_live/core/site/bigo/bigo_api.dart';
import 'package:pure_live/core/site/bigo/bigo_hls_protection.dart';

import 'ffmpeg_hls_input_relay.dart';
import 'owned_record_input.dart';
import 'recorder_proxy_routing.dart';

typedef BigoRelayFactory = Future<FFmpegHlsInputRelay?> Function(
  Uri source, {
  required bool recording,
  required String Function(Uri) findProxy,
});

/// One consumer's short-lived Bigo status/media lease and private HLS relay.
/// Protected TS bytes are restored before they cross the loopback boundary.
final class BigoHlsInput implements OwnedRecordInput {
  BigoHlsInput._(this._relay);

  FFmpegHlsInputRelay? _relay;
  Future<void>? _closing;
  bool _closed = false;
  bool _finished = false;
  bool _tailDiscarded = false;
  Duration _lastDrainTimeout = Duration.zero;

  static Future<BigoHlsInput> open(
    String siteId, {
    required bool recording,
    BigoApi? api,
    String Function(Uri) findProxy = resolveRecorderProxyDirective,
    CancelToken? cancel,
    BigoRelayFactory? createRelay,
  }) async {
    final client = api ?? BigoApi();
    if (cancel?.isCancelled == true) throw const BigoException(BigoFailure.cancelled);
    final room = await client.studioRoom(siteId: siteId, cancel: cancel);
    if (cancel?.isCancelled == true) throw const BigoException(BigoFailure.cancelled);
    if (room.status.access != BigoAccess.public || room.status.reportedAlive != true || room.hls == null) {
      throw const BigoException(BigoFailure.api);
    }
    final factory = createRelay ?? _startRelay;
    final relay = await factory(room.hls!, recording: recording, findProxy: findProxy);
    if (relay == null) throw const BigoException(BigoFailure.schema);
    if (cancel?.isCancelled == true) {
      await relay.close();
      throw const BigoException(BigoFailure.cancelled);
    }
    return BigoHlsInput._(relay);
  }

  static Future<FFmpegHlsInputRelay?> _startRelay(
    Uri source, {
    required bool recording,
    required String Function(Uri) findProxy,
  }) => FFmpegHlsInputRelay.startForArguments(
    [
      '-rw_timeout',
      '20000000',
      '-headers',
      BigoApi.headers.entries.map((entry) => '${entry.key}: ${entry.value}\r\n').join(),
      '-i',
      source.toString(),
    ],
    force: true,
    drainOnStop: recording,
    findProxy: findProxy,
    manifestMediaTransform: (manifest, source) {
      if (!RegExp(r'^#EXTINF:', multiLine: true).hasMatch(source)) return null;
      final seed = BigoHlsProtection.seedFromManifest(source);
      return seed == null
          ? null
          : HlsMediaPrefixTransform(
              prefixBytes: 376,
              transform: (prefix) => BigoHlsProtection.transformSegment(prefix, seed),
            );
    },
  );

  FFmpegHlsInputRelay get _active {
    final relay = _relay;
    if (_closed || relay == null) throw StateError('Bigo HLS input is closed');
    return relay;
  }

  @override
  Uri get inputUri => _active.inputUri;

  @override
  bool get isClosed => _closed;

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
    _closed = true;
    final relay = _relay;
    if (relay == null) return;
    _finished = relay.finishRequested;
    _tailDiscarded = relay.inputTailDiscarded;
    _lastDrainTimeout = relay.drainTimeout;
    _relay = null;
    await relay.close();
    _finished = relay.finishRequested;
    _tailDiscarded = relay.inputTailDiscarded;
  }
}
