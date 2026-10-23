import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_manifest.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// JD Live's search: a broadcast id or room link found directly, the featured
/// list filtered by anything else.
///
/// The site has no search endpoint, so the filter works on the list pages;
/// each keyword keeps its own page sequence. Only rooms are searched — the
/// site has no anchor or area index the adapter could ask.
final class JdliveSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  JdliveSearchProvider({required this.site});

  /// The site this capability serves.
  final JdliveSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: jdliveSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage.of(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError(jdliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: jdliveSiteId, message: '$error', cause: error));
    }
  }
}
