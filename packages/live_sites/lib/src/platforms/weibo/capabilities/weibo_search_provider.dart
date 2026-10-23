import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';
import 'package:live_sites/src/platforms/weibo/weibo_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Weibo's search: a broadcast id or room link finds that room (a `t.cn`
/// short link is asked where it leads), another keyword filters the snapshot's
/// nicknames.
///
/// There is no server search; the matches are what this session's snapshot
/// holds, on page 1 only, and the site has no area or anchor index the
/// adapter could ask — only rooms are searched.
final class WeiboSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  WeiboSearchProvider({required this.site});

  /// The site this capability serves.
  final WeiboSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: weiboSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage.of(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on WeiboFailure catch (failure) {
      return left(failure.toLiveSiteError(weiboSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: weiboSiteId, message: '$error', cause: error));
    }
  }
}
