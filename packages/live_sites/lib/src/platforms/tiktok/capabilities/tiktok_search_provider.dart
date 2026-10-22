import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_manifest.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TikTok's search: the one user a username, `@username`, user link,
/// `share/live` link or share short link names — one request, two for a
/// `share/live` link.
///
/// TikTok has no anonymous keyword search; anything else finds nothing. Only
/// rooms are searched — there is no anchor or area index the adapter could
/// ask.
final class TiktokSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  TiktokSearchProvider({required this.site});

  /// The site this capability serves.
  final TiktokSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: tiktokSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on TiktokFailure catch (failure) {
      return left(failure.toLiveSiteError(tiktokSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: tiktokSiteId, message: '$error', cause: error));
    }
  }
}
