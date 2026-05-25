import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class PlatformSettingsPage extends GetView<SettingsService> {
  const PlatformSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("platform_settings"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("platform_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.apps_2_line,
              title: i18n("platform_display"),
              subtitle: i18n("platform_display_subtitle"),
              onTap: () => Get.toNamed(RoutePath.kSettingsHotAreas),
            ),
            context.buildTile(
              icon: Remix.accessibility_fill,
              title: i18n('third_party_auth'),
              subtitle: i18n('third_party_auth_subtitle'),
              onTap: () {
                Get.toNamed(RoutePath.kSettingsAccount);
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
