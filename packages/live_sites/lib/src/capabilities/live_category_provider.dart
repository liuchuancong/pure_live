import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/live_category/live_category.dart';
import 'package:live_sites/src/models/live_page/live_page.dart';
import 'package:live_sites/src/models/live_room/live_room.dart';

/// The category tree a site is browsed by, and the rooms under a category.
abstract interface class LiveCategoryProvider implements LiveSiteCapability {
  /// The site's categories, in the order it presents them.
  Future<Either<LiveSiteError, List<LiveCategory>>> getCategories();

  /// A page of rooms under [categoryId] for [request].
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getCategoryRooms({
    required String categoryId,
    LivePageRequest request = const LivePageRequest(),
  });
}
