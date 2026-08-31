import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';

class RendererSettingsPage extends GetView<SettingsService> {
  const RendererSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('video_output_driver'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('video_output_driver')),
          context.buildModernCard([
            Obx(
              () => Column(
                children: PlayerConsts.androidVideoRenderersList.map((item) {
                  final key = item['key']!;
                  final selected = controller.player.videoOutputDriver.v == key;

                  return _RendererTile(
                    title: _getLocalizedName(context, item),
                    selected: selected,
                    onTap: () {
                      controller.player.videoOutputDriver.v = key;
                    },
                  );
                }).toList(),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getLocalizedName(BuildContext context, Map<String, String> item) {
    final bool isZh = Get.locale?.languageCode == 'zh';
    return isZh ? item['nameZh']! : item['nameEn']!;
  }
}

class _RendererTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _RendererTile({required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: AppTextStyles.t14)),
          ],
        ),
      ),
    );
  }
}
