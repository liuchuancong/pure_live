import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/picarto_manifest.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Picarto's search: `api/search`'s channel profiles for a keyword, live
/// and offline ones alike.
///
/// The platform indexes channels only — no area index the adapter could ask,
/// so only rooms are searched. A page that read nothing ends the keyword
/// (the answer's `count` differs between pages and is not read).
final class PicartoSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  PicartoSearchProvider({required this.site});

  /// The site this capability serves.
  final PicartoSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: picartoSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(
        LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore),
      );
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError(picartoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: picartoSiteId, message: '$error', cause: error));
    }
  }
}
