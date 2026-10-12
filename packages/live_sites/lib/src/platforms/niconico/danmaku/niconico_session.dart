import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_danmaku.dart';
import 'package:live_sites/src/registry/site_ids/site_ids.dart';

/// What a niconico comment session needs: the room and the watching seat's
/// WebSocket address (the watch page's `site.relive.webSocketUrl`, fetched at
/// connect time).
final class NiconicoDanmakuArgs {
  /// A comment follow target.
  const new({required this.roomId, required this.seatSocket});

  /// The room (program id), for messages that name it.
  final String roomId;

  /// The seat WebSocket to hold open while the comment server is read.
  final Uri seatSocket;
}

/// niconico's comments: a watching seat of its own (the watch page's seat
/// WebSocket, which names the comment server), then the comment server over
/// HTTP ([NiconicoDanmakuProtocol]) — `view` is followed from `at=now` with
/// each `next`, and every window it announces is read as it streams, so a
/// comment comes as it is posted.
///
/// - Joined once a `view` answer gives its first entry.
/// - A lost window only loses its comments. A failed `view` is retried with a
///   short backoff; one the server refuses (4xx) or the seat ending ends this
///   build (the caller's supervisor reconnects, which reads the watch page
///   again and takes a fresh seat — the same division as the baidulive and
///   steambroadcast sessions; the reference's own reconnect ladder is not
///   ported). The program's end (a window's `program_status`, or the seat's
///   `END_PROGRAM`) is reported once and ends the stream normally.
/// - No heartbeat of its own: the seat keeps itself (`keepSeat` on the
///   announced interval, `pong` for the server's `ping`, 90 s of silence ends
///   it).
///
/// Archived from the reference and not run against the live service.
final class NiconicoDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  NiconicoDanmakuSession._(this._http, this._seat, this._view) {
    unawaited(_follow());
  }

  /// Opens a session for [args] over [http]: it reads the seat and waits for
  /// it to name the comment server.
  static Future<NiconicoDanmakuSession> connect(NiconicoDanmakuArgs args, LiveHttp http) async {
    final seat = await _NiconicoSeat.open(args.seatSocket);
    final view = seat.messageServer;
    if (view == null || !NiconicoDanmakuProtocol.isCommentServer(view)) {
      await seat.close();
      throw const SiteApiChangedError('niconico seat named no comment server');
    }
    return NiconicoDanmakuSession._(http, seat, view);
  }

  final LiveHttp _http;
  final _NiconicoSeat _seat;
  final Uri _view;
  final _messages = StreamController<LiveMessage>.broadcast();
  final CancelToken _cancel = CancelToken();
  final Set<String> _windows = {};
  final NiconicoMessageReader _reader = NiconicoMessageReader();
  int _openWindows = 0;
  int _failures = 0;
  int? _lastViewers;
  bool _endedProgram = false;
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  Future<void> _follow() async {
    var at = 'now';
    unawaited(_seat.done.then(_endSeat));
    while (!_closed) {
      try {
        at = '${await _viewOnce(at)}';
        _failures = 0;
      } on Object catch (error) {
        if (_closed || _endedProgram) return;
        if (!_seat.isClosed && error is! _Refused) {
          if (++_failures > NiconicoDanmakuProtocol.maxFailures) {
            _fail(error, StackTrace.current);
            return;
          }
          await Future<void>.delayed(NiconicoDanmakuProtocol.backoff(_failures));
          continue;
        }
        _fail(error, StackTrace.current);
        return;
      }
    }
  }

  /// Reads one `view` answer for [at], opening each new window it announces;
  /// returns its `next`.
  Future<int> _viewOnce(String at) async {
    final response = await _http.open(
      LiveRequest.get(
        NiconicoDanmakuProtocol.viewUrl(_view, at),
        headers: NiconicoDanmakuProtocol.headers,
        timeout: at == 'now' ? NiconicoDanmakuProtocol.firstViewTimeout : NiconicoDanmakuProtocol.viewTimeout,
        cancelToken: _cancel,
        site: SiteIds.niconico,
      ),
    );
    if (!_isOk(response.statusCode)) {
      await _discard(response);
      throw _Refused(response.statusCode);
    }
    int? next;
    await for (final bytes in NiconicoDanmakuProtocol.delimited(response.stream)) {
      if (_closed) break;
      final NiconicoViewEntry entry;
      try {
        entry = NiconicoDanmakuProtocol.viewEntry(bytes);
      } on FormatException {
        continue;
      }
      switch (entry.kind) {
        case NiconicoViewEntryKind.segment:
          if (entry.window case final window?) _openWindow(window);
        case NiconicoViewEntryKind.next:
          next = entry.next ?? next;
        case NiconicoViewEntryKind.previous || NiconicoViewEntryKind.backward || NiconicoViewEntryKind.unknown:
          break;
      }
    }
    if (_endedProgram || _closed) return 0;
    if (next == null) throw const SiteApiChangedError('niconico view ended without next');
    return next;
  }

  /// Reads [window] unless it was read on this seat or too many are open.
  void _openWindow(NiconicoCommentWindow window) {
    final key = '${window.uri}';
    if (_windows.contains(key) || _openWindows >= NiconicoDanmakuProtocol.maxOpenWindows) return;
    _windows.add(key);
    if (_windows.length > NiconicoDanmakuProtocol.rememberedWindows) _windows.remove(_windows.first);
    _openWindows++;
    unawaited(_readWindow(window).whenComplete(() => _openWindows--));
  }

  /// Reports the messages of [window] as they stream; a failure loses only the
  /// rest of this window. The program's end ends the run.
  Future<void> _readWindow(NiconicoCommentWindow window) async {
    try {
      final response = await _http.open(
        LiveRequest.get(
          window.uri,
          headers: NiconicoDanmakuProtocol.headers,
          timeout: NiconicoDanmakuProtocol.windowTimeout(window.until, DateTime.now()),
          cancelToken: _cancel,
          site: SiteIds.niconico,
        ),
      );
      if (!_isOk(response.statusCode)) {
        await _discard(response);
        return;
      }
      await for (final bytes in NiconicoDanmakuProtocol.delimited(response.stream)) {
        if (_closed || _cancel.isCancelled) return;
        final reader = _reader;
        final LiveMessage? message;
        try {
          message = reader.read(bytes);
        } on FormatException {
          continue;
        }
        if (message != null) _report(message);
        if (reader.endedProgram) {
          _endedProgram = true;
          _cancel.cancel();
          return;
        }
      }
    } on Object {
      // A lost window only loses its comments.
    }
  }

  /// Reports [message]; an audience figure only when it changed.
  void _report(LiveMessage message) {
    if (message.data case LiveAudienceUpdate(:final watching)) {
      if (watching == _lastViewers) return;
      _lastViewers = watching;
    }
    if (!_closed) _messages.add(message);
  }

  /// The seat ended: a program end closes normally, anything else fails the
  /// stream (the caller reconnects).
  void _endSeat(Object? reason) {
    if (_closed || _endedProgram) return;
    if (reason == _programEnd) {
      if (!_endedProgram) {
        _endedProgram = true;
        _report(NiconicoDanmakuProtocol.programEnded());
      }
      _cancel.cancel();
      unawaited(_shutdown());
      return;
    }
    _fail(reason ?? const SiteApiChangedError('niconico seat closed'), StackTrace.current);
  }

  Future<void> _discard(LiveStreamedResponse response) async {
    try {
      await response.close();
    } on Object {
      // Already closed.
    }
  }

  static bool _isOk(int status) => status >= 200 && status < 300;

  void _fail(Object error, StackTrace stack) {
    if (_closed) return;
    _closed = true;
    _cancel.cancel();
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
    unawaited(_seat.close());
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cancel.cancel();
    await _shutdown();
  }

  Future<void> _shutdown() async {
    _cancel.cancel();
    await _seat.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}

/// The comment server answered a request with a non-2xx, non-retryable status.
final class _Refused implements Exception {
  const new(this.status);

  final int status;

  @override
  String toString() => 'niconico comment server answered HTTP $status';
}

/// The seat disconnected because its program ended.
final class _ProgramEnd {
  const new();
}

/// The shared program-end sentinel the seat ends with and the session matches.
const Object _programEnd = _ProgramEnd();

/// One watching seat: the WebSocket that holds a program's stream grant, kept
/// alive here only long enough to name the comment server. Text frames;
/// `startWatching` and `getAkashic` after the handshake; `keepSeat` every
/// `keepIntervalSec`; `ping` is answered with `pong` and one more `keepSeat`;
/// `error` and `disconnect` (with the program-end sentinel) end the seat, as
/// does 90 s of silence.
final class _NiconicoSeat {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  _NiconicoSeat._(this._socket);

  /// Opens the seat on [socket] and waits for it to name the comment server.
  static Future<_NiconicoSeat> open(Uri socket) async {
    final WebSocket channel;
    try {
      channel = await WebSocket.connect(socket.toString(), headers: const {'origin': NiconicoDanmakuProtocol.origin});
    } on Object {
      throw const SiteApiChangedError('niconico seat handshake failed');
    }
    final seat = _NiconicoSeat._(channel);
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
      await seat._ready.future.timeout(NiconicoDanmakuProtocol.messageServerTimeout);
      return seat;
    } on Object catch (error) {
      await seat.close();
      throw error is SiteError ? error : const SiteApiChangedError('niconico seat named no comment server');
    }
  }

  final WebSocket _socket;
  final Completer<void> _ready = Completer<void>();
  final Completer<Object?> _done = Completer<Object?>();
  Uri? _messageServer;
  Timer? _silence;
  Timer? _keep;
  bool _closed = false;

  /// The comment server once announced.
  Uri? get messageServer => _messageServer;

  /// Whether the seat has ended.
  bool get isClosed => _closed;

  /// Completes when the seat ends: the program-end sentinel, or a failure.
  Future<Object?> get done => _done.future;

  void _receive(Object? frame) {
    if (_closed) return;
    _resetSilence();
    if (frame is! String || frame.length > 1024 * 1024) return;
    final Object? message;
    try {
      message = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (message is! Map<String, Object?> || message['type'] is! String) return;
    final data = message['data'];
    switch (message['type']) {
      case 'ping':
        _send({'type': 'pong'});
        _keepSeat();
      case 'seat':
        final seconds = data is Map ? data['keepIntervalSec'] : null;
        if (seconds is int && seconds >= 1 && seconds <= 300) {
          _keep?.cancel();
          _keep = Timer.periodic(Duration(seconds: seconds), (_) => _keepSeat());
        }
      case 'messageServer':
        final view = data is Map ? Uri.tryParse('${data['viewUri']}') : null;
        if (view != null) {
          _messageServer = view;
          if (!_ready.isCompleted) _ready.complete();
        }
      case 'error':
        _end(_seatError(data));
      case 'disconnect':
        final reason = data is Map ? data['reason'] : null;
        _end(reason == 'END_PROGRAM' ? _programEnd : SiteApiChangedError('niconico seat disconnected: $reason'));
    }
  }

  static SiteError _seatError(Object? data) {
    final code = data is Map ? '${data['code']}' : 'unknown';
    return switch (code) {
      'NO_PERMISSION' || 'NOT_PLAYABLE' || 'TICKET_REQUIRED' => SiteNeedsLoginError('niconico seat error $code'),
      'TOO_MANY_CONNECTIONS' || 'CONNECT_ERROR' => SiteRateLimitedError('niconico seat error $code'),
      _ => SiteApiChangedError('niconico seat error $code'),
    };
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(const Duration(seconds: 90), () => _end(const SiteApiChangedError('niconico seat silent')));
  }

  void _keepSeat() => _send({'type': 'keepSeat'});

  bool _send(Map<String, Object?> message) {
    if (_closed) return false;
    try {
      _socket.add(jsonEncode(message));
      return true;
    } on Object {
      _end(const SiteApiChangedError('niconico seat send failed'));
      return false;
    }
  }

  void _end(Object reason) {
    if (_closed) return;
    _closed = true;
    _silence?.cancel();
    _keep?.cancel();
    if (!_ready.isCompleted) {
      _ready.completeError(reason is SiteError ? reason : SiteApiChangedError('$reason'));
    }
    unawaited(_socket.close());
    if (!_done.isCompleted) _done.complete(reason);
  }

  /// Ends the seat: timers stop, the socket is closed. Idempotent.
  Future<void> close() async {
    if (!_closed) _end(const _SeatClosed());
    _silence?.cancel();
    _keep?.cancel();
    try {
      await _socket.close();
    } on Object {
      // Already closed or broken.
    }
    if (!_done.isCompleted) _done.complete(null);
  }
}

/// A seat closed by us, not by a failure.
final class _SeatClosed {
  const new();
}
