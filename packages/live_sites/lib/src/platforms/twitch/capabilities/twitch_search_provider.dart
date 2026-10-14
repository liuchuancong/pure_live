import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Twitch's search: the channel index (`SearchResultsPage_SearchResults`),
/// live or not, as room cards.
///
/// Twitch's other result indexes (games, streams) are not read: the 3.x client
/// searched channels only, and a stream search returns the same rooms the
/// channel index marks live. A blank keyword gives an empty page without a
/// request.
final class TwitchSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  TwitchSearchProvider({required this.site});

  /// The site this capability serves.
  final TwitchSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: 'twitch', message: 'search target ${request.target.name} not supported'),
      );
    }
    if (request.query.trim().isEmpty) return right(const LivePage(items: []));
    try {
      final result = await site.search(request.query, request.page);
      final size = request.pageSize < 1 ? 0 : request.pageSize;
      return right(LivePage(items: [for (final room in result.rooms.take(size)) LiveSearchResult.room(room)]));
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError('twitch'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'twitch', message: '$error', cause: error));
    }
  }
}
