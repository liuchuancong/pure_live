import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_endpoints.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's API search: rooms and anchors.
/// Douyu's API search: rooms and anchors.
final class DouyuSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  /// Serves [site].
  DouyuSearchProvider({required this.site});

  /// The site this capability serves.
  final DouyuSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms, LiveSearchTarget.anchors};

  @override
  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    final text = request.query.trim();
    if (text.isEmpty) {
      // The platform answers a blank keyword with an error; the caller gets
      // a successful empty page instead of a round trip.
      return right(const LivePage(items: []));
    }
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: 'douyu', message: 'search target ${request.target.name} not supported'),
      );
    }
    final page = request.page < 1 ? 1 : request.page;
    final pageSize = request.pageSize.clamp(1, 50);
    try {
      final response = await site.httpGet(
        request.target == LiveSearchTarget.rooms
            ? DouyuEndpoints.searchShow(text, page, pageSize)
            : DouyuEndpoints.searchUser(text, page, pageSize),
        headers: {...site.apiHeaders(''), 'referer': 'https://www.douyu.com/search/'},
      );
      final items = request.target == LiveSearchTarget.rooms
          ? DouyuRoomParser.searchRooms(response.text, status: response.status)
          : DouyuRoomParser.searchAnchors(response.text, status: response.status);
      return right(LivePage(items: items));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError('douyu'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'douyu', message: '$error', cause: error));
    }
  }
}
