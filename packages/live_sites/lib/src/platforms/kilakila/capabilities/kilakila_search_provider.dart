import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// KilaKila's search: the website's user search page for a keyword, one
/// profile request for a uid or anchor link, `getRoomInfo` and the profile
/// for a broadcast link.
///
/// The user search page says nothing about broadcasts, so the anchors' state
/// is unknown there; an exact find carries the anchor's own state. Only
/// rooms are searched — the site has no area index the adapter could ask.
final class KilakilaSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  KilakilaSearchProvider({required this.site});

  /// The site this capability serves.
  final KilakilaSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(
          siteId: kilakilaSiteId,
          message: 'search target ${request.target.name} not supported',
        ),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage.of(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError(kilakilaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kilakilaSiteId, message: '$error', cause: error));
    }
  }
}
