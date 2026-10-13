import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/niconico/niconico_models.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_parser.dart';

/// One watching seat for playback: the WebSocket that holds a program's stream
/// grant. Text frames only; `startWatching` (abr, hls, high latency, no
/// comments, no reconnect) and `getAkashic` after the handshake; the seat is
/// ready once both a `seat` (its `keepIntervalSec`) and a `stream` (its grant)
/// arrived; a later `stream` replaces the grant and revokes the old one;
/// `keepSeat` every `keepIntervalSec`; `ping` is answered with `pong` and one
/// more `keepSeat`; `error` and `disconnect` end the seat, as does 90 s of
/// silence. It never reconnects — when it ends, [close] is the owner's cue to
/// read the watch page and open a fresh seat.
final class NiconicoStreamSeat {
  // A private named constructor cannot use the `new` shorthand (as in the
  // niconico danmaku and kick sessions).
  // ignore: unnecessary_type_name_in_constructor
  NiconicoStreamSeat._(this._socket);

  /// Opens a seat on the watch page's [socket] and waits, at most
  /// [_startupTimeout], for its first grant.
  static Future<NiconicoStreamSeat> open(Uri socket) async {
    if (!NiconicoParser.isSeatSocket(socket)) {
      throw const SiteApiChangedError('niconico seat: not a seat WebSocket');
    }
    final WebSocket channel;
    try {
      channel = await WebSocket.connect(
        socket.toString(),
        headers: const {'origin': NiconicoParser.origin},
      ).timeout(_startupTimeout);
    } on Object {
      throw const SiteApiChangedError('niconico seat handshake failed');
    }
    final seat = NiconicoStreamSeat._(channel);
    channel.listen(
      seat._receive,
      onError: (Object _) => seat._end(const SiteApiChangedError('niconico seat error')),
      onDone: () => seat._end(const SiteApiChangedError('niconico seat closed')),
      cancelOnError: true,
    );
    seat
      .._resetSilence()
      .._send({
        'type': 'startWatching',
        'data': {
          'stream': {'quality': 'abr', 'protocol': 'hls', 'latency': 'high', 'chasePlay': false},
          'room': {'protocol': 'webSocket', 'commentable': false},
          'reconnect': false,
        },
      })
      .._send({
        'type': 'getAkashic',
        'data': {'chasePlay': false},
      });
    try {
      await seat._ready.future.timeout(_startupTimeout);
      return seat;
    } on Object catch (error) {
      await seat.close();
      throw error is SiteError ? error : const SiteStreamUnavailableError('niconico seat got no stream grant');
    }
  }

  final WebSocket _socket;
  final Completer<void> _ready = Completer<void>();
  final StreamController<NiconicoGrant> _changes = StreamController<NiconicoGrant>.broadcast();
  Timer? _silence;
  Timer? _keep;
  NiconicoGrant? _grant;
  int? _keepIntervalSeconds;
  Object? _failure;
  bool _closed = false;

  /// The seat's current grant; a [SiteStreamUnavailableError] once the seat has
  /// ended or no grant arrived.
  NiconicoGrant get current {
    final grant = _grant;
    if (_closed || grant == null || _keepIntervalSeconds == null) {
      throw const SiteStreamUnavailableError('niconico: the seat is closed');
    }
    return grant;
  }

  /// Each new grant (the previous one is revoked).
  Stream<NiconicoGrant> get changes => _changes.stream;

  /// The seat handshake, media and silence bounds (the reference's seat).
  static const Duration _startupTimeout = Duration(seconds: 20);
  static const Duration _silenceTimeout = Duration(seconds: 90);

  void _receive(Object? frame) {
    if (_closed) {
      return;
    }
    _resetSilence();
    if (frame is! String || frame.length > 1024 * 1024) {
      return;
    }
    final Object? message;
    try {
      message = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (message is! Map<String, Object?> || message['type'] is! String) {
      return;
    }
    final data = message['data'];
    switch (message['type']) {
      case 'ping':
        _send({'type': 'pong'});
        _keepSeat();
      case 'seat':
        _keepIntervalSeconds = NiconicoStream.seatInterval(data);
        _keep?.cancel();
        final seconds = _keepIntervalSeconds!;
        _keep = Timer.periodic(Duration(seconds: seconds), (_) => _keepSeat());
        _readyIfComplete();
      case 'stream':
        if (data is! Map<String, Object?>) {
          _end(const SiteApiChangedError('niconico seat: stream without data'));
          return;
        }
        final NiconicoGrant next;
        try {
          next = NiconicoStream.grant(data);
        } on SiteError catch (error) {
          _end(error);
          return;
        }
        _grant?.revoke();
        _grant = next;
        _readyIfComplete();
        _changes.add(next);
      case 'error':
        _end(NiconicoStream.seatError(data));
      case 'disconnect':
        _end(NiconicoStream.seatDisconnect(data));
    }
  }

  void _readyIfComplete() {
    if (_keepIntervalSeconds != null && _grant != null && !_ready.isCompleted) {
      _ready.complete();
    }
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(_silenceTimeout, () => _end(const SiteApiChangedError('niconico seat silent')));
  }

  void _keepSeat() {
    if (_keepIntervalSeconds != null) {
      _send({'type': 'keepSeat'});
    }
  }

  bool _send(Map<String, Object?> message) {
    if (_closed) {
      return false;
    }
    try {
      _socket.add(jsonEncode(message));
      return true;
    } on Object {
      _end(const SiteApiChangedError('niconico seat send failed'));
      return false;
    }
  }

  void _end(Object reason) {
    if (_closed) {
      return;
    }
    _failure = reason;
    unawaited(close());
  }

  /// Ends the seat: timers stop, the grant is revoked and the socket is closed.
  /// Idempotent.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _silence?.cancel();
    _keep?.cancel();
    _grant?.revoke();
    if (!_ready.isCompleted) {
      final failure = _failure;
      _ready.completeError(
        failure is SiteError ? failure : const SiteStreamUnavailableError('niconico: the seat was closed'),
      );
    }
    unawaited(_changes.close());
    try {
      await _socket.close();
    } on Object {
      // Already closed or broken.
    }
  }

  /// Whether the seat has ended.
  bool get isClosed => _closed;
}
