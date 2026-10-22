import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_manifest.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TwitCasting's search: the website's text search page for a keyword, or
/// the channel a channel link names, live or not.
///
/// Only rooms are searched — the site has no area or anchor index the
/// adapter could ask.
final class TwitcastingSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  TwitcastingSearchProvider({required this.site});

  /// The site this capability serves.
  final TwitcastingSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(
          siteId: twitcastingSiteId,
          message: 'search target ${request.target.name} not supported',
        ),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError(twitcastingSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitcastingSiteId, message: '$error', cause: error));
    }
  }
}
