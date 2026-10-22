import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_manifest.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// PandaTV's search: the BJ search and the LIVE search for a keyword, one
/// `member/bj` for a broadcaster id or a room link.
///
/// Only rooms are searched — the platform has no area index the adapter
/// could ask.
final class PandaliveSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  PandaliveSearchProvider({required this.site});

  /// The site this capability serves.
  final PandaliveSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(
          siteId: pandaliveSiteId,
          message: 'search target ${request.target.name} not supported',
        ),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(pandaliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: pandaliveSiteId, message: '$error', cause: error));
    }
  }
}
