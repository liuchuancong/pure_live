import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_manifest.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// FC2 Live's search: the directory filtered here, plus one exact channel.
///
/// The platform has no search API at all, so a keyword is matched against the
/// snapshot of every channel on air — its number, its owner, its title and its
/// area, in the site's own names and in the English ones 3.x wrote, so a search
/// made under 3.x still finds the same rooms. That also means a channel nobody
/// is watching cannot be found by word: only a keyword that *is* a channel
/// number or a channel link reaches one, through the channel's own answer, and
/// finds it even offline.
///
/// A page size beyond [Fc2LiveEndpoints.maxPageSize] and a page below 1 gave
/// nothing under 3.x too, and asking for nothing is not the same as failing to
/// search: both are an empty page.
final class Fc2LiveSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  Fc2LiveSearchProvider({required this.site});

  /// The site this capability serves.
  final Fc2LiveSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: fc2LiveSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage.of(
          items: [for (final room in page.rooms) LiveSearchResult.room(room)],
          totalCount: page.totalCount,
          hasMore: page.hasMore,
        ),
      );
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError(fc2LiveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: fc2LiveSiteId, message: '$error', cause: error));
    }
  }
}
