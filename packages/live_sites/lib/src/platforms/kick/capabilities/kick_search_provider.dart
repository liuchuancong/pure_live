import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/kick_manifest.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kick's API search: the channels matching the keyword (live or not), then
/// the live broadcasts tagged with it — all as room results.
///
/// Kick's search has one page: a request for page two answers an empty page
/// without a round trip, and a blank keyword likewise.
final class KickSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  KickSearchProvider({required this.site});

  /// The site this capability serves.
  final KickSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      // The contract promises `unsupported` for a target this site does not
      // search, whatever the keyword is — so it is checked before the blank
      // keyword short-circuit below.
      return left(
        LiveSiteError.unsupported(siteId: kickSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    final text = request.query.trim();
    if (text.isEmpty || request.page > 1) {
      // One page only, and the platform answers a blank keyword with an
      // error; the caller gets a successful empty page instead.
      return right(const LivePage(items: []));
    }
    final word = text.length > KickEndpoints.maxKeywordLength
        ? text.substring(0, KickEndpoints.maxKeywordLength)
        : text;
    try {
      final response = await site.httpGet(KickEndpoints.search(word), headers: site.apiHeaders());
      final rooms = KickRoomParser.searchRooms(response.text, status: response.status);
      return right(LivePage(items: [for (final room in rooms) LiveSearchResult.room(room)], hasMore: false));
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError(kickSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kickSiteId, message: '$error', cause: error));
    }
  }
}
