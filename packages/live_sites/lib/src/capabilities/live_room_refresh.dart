import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

/// Room detail re-reads that must not cost what a full `getRoom` costs.
///
/// `LiveRoomProvider.getRoom` answers a first visit: everything a room page
/// shows, with whatever probing that takes (a danmaku handshake, a play
/// probe). These re-reads are for callers that already hold the room and
/// want one slice of it back.
abstract interface class LiveRoomRefresh implements LiveSiteCapability {
  /// The room behind [roomId] as a refresh: display state and figures, with
  /// no play probing and no danmaku handshake.
  ///
  /// A sparse answer is expected and merges into the stored room by
  /// `LiveRoom.mergedWith`; fields the source omits arrive null, never
  /// invented.
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId});

  /// The room behind [roomId] exactly as the recorder needs it: identity,
  /// live state and the play-relevant facts, with nothing deferred.
  ///
  /// The recorder must not start on a stale or partial answer, so this read
  /// is the strict one; a room that cannot be resolved strictly is a left.
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId});
}
