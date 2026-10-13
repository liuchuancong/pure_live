import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's API search: live rooms (`search_type=live`) and streamers
/// (`search_type=live_user`), both on `api.bilibili.com` and unsigned.
///
/// The room target answers live, carousel and offline rooms; streamers whose
/// name matched are folded into the room page on the first page only (the
/// platform repeats them on every page), which is where an offline streamer
/// shows up at all.
final class BilibiliSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  BilibiliSearchProvider({required this.site});

  /// The site this capability serves.
  final BilibiliSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms, LiveSearchTarget.anchors};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: 'bilibili', message: 'search target ${request.target.name} not supported'),
      );
    }
    final text = request.query.trim();
    if (text.isEmpty) {
      // The platform answers a blank keyword with an error; the caller gets a
      // successful empty page instead of a round trip.
      return right(const LivePage(items: []));
    }
    final page = request.page < 1 ? 1 : request.page;
    try {
      final items = request.target == LiveSearchTarget.rooms
          ? await _rooms(text, page, request.pageSize.clamp(1, 50))
          : await _anchors(text, page);
      return right(LivePage(items: items, hasMore: items.isNotEmpty));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError('bilibili'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'bilibili', message: '$error', cause: error));
    }
  }

  Future<List<LiveSearchResult>> _rooms(String text, int page, int pageSize) async {
    final response = await site.unsignedGet(
      BilibiliEndpoints.search(type: 'live', keyword: text, page: page, pageSize: pageSize),
    );
    return [
      for (final room in BilibiliRoomParser.searchRooms(response.text, page: page, status: response.status))
        LiveSearchResult.room(room),
    ];
  }

  Future<List<LiveSearchResult>> _anchors(String text, int page) async {
    final response = await site.unsignedGet(BilibiliEndpoints.search(type: 'live_user', keyword: text, page: page));
    return [
      for (final anchor in BilibiliRoomParser.searchAnchors(response.text, status: response.status))
        LiveSearchResult.anchor(anchor),
    ];
  }
}
