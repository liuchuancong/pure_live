import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kick's areas: every top-level category (`api/v1/categories`) walked to
/// its 32 most watched subcategories (`api/v1/subcategories`), and one live
/// directory page per subcategory.
///
/// The areas come back flat, each carrying its top-level category as parent;
/// only the subcategories list rooms (`getAreaRooms` refuses a top-level
/// slug). A category whose subcategories fail is left out; when all fail,
/// the first failure is reported.
final class KickAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  KickAreaProvider({required this.site});

  /// The site this capability serves.
  final KickSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await _categories());
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError('kick'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kick', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    final slug = areaId.trim();
    if (!KickEndpoints.subcategoryPattern.hasMatch(slug)) {
      return left(LiveSiteError.notFound(siteId: 'kick', message: 'area id "$areaId" is not a Kick subcategory slug'));
    }
    try {
      final page = request.page < 1 ? 1 : request.page;
      final size = request.pageSize.clamp(1, KickEndpoints.pageSize);
      final response = await site.httpGet(
        KickEndpoints.livestreams(page, size, subcategory: slug),
        headers: site.apiHeaders(),
      );
      final result = KickRoomParser.directoryPage(
        response.text,
        page: page,
        pageSize: size,
        subcategory: slug,
        status: response.status,
      );
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError('kick'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kick', message: '$error', cause: error));
    }
  }

  /// The parents with their subcategories in one parallel round; a failed
  /// parent is left out unless every one fails.
  Future<List<LiveArea>> _categories() async {
    final response = await site.httpGet(KickEndpoints.categories(), headers: site.apiHeaders());
    final parents = KickRoomParser.mainCategories(response.text, status: response.status);
    final results = await Future.wait([
      for (final parent in parents)
        _subcategories(parent).then<Object>((areas) => areas, onError: (Object error) => error),
    ]);
    final areas = <LiveArea>[];
    Object? failure;
    for (final result in results) {
      if (result is List<LiveArea>) {
        areas.addAll(result);
      } else {
        failure ??= result;
      }
    }
    if (areas.isEmpty && failure != null) {
      if (failure is KickFailure) throw failure;
      throw KickFailure(KickFailureKind.network, 'subcategories: $failure', cause: failure);
    }
    return areas;
  }

  Future<List<LiveArea>> _subcategories(KickMainCategory parent) async {
    final response = await site.httpGet(KickEndpoints.subcategories(parent.slug), headers: site.apiHeaders());
    return KickRoomParser.subcategories(response.text, parent: parent, status: response.status);
  }
}
