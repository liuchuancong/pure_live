import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bigo's search: the public list filtered, with a room-link or an id-shaped
/// keyword looked up as a studio.
///
/// The web search endpoints answer nothing for an anonymous client, so there is
/// no server-side query and no second page: only the first page is searched, and
/// a keyword that matches nothing gives an empty page (an unknown id is no
/// result, not an error). Only rooms are searched — the site has no anchor index
/// the adapter could ask.
final class BigoSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  BigoSearchProvider({required this.site});

  /// The site this capability serves.
  final BigoSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: bigoSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    if (request.query.trim().isEmpty) return right(LivePage.of(items: []));
    try {
      final rooms = await site.search(request.query, request.page, request.pageSize);
      final page = BigoRoomParser.slice(rooms, page: request.page, pageSize: request.pageSize);
      return right(LivePage.of(items: [for (final room in page) LiveSearchResult.room(room)]));
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError(bigoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bigoSiteId, message: '$error', cause: error));
    }
  }
}
