import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/models/player_super_resolution.dart';

class SuperResolutionSettingsPage extends GetView<SettingsService> {
  const SuperResolutionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isZh = Get.locale?.languageCode == 'zh';

    return Scaffold(
      appBar: AppBar(title: Text(i18n('super_resolution'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('super_resolution')),

          context.buildModernCard([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(i18n('super_resolution_description'), style: AppTextStyles.t12Muted),
            ),

            Obx(
              () => Column(
                children: SuperResolutionMode.values.map((mode) {
                  final selected = controller.player.defaultSuperResolutionMode.v == mode.storageValue;

                  return _SuperResolutionTile(
                    title: isZh ? mode.nameZh : mode.nameEn,
                    subtitle: isZh ? mode.descriptionZh : mode.descriptionEn,
                    selected: selected,
                    onTap: () {
                      controller.player.defaultSuperResolutionMode.v = mode.storageValue;
                    },
                  );
                }).toList(),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          context.buildGroupTitle(i18n('default_behavior')),

          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n('disable_super_resolution_warning'),
              subtitle: i18n('disable_super_resolution_warning_subtitle'),
              value: controller.player.disableSuperResolutionWarning,
              icon: Remix.notification_off_line,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SuperResolutionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SuperResolutionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.t14),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.t12Muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
