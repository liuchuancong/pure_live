import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_repository.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_items_page.dart';
import 'package:remixicon/remixicon.dart';

/// The groups of one picture source.
///
/// A plain drill-down: a source with a single group never reaches this page, and
/// switching groups here opens a grid instead of rebuilding a page of tabs.
class WallpaperGalleryPage extends StatelessWidget {
  const WallpaperGalleryPage({super.key, required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context) {
    final WallpaperSource? source = WallpaperRepository.instance.loadCatalog().sourceById(sourceId);
    if (source == null) {
      return Scaffold(
        appBar: AppBar(title: Text(i18n('wallpaper_library'))),
        body: AppStatusView(type: AppStatusType.empty, title: i18n('background_no_category'), subtitle: ''),
      );
    }

    final List<WallpaperGroup> groups = source.visibleGroups;
    return Scaffold(
      appBar: AppBar(title: Text(i18n(source.nameKey))),
      body: groups.isEmpty
          ? AppStatusView(type: AppStatusType.empty, title: i18n('background_no_category'), subtitle: '')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                context.buildModernCard(<Widget>[
                  for (final WallpaperGroup group in groups)
                    context.buildTile(
                      icon: Remix.image_2_line,
                      title: i18n(group.nameKey),
                      trailing: const Icon(Remix.arrow_right_s_line),
                      onTap: () => Get.to<void>(() => WallpaperItemsPage(sourceId: source.id, groupId: group.id)),
                    ),
                ]),
              ],
            ),
    );
  }
}
