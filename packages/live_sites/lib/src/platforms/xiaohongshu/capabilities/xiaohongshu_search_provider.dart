import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Xiaohongshu's search: the one room a room id, share page, app deep link
/// or short link names — the website has no keyword search of live rooms
/// that is reachable anonymously (3.x searched nothing else either).
///
/// Only rooms are searched — the platform has no anchor or area index the
/// adapter could ask. An exact find is the room's card alone, without its
/// stream data; a room that does not exist finds nothing.
final class XiaohongshuSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  XiaohongshuSearchProvider({required this.site});

  /// The site this capability serves.
  final XiaohongshuSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: 'xiaohongshu', message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page);
      return right(
        LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError('xiaohongshu'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'xiaohongshu', message: '$error', cause: error));
    }
  }
}
