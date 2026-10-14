import 'dart:async';
import 'dart:convert';

import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_json.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_play_parser.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_room_parser.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// The value wrappers spell their class name in their constructors; the `.new`
// shorthand would read as a field declaration at the call site. The socket
// subscription is owned by the seat and cancelled in [NiconicoSeat.close], not
// lexically in the method that creates it.
// ignore_for_file: unnecessary_type_name_in_constructor, cancel_subscriptions

/// The seat's outbound frames, as the wire JSON. Playback, recording and the
/// comment connection each open a seat and send these; the builders are pure
/// so the exact shape is testable without a socket.
abstract final class NiconicoSeatMessages {
  /// `startWatching`: an `abr`/`hls` high-latency stream, a `webSocket` room
  /// that is not commentable, no reconnect.
  static String get startWatching => jsonEncode({
    'type': 'startWatching',
    'data': {
      'stream': {'quality': 'abr', 'protocol': 'hls', 'latency': 'high', 'chasePlay': false},
      'room': {'protocol': 'webSocket', 'commentable': false},
      'reconnect': false,
    },
  });

  /// `getAkashic`: the program's title and images, no chase of history.
  static String get getAkashic => jsonEncode({
    'type': 'getAkashic',
    'data': {'chasePlay': false},
  });

  /// `keepSeat`: the every-interval heartbeat that holds the grant.
  static String get keepSeat => '{"type":"keepSeat"}';

  /// `pong`: the reply to the server's `ping`.
  static String get pong => '{"type":"pong"}';
}

/// One watching seat: the WebSocket that holds a program's stream grant.
///
/// The seat is owned by whoever opened it and never reconnects with an expired
/// bootstrap: when it ends, [done] names why and the owner reads the watch page
/// again. It sends [NiconicoSeatMessages.startWatching] and
/// [NiconicoSeatMessages.getAkashic] after the handshake; it is ready once both
/// a `seat` (with `keepIntervalSec`) and a `stream` grant arrived; a later
/// `stream` replaces the grant and revokes the old one; `keepSeat` goes out
/// every `keepIntervalSec`; a `ping` is answered with `pong` and one more
/// `keepSeat`; an `error` or `disconnect`, or the startup or silence timeout,
/// ends the seat. A `messageServer` frame names the comment server.
final class NiconicoSeat {
  /// A seat on the watch page's [socket]; [connect] opens it.
  NiconicoSeat(this.socket, {DateTime Function()? now, WebSocketChannel Function(Uri)? connector})
    : _now = now ?? DateTime.now,
      _connector = connector ?? WebSocketChannel.connect;

  /// The seat WebSocket (the watch page's `site.relive.webSocketUrl` with a
  /// `frontend_id`).
  final Uri socket;

  /// How long the seat may take to deliver both its `seat` and its `stream`.
  static const Duration startupTimeout = Duration(seconds: 20);

  /// How long a silent seat is held before it ends.
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// The broadcast of each new grant (the previous one is revoked).
  Stream<NiconicoGrant> get grants => _grants.stream;

  /// The current grant; null before the first `stream` or once revoked.
  NiconicoGrant? get currentGrant => _grant;

  /// The comment server (`messageServer.viewUri`) once announced.
  Uri? get messageServer => _messageServer;

  /// Whether the seat has ended.
  bool get isClosed => _closed;

  /// Completes when the seat has ended: null after a clean [close], else why it
  /// ended (a [NiconicoFailure]).
  Future<NiconicoFailure?> get done => _done.future;

  final DateTime Function() _now;
  final WebSocketChannel Function(Uri) _connector;

  final _grants = StreamController<NiconicoGrant>.broadcast();
  final _ready = Completer<void>();
  final _done = Completer<NiconicoFailure?>();
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _startup;
  Timer? _silence;
  Timer? _keep;
  NiconicoGrant? _grant;
  Uri? _messageServer;
  NiconicoFailure? _failure;
  bool _closed = false;
  int? _keepIntervalSeconds;

  /// Opens the socket, starts the handshake and waits (at most
  /// [startupTimeout]) for the seat and its first grant. A socket that is not
  /// the seat endpoint, or a handshake that never completes, throws a
  /// [NiconicoFailure].
  Future<void> connect() async {
    if (!NiconicoRoomParser.isSeatSocket(socket)) {
      throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'seat: not a seat WebSocket');
    }
    final channel = _connector(socket);
    try {
      await channel.ready.timeout(startupTimeout);
    } on Object catch (error) {
      await _quietly(channel.sink.close());
      throw NiconicoFailure(NiconicoFailureKind.network, 'seat handshake: $error', cause: error);
    }
    if (_closed) {
      await _quietly(channel.sink.close());
      return;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      _receive,
      onError: (Object error) => _end(NiconicoFailure(NiconicoFailureKind.network, 'seat: $error', cause: error)),
      onDone: () => _end(const NiconicoFailure(NiconicoFailureKind.network, 'seat closed by the server')),
    );
    _send(NiconicoSeatMessages.startWatching);
    _send(NiconicoSeatMessages.getAkashic);
    _startup = Timer(startupTimeout, () {
      _end(const NiconicoFailure(NiconicoFailureKind.network, 'seat: no seat and stream within startup'));
    });
    _resetSilence();
    await _ready.future;
  }

  void _receive(Object? frame) {
    if (_closed) return;
    if (frame is! String || frame.length > 1024 * 1024) {
      _end(const NiconicoFailure(NiconicoFailureKind.apiChanged, 'seat: not a text frame of at most 1 MiB'));
      return;
    }
    final Object? message;
    try {
      message = jsonDecode(frame);
    } on FormatException {
      _end(const NiconicoFailure(NiconicoFailureKind.apiChanged, 'seat: frame is not JSON'));
      return;
    }
    if (message is! Map<String, dynamic> || message['type'] is! String) {
      _end(const NiconicoFailure(NiconicoFailureKind.apiChanged, 'seat: message without a type'));
      return;
    }
    _resetSilence();
    final data = message['data'];
    switch (message['type']) {
      case 'ping':
        _send(NiconicoSeatMessages.pong);
        _send(NiconicoSeatMessages.keepSeat);
      case 'seat':
        try {
          _keepIntervalSeconds = NiconicoPlayParser.seatInterval(data);
        } on NiconicoFailure catch (failure) {
          _end(failure);
          return;
        }
        _keep?.cancel();
        _keep = Timer.periodic(Duration(seconds: _keepIntervalSeconds!), (_) => _send(NiconicoSeatMessages.keepSeat));
        _readyIfComplete();
      case 'stream':
        if (data is! Map<String, dynamic>) {
          _end(const NiconicoFailure(NiconicoFailureKind.apiChanged, 'seat: stream without data'));
          return;
        }
        final NiconicoGrant next;
        try {
          next = NiconicoPlayParser.grant(data, now: _now());
        } on NiconicoFailure catch (failure) {
          _end(failure);
          return;
        }
        _grant?.revoke();
        _grant = next;
        _grants.add(next);
        _readyIfComplete();
      case 'messageServer':
        final view = data is Map ? jsonUrl(data['viewUri']) : null;
        if (view != null) _messageServer = view;
      case 'error':
        _end(NiconicoPlayParser.seatError(data));
      case 'disconnect':
        _end(NiconicoPlayParser.seatDisconnect(data));
      // serverTime, schedule, statistics and the rest grant nothing.
    }
  }

  void _readyIfComplete() {
    if (_keepIntervalSeconds != null && _grant != null && !_ready.isCompleted) {
      _startup?.cancel();
      _ready.complete();
    }
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(silenceTimeout, () {
      _end(const NiconicoFailure(NiconicoFailureKind.network, 'seat silent past the timeout'));
    });
  }

  void _send(String frame) {
    final channel = _channel;
    if (_closed || channel == null) return;
    try {
      channel.sink.add(frame);
    } on Object catch (error) {
      _end(NiconicoFailure(NiconicoFailureKind.network, 'seat send: $error', cause: error));
    }
  }

  void _end(NiconicoFailure reason) {
    if (_closed) return;
    _failure = reason;
    unawaited(close());
  }

  /// Ends the seat: timers stop, the grant is revoked and the socket closed.
  /// Idempotent.
  Future<void> close() async {
    if (_closed) {
      await _done.future;
      return;
    }
    _closed = true;
    _startup?.cancel();
    _silence?.cancel();
    _keep?.cancel();
    _grant?.revoke();
    if (!_ready.isCompleted) {
      _ready.completeError(_failure ?? const NiconicoFailure(NiconicoFailureKind.streamUnavailable, 'seat closed'));
    }
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    await _quietly(subscription?.cancel() ?? Future<void>.value());
    await _quietly(channel?.sink.close() ?? Future<void>.value());
    unawaited(_grants.close());
    if (!_done.isCompleted) _done.complete(_failure);
  }

  static Future<void> _quietly(Future<void>? future) async {
    if (future == null) return;
    try {
      await future;
    } on Object {
      // Already closed or broken.
    }
  }
}
