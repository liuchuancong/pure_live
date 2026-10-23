import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_manifest.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Chzzk's search: the channel search, whose hits are rooms — a channel is the
/// room on this platform, and the answer lists offline channels too, marked
/// offline.
///
/// The platform has no separate live-room index, so only rooms are searched.
/// A page is [ChzzkEndpoints.searchPageSize] results by offset whatever the
/// caller asked for, because that is the only size the endpoint answers with; a
/// page below 1 or a blank keyword finds nothing without a request, an offset
/// past [ChzzkEndpoints.maxSearchOffset] is a caller error, and a keyword longer
/// than the platform's own limit is cut rather than refused.
final class ChzzkSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  ChzzkSearchProvider({required this.site});

  /// The site this capability serves.
  final ChzzkSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: chzzkSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    if (request.page < 1) return right(LivePage.of(items: []));
    final keyword = ChzzkRoomParser.searchKeyword(request.query);
    if (keyword.isEmpty) return right(LivePage.of(items: []));
    final offset = (request.page - 1) * ChzzkEndpoints.searchPageSize;
    if (offset > ChzzkEndpoints.maxSearchOffset) {
      return left(
        LiveSiteError.invalidArgument(siteId: chzzkSiteId, message: 'search offset $offset is past the platform'),
      );
    }
    try {
      final response = await site.get(ChzzkEndpoints.search(keyword, offset));
      final rooms = ChzzkRoomParser.searchRooms(response.text, status: response.status);
      return right(LivePage.of(items: [for (final room in rooms) LiveSearchResult.room(room)]));
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }
}
