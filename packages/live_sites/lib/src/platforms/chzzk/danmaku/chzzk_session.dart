import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/chzzk/danmaku/chzzk_danmaku.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_parser.dart';

/// A CHZZK danmaku session: one chat socket at a time, replaced as the
/// site's own client replaces its.
///
/// Lifecycle per socket: the live's state names the chat channel, the token
/// endpoint names an access token (up to three tries, as the site's client),
/// the routing endpoint names the session servers (the SDK's built-in list
/// as fallback), and one of them takes the socket: join (`cmd 100`) → the
/// answer's session id opens the recent chat (`cmd 5101`) → chat and
/// ping/pong, a ping every twenty seconds.
///
/// The socket is replaced when it drops, when the join is refused with one
/// of the retry codes (302/303/304, which the site's SDK also reconnects
/// on), or when it goes quiet for [ChzzkDanmakuProtocol.quietPeriod] — the
/// quiet check then asks the live's state, because the streamer may have
/// gone live again with another chat channel. A refusal without a retry
/// code, the server ending the session, or a channel with no open chat at
/// all ends the run with an error on the stream; the caller's supervisor
/// owns the retry policy, as with every adapter here.
final class ChzzkDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand on this
  // analyzer, so the traditional form stays by design (the same as the
  // showroom and bilibili sessions).
  // ignore: unnecessary_type_name_in_constructor
  ChzzkDanmakuSession._(this._http, this._channelId) {
    unawaited(_run());
  }

  final LiveHttp _http;

  /// The channel the live plays on; the chat channel may change when the
  /// streamer goes live again.
  final String _channelId;

  final _messages = StreamController<LiveMessage>.broadcast();
  WebSocket? _socket;
  Timer? _heartbeat;
  Timer? _quiet;

  /// Completes when the current socket is torn down; [_run] waits on it.
  Completer<void>? _socketDone;

  /// The channel the current socket joined, which the quiet check compares
  /// against; null before the join's answer.
  String? _joinedChannel;

  bool _closed = false;

  /// Opens a session for the channel [channelId] over [http].
  static Future<ChzzkDanmakuSession> connect(LiveHttp http, String channelId) async {
    return ChzzkDanmakuSession._(http, channelId);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  /// Runs sockets until the session closes or fails for good.
  Future<void> _run() async {
    var round = 0;
    while (!_closed) {
      final done = Completer<void>();
      _socketDone = done;
      final opened = await _open(round++);
      if (_closed) {
        return;
      }
      if (!opened) {
        // The channel has no open chat (or no token, or no server): a
        // permanent answer about this live, not a dropped socket.
        _fail(StateError('chzzk: the channel has no open chat'));
        return;
      }
      await done.future;
    }
  }

  /// Opens one socket and arms its join, heartbeat and quiet timer. Answers
  /// whether a socket was opened at all; the socket itself runs until
  /// [_replace] tears it down.
  Future<bool> _open(int round) async {
    final channel = await _chatChannel();
    if (_closed) {
      return false;
    }
    if (channel == null) {
      return false;
    }
    final token = await _token(channel);
    if (_closed) {
      return false;
    }
    if (token == null) {
      return false;
    }
    final servers = await _servers();
    final endpoints = ChzzkDanmakuProtocol.endpoints(servers, (DateTime.now().millisecond + round) % servers.length);
    Object? lastError;
    for (final endpoint in endpoints) {
      if (_closed) {
        return false;
      }
      try {
        final socket = await WebSocket.connect(
          endpoint.toString(),
          headers: ChzzkDanmakuProtocol.handshakeHeaders,
        ).timeout(ChzzkDanmakuProtocol.quietPeriod);
        _joinedChannel = null;
        _pendingChannel = channel;
        _socket = socket;
        socket.add(ChzzkDanmakuProtocol.join(channel, token));
        _armHeartbeat(socket);
        _armQuiet();
        socket.listen(_onData, onError: _replace, onDone: () => _replace(null, null));
        return true;
      } on Object catch (error) {
        lastError = error;
      }
    }
    _fail(lastError ?? StateError('chzzk: no chat server answered'));
    return false;
  }

  /// The chat channel of the live now, or null when it has none.
  Future<String?> _chatChannel() async {
    try {
      final response = await _http.send(
        LiveRequest.get(ChzzkDanmakuProtocol.liveStatusUrl(_channelId), headers: ChzzkParser.headers, site: 'chzzk'),
      );
      if (response.statusCode != 200) {
        return null;
      }
      return ChzzkDanmakuProtocol.liveChatChannel(jsonDecode(response.text));
    } on Object {
      return null;
    }
  }

  /// The access token of [channel], asked up to three times as the site's
  /// client does.
  Future<String?> _token(String channel) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (_closed) {
        return null;
      }
      try {
        final response = await _http.send(
          LiveRequest.get(ChzzkDanmakuProtocol.tokenUrl(channel), headers: ChzzkParser.headers, site: 'chzzk'),
        );
        if (response.statusCode == 200) {
          if (ChzzkDanmakuProtocol.accessToken(jsonDecode(response.text)) case final String token) {
            return token;
          }
        }
      } on Object {
        // The retry below is the whole handling.
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  /// The session servers, the routing answer's or the SDK's built-in list.
  Future<List<String>> _servers() async {
    try {
      final response = await _http.send(
        LiveRequest.get(ChzzkDanmakuProtocol.routingUrl, headers: ChzzkParser.headers, site: 'chzzk'),
      );
      if (response.statusCode == 200) {
        if (ChzzkDanmakuProtocol.servers(jsonDecode(response.text)) case final List<String> servers) {
          return servers;
        }
      }
    } on Object {
      // The fallback below is the whole handling.
    }
    return ChzzkDanmakuProtocol.defaultServers;
  }

  void _armHeartbeat(WebSocket socket) {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(ChzzkDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) {
        socket.add(ChzzkDanmakuProtocol.ping);
      }
    });
  }

  void _armQuiet() {
    _quiet?.cancel();
    _quiet = Timer(ChzzkDanmakuProtocol.quietPeriod, () => unawaited(_wentQuiet()));
  }

  /// The socket went quiet: the site's own page re-checks the live's state,
  /// and so does this. A live that is gone, or that now has another chat
  /// channel, replaces the socket; a live still on the same channel gets
  /// another quiet period.
  Future<void> _wentQuiet() async {
    if (_closed) {
      return;
    }
    final channel = await _chatChannel();
    if (_closed) {
      return;
    }
    if (channel == null || channel != (_joinedChannel ?? _channelId)) {
      _replace(null, null);
    } else {
      _armQuiet();
    }
  }

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    final frame = ChzzkDanmakuProtocol.decode(data);
    if (frame.ping) {
      _socket?.add(ChzzkDanmakuProtocol.pong);
      return;
    }
    if (frame.joined != null) {
      if (frame.joined!) {
        _joinedChannel = _pendingChannel;
        if (frame.sessionId.isNotEmpty) {
          _socket?.add(ChzzkDanmakuProtocol.recent(_joinedChannel ?? _channelId, frame.sessionId));
        }
      } else if (frame.retry) {
        _replace(null, null);
      } else {
        _fail(StateError('chzzk: join refused: ${frame.refusal}'));
      }
      return;
    }
    if (frame.closed) {
      _fail(StateError('chzzk: closed by the server'));
      return;
    }
    if (frame.pushed) {
      _armQuiet();
    }
    frame.messages.forEach(_messages.add);
  }

  /// The channel the current join asked for; read by the join's answer to
  /// record [_joinedChannel].
  String? _pendingChannel;

  /// Replaces the socket: everything of it is torn down and the run opens
  /// the next one. An [error] from the transport is swallowed — the
  /// replacement is the handling; ending the session is [_fail]'s business.
  void _replace(Object? error, StackTrace? stack) {
    if (_closed) {
      return;
    }
    _teardownSocket();
  }

  /// Ends the session with [error].
  void _fail(Object error) {
    if (_closed) {
      return;
    }
    _closed = true;
    _teardownSocket();
    if (!_messages.isClosed) {
      _messages.addError(error);
      unawaited(_messages.close());
    }
  }

  void _teardownSocket() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _quiet?.cancel();
    _quiet = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      unawaited(socket.close());
    }
    _socketDone?.complete();
    _socketDone = null;
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _teardownSocket();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
