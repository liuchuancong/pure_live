import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_api_catalog.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_api_group_page.dart';
import 'package:remixicon/remixicon.dart';

/// The random-wallpaper APIs, grouped.
///
/// The flat list reaches nearly a hundred entries once alcy's categories became
/// individual sources, so it is one row per family here and the sources live on
/// a second-level page.
class WallpaperApiPage extends StatelessWidget {
  const WallpaperApiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String languageCode = context.locale.languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(i18n('wallpaper_api_group'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          context.buildModernCard(<Widget>[
            for (final WallpaperApiGroup group in kWallpaperApiGroups)
              context.buildTile(
                icon: Remix.magic_line,
                title: group.localizedName(languageCode),
                subtitle: i18n('wallpaper_api_group_count', args: <String, String>{'count': '${group.sources.length}'}),
                trailing: const Icon(Remix.arrow_right_s_line),
                onTap: () => Get.to<void>(() => WallpaperApiGroupPage(groupId: group.id)),
              ),
          ]),
        ],
      ),
    );
  }
}
