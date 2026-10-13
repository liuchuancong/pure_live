import 'dart:async';

import 'package:fpdart/fpdart.dart';

import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/live_danmaku_event/live_danmaku_event.dart';

/// Creates a danmaku session for a room.
///
/// Protocol-level reconnection required by a platform's transport belongs to
/// the session; application-level playback recovery does not — [LiveSiteError]
/// only reports that a connection could not be started or was lost.
abstract interface class LiveDanmakuProvider implements LiveSiteCapability {
  /// Creates a session for [roomId]. A left reports why the session could not
  /// be started (auth, unsupported, temporary unavailability).
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId});
}

/// A live danmaku connection over a platform protocol.
abstract interface class LiveDanmakuSession {
  /// The normalized events, in receive order.
  Stream<LiveDanmakuEvent> get events;

  /// Connects to the platform's danmaku service.
  Future<void> connect();

  /// Disconnects, stopping delivery but leaving resources for a [connect].
  Future<void> disconnect();

  /// Releases all resources owned by the session; not reusable afterwards.
  Future<void> dispose();
}
