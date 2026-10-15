import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LOOK Live's search: a room number or room link finds that room (one room
/// answer), another keyword filters the first page of the merged homepage
/// lists by number, name and title.
///
/// The platform has no search API of its own — the website filters its first
/// page — so only page 1 finds anything, and whether later pages would match
/// is not known.
final class LookliveSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  LookliveSearchProvider({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: 'looklive', message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError('looklive'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'looklive', message: '$error', cause: error));
    }
  }
}
