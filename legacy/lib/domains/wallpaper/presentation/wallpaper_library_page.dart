import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_repository.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_items_page.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_gallery_page.dart';

/// The picture library: one row per picture source.
///
/// The source tree is compiled in, so the page draws immediately - no loading
/// state and no failure state at this level. Only the individual grids talk to
/// the network.
class WallpaperLibraryPage extends StatelessWidget {
  const WallpaperLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<WallpaperSource> sources = WallpaperRepository.instance.loadCatalog().imageSources;

    return Scaffold(
      // Transparent so the wallpaper painted behind the navigator stays visible.
      appBar: AppBar(title: Text(i18n('wallpaper_library'))),
      body: sources.isEmpty
          ? AppStatusView(type: AppStatusType.empty, title: i18n('background_catalog_empty'), subtitle: '')
          : ListView(
              physics: const PureLiveScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                context.buildModernCard(<Widget>[
                  for (final WallpaperSource source in sources)
                    context.buildTile(
                      icon: Remix.image_line,
                      title: i18n(source.nameKey),
                      // No item counts: the lists are paged, so a number would
                      // either be a guess or cost one request per row.
                      subtitle: source.categorized && source.visibleGroups.length > 1
                          ? i18n(
                              'wallpaper_category_group',
                              args: <String, String>{'categories': '${source.visibleGroups.length}'},
                            )
                          : null,
                      trailing: const Icon(Remix.arrow_right_s_line),
                      onTap: () => _open(context, source),
                    ),
                ]),
              ],
            ),
    );
  }

  void _open(BuildContext context, WallpaperSource source) {
    final List<WallpaperGroup> groups = source.visibleGroups;
    if (groups.isEmpty) return;
    if (source.categorized && groups.length > 1) {
      Get.to<void>(() => WallpaperGalleryPage(sourceId: source.id));
      return;
    }
    Get.to<void>(() => WallpaperItemsPage(sourceId: source.id, groupId: groups.first.id));
  }
}
