import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/yy_manifest.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YY's search: `apiSearch/doSearch.json`, tab 120 for rooms and tab 1 for
/// streamers, live or not. A blank keyword finds nothing, without a request.
///
/// The search API names no page count, so `hasMore` stays unknown.
final class YySearchProvider implements LiveSearchProvider {
  /// Serves [site].
  YySearchProvider({required this.site});

  /// The site this capability serves.
  final YySite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms, LiveSearchTarget.anchors};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: yySiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final List<LiveSearchResult> results;
      switch (request.target) {
        case LiveSearchTarget.rooms:
          results = [
            for (final room in await site.searchRooms(request.query, page: request.page)) LiveSearchResult.room(room),
          ];
        case LiveSearchTarget.anchors:
          results = [
            for (final anchor in await site.searchAnchors(request.query, page: request.page))
              LiveSearchResult.anchor(anchor),
          ];
        case LiveSearchTarget.areas:
          results = const [];
      }
      return right(LivePage.of(items: results));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
  }
}
