import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_http.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_danmaku_codec.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_seat_session.dart';
import 'package:live_sites/src/platforms/niconico/niconico_manifest.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for niconico. Each session seats a watching seat of
/// its own (the watch page, then the seat WebSocket, which names the comment
/// server) and follows the comment server over HTTP, re-seating when the
/// program ends or a seat is refused (see [NiconicoDanmakuSession]).
final class NiconicoDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (whose watch page boots the seat).
  NiconicoDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the seat and the transport.
  final NiconicoSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final session = NiconicoDanmakuSession(
      roomId: room.roomId,
      http: site.http,
      openSeat: site.openSeat,
      now: site.now,
    );
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// A window said that the program ended.
final class _ProgramEnded implements Exception {
  const _ProgramEnded();
}

/// The comment server answered a request with a non-2xx [status].
final class _Refused implements Exception {
  const _Refused(this.status);

  final int status;
}

/// One live comment connection: a watching seat names the comment server, whose
/// `view` address is followed from `at=now` with each `next`, and every window it
/// announces is read live as it streams — so a comment, gift, viewer count,
/// comment-lock change or the program's end comes as it happens.
///
/// Protocol-level recovery is this session's job (mirroring niconico's web
/// player):
/// - a lost window only loses its comments; windows are read at most
///   [maxOpenWindows] at a time, each remembered so it is read once per seat;
/// - a failed `view` is retried 1, 2, 4, 8, 8… s and the request after
///   [maxFailures] in a row closes [events]; the first reports nothing extra
///   (there is no reconnection event in this model);
/// - one the server refuses (a 4xx), a seat that ends, or a window that says
///   the program ended take a **new seat** (the watch page is read again, so a
///   broadcaster's next program is followed); the end is reported once as a
///   notice;
/// - a room that cannot be watched (offline, restricted, gone) ends the
///   connection.
///
/// The seat keeps itself alive; this session owns no heartbeat. [connect] starts
/// the loop and returns once the first seat joined (null) or could not
/// (a failure); [disconnect] and [dispose] stop it and close the seat; [dispose]
/// also closes the stream.
///
/// The run lifecycle — the generation the loop and its callbacks guard with — is
/// the shared base's ([DanmakuSessionBase]): one [DanmakuRun] per [connect],
/// whose [DanmakuRun.delay] paces the seat and backoff waits, and the base drops
/// whatever a dead one reports.
final class NiconicoDanmakuSession extends DanmakuSessionBase {
  /// A session for the room [roomId] over [http]. [openSeat] boots a watching
  /// seat (the site's [NiconicoSite.openSeat]); [now] times the windows' waits.
  NiconicoDanmakuSession({required this.roomId, required this.http, required this.openSeat, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The room whose seat and comment server this session follows.
  final String roomId;

  /// The transport the comment requests go over.
  final NiconicoHttp http;

  /// Boots a watching seat (the site's [NiconicoSite.openSeat]).
  final Future<NiconicoSeat> Function(String roomId) openSeat;

  final DateTime Function() _now;

  /// Failed requests in a row that are retried; the next ends the feed.
  static const int maxFailures = 8;

  /// Windows read at the same time at most (normally two or three).
  static const int maxOpenWindows = 8;

  /// Windows remembered as read, per seat.
  static const int rememberedWindows = 64;

  /// Longest wait for the seat to name the comment server.
  static const Duration messageServerTimeout = Duration(seconds: 10);

  /// How often the seat is checked for the comment server meanwhile.
  static const Duration messageServerPoll = Duration(milliseconds: 100);

  /// Longest wait for the `view?at=now` answer, which comes at once.
  static const Duration firstViewTimeout = Duration(seconds: 15);

  /// Longest wait for the headers and between entries of a `view` answer.
  static const Duration viewTimeout = Duration(seconds: 60);

  /// Added to the time left of a window for the longest wait between its
  /// messages.
  static const Duration windowGrace = Duration(seconds: 20);

  /// The most time left a window is granted (more means a clock that is off).
  static const Duration maxWindowLeft = Duration(seconds: 60);

  /// Wait after the [failures]-th failure in a row: 1, 2, 4, then 8 s.
  static Duration backoff(int failures) => Duration(seconds: 1 << (failures - 1).clamp(0, 3));

  /// The longest wait for the messages of a window ending at [until].
  static Duration windowTimeout(DateTime until, DateTime now) {
    final left = until.difference(now);
    final bounded = left.isNegative ? Duration.zero : (left > maxWindowLeft ? maxWindowLeft : left);
    return bounded + windowGrace;
  }

  CancelToken _cancel = CancelToken();
  int _failures = 0;
  int _openWindows = 0;
  int? _lastViewers;
  NiconicoSeat? _seat;
  Completer<LiveSiteError?>? _first;

  /// Seats and follows the comment server in the background; returns once the
  /// first seat joined (null) or could not (why). A second call while the loop
  /// is under way is ignored.
  @override
  Future<LiveSiteError?> connect() async {
    if (isDisposed) {
      return const LiveSiteError.unsupported(siteId: niconicoSiteId, message: 'session is disposed');
    }
    if (run != null) return null;
    _failures = 0;
    _lastViewers = null;
    _cancel = CancelToken();
    final first = _first = Completer<LiveSiteError?>();
    unawaited(_loop(beginRun()));
    return await first.future;
  }

  Future<void> _loop(DanmakuRun run) async {
    try {
      while (run.isActive) {
        final NiconicoSeat seat;
        try {
          seat = await openSeat(roomId);
        } on Object catch (error) {
          if (!await _failed(error, permanent: _unwatchable(error), run: run)) return;
          continue;
        }
        if (!run.isActive) {
          await seat.close();
          return;
        }
        _seat = seat;
        final Object? end;
        try {
          end = await _read(seat, run);
        } finally {
          _seat = null;
          await seat.close();
        }
        if (!run.isActive) return;
        if (end == null) return;
        if (_endsProgram(end, run)) continue;
        if (!await _failed(end, run: run)) return;
      }
    } finally {
      _settle();
    }
  }

  /// Follows [seat]'s comment server while it lasts. Returns why it stopped (the
  /// seat ended, a window said the program ended, the server refused the view,
  /// no comment server), or null when the run ended.
  Future<Object?> _read(NiconicoSeat seat, DanmakuRun run) async {
    final view = await _messageServer(seat, run);
    if (!run.isActive) return null;
    if (view == null) {
      if (seat.isClosed) return await seat.done ?? const NiconicoFailure(NiconicoFailureKind.network, 'seat closed');
      return 'the seat named no comment server within ${messageServerTimeout.inMilliseconds} ms';
    }
    if (!NiconicoDanmakuCodec.isCommentServer(view)) return 'the seat named an unexpected comment server';

    final cancel = CancelToken();
    Object? seatEnd;
    void end(Object reason) {
      seatEnd ??= reason;
      cancel.cancel();
    }

    unawaited(_cancel.whenCancel.then((_) => cancel.cancel()));
    unawaited(
      seat.done.then((failure) => end(failure ?? const NiconicoFailure(NiconicoFailureKind.network, 'seat closed'))),
    );
    final windows = <String>{};
    var at = 'now';
    try {
      while (run.isActive) {
        if (seatEnd case final reason?) return reason;
        try {
          at = '${await _view(view, at, cancel, windows, end, run)}';
        } on Object catch (error) {
          if (!run.isActive) return null;
          if (seatEnd case final reason?) return reason;
          if (error is _Refused && error.status >= 400 && error.status < 500) return error;
          if (!await _failed(error, run: run)) return null;
        }
      }
      return null;
    } finally {
      cancel.cancel();
    }
  }

  /// The seat's comment server once named; null when the seat ended, the run
  /// ended, or it took too long.
  Future<Uri?> _messageServer(NiconicoSeat seat, DanmakuRun run) async {
    for (var waited = Duration.zero; ; waited += messageServerPoll) {
      final view = seat.messageServer;
      if (view != null || seat.isClosed) return view;
      if (waited >= messageServerTimeout) return null;
      if (!await run.delay(messageServerPoll)) return null;
    }
  }

  /// Reads one `view` answer for [at], opening each new window it announces;
  /// returns the `at` of the next request.
  Future<int> _view(
    Uri view,
    String at,
    CancelToken cancel,
    Set<String> windows,
    void Function(Object) end,
    DanmakuRun run,
  ) async {
    final response = await http.openStream(
      NiconicoDanmakuCodec.viewUrl(view, at),
      headers: NiconicoEndpoints.danmakuHeaders,
      timeout: at == 'now' ? firstViewTimeout : viewTimeout,
      cancel: cancel,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _discard(response);
      throw _Refused(response.statusCode);
    }
    int? next;
    await for (final bytes in NiconicoDanmakuCodec.delimited(response.stream)) {
      final NiconicoViewEntry entry;
      try {
        entry = NiconicoDanmakuCodec.viewEntry(bytes);
      } on FormatException {
        continue;
      }
      if (!run.isActive) break;
      _joined(run);
      switch (entry.kind) {
        case NiconicoViewEntryKind.segment:
          if (entry.window case final window?) _open(window, cancel, windows, end, run);
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

  /// Reads [window] unless it was read on this seat or too many are open.
  void _open(
    NiconicoCommentWindow window,
    CancelToken cancel,
    Set<String> windows,
    void Function(Object) end,
    DanmakuRun run,
  ) {
    final key = '${window.uri}';
    if (windows.contains(key) || _openWindows >= maxOpenWindows) return;
    windows.add(key);
    if (windows.length > rememberedWindows) windows.remove(windows.first);
    _openWindows++;
    unawaited(_window(window, cancel, end, run).whenComplete(() => _openWindows--));
  }

  /// Reports the messages of [window] as they stream; a failure loses only the
  /// rest of this window. The program's end is reported, then ends the seat.
  Future<void> _window(
    NiconicoCommentWindow window,
    CancelToken cancel,
    void Function(Object) end,
    DanmakuRun run,
  ) async {
    final reader = _reader;
    try {
      final response = await http.openStream(
        window.uri,
        headers: NiconicoEndpoints.danmakuHeaders,
        timeout: windowTimeout(window.until, _now()),
        cancel: cancel,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _discard(response);
        return;
      }
      await for (final bytes in NiconicoDanmakuCodec.delimited(response.stream)) {
        if (!run.isActive || cancel.isCancelled) return;
        final LiveMessage? message;
        try {
          message = reader.read(bytes);
        } on FormatException {
          continue;
        }
        if (message != null) _report(message, run);
        if (reader.endedProgram) {
          end(const _ProgramEnded());
          return;
        }
      }
    } on Object {
      // A lost window only loses its comments.
    }
  }

  NiconicoMessageReader _reader = NiconicoMessageReader();

  /// Reports [message]; an audience figure only when it changed since the last
  /// one reported.
  void _report(LiveMessage message, DanmakuRun run) {
    if (message.payload case LiveAudienceUpdate(:final value)) {
      if (value == _lastViewers) return;
      _lastViewers = value;
    }
    run.message(message);
  }

  /// Counts a failure: ends the run when [permanent] or when too many came in a
  /// row, else waits. True when the run goes on.
  Future<bool> _failed(Object error, {required DanmakuRun run, bool permanent = false}) async {
    if (!run.isActive) return false;
    final detail = '$error';
    if (permanent) {
      _terminal(detail, run);
      return false;
    }
    _failures++;
    if (_failures > maxFailures) {
      _terminal(detail, run);
      return false;
    }
    _settle();
    return await run.delay(backoff(_failures));
  }

  /// The comment server answered: the failures in a row are over.
  void _joined(DanmakuRun run) {
    _failures = 0;
    _programJustEnded = false;
    if (!run.isJoined) run.joined();
    _settle();
  }

  /// Whether [end] is the program's end (a window's `program_status`, or the
  /// seat's `END_PROGRAM`, which come within milliseconds of each other): the
  /// notice is reported once, the reader and viewer count reset, and the next
  /// seat is taken at once. An end before a later seat answered is treated as a
  /// failure (the watch page still showed the ended program).
  bool _endsProgram(Object end, DanmakuRun run) {
    if (!run.isActive) return false;
    final bySeat = end is! _ProgramEnded && _isProgramEnd(end);
    if (end is! _ProgramEnded && !bySeat) return false;
    if (_programJustEnded) return false;
    if (bySeat) run.message(NiconicoDanmakuCodec.programEnded());
    _programJustEnded = true;
    _reader = NiconicoMessageReader();
    _lastViewers = null;
    return true;
  }

  bool _programJustEnded = false;

  /// Completes the pending [connect] once the first attempt joined (null).
  void _settle() {
    final first = _first;
    if (first != null && !first.isCompleted) first.complete(null);
  }

  static bool _unwatchable(Object error) =>
      error is NiconicoFailure &&
      const {
        NiconicoFailureKind.notFound,
        NiconicoFailureKind.streamUnavailable,
        NiconicoFailureKind.needsLogin,
        NiconicoFailureKind.regionBlocked,
      }.contains(error.kind);

  static bool _isProgramEnd(Object end) => end is NiconicoFailure && end.message.contains('END_PROGRAM');

  static Future<void> _discard(LiveStreamedResponse response) async {
    try {
      await response.close();
    } on Object {
      // Already closed.
    }
  }

  /// The run is over: [connect] is told why it could not join, the reason is
  /// told once as a system message, and the stream closes; nothing reconnects
  /// afterwards.
  void _terminal(String reason, DanmakuRun run) {
    final first = _first;
    if (first != null && !first.isCompleted) {
      first.complete(const LiveSiteError.network(siteId: niconicoSiteId, message: 'comment server failed'));
    }
    run
      ..exhausted(reason)
      ..message(
        LiveMessage.normalized(type: LiveMessageType.system, text: '弹幕连接已中断 ($reason)', color: LiveMessageColor.white),
      );
    unawaited(dispose());
  }

  /// Cancels the comment requests in flight and closes the seat; safe when
  /// nothing is open.
  @override
  Future<void> stop() async {
    _cancel.cancel();
    final seat = _seat;
    _seat = null;
    await seat?.close();
    _settle();
  }
}
