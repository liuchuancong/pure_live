import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's discovery feed: the anonymous ranked list of every area
/// (`sort=online`), which is what a guest can actually read.
///
/// The ranked list is tried twice [BilibiliEndpoints.retryDelay] apart, then
/// the recommendation feed (`getMoreRecList`) as a fallback; a throttle is
/// never retried, and when the fallback fails too the ranked list's error is
/// reported.
final class BilibiliDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  BilibiliDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final BilibiliSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      return right(await page(request));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError('bilibili'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'bilibili', message: '$error', cause: error));
    }
  }

  /// One page of the ranked list, with the feed as the fallback.
  Future<LivePage<LiveRoom>> page(LivePageRequest request) async {
    final number = request.page < 1 ? 1 : request.page;
    final size = request.pageSize.clamp(1, 30);
    BilibiliFailure? ranked;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await site.sleep(BilibiliEndpoints.retryDelay);
      try {
        final response = await site.unsignedGet(BilibiliEndpoints.recommend(page: number, pageSize: size));
        final list = BilibiliRoomParser.roomList(response.text, status: response.status);
        return LivePage(items: list.rooms, hasMore: list.hasMore);
      } on BilibiliFailure catch (failure) {
        if (failure.kind == BilibiliFailureKind.rateLimited) rethrow;
        ranked = failure;
      }
    }
    try {
      final response = await site.unsignedGet(BilibiliEndpoints.moreRecommendations(page: number));
      final list = BilibiliRoomParser.roomList(response.text, status: response.status);
      return LivePage(items: list.rooms, hasMore: list.hasMore);
    } on BilibiliFailure catch (fallback) {
      if (fallback.kind == BilibiliFailureKind.rateLimited) rethrow;
      throw ranked!;
    }
  }
}
