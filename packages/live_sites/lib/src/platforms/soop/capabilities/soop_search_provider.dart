import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SOOP's search: the website's live search, one page of rooms a request,
/// ending with an empty page (the platform's own flag stays true there).
///
/// Only rooms are searched — the site's user index is not one this adapter
/// asks.
final class SoopSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  SoopSearchProvider({required this.site});

  /// The site this capability serves.
  final SoopSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: soopSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage.of(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(soopSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: soopSiteId, message: '$error', cause: error));
    }
  }
}
