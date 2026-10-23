import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart' show siteId;
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Steam Broadcast's search: a Steam id, a watch or profile link looks the
/// account up (the refresh's two requests, first page only); a custom
/// address `steamcommunity.com/id/<name>` is resolved first (one more
/// request); any other keyword filters a page of the trending broadcasts by
/// id, name, title and game, case ignored.
///
/// Steam has no anonymous broadcast search of its own — the keyword path is
/// the filter the reference ran over the directory. Only rooms are searched.
final class SteambroadcastSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  SteambroadcastSearchProvider({required this.site});

  /// The site this capability serves.
  final SteambroadcastSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: siteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage.of(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(siteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: siteId, message: '$error', cause: error));
    }
  }
}
