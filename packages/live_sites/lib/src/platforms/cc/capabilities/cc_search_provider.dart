import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CC's search: the website's anchor search (`search/anchor/`), streamers
/// live or not.
///
/// The same answer serves both targets: rooms for the lists, and anchors
/// (the streamer's own card) for the anchor view. Areas are not searched —
/// the site has no area index the adapter could ask.
final class CcSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  CcSearchProvider({required this.site});

  /// The site this capability serves.
  final CcSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms, LiveSearchTarget.anchors};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: ccSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      final items =
          request.target == LiveSearchTarget.anchors
          ? [
              for (final room in page.rooms)
                LiveSearchResult.anchor(
                  LiveAnchor.of(
                    platform: ccSiteId,
                    anchorId: room.ref.roomId,
                    name: room.content.title,
                    avatarUrl: room.content.coverUrl.isEmpty ? null : room.content.coverUrl,
                    liveStatus: room.broadcast.liveStatus,
                  ),
                ),
            ]
          : [for (final room in page.rooms) LiveSearchResult.room(room)];
      return right(LivePage.of(items: items, hasMore: page.hasMore));
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
    }
  }
}
