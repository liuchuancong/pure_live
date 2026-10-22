import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_site.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Baidu Live's search: a room number or a room link finds that room, live or
/// not (one room command, on page 1); Baidu has no public keyword search, so
/// any other query finds nothing without a request — as the directory notice
/// tells the user.
///
/// Only page 1 can have results, and a room the platform has no command for is
/// no result rather than an error.
final class BaiduliveSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  BaiduliveSearchProvider({required this.site});

  /// The site this capability serves.
  final BaiduliveSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(
          siteId: baiduliveSiteId,
          message: 'search target ${request.target.name} not supported',
        ),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on BaiduliveFailure catch (failure) {
      return left(failure.toLiveSiteError(baiduliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: baiduliveSiteId, message: '$error', cause: error));
    }
  }
}
