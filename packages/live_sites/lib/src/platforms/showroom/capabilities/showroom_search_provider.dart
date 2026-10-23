import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SHOWROOM's search: the `live/onlives` snapshot filtered by anything —
/// SHOWROOM has no search API, so only live rooms are found, and a link is a
/// keyword like any other. Page 1 asks for a new snapshot; the pages after it
/// come from the same one, so they neither repeat nor skip rooms of page 1.
///
/// Only rooms are searched — the site has no anchor or area index the adapter
/// could ask.
final class ShowroomSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  ShowroomSearchProvider({required this.site});

  /// The site this capability serves.
  final ShowroomSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(
          siteId: showroomSiteId,
          message: 'search target ${request.target.name} not supported',
        ),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage.of(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(showroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: showroomSiteId, message: '$error', cause: error));
    }
  }
}
