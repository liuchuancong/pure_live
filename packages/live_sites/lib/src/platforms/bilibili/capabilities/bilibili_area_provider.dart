import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's areas: the two-level board (`getList`) as a flat list whose ids
/// carry their category, and the rooms under one area.
final class BilibiliAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  BilibiliAreaProvider({required this.site});

  /// The site this capability serves.
  final BilibiliSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      final response = await site.unsignedGet(BilibiliEndpoints.areaList());
      return right(BilibiliRoomParser.areas(response.text, status: response.status));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      return right(await page(area.areaId, request));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }

  /// One area page: the unsigned `area/getRoomList` (its page size limited to
  /// 1–30), then the WBI-signed `second/getList` (with `w_webid`) as a
  /// fallback. Guests get `-352` on every page of the signed list, so the
  /// unsigned one leads; a throttle (`412`) is never retried, and when the
  /// fallback fails too the first list's error is reported.
  Future<LivePage<LiveRoom>> page(String areaId, LivePageRequest request) async {
    final area = BilibiliRoomParser.splitAreaId(areaId);
    final number = request.page < 1 ? 1 : request.page;
    final size = request.pageSize.clamp(1, 30);
    try {
      final response = await site.unsignedGet(
        BilibiliEndpoints.areaRooms(parentAreaId: area.parentAreaId, areaId: area.areaId, page: number, pageSize: size),
      );
      final list = BilibiliRoomParser.roomList(response.text, status: response.status);
      return LivePage.of(items: list.rooms, hasMore: list.hasMore);
    } on BilibiliFailure catch (first) {
      if (first.kind == BilibiliFailureKind.rateLimited) rethrow;
      try {
        final result = await site.signed(
          BilibiliEndpoints.secondListPath,
          BilibiliEndpoints.secondListParams(parentAreaId: area.parentAreaId, areaId: area.areaId, page: number),
          (response) => BilibiliRoomParser.roomList(response.text, status: response.status),
          webId: true,
        );
        return LivePage.of(items: result.value.rooms, hasMore: result.value.hasMore);
      } on BilibiliFailure catch (fallback) {
        if (fallback.kind == BilibiliFailureKind.rateLimited) rethrow;
        throw first;
      }
    }
  }
}
