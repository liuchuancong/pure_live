import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/live_page/live_page.dart';
import 'package:live_sites/src/models/live_room/live_room.dart';

/// A site's hot list — the busiest rooms it ranks for everyone.
///
/// Kept a separate capability from the discovery feed (personalised
/// recommendations) and the category provider (browsed boards): they are
/// different concepts and a platform exposes any subset.
abstract interface class LiveHotProvider implements LiveSiteCapability {
  /// Fetches a page of the hot list.
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getHotRooms({LivePageRequest request = const LivePageRequest()});
}
