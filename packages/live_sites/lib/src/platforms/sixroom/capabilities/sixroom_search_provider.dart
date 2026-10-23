import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Six Rooms' search: the web's user search page for a keyword, or the room
/// itself for a room number or room link.
///
/// Only rooms are searched — the site has no area index the adapter could
/// ask. A keyword search has one page: `hasMore` stays unknown.
final class SixroomSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  SixroomSearchProvider({required this.site});

  /// The site this capability serves.
  final SixroomSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: sixroomSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage.of(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on SixroomFailure catch (failure) {
      return left(failure.toLiveSiteError(sixroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: sixroomSiteId, message: '$error', cause: error));
    }
  }
}
