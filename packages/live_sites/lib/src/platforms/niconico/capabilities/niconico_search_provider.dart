import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Niconico's API search: the on-air programs for a keyword.
final class NiconicoSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  NiconicoSearchProvider({required this.site});

  /// The site this capability serves.
  final NiconicoSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: 'niconico', message: 'search target ${request.target.name} not supported'),
      );
    }
    try {
      final result = await site.search(request.query, request.page);
      return right(LivePage(items: result.items, hasMore: result.hasMore));
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError('niconico'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'niconico', message: '$error', cause: error));
    }
  }
}
