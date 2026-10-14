import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_http.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_danmaku_codec.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_seat_session.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for niconico: each opens a watching seat of its
/// own (the watch page, then the seat WebSocket, which names the comment
/// server) and follows the comment server over HTTP.
final class NiconicoDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (whose watch page boots the seat).
  NiconicoDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the seat and the transport.
  final NiconicoSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final NiconicoSeat seat;
    try {
      seat = await site.openSeat(roomId);
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError('niconico'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'niconico', message: '$error', cause: error));
    }
    final session = NiconicoDanmakuSession(seat: seat, http: site.http);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live comment connection: after the seat names the comment server, the
/// `view` address is followed from `at=now` with each `next`, and every window
/// it announces is read for its chats.
///
/// Protocol-level recovery is this session's job: a failed `view` is retried
/// after 1, 2, 4, 8, 8… seconds, and the request after [maxFailures] failures
/// in a row closes [events] with a terminal system message instead of retrying
/// forever. The seat keeps itself alive; this session owns no heartbeat.
/// [disconnect] and [dispose] stop the loop; [dispose] closes both the loop and
/// the seat.
final class NiconicoDanmakuSession implements LiveDanmakuSession {
  /// A session over the open [seat] and the comment server's [http].
  NiconicoDanmakuSession({required this.seat, required this.http});

  /// The watching seat that names the comment server.
  final NiconicoSeat seat;

  /// The transport the comment requests go over.
  final NiconicoHttp http;

  /// Failed `view` requests in a row that are retried; the next ends the feed.
  static const int maxFailures = 8;

  /// Longest wait for the seat to name the comment server.
  static const Duration messageServerTimeout = Duration(seconds: 10);

  /// How often the seat is checked for the comment server meanwhile.
  static const Duration messageServerPoll = Duration(milliseconds: 100);

  /// Failed requests in a row that are retried: 1, 2, 4, then 8 seconds.
  static Duration backoff(int failures) => Duration(seconds: 1 << (failures - 1).clamp(0, 3));

  final _events = StreamController<LiveMessage>.broadcast();
  CancelToken _cancel = CancelToken();
  bool _running = false;
  bool _disposed = false;
  int _generation = 0;
  int _failures = 0;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Follows the comment server in the background: null once the poll loop has
  /// started, else why it could not (the seat named no comment server).
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'niconico', message: 'session is disposed');
    }
    final generation = ++_generation;
    _running = true;
    _failures = 0;
    _cancel = CancelToken();
    final view = await _awaitMessageServer(generation);
    if (!_running || _disposed || generation != _generation) return null;
    if (view == null || !NiconicoDanmakuCodec.isCommentServer(view)) {
      await dispose();
      return const LiveSiteError.contentUnavailable(siteId: 'niconico', message: 'the seat named no comment server');
    }
    unawaited(_follow(view, generation));
    return null;
  }

  /// The seat's comment server once named; null when it never did or the
  /// session stopped.
  Future<Uri?> _awaitMessageServer(int generation) async {
    for (var waited = Duration.zero; ; waited += messageServerPoll) {
      if (!_running || _disposed || generation != _generation) return null;
      final view = seat.messageServer;
      if (view != null) return view;
      if (seat.isClosed) return null;
      if (waited >= messageServerTimeout) return null;
      await Future<void>.delayed(messageServerPoll);
    }
  }

  /// Seats one `view` after another until the session stops, following each
  /// `next`; a lost window only loses its comments.
  Future<void> _follow(Uri view, int generation) async {
    var at = 'now';
    final seen = <String>{};
    while (_running && !_disposed && generation == _generation) {
      final int next;
      try {
        next = await _view(view, at, generation, seen);
      } on Object catch (error) {
        if (!_running || _disposed || generation != _generation) return;
        _failures++;
        if (_failures > maxFailures) {
          _terminal('$error');
          return;
        }
        if (!await _wait(backoff(_failures), generation)) return;
        continue;
      }
      if (!_running || _disposed || generation != _generation) return;
      _failures = 0;
      at = '$next';
    }
  }

  /// Reads one `view` answer for [at], opening each new window it announces;
  /// returns the `at` of the next request.
  Future<int> _view(Uri view, String at, int generation, Set<String> seen) async {
    final response = await http.feed(
      NiconicoDanmakuCodec.viewUrl(view, at),
      headers: NiconicoEndpoints.danmakuHeaders,
      cancel: _cancel,
    );
    if (response.status >= 400 && response.status < 500) {
      throw NiconicoFailure(NiconicoFailureKind.streamUnavailable, 'view: HTTP ${response.status}');
    }
    if (response.status != 200) {
      throw NiconicoFailure(NiconicoFailureKind.network, 'view: HTTP ${response.status}');
    }
    int? next;
    for (final bytes in NiconicoDanmakuCodec.split(response.bytes)) {
      if (!_running || _disposed || generation != _generation) break;
      final NiconicoViewEntry entry;
      try {
        entry = NiconicoDanmakuCodec.viewEntry(bytes);
      } on FormatException {
        continue;
      }
      switch (entry.kind) {
        case NiconicoViewEntryKind.segment:
          final window = entry.window;
          if (window != null) await _window(window, generation);
        case NiconicoViewEntryKind.next:
          next = entry.next ?? next;
        case NiconicoViewEntryKind.previous:
        case NiconicoViewEntryKind.backward:
        case NiconicoViewEntryKind.unknown:
          break;
      }
    }
    if (next == null) throw const FormatException('the view answer ended without next');
    return next;
  }

  /// Reports the chats of [window]; a failure loses only this window.
  Future<void> _window(NiconicoCommentWindow window, int generation) async {
    if (!_running || _disposed || generation != _generation) return;
    final NiconicoResponse response;
    try {
      response = await http.feed(window.uri, headers: NiconicoEndpoints.danmakuHeaders, cancel: _cancel);
    } on Object {
      return; // A lost window only loses its comments.
    }
    if (response.status != 200) return;
    for (final bytes in NiconicoDanmakuCodec.split(response.bytes)) {
      if (!_running || _disposed || generation != _generation) return;
      final LiveMessage? message;
      try {
        message = NiconicoDanmakuCodec.message(bytes);
      } on FormatException {
        continue;
      }
      if (message != null) _events.add(message);
    }
  }

  Future<bool> _wait(Duration delay, int generation) async {
    final completer = Completer<bool>();
    final timer = Timer(delay, () => completer.complete(_running && !_disposed && generation == _generation));
    unawaited(
      _cancel.whenCancel.then((_) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(false);
      }),
    );
    return await completer.future;
  }

  void _terminal(String reason) {
    _running = false;
    _events.add(
      LiveMessage.normalized(type: LiveMessageType.system, text: '弹幕连接已中断 ($reason)', color: LiveMessageColor.white),
    );
    unawaited(_events.close());
  }

  @override
  Future<void> disconnect() async {
    _running = false;
    _generation++;
    _cancel.cancel();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    _generation++;
    _cancel.cancel();
    await seat.close();
    unawaited(_events.close());
  }
}
