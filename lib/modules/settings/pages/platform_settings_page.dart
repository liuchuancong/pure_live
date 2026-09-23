import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class PlatformSettingsPage extends GetView<SettingsService> {
  const PlatformSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("platform_settings"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
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
                subtitle: i18n('prefer_platform_subtitle'),
                isLong: true,
                stackTrailingOnNarrow: true,
                showNavigationChevronWhenStacked: false,
                trailing: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _platformLabel(SettingsService.to.fav.preferPlatform.value),
                      style: AppTextStyles.t14.copyWith(color: Theme.of(context).hintColor.withValues(alpha: 0.75)),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context).hintColor.withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ],
                ),
                onTap: () => showPreferPlatformSelectorDialog(context),
              ),
            ),
            context.buildTile(
              icon: Remix.accessibility_line,
              title: i18n('third_party_auth'),
              subtitle: i18n('third_party_auth_subtitle'),
              isLong: true,
              onTap: () {
                Get.toNamed(RoutePath.kSettingsAccount);
              },
            ),
            context.buildTile(
              icon: Remix.price_tag_3_line,
              title: i18n('tag_management'),
              subtitle: i18n('tag_management_subtitle'),
              isLong: true,
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

  String _platformLabel(String id) {
    final normalized = id.trim().toLowerCase();
    return i18nOr('site_$normalized', normalized);
  }

  void showPreferPlatformSelectorDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(i18n('prefer_platform'), style: const TextStyle(fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          content: Obx(
            () => RadioGroup<String>(
              groupValue: SettingsService.to.fav.preferPlatform.value,
              onChanged: (value) {
                if (value == null) return;
                SettingsService.to.fav.changePreferPlatform(value);
                Navigator.of(dialogContext).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: Sites()
                    .availableSites()
                    .map(
                      (site) => RadioListTile<String>(
                        value: site.id,
                        activeColor: theme.colorScheme.primary,
                        title: Text(site.name, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w500)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        );
      },
    );
  }
}
