import 'dart:async';
import 'dart:io';

import 'package:live_net/live_net.dart';

import 'package:live_sites/src/contracts/site_capability.dart';
import 'package:live_sites/src/contracts/site_error.dart';
import 'package:live_sites/src/models/live_message.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku.dart';

/// A TwitCasting danmaku session over the broadcast's event socket.
///
/// Lifecycle: ask `eventpubsuburl.php` for a freshly signed socket URL, then
/// connect and decode whatever the server pushes. The client sends nothing
/// after the handshake, so the only failure modes are a refused handshake and
/// a dropped socket — both end the session with an error on the stream, and
/// reconnecting (which re-signs the URL) belongs to the caller's supervisor.
final class TwitcastingDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (the same as the other sessions).
  // ignore: unnecessary_type_name_in_constructor
  TwitcastingDanmakuSession._(this._movieId, this._socket) {
    _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final int _movieId;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  bool _closed = false;

  /// Opens a session for broadcast [movieId], using [http] as the transport.
  ///
  /// A refused handshake or a body without a socket URL throws a
  /// [SiteNotFoundError]: the site answers that way for a broadcast that
  /// ended or is password-protected, and both mean "no danmaku here" rather
  /// than a broken adapter.
  static Future<TwitcastingDanmakuSession> connect(int movieId, LiveHttp http) async {
    final response = await http.send(
      LiveRequest.form(
        TwitcastingDanmakuProtocol.pubsubUrl,
        fields: {'movie_id': '$movieId'},
        headers: TwitcastingDanmakuProtocol.socketHeaders,
        site: 'twitcasting',
      ),
    );
    final socket = TwitcastingDanmakuProtocol.socketUrl(response.text, status: response.statusCode);
    if (socket == null) {
      throw SiteNotFoundError('twitcasting $movieId: no danmaku socket');
    }
    final connected = await WebSocket.connect(socket.toString(), headers: TwitcastingDanmakuProtocol.socketHeaders);
    return TwitcastingDanmakuSession._(movieId, connected);
  }

  /// The broadcast this session listens to.
  int get movieId => _movieId;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    TwitcastingDanmakuProtocol.decode(data).forEach(_messages.add);
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) {
      return;
    }
    _closed = true;
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
