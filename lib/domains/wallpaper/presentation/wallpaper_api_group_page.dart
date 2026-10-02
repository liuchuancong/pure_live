import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_api_catalog.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_preview_page.dart';
import 'package:remixicon/remixicon.dart';

/// The sources inside one random-API group.
///
/// Picking a row opens the fullscreen preview, which downloads a picture and
/// offers "another one" until the user keeps it.
class WallpaperApiGroupPage extends StatelessWidget {
  const WallpaperApiGroupPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    WallpaperApiGroup? group;
    for (final WallpaperApiGroup candidate in kWallpaperApiGroups) {
      if (candidate.id == groupId) group = candidate;
    }
    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: Text(i18n('wallpaper_api_group'))),
        body: AppStatusView(type: AppStatusType.empty, title: i18n('background_no_category'), subtitle: ''),
      );
    }

    final WallpaperApiGroup resolved = group;
    return Scaffold(
      appBar: AppBar(title: Text(resolved.localizedName(context.locale.languageCode))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          context.buildModernCard(<Widget>[
            for (final WallpaperApiSource source in resolved.sources)
              context.buildTile(
                icon: Remix.global_line,
                title: source.name,
                subtitle: source.host,
                trailing: const Icon(Remix.arrow_right_s_line),
                onTap: () => Get.to<void>(() => WallpaperPreviewPage.api(source)),
              ),
          ]),
        ],
      ),
    );
  }
}
