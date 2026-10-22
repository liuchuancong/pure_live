import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_manifest.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugou Live's search: a room number or link found directly, the website's
/// user search (JSONP) for a keyword, paged here.
///
/// The search answers live and offline anchors both; a room number's exact
/// find carries the room's own state. Only rooms are searched — the site has
/// no area index the adapter could ask.
final class KugouliveSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  KugouliveSearchProvider({required this.site});

  /// The site this capability serves.
  final KugouliveSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) {
    if (!supportedTargets.contains(request.target)) {
      return Future.value(
        left(
          LiveSiteError.unsupported(
            siteId: kugouliveSiteId,
            message: 'search target ${request.target.name} not supported',
          ),
        ),
      );
    }
    return _run(() async {
      final page = await site.search(request.query, page: request.page, pageSize: request.pageSize);
      return LivePage(items: [for (final room in page.rooms) LiveSearchResult.room(room)], hasMore: page.hasMore);
    });
  }

  Future<Either<LiveSiteError, T>> _run<T>(Future<T> Function() work) async {
    try {
      return right(await work());
    } on KugouliveFailure catch (failure) {
      return left(failure.toLiveSiteError(kugouliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kugouliveSiteId, message: '$error', cause: error));
    }
  }
}
