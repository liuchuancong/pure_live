import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke's search: a uid or room link finds that room, another keyword
/// filters the nicknames of the website's showcases and the app's hot list.
///
/// There is no server search; the matches are what this session's three
/// lists hold, and `hasMore` says whether the filtered list goes on past the
/// page. Only rooms are searched — the site has no area or anchor index the
/// adapter could ask.
final class InkeSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  InkeSearchProvider({required this.site});

  /// The site this capability serves.
  final InkeSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: 'inke', message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError('inke'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'inke', message: '$error', cause: error));
    }
  }
}
