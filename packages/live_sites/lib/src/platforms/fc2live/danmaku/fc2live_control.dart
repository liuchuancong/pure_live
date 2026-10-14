import 'dart:async';
import 'dart:convert';

import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_play_parser.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The socket a control or a comment connection speaks through: the frames the
/// site sends, a way to send one's own, and why the site closed it.
///
/// This narrow shape exists so that a test can drive a socket by hand: the
/// platform's own WebSocket channel is a wider thing, and neither a control nor
/// a chat connection uses more of it than this.
abstract interface class Fc2LiveSocket {
  /// The frames the site sends, which ends when the socket closes.
  Stream<Object?> get frames;

  /// Why the site closed the socket, once it has.
  int? get closeCode;

  /// Sends one text frame.
  void send(String frame);

  /// Closes the socket; a socket already gone is not an error.
  Future<void> close();
}

/// How a socket is made: the grant's endpoint and handshake headers, with the
/// wait bounded by the caller's own timeout. The default is [Fc2LiveControl.io],
/// and a caller may pass another (tests).
typedef Fc2LiveSocketConnect = Future<Fc2LiveSocket> Function(
  Uri endpoint, {
  required Map<String, String> headers,
  required Duration connectTimeout,
});

/// One FC2 Live media control: the WebSocket whose session authorizes a
/// channel's HLS playlists.
///
/// The media server answers a playlist only while the control that was told
/// about it is open, so whoever opens one keeps it open for exactly as long as
/// its consumer reads the playlist, and closes it afterwards. A control never
/// reconnects with a used grant: [done] says why it ended and its owner takes a
/// fresh one (which is what a line's lease is for).
///
/// The protocol is the site's own: the handshake carries the origin, the agent
/// and the grant's session cookie; after `connect_complete` the control asks
/// for the HLS information exactly once, and is open when the answer names a
/// playlist of its quality. Only text frames of at most
/// [Fc2LiveEndpoints.messageLimit] characters are understood — anything else,
/// `control_disconnection` (4500 is the grant's own expiry), an error or the
/// socket closing ends the control. The comment connection, which speaks the
/// same protocol on a socket of its own, is more forgiving of a frame it cannot
/// read; a control is not, because an answer it cannot parse means it never got
/// the playlist it opened for.
final class Fc2LiveControl {
  /// A control of [grant], asked to play [requestedQuality], whose close waits
  /// its own bounded time for the socket.
  Fc2LiveControl._(this.grant, this.requestedQuality, this._closeTimeout);

  /// Opens the control socket of [grant] for [quality] with [connect], waiting
  /// at most [startupTimeout] for the handshake and the answer together.
  ///
  /// A quality that is not one of [Fc2LivePlayParser.qualityIds] is a caller
  /// error and opens nothing. [timer] makes the startup wait (a test's own
  /// clock); once open, the control belongs to its caller, who closes it.
  static Future<Fc2LiveControl> open(
    Fc2LiveGrant grant, {
    required Fc2LiveSocketConnect connect,
    String quality = Fc2LivePlayParser.autoQualityId,
    Duration startupTimeout = Fc2LiveEndpoints.requestTimeout,
    Duration closeTimeout = Fc2LiveEndpoints.closeTimeout,
    Timer Function(Duration delay, void Function() callback)? timer,
  }) async {
    final timerOf = timer ?? Timer.new;
    final control = Fc2LiveControl._(grant, quality, closeTimeout);
    if (!Fc2LivePlayParser.qualityIds.contains(quality)) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.invalidArgument, 'quality "$quality" is not an FC2 Live quality');
    }
    final startup = timerOf(startupTimeout, () {
      control._end(
        Fc2LiveFailure(Fc2LiveFailureKind.network, 'control: no HLS information within ${startupTimeout.inSeconds} s'),
      );
    });
    control._startup = startup;
    unawaited(control._handshake(connect));
    try {
      await control._ready.future;
    } on Object {
      await control.close();
      rethrow;
    }
    return control;
  }

  /// The default connector: `dart:io`, with the site's own WebSocket ping every
  /// [Fc2LiveControl.pingInterval] (the page keeps its sockets alive that way).
  static Future<Fc2LiveSocket> io(
    Uri endpoint, {
    required Map<String, String> headers,
    required Duration connectTimeout,
  }) async {
    final channel = IOWebSocketChannel.connect(endpoint, headers: headers, pingInterval: pingInterval);
    await channel.ready.timeout(connectTimeout);
    return _ChannelSocket(channel);
  }

  /// The site's WebSocket ping period.
  static const Duration pingInterval = Duration(seconds: 15);

  /// The one request the control sends, byte for byte as the page sends it.
  static const String hlsRequest = '{"name":"get_hls_information","arguments":{},"id":1}';

  /// The grant this control was opened with (used once: a socket, not a ticket).
  final Fc2LiveGrant grant;

  /// The quality asked for.
  final String requestedQuality;

  final Duration _closeTimeout;
  final Completer<void> _ready = Completer<void>();
  final Completer<Fc2LiveFailure?> _done = Completer<Fc2LiveFailure?>();

  Fc2LiveSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _startup;
  Map<int, Uri>? _playlists;
  Fc2LivePlaylist? _playlist;
  Fc2LiveFailure? _failure;
  Future<void>? _closing;
  bool _closed = false;
  bool _requested = false;

  /// The channel.
  String get channelId => grant.channelId;

  /// Every playlist the HLS answer named, by mode.
  Map<int, Uri> get playlists => _playlists ?? (throw StateError('the control never opened'));

  /// The playlist to play, and the quality it is: [requestedQuality], or the
  /// tier it fell back to when the channel no longer offers that one.
  Fc2LivePlaylist get playlist => _playlist ?? (throw StateError('the control never opened'));

  /// The headers every request for [playlist] needs.
  Map<String, String> get mediaHeaders => Fc2LiveEndpoints.mediaHeaders(channelId);

  /// Completes when the control has ended: null after [close], else why.
  Future<Fc2LiveFailure?> get done => _done.future;

  /// Whether the control has ended: its playlist is not worth asking for.
  bool get isClosed => _closed;

  Future<void> _handshake(Fc2LiveSocketConnect connect) async {
    final Fc2LiveSocket socket;
    try {
      socket = await connect(
        grant.endpoint,
        headers: grant.handshakeHeaders,
        connectTimeout: Fc2LiveEndpoints.connectTimeout,
      );
    } on Object catch (error) {
      _end(Fc2LiveFailure(Fc2LiveFailureKind.network, 'control handshake: ${error.runtimeType}', cause: error));
      return;
    }
    if (_closed) {
      // The control ended (in its startup timeout) while the handshake waited.
      unawaited(_quietly(socket.close()));
      return;
    }
    _socket = socket;
    await _subscription?.cancel();
    _subscription = socket.frames.listen(
      _receive,
      onDone: () {
        final code = socket.closeCode;
        _end(
          Fc2LiveFailure(Fc2LiveFailureKind.network, 'control closed by the server${code == null ? '' : ' ($code)'}'),
        );
      },
      onError: (Object error) =>
          _end(Fc2LiveFailure(Fc2LiveFailureKind.network, 'control: ${error.runtimeType}', cause: error)),
      cancelOnError: true,
    );
  }

  void _receive(Object? frame) {
    if (_closed) return;
    Fc2LiveFailure? failure;
    try {
      failure = _read(frame);
    } on Fc2LiveFailure catch (error) {
      failure = error;
    }
    if (failure != null) _end(failure);
  }

  /// One frame: null when it left the control waiting, and the reason it ended
  /// when it was one the control cannot go on from.
  ///
  /// Only text of at most [Fc2LiveEndpoints.messageLimit] characters that is a
  /// JSON object with a name is read at all; anything else ends the control,
  /// because an answer the control cannot parse means the playlist it opened for
  /// never arrived. `connect_complete` is answered with the one request, and the
  /// reply to that request (id 1, no playlist yet) is what opens the control.
  Fc2LiveFailure? _read(Object? frame) {
    if (frame is! String || frame.length > Fc2LiveEndpoints.messageLimit) {
      throw const Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'control: not a text frame of at most 2 MiB');
    }
    final Object? message;
    try {
      message = jsonDecode(frame);
    } on FormatException {
      throw const Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'control: frame is not JSON');
    }
    if (message is! Map) throw const Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'control: message is not an object');
    switch (message['name']) {
      case 'connect_complete':
        if (!_requested) {
          _requested = true;
          _send(hlsRequest);
        }
      case '_response_' when message['id'] == 1 && _requested && _playlist == null:
        final playlists = Fc2LivePlayParser.hlsPlaylists(Map<String, Object?>.from(message), channelId: channelId);
        final playlist = Fc2LivePlayParser.playlistFor(playlists, requestedQuality);
        if (playlist == null) {
          throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'control: no playlist for $requestedQuality');
        }
        _playlists = playlists;
        _playlist = playlist;
        _startup?.cancel();
        if (!_ready.isCompleted) _ready.complete();
      case 'control_disconnection':
        final arguments = message['arguments'];
        final code = arguments is Map ? arguments['code'] : null;
        // 4500 is the grant's own expiry; the site ends any control the same
        // way, so its consumer takes a fresh grant.
        return Fc2LiveFailure(Fc2LiveFailureKind.network, 'control_disconnection${code == null ? '' : ' $code'}');
      // `initial_connect`, `connect_data`, `user_count`, the comments and the
      // rest grant nothing to a control.
    }
    return null;
  }

  void _send(String text) {
    final socket = _socket;
    if (_closed || socket == null) return;
    try {
      socket.send(text);
    } on Object catch (error) {
      _end(Fc2LiveFailure(Fc2LiveFailureKind.network, 'control send: ${error.runtimeType}', cause: error));
    }
  }

  void _end(Fc2LiveFailure reason) {
    if (_closed) return;
    _failure = reason;
    unawaited(close());
  }

  /// Ends the control: the startup wait stops and the socket is closed, at most
  /// [Fc2LiveEndpoints.closeTimeout] for it. Idempotent.
  Future<void> close() => _closing ??= _dispose();

  Future<void> _dispose() async {
    _closed = true;
    _startup?.cancel();
    if (!_ready.isCompleted) {
      _ready.completeError(_failure ?? const Fc2LiveFailure(Fc2LiveFailureKind.network, 'the control was closed'));
    }
    final subscription = _subscription;
    final socket = _socket;
    _subscription = null;
    _socket = null;
    await Future.wait<void>([
      if (subscription != null) _quietly(subscription.cancel()),
      if (socket != null) _quietly(socket.close()),
    ]).timeout(_closeTimeout, onTimeout: () => const []);
    if (!_done.isCompleted) _done.complete(_failure);
  }

  static Future<void> _quietly(Future<void> future) async {
    try {
      await future;
    } on Object {
      // Already closed or broken.
    }
  }
}

/// [Fc2LiveSocket] over a [WebSocketChannel].
final class _ChannelSocket implements Fc2LiveSocket {
  _ChannelSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<Object?> get frames => _channel.stream;

  @override
  int? get closeCode => _channel.closeCode;

  @override
  void send(String frame) => _channel.sink.add(frame);

  @override
  Future<void> close() async {
    try {
      await _channel.sink.close();
    } on Object {
      // A socket already gone is closed for our purposes.
    }
  }
}
