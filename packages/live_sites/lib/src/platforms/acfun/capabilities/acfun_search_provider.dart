import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// AcFun's search: the channel index (`type=user`), authors live or not.
///
/// The site has no separate stream search for an anonymous visitor — its search
/// page indexes authors and marks the ones on air, so one request serves both
/// targets: [LiveSearchTarget.rooms] hands back the cards,
/// [LiveSearchTarget.anchors] the broadcaster each card names. A blank keyword
/// gives an empty page without a request.
final class AcfunSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  AcfunSearchProvider({required this.site});

  /// The site this capability serves.
  final AcfunSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms, LiveSearchTarget.anchors};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: acfunSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    if (request.query.trim().isEmpty) return right(const LivePage(items: []));
    try {
      final rooms = await site.search(request.query, request.page, request.pageSize);
      final anchors = request.target == LiveSearchTarget.anchors;
      return right(
        LivePage(
          items: [
            for (final room in rooms)
              if (anchors) ...[
                if (room.anchor case final anchor?) LiveSearchResult.anchor(anchor),
              ] else
                LiveSearchResult.room(room),
          ],
          hasMore: rooms.isNotEmpty,
        ),
      );
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError(acfunSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: acfunSiteId, message: '$error', cause: error));
    }
  }
}
