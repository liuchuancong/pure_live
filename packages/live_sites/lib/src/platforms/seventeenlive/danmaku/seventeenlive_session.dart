import 'dart:async';
import 'dart:io';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/seventeenlive/danmaku/seventeenlive_danmaku.dart';
import 'package:live_sites/src/registry/site_ids/site_ids.dart';

/// A 17LIVE chat session: an anonymous Ably token, then Ably's JSON realtime
/// protocol over one WebSocket.
///
/// - `POST messenger/auth` ([_grant]) brings the token; the socket is the first
///   of [SeventeenLiveDanmakuProtocol.endpoints] that opens (the primary host,
///   then the website's three fallbacks).
/// - At `CONNECTED` the room's channel is attached; `ATTACHED` joins it, and an
///   attach unanswered within [SeventeenLiveDanmakuProtocol.joinTimeout] ends the
///   stream. The server heartbeats every 15 s and the client sends none; a socket
///   silent for 25 s ends it too.
/// - A server-sent `AUTH` asks a new token and sends it on the same socket; a
///   server-sent `DETACHED` attaches the channel again on the same socket, and
///   [SeventeenLiveDanmakuProtocol.maxRefusals] detaches without an attach
///   between end the stream.
/// - Unlike the reference, which folds a reconnect ladder and a connection resume
///   into the connection, this build ends the stream on a `DISCONNECTED`, an
///   `ERROR`, the stream end or silence — the caller's supervisor reconnects,
///   which re-grants the token and opens a fresh socket (the same division as the
///   looklive and kick sessions).
/// - While the streamer has paused the stream (the live figures' `liveinfo.mute`)
///   the viewers are 0; the last count is kept (the 0 is not reported), and a
///   pause or resume turns into a system notice.
///
/// Archived from the reference and not run against the live service.
final class SeventeenLiveDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the looklive session).
  // ignore: unnecessary_type_name_in_constructor
  SeventeenLiveDanmakuSession._(this._http, this._roomId, this._socket) {
    _joinTimer = Timer(SeventeenLiveDanmakuProtocol.joinTimeout, () {
      if (!_attached) _fail(const SiteApiChangedError('17live chat: join timed out'));
    });
    _resetSilence();
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  /// Opens a session for the room [roomId] over [http]: the token first, then
  /// the first endpoint whose socket opens.
  static Future<SeventeenLiveDanmakuSession> connect(LiveHttp http, String roomId) async {
    final token = await _grant(http);
    Object? failure;
    for (final endpoint in SeventeenLiveDanmakuProtocol.endpoints) {
      try {
        final socket = await WebSocket.connect(
          SeventeenLiveDanmakuProtocol.withToken(endpoint, token).toString(),
          headers: SeventeenLiveDanmakuProtocol.handshakeHeaders,
        );
        return SeventeenLiveDanmakuSession._(http, roomId, socket);
      } on Object catch (error) {
        failure = error;
      }
    }
    throw failure is SiteError ? failure : const SiteApiChangedError('17live chat: no ably host reachable');
  }

  /// `POST messenger/auth` with `{}`: the Ably token. Another provider than Ably
  /// throws [SeventeenLiveChatRefusal]; a bad answer throws its `SiteError`.
  static Future<String> _grant(LiveHttp http) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'POST',
        url: SeventeenLiveDanmakuProtocol.authUrl,
        body: '{}',
        headers: SeventeenLiveDanmakuProtocol.authHeaders,
        site: SiteIds.seventeenLive,
      ),
    );
    return SeventeenLiveDanmakuProtocol.grant(response.text, status: response.statusCode);
  }

  final LiveHttp _http;
  final String _roomId;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final StreamSubscription<Object?> _subscription;
  late final Timer _joinTimer;
  Timer? _silence;
  Timer? _reattachWatch;
  String? _channelSerial;
  bool _attached = false;
  bool _attachedBefore = false;
  bool _reattaching = false;
  int _refusals = 0;
  bool? _muted;
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(Object? data) {
    if (_closed) return;
    _resetSilence();
    final frame = SeventeenLiveDanmakuProtocol.decode(data, roomId: _roomId, now: DateTime.now());
    if (frame.channelSerial case final serial?) _channelSerial = serial;
    switch (frame.signal) {
      case SeventeenLiveSignal.none:
        break;
      case SeventeenLiveSignal.connected:
        _attach();
      case SeventeenLiveSignal.attached:
        _attached = true;
        _attachedBefore = true;
        _reattaching = false;
        _refusals = 0;
        _joinTimer.cancel();
        _reattachWatch?.cancel();
      case SeventeenLiveSignal.detached:
        _detached(frame.error);
      case SeventeenLiveSignal.disconnected:
        _fail(SiteApiChangedError('17live chat: server dropped the session${_when(frame.error)}'));
      case SeventeenLiveSignal.connectionError:
        _fail(SiteApiChangedError('17live chat: Ably error ${frame.error}'));
      case SeventeenLiveSignal.channelError:
        _fail(SiteApiChangedError('17live chat: channel refused ${frame.error}'));
      case SeventeenLiveSignal.reauthorize:
        unawaited(_reauthorize());
    }
    for (final entry in frame.entries) {
      if (_closed) return;
      final paused = _muted == true || entry.muted == true;
      for (final message in entry.messages) {
        if (_closed) return;
        if (message.data case LiveAudienceUpdate(onlineViewers: 0) when paused) continue;
        _messages.add(message);
      }
      final notice = entry.muted == null ? null : _muteNotice(muted: entry.muted!, id: entry.id);
      if (notice != null) _messages.add(notice);
      if (entry.ended) {
        _done();
        return;
      }
    }
  }

  void _attach() =>
      _socket.add(SeventeenLiveDanmakuProtocol.attach(_roomId, channelSerial: _channelSerial, resume: _attachedBefore));

  /// The server detached the channel: attach again on this socket, counting it as
  /// a refusal; [SeventeenLiveDanmakuProtocol.maxRefusals] detaches without an
  /// attach between end the stream, and one whose re-attach is unanswered drops
  /// it too.
  void _detached(SeventeenLiveAblyError? error) {
    if (++_refusals > SeventeenLiveDanmakuProtocol.maxRefusals) {
      _fail(SiteApiChangedError('17live chat: ${error == null ? 'channel detached' : 'channel detached: $error'}'));
      return;
    }
    if (_reattaching) _channelSerial = null;
    _reattaching = true;
    _reattachWatch?.cancel();
    _reattachWatch = Timer(SeventeenLiveDanmakuProtocol.joinTimeout, () {
      if (!_closed && _reattaching) _fail(const SiteApiChangedError('17live chat: re-attach timed out'));
    });
    _attach();
  }

  /// The server asked for a new token: ask `messenger/auth` and send it on the
  /// same socket. A failure is left to the server, which then drops the socket.
  Future<void> _reauthorize() async {
    final String token;
    try {
      token = await _grant(_http);
    } on Object {
      return;
    }
    if (_closed) return;
    _socket.add(SeventeenLiveDanmakuProtocol.reauthorize(token));
  }

  /// The live figures' `liveinfo.mute` turning [muted]: a notice only when it
  /// changed (or first turns true).
  LiveMessage? _muteNotice({required bool muted, required String id}) {
    final before = _muted;
    _muted = muted;
    if (before == muted || (before == null && !muted)) return null;
    return SeventeenLiveDanmakuProtocol.muteNotice(muted: muted, id: id);
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(
      SeventeenLiveDanmakuProtocol.inactivityTimeout,
      () => _fail(const SiteApiChangedError('17live chat: socket silent')),
    );
  }

  static String _when(SeventeenLiveAblyError? error) => error == null ? '' : ': $error';

  void _fail(Object error, [StackTrace? stack]) {
    if (_closed) return;
    _closed = true;
    _joinTimer.cancel();
    _reattachWatch?.cancel();
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
    _joinTimer.cancel();
    _reattachWatch?.cancel();
    _silence?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_socket.close());
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _joinTimer.cancel();
    _reattachWatch?.cancel();
    _silence?.cancel();
    await _subscription.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
