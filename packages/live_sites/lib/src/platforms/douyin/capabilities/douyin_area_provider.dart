import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/douyin_manifest.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyin's areas: the home page's category tree (ids `id_str,type`) and one
/// signed `partition/detail/room/v2` page per area.
///
/// A captcha answer on the signed host (the signature was refused) is asked
/// once of the unsigned `webcast.amemv.com` host, which serves the same list.
final class DouyinAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  DouyinAreaProvider({required this.site});

  /// The site this capability serves.
  final DouyinSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      final response = await site.home();
      return right(DouyinRoomParser.areas(response.text, status: response.status, headers: response.headers));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
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
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
    }
  }

  /// One area page: [DouyinEndpoints.areaPageSize] rooms from `(page − 1) ×
  /// 15`, signed with `a_bogus`; the unsigned host on a captcha.
  Future<LivePage<LiveRoom>> page(String areaId, LivePageRequest request) async {
    final area = DouyinRoomParser.partition(areaId);
    final number = request.page < 1 ? 1 : request.page;
    final offset = (number - 1) * DouyinEndpoints.areaPageSize;
    final params = DouyinEndpoints.partitionParams(area, count: DouyinEndpoints.areaPageSize, offset: offset);
    final cookie = await site.cookie();
    final signed = await site.httpGet(
      site.signer.signedUrl(DouyinEndpoints.partitionRooms(), params),
      headers: site.apiHeaders(cookie),
    );
    try {
      return _parsed(
        signed,
        offset: offset,
        fallback: const DouyinFailure(DouyinFailureKind.riskControl, 'partition rooms: refused'),
      );
    } on DouyinFailure catch (failure) {
      // Only a captcha is worth the second host; anything else is the answer.
      if (failure.kind != DouyinFailureKind.riskControl) rethrow;
      final unsigned = await site.httpGet(
        DouyinEndpoints.amemvPartitionRooms(
          DouyinEndpoints.partitionParams(
            area,
            count: DouyinEndpoints.areaPageSize,
            offset: offset,
            browserName: 'Chrome',
            browserVersion: '120.0.0.0',
            screenWidth: 1920,
          ),
        ),
        headers: site.searchHeaders('', cookie),
      );
      return _parsed(unsigned, offset: offset, fallback: failure);
    }
  }

  LivePage<LiveRoom> _parsed(
    ({String text, int status, Map<String, String> headers}) response, {
    required int offset,
    required DouyinFailure fallback,
  }) {
    try {
      final result = DouyinRoomParser.partitionRooms(
        response.text,
        offset: offset,
        status: response.status,
        headers: response.headers,
      );
      return LivePage.of(items: result.rooms, hasMore: result.hasMore);
    } on DouyinFailure {
      // The fallback host failed too: report the refusal that started the
      // detour, which names the endpoint the caller asked for.
      throw fallback;
    }
  }
}
