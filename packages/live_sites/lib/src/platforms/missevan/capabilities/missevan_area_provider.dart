import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Missevan's areas: the `meta/data` tabs, grouped by their namespace
/// (分区, 团播, 标签) through each area's parent, and the live rooms under
/// each.
///
/// An area id that is not a composite `<namespace>:<id>` of a tab the site
/// serves is a caller error, never an empty page.
final class MissevanAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  MissevanAreaProvider({required this.site});

  /// The site this capability serves.
  final MissevanSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on MissevanFailure catch (failure) {
      return left(failure.toLiveSiteError('missevan'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'missevan', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.directory(request.page, areaId: areaId, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on MissevanFailure catch (failure) {
      return left(failure.toLiveSiteError('missevan'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'missevan', message: '$error', cause: error));
    }
  }
}
