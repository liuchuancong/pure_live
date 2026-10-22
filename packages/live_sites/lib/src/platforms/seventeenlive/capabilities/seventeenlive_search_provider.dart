import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// 17LIVE's search: the live-broadcaster index, whose hits are rooms.
///
/// The platform has no anchor index and no category index of its own — the
/// catalog is three fixed regions — so only rooms are searched, and one request
/// answers one page: a request for another page finds nothing, which is what the
/// reference did rather than inventing pagination for an endpoint that has none.
/// The rules of [SeventeenLiveSite.search] carry over whole: a room link (also
/// `www.17.live`) or a room id is one `lives/<id>` that answers the room, live or
/// not, and nothing when there is no such room; another address or a blank
/// keyword finds nothing; the keyword itself is cut to the platform's 100
/// characters, and one with a colon (`Re:Zero`) is searched, as on the website.
final class SeventeenLiveSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  SeventeenLiveSearchProvider({required this.site});

  /// The site this capability serves.
  final SeventeenLiveSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(
          siteId: seventeenliveSiteId,
          message: 'search target ${request.target.name} not supported',
        ),
      );
    }
    try {
      final rooms = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: [for (final room in rooms) LiveSearchResult.room(room)], hasMore: false));
    } on SeventeenLiveFailure catch (failure) {
      return left(failure.toLiveSiteError(seventeenliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: seventeenliveSiteId, message: '$error', cause: error));
    }
  }
}
