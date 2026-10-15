import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugou Live's recommendations: the list the home page shows (推荐).
///
/// The platform has no personalized feed for an anonymous viewer.
final class KugouliveDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  KugouliveDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final KugouliveSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) => _run(() async {
    final page = await site.directory(request.page);
    return LivePage(items: page.rooms, hasMore: page.hasMore);
  });

  Future<Either<LiveSiteError, T>> _run<T>(Future<T> Function() work) async {
    try {
      return right(await work());
    } on KugouliveFailure catch (failure) {
      return left(failure.toLiveSiteError('kugoulive'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kugoulive', message: '$error', cause: error));
    }
  }
}
