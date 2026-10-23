import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

/// Whether a room is on air, asked the cheap way.
///
/// Distinct from `LiveRoomProvider.getRoom`, which answers everything a
/// room page shows and may probe for play data: this is the one-bit ask a
/// follow list wants on a timer. The platform's own notion decides — an
/// unknown answer is a left, never an invented offline.
abstract interface class LiveStatusCheck implements LiveSiteCapability {
  /// Whether [room] is broadcasting. A left names why the answer could not
  /// be read.
  Future<Either<LiveSiteError, bool>> getLiveStatus({required LiveRoom room});
}
