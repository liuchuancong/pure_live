import 'dart:async';

import 'package:live_sites/src/models/live_message.dart';
import 'package:live_sites/src/models/live_room.dart';

/// A connected danmaku session for one room.
///
/// The session yields normalized [LiveMessage]s; transport, reconnects
/// and heartbeats are the adapter's business, rendering stays with the
/// UI layer. [close] is idempotent.
abstract interface class LiveDanmakuSession {
  /// The normalized message stream. Single subscription.
  Stream<LiveMessage> get messages;

  /// Stops the session and releases the transport.
  Future<void> close();
}

/// The danmaku capability a site may implement.
///
/// Sites whose protocol cannot connect a room simply do not implement
/// this interface — capability probing is `site is LiveDanmakuCapability`,
/// no flags and no null-returning methods.
abstract interface class LiveDanmakuCapability {
  /// Opens a danmaku session for [room]; the room's runtime cache may
  /// carry platform init payloads from an earlier detail fetch.
  Future<LiveDanmakuSession> connect(LiveRoom room);
}

/// Cooperative cancellation for long-lived site operations.
///
/// Transport-agnostic: adapters bridge it to their own cancellation
/// primitives. Cancelling is idempotent; the first [reason] wins.
final class CancellationToken {
  final Completer<Object?> _completer = Completer<Object?>();

  bool _isCancelled = false;
  Object? _reason;

  /// Whether [cancel] has been called.
  bool get isCancelled => _isCancelled;

  /// The reason of the first cancellation, if any.
  Object? get reason => _reason;

  /// Completes with the [reason] once cancelled.
  Future<Object?> get whenCancel => _completer.future;

  /// Marks the token cancelled. Later calls are ignored.
  void cancel([Object? reason]) {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    _reason = reason;
    _completer.complete(reason);
  }
}

/// The directory capability: a site whose `getRecommendRooms` and
/// `getCategoryRooms` return real data.
///
/// The methods themselves live on `LiveSite`, because a site always has to
/// answer them; this marker is how it says whether the answer is real. The
/// migration rule behind it: an adapter that has not implemented a directory
/// throws `UnimplementedError` from those two methods, and *implements* this
/// interface only once they work — so a caller probes
/// `site is LiveDirectoryCapability` once, up front, instead of discovering
/// the gap by catching an error mid-page.
///
/// This is the same shape as [LiveDanmakuCapability] on purpose: a site
/// declares what it can do, and callers never guess.
abstract interface class LiveDirectoryCapability;

/// The search capability: a site whose `searchRooms` returns real data.
///
/// Separate from [LiveDirectoryCapability] because the two land
/// independently: Douyu browses by directory but its search port is still on
/// the migration list, and a page that offers search must not offer it there.
abstract interface class LiveSearchCapability;
