import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_repository.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';

/// Paging for one wallpaper grid, on the app's own paging core.
///
/// Compiled-in sources (solid colours, deepin) hand their fixed table over once
/// and the core slices it locally; the iTab sources ask for a fixed server page
/// (24 rows, 16 for Bing) and the core either appends it on a phone or turns it
/// into numbered pages on desktop - the same 刷新 / 上一页 / 页码 / 下一页 /
/// 每页数量 bar every other list in the app shows.
class WallpaperLocalGridController extends ServerAllPageController<WallpaperItem> {
  WallpaperLocalGridController(this.source);

  final WallpaperSource source;

  @override
  Future<List<WallpaperItem>> fetchAllServerData() async => WallpaperRepository.instance.localItems(source.id);
}

class WallpaperRemoteGridController extends ServerFixedPageController<WallpaperItem> {
  WallpaperRemoteGridController({required this.source, required this.group})
    : super(fixedServerPageSize: WallpaperRepository.instance.serverPageSize(source.id));

  final WallpaperSource source;
  final WallpaperGroup group;

  @override
  Future<List<WallpaperItem>> fetchFixedNetworkData(int bigPage, int fixedSize) =>
      WallpaperRepository.instance.fetchPage(source: source, group: group, page: bigPage, size: fixedSize);
}

/// One controller per (source, group), for as long as its grid is on screen.
///
/// The preview page walks the very same list as the grid it was opened from, so
/// the two cannot drift; the grid releases the controller when it leaves the
/// navigation stack, which is what keeps the cache bounded.
class WallpaperPagingStore {
  WallpaperPagingStore._();

  static final WallpaperPagingStore instance = WallpaperPagingStore._();

  static String keyOf(WallpaperSource source, WallpaperGroup group) => '${source.id}|${group.id}';

  BasePageScrollAndStateBone<WallpaperItem> obtain(WallpaperSource source, WallpaperGroup group) {
    final String key = keyOf(source, group);
    if (Get.isRegistered<BasePageScrollAndStateBone<WallpaperItem>>(tag: key)) {
      return Get.find<BasePageScrollAndStateBone<WallpaperItem>>(tag: key);
    }
    final BasePageScrollAndStateBone<WallpaperItem> controller = WallpaperRepository.instance.isLocalSource(source.id)
        ? WallpaperLocalGridController(source)
        : WallpaperRemoteGridController(source: source, group: group);
    return Get.put<BasePageScrollAndStateBone<WallpaperItem>>(controller, tag: key);
  }

  void release(WallpaperSource source, WallpaperGroup group) {
    final String key = keyOf(source, group);
    if (Get.isRegistered<BasePageScrollAndStateBone<WallpaperItem>>(tag: key)) {
      Get.delete<BasePageScrollAndStateBone<WallpaperItem>>(tag: key);
    }
  }
}
