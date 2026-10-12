import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_parser.dart';
import 'package:live_sites/src/registry/site_ids/site_ids.dart';

/// What a Missevan chat session needs: the room, its socket URL (the room
/// detail's `websocket`) and the API headers the guest-session request is sent
/// with.
final class MissevanDanmakuArgs {
  /// A chat join target.
  const new({required this.roomId, required this.url, required this.headers});

  /// The room number.
  final String roomId;

  /// The room's socket URL.
  final Uri url;

  /// The site's API headers (origin, UA) the guest session and handshake use.
  final Map<String, String> headers;
}

/// Missevan's chat: a guest session over [LiveHttp], then the room's chat
/// socket.
///
/// - A guest session (`api/user/info`, `FM_SESS`) is asked up to three times
///   (0.5 s and 1 s apart); without one the connect throws.
/// - At open the socket sends the join; the room is joined when the server
///   accepts it, and a join not answered within 5 s ends the stream.
/// - The heartbeat `❤️` goes out every 30 s and the server echoes it, so a
///   socket silent for 90 s ends the stream; a refused join ends it too.
/// - Unlike the reference, which renews the guest session and reopens on a
///   refused join or an expired handshake, this build ends the stream and the
///   caller's supervisor reconnects (the same division as the looklive and yy
///   sessions).
///
/// Archived from the reference and not run against the live service.
final class MissevanDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  MissevanDanmakuSession._(this._args, this._socket, this._uuid) {
    _heartbeat = Timer.periodic(MissevanDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(MissevanDanmakuProtocol.heartbeat);
    });
    _joinTimer = Timer(MissevanDanmakuProtocol.joinTimeout, () {
      if (!_joined) _fail(const SiteApiChangedError('missevan chat: join timed out'));
    });
    _resetSilence();
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
    _socket.add(MissevanDanmakuProtocol.join(_args.roomId, uuid: _uuid));
  }

  static const int _sessionAttempts = 3;
  static const Duration _sessionTimeout = Duration(seconds: 5);

  /// Opens a session for [args] over [http]: it first asks for a guest session,
  /// then connects the socket. [random] makes the join's `uuid`.
  static Future<MissevanDanmakuSession> connect(MissevanDanmakuArgs args, LiveHttp http, {Random? random}) async {
    if (!MissevanParser.idPattern.hasMatch(args.roomId)) {
      throw const SiteApiChangedError('missevan chat: not a room id');
    }
    final endpoint = MissevanDanmakuProtocol.endpoint(args.url, roomId: args.roomId);
    String? session;
    Object? failure;
    for (var attempt = 0; attempt < _sessionAttempts && session == null; attempt++) {
      if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 500) * attempt);
      try {
        final response = await http.send(
          LiveRequest.get(
            MissevanParser.guestSession,
            headers: args.headers,
            timeout: _sessionTimeout,
            site: SiteIds.missevan,
          ),
        );
        if (response.isOk) {
          session = MissevanDanmakuProtocol.session([response.headers['set-cookie'] ?? '']);
        } else {
          failure = 'Guest session: HTTP ${response.statusCode}';
        }
      } on Object catch (error) {
        failure = error;
      }
    }
    if (session == null) {
      throw SiteNeedsLoginError('missevan chat: no guest session (${failure ?? 'none'})');
    }
    final socket = await WebSocket.connect(
      endpoint.toString(),
      headers: MissevanDanmakuProtocol.handshakeHeaders(args.headers, session),
    );
    return MissevanDanmakuSession._(args, socket, MissevanDanmakuProtocol.uuid(random ?? Random.secure()));
  }

  final MissevanDanmakuArgs _args;
  final WebSocket _socket;
  final String _uuid;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final StreamSubscription<Object?> _subscription;
  late final Timer _heartbeat;
  late final Timer _joinTimer;
  Timer? _silence;
  bool _joined = false;
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(Object? data) {
    if (_closed) return;
    _resetSilence();
    final frame = MissevanDanmakuProtocol.decode(data, roomId: _args.roomId, uuid: _uuid, receivedAt: DateTime.now());
    frame.messages.forEach(_messages.add);
    switch (frame.joined) {
      case true:
        _joined = true;
        _joinTimer.cancel();
      case false:
        _fail(SiteApiChangedError('missevan chat: join refused (${frame.refusal})'));
      default:
        break;
    }
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(
      const Duration(seconds: 90),
      () => _fail(const SiteApiChangedError('missevan chat: socket silent')),
    );
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
    _silence?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_socket.close());
    if (!_messages.isClosed) {
      _messages.addError(error, stack ?? StackTrace.current);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
    _silence?.cancel();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
    _silence?.cancel();
    await _subscription.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
