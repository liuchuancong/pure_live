import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kuaishou's `search/author`: the streamer search, live or not, as room cards.
///
/// The platform answers the live-stream search to guests with "服务器繁忙", so
/// only streamers are searched; a blank keyword gives an empty page without a
/// request.
final class KuaishouSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  KuaishouSearchProvider({required this.site});

  /// The site this capability serves.
  final KuaishouSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: 'kuaishou', message: 'search target ${request.target.name} not supported'),
      );
    }
    if (request.query.trim().isEmpty) return right(const LivePage(items: []));
    try {
      final page = request.page < 1 ? 1 : request.page;
      final rooms = await site.search(request.query, page);
      final size = request.pageSize < 1 ? 0 : request.pageSize;
      final items = [for (final room in rooms.take(size)) LiveSearchResult.room(room)];
      return right(LivePage(items: items));
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError('kuaishou'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kuaishou', message: '$error', cause: error));
    }
  }
}
