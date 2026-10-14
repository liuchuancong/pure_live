import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Niconico's areas: one category (`niconico`) whose areas are the seven
/// recent-program tabs; each tab is read through `recent?tab=`.
final class NiconicoAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  NiconicoAreaProvider({required this.site});

  /// The site this capability serves.
  final NiconicoSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(tabAreas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final result = await site.recent(areaId.trim(), request.page);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError('niconico'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'niconico', message: '$error', cause: error));
    }
  }

  /// The category every tab is parented under.
  static const String _parent = 'niconico';

  /// The tab areas, each parented under the `niconico` category, in the
  /// platform's order.
  static List<LiveArea> tabAreas() => [
    for (final (index, tab) in NiconicoEndpoints.tabs.indexed)
      LiveArea(
        platform: 'niconico',
        areaId: tab,
        areaName: NiconicoEndpoints.tabNames[tab] ?? tab,
        parentAreaId: _parent,
        parentAreaName: _parent,
        position: index,
      ),
  ];
}
