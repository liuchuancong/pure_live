import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/huya/api/huya_endpoints.dart';
import 'package:live_sites/src/platforms/huya/huya_manifest.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Huya's API search: rooms (`v=4`) and anchors (`v=1`).
final class HuyaSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  HuyaSearchProvider({required this.site});

  /// The site this capability serves.
  final HuyaSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms, LiveSearchTarget.anchors};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      // The contract promises `unsupported` for a target this site does not
      // search, whatever the keyword is — checked before the blank short
      // circuit below.
      return left(
        LiveSiteError.unsupported(siteId: huyaSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    final text = request.query.trim();
    if (text.isEmpty) {
      // A blank keyword is a successful empty page, not a round trip.
      return right(const LivePage(items: []));
    }
    final page = request.page < 1 ? 1 : request.page;
    final rows = request.pageSize.clamp(1, 50);
    final start = (page - 1) * rows;
    final rooms = request.target == LiveSearchTarget.rooms;
    try {
      final response = await site.httpGet(
        HuyaEndpoints.search(text, version: rooms ? 4 : 1, rows: rows, start: start),
        headers: const {'user-agent': HuyaEndpoints.userAgent},
      );
      final items = rooms
          ? HuyaRoomParser.searchRooms(response.text, start: start, rows: rows, status: response.status)
          : HuyaRoomParser.searchAnchors(response.text, status: response.status);
      return right(LivePage(items: items));
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError(huyaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
    }
  }
}
