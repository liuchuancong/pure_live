import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kuaishou's `search/author`: the streamer search, live or not.
///
/// The platform answers the live-stream search to guests with "服务器繁忙", so
/// only streamers are searched; a blank keyword gives an empty page without a
/// request. The same answer serves both targets: as rooms for the lists, and
/// as anchors (the streamer's own card) for the anchor view.
final class KuaishouSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  KuaishouSearchProvider({required this.site});

  /// The site this capability serves.
  final KuaishouSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms, LiveSearchTarget.anchors};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(
          siteId: kuaishouSiteId,
          message: 'search target ${request.target.name} not supported',
        ),
      );
    }
    if (request.query.trim().isEmpty) return right(LivePage.of(items: []));
    try {
      final page = request.page < 1 ? 1 : request.page;
      final rooms = await site.search(request.query, page);
      final size = request.pageSize < 1 ? 0 : request.pageSize;
      final items = request.target == LiveSearchTarget.anchors
          ? [
              for (final room in rooms.take(size))
                LiveSearchResult.anchor(
                  LiveAnchor.of(
                    platform: kuaishouSiteId,
                    anchorId: room.ref.roomId,
                    name: room.content.title,
                    avatarUrl: room.content.coverUrl.isEmpty ? null : room.content.coverUrl,
                    liveStatus: room.broadcast.liveStatus,
                  ),
                ),
            ]
          : [for (final room in rooms.take(size)) LiveSearchResult.room(room)];
      return right(LivePage.of(items: items));
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError(kuaishouSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kuaishouSiteId, message: '$error', cause: error));
    }
  }
}
