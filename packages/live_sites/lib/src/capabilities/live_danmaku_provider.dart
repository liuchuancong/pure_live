import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';

/// Creates a danmaku session for a room.
///
/// Protocol-level reconnection required by a platform's transport belongs to
/// the session; application-level playback recovery does not — a
/// [LiveSiteError] only reports that a connection could not be started or
/// was lost.
///
/// Sessions are per room identity and meant to be **reused across room
/// refreshes**: the caller keeps one session per room and does not reopen it
/// because a refreshed room detail arrived. A refresh that failed to obtain
/// play lines must not tear the danmaku session down with it — chat outlives
/// a failed stream. Updates a refresh carries for the session (fresh gift
/// catalogues) flow into the live session through the concrete session's
/// update methods, not through a new connection.
abstract interface class LiveDanmakuProvider implements LiveSiteCapability {
  /// Creates a session for [roomId]. A left reports why the session could
  /// not be started (auth, unsupported, temporary unavailability).
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId});
}

/// A live danmaku connection over a platform protocol.
abstract interface class LiveDanmakuSession {
  /// The normalized events, in receive order.
  Stream<LiveMessage> get events;

  /// Connects to the platform's danmaku service.
  Future<void> connect();

  /// Disconnects, stopping delivery but leaving resources for a [connect].
  Future<void> disconnect();

  /// Releases all resources owned by the session; not reusable afterwards.
  Future<void> dispose();
}
