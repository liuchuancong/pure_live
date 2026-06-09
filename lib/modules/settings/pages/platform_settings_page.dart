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
            Obx(
              () => context.buildTile(
                icon: Remix.heart_3_line,
                title: i18n("prefer_platform"),
                subtitle: Sites.of(SettingsService.to.fav.preferPlatform.value).name,
                onTap: showPreferPlatformSelectorDialog,
              ),
            ),
            context.buildTile(
              icon: Remix.accessibility_line,
              title: i18n('third_party_auth'),
              subtitle: i18n('third_party_auth_subtitle'),
              onTap: () {
                Get.toNamed(RoutePath.kSettingsAccount);
              },
            ),
            context.buildTile(
              icon: Remix.price_tag_3_line,
              title: i18n('tag_management'),
              onTap: () {
                Get.toNamed(RoutePath.kSettingsTags);
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void showPreferPlatformSelectorDialog() {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n('prefer_platform')),
          children: [
            Obx(
              () => RadioGroup<String>(
                groupValue: SettingsService.to.fav.preferPlatform.value,
                onChanged: (String? value) {
                  if (value != null) {
                    SettingsService.to.fav.preferPlatform.value = value;
                    Navigator.of(context).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: Sites.supportSites.map<Widget>((site) {
                    return RadioListTile<String>(
                      title: Text(site.name),
                      value: site.id,
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
