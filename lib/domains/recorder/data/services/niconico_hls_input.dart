import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/core/stream/hls_master_selection.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_session.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_stream.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_watch.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_contract.dart';

import 'owned_record_input.dart';
import 'cancellable_http_connections.dart';
import 'ffmpeg_hls_input_relay.dart';
import 'hls_body_reader.dart';

import 'package:pure_live/core/stream/hls_session_cookies.dart';

import 'hls_upstream_client.dart';

typedef NiconicoRelayFactory = Future<FFmpegHlsInputRelay> Function(
  Uri source,
  String? Function(Uri) cookies,
  HlsMasterSelection? selection,
);

/// One consumer's seat, current grant, master pre-read and private HLS relay.
/// Never persist this object or share it between playback and recording. A new
/// media root terminates the lease; the consumer must reacquire watch metadata.
class NiconicoHlsInput implements OwnedRecordInput {
  NiconicoHlsInput._();
  final _cancel = CancelToken();
  final _done = Completer<NiconicoFailure?>();
  Future<void>? _initializing;
  Future<void>? _closing;
  Future<void>? _seatClosing;
  Future<void>? _relayClosing;
  StreamSubscription<dynamic>? _parentCancellation;
  StreamSubscription<NiconicoStream>? _changes;
  NiconicoSession? _seat;
  NiconicoStream? _grant;
  FFmpegHlsInputRelay? _relay;
  Uri? _source;
  bool _closed = false;
  bool _cleanupSucceeded = false;
  bool _cleanupFailed = false;
  int _closedResourceCount = 0;
  int _closedKeepAlives = 0;
  NiconicoFailure? _failure;

  bool _finished = false;
  bool _tailDiscarded = false;
  Duration _lastDrainTimeout = Duration.zero;
  void Function()? _coverageListener;

  @override
  set onCoverageIncomplete(void Function()? listener) => _coverageListener = listener;
  @override
  bool get finishRequested => _relay?.finishRequested ?? _finished;
  @override
  bool get inputTailDiscarded => _relay?.inputTailDiscarded ?? _tailDiscarded;
  @override
  bool get isClosed => _closed;
  bool get cleanupSucceeded => _cleanupSucceeded;
  Future<NiconicoFailure?> get done => _done.future;
  int get retainedCookieCount => _grant?.retainedCookieCount ?? 0;
  int get seatKeepAlivesSent => _seat?.seatKeepAlivesSent ?? _closedKeepAlives;
  @visibleForTesting
  // ignore: invalid_use_of_visible_for_testing_member
  int get resourceCount => _relay?.resourceCount ?? _closedResourceCount;
  @visibleForTesting
  // ignore: invalid_use_of_visible_for_testing_member
  int get prefetchFeedCount => _relay?.prefetchFeedCount ?? 0;

  @override
  Uri get inputUri {
    _check();
    return _relay!.inputUri;
  }

  @override
  Duration get drainTimeout => _relay?.drainTimeout ?? _lastDrainTimeout;

  @override
  List<String> replaceFirstInput(Iterable<String> arguments) {
    _check();
    return _relay!.replaceFirstInput(arguments);
  }

  // A graceful recorder drain still needs a live seat until native completion.
  @override
  Future<void> finish() {
    _check();
    return _relay!.finish();
  }

  static Future<NiconicoHlsInput> open(
    NiconicoWatch watch, {
    required String? resolution,
    // Distinguish equal-resolution variants using their observed master bitrate.
    int? bandwidth,
    required bool recording,
    required String Function(Uri) findProxy,
    CancelToken? cancel,
    HlsRelayDiagnostics? diagnostics,
    NiconicoSeatFactory? openSeat,
    NiconicoMasterReader readMaster = readNiconicoMaster,
    NiconicoRelayFactory? createRelay,
  }) async {
    if (cancel?.isCancelled == true) throw const NiconicoException(NiconicoFailure.cancelled);
    if (bandwidth != null && (resolution == null || bandwidth <= 0)) {
      throw ArgumentError('A positive bandwidth selector requires an explicit resolution');
    }
    final input = NiconicoHlsInput._();
    input._parentCancellation = cancel?.whenCancel.asStream().listen((_) => input._end(NiconicoFailure.cancelled));
    input._initializing = input._initialize(
      watch,
      resolution,
      bandwidth,
      findProxy,
      openSeat ?? (watch, cancel, proxy) => NiconicoSession.open(watch, cancel: cancel, findProxy: proxy),
      readMaster,
      createRelay ??
          (source, cookies, selection) async {
            final relay = await FFmpegHlsInputRelay.startForArguments(
              ['-rw_timeout', '20000000', '-i', source.toString()],
              requestCookies: cookies,
              masterSelection: selection,
              findProxy: findProxy,
              drainOnStop: recording,
              enablePrefetch: recording && selection != null,
              diagnostics: diagnostics,
            );
            if (relay == null) throw const NiconicoException(NiconicoFailure.schema);
            return relay;
          },
    );
    try {
      await input._initializing;
      input._check();
      return input;
    } catch (error) {
      input._failure ??= error is NiconicoException
          ? error.kind
          : error is FormatException
          ? NiconicoFailure.schema
          : NiconicoFailure.transport;
      await input.close();
      throw NiconicoException(input._failure!);
    }
  }

  Future<void> _initialize(
    NiconicoWatch watch,
    String? resolution,
    int? bandwidth,
    String Function(Uri) findProxy,
    NiconicoSeatFactory openSeat,
    NiconicoMasterReader readMaster,
    NiconicoRelayFactory createRelay,
  ) async {
    // Take ownership before checking cancellation, including late factory results.
    final seat = _seat = await openSeat(watch, _cancel, findProxy);
    if (_closed) return;
    _grant = seat.current;
    _source = _grant!.uri;
    _changes = seat.changes.listen((grant) {
      _grant = grant;
      if (grant.uri != _source) _end(NiconicoFailure.sessionClosed);
    }, onError: (Object _) => _end(NiconicoFailure.transport));
    unawaited(seat.done.then((reason) => _end(reason ?? NiconicoFailure.sessionClosed)));
    HlsMasterSelection? selection;
    if (resolution != null) {
      final text = await readMaster(_source!, _cookies, _cancel, findProxy);
      _check();
      final variants = HlsMasterPlaylist.parse(_source!, text).variants
          .where(
            (variant) =>
                variant.attributes['RESOLUTION'] == resolution &&
                (bandwidth == null || variant.attributes['BANDWIDTH'] == '$bandwidth'),
          )
          .toList();
      if (variants.length != 1) throw const NiconicoException(NiconicoFailure.schema);
      selection = HlsMasterSelection.fromMaster(text, source: _source!, video: variants.single.uri);
    }
    _check();
    _relay = await createRelay(_source!, _cookies, selection);
    _relay!.onCoverageIncomplete = () => _coverageListener?.call();
    _check();
  }

  void _check() {
    if (_closed || _cancel.isCancelled) throw NiconicoException(_failure ?? NiconicoFailure.sessionClosed);
    final grant = _seat!.current;
    if (grant.uri != _source) {
      _end(NiconicoFailure.sessionClosed);
      throw const NiconicoException(NiconicoFailure.sessionClosed);
    }
    _grant = grant;
  }

  String? _cookies(Uri uri) {
    _check();
    return _grant!.cookieHeaderFor(uri);
  }

  void _end(NiconicoFailure reason) {
    if (_closed) return;
    _failure = reason;
    // done reports cleanup failures even when there is no caller awaiting close.
    unawaited(close().catchError((Object _) {}));
  }

  @override
  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _cancel.cancel();
    return _closing = _dispose();
  }

  Future<void> _cleanupStep(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _cleanupFailed = true;
    }
  }

  Future<void> _release() {
    final parent = _parentCancellation;
    final changes = _changes;
    _parentCancellation = null;
    _changes = null;
    final seat = _seat;
    final relay = _relay;
    return Future.wait<void>([
      if (parent != null) _cleanupStep(parent.cancel),
      if (changes != null) _cleanupStep(changes.cancel),
      if (seat != null)
        _seatClosing ??= _cleanupStep(() async {
          await seat.close();
          if (!seat.cleanupSucceeded) throw const NiconicoException(NiconicoFailure.cleanup);
        }),
      if (relay != null) _relayClosing ??= _cleanupStep(relay.close),
    ]).then((_) {});
  }

  Future<void> _dispose() async {
    final early = _release();
    // Never abandon a late allocation or wait for it before closing live peers.
    try {
      await _initializing;
    } catch (_) {
      // open owns the initialization error, disposal still joins every resource.
    }
    // Start late resource cleanup even while an early peer is still closing.
    final late = _release();
    await Future.wait([early, late]);
    _grant?.close();
    _closedKeepAlives = _seat?.seatKeepAlivesSent ?? 0;
    // Only sanitized counters survive teardown, not signed roots/bootstrap URLs.
    // ignore: invalid_use_of_visible_for_testing_member
    _closedResourceCount = _relay?.resourceCount ?? 0;
    _finished = _relay?.finishRequested ?? _finished;
    _tailDiscarded = _relay?.inputTailDiscarded ?? _tailDiscarded;
    _lastDrainTimeout = _relay?.drainTimeout ?? _lastDrainTimeout;
    _coverageListener = null;
    _source = null;
    _grant = null;
    _seat = null;
    _relay = null;
    _initializing = null;
    _seatClosing = null;
    _relayClosing = null;
    _cleanupSucceeded = !_cleanupFailed;
    if (_cleanupFailed) _failure = NiconicoFailure.cleanup;
    _done.complete(_failure);
    if (_cleanupFailed) throw const NiconicoException(NiconicoFailure.cleanup);
  }
}

/// Bounded master pre-read with owned DNS/TCP/TLS and body cancellation. Runtime
/// cookies are evaluated on the actual request; a redirect is not a new root.
Future<String> readNiconicoMaster(
  Uri source,
  String? Function(Uri) cookies,
  CancelToken cancel,
  String Function(Uri) findProxy,
) async {
  if (cancel.isCancelled) throw const NiconicoException(NiconicoFailure.cancelled);
  final connections = CancellableHttpConnections();
  final client = HttpClient()
    ..connectionFactory = connections.connect
    ..connectionTimeout = const Duration(seconds: 10)
    ..findProxy = findProxy;
  final jar = HlsSessionCookies();
  final upstream = HlsUpstreamClient(
    client: client,
    source: source,
    headers: const {},
    cookies: jar,
    requestCookies: cookies,
  );
  HlsBodyReader? reader;
  void abort() {
    upstream.stop();
    if (reader != null) unawaited(reader.cancel().catchError((Object _) {}));
    client.close(force: true);
    connections.cancel();
  }

  final cancellation = cancel.whenCancel.asStream().listen((_) => abort());
  final budget = HlsResponseBudget(const Duration(seconds: 5));
  try {
    final (response, finalUri) = await upstream.open('GET', source, budget: budget);
    reader = HlsBodyReader(response);
    if (cancel.isCancelled) throw const NiconicoException(NiconicoFailure.cancelled);
    if (response.statusCode != 200 || finalUri != source) throw const NiconicoException(NiconicoFailure.schema);
    final bytes = <int>[];
    while (await budget.wait(reader.moveNext, abort: abort)) {
      if (cancel.isCancelled) throw const NiconicoException(NiconicoFailure.cancelled);
      final chunk = reader.current;
      if (bytes.length + chunk.length > 4 * 1024 * 1024) throw const NiconicoException(NiconicoFailure.schema);
      bytes.addAll(chunk);
    }
    if (cancel.isCancelled) throw const NiconicoException(NiconicoFailure.cancelled);
    return utf8.decode(bytes);
  } catch (_) {
    if (cancel.isCancelled) throw const NiconicoException(NiconicoFailure.cancelled);
    rethrow;
  } finally {
    abort();
    try {
      await Future.wait<void>([cancellation.cancel(), if (reader != null) reader.cancel(), connections.settled]);
    } finally {
      upstream.clear();
      jar.clear();
    }
  }
}
