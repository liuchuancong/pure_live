import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_manifest.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugou Live's areas: the home page's area links, and the rooms of one
/// list.
///
/// The areas are read once for the adapter's lifetime; another platform's
/// area or an id that is not 1-8 digits is a caller error, never an empty
/// page.
final class KugouliveAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  KugouliveAreaProvider({required this.site});

  /// The site this capability serves.
  final KugouliveSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() => _run(site.catalog);

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) => _run(() async {
    final page = await site.directory(request.page, areaId: areaId);
    return LivePage(items: page.rooms, hasMore: page.hasMore);
  });

  Future<Either<LiveSiteError, T>> _run<T>(Future<T> Function() work) async {
    try {
      return right(await work());
    } on KugouliveFailure catch (failure) {
      return left(failure.toLiveSiteError(kugouliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kugouliveSiteId, message: '$error', cause: error));
    }
  }
}
