import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class FontSettingsPage extends GetView<SettingsService> {
  const FontSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("font_settings_title")),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Remix.rest_time_line),
              tooltip: i18n("reset"),
              onPressed: () => _resetToDefaults(context),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("body_typography_group")),
          context.buildModernCard([
            _buildSliderTile(
              context,
              title: i18n("font_body_small_title"),
              subtitle: i18n("font_body_small_desc"),
              value: controller.fontSizeBodySmall,
              min: 9.0,
              max: 15.0,
            ),
            const Divider(height: 1, indent: 56),
            _buildSliderTile(
              context,
              title: i18n("font_body_medium_title"),
              subtitle: i18n("font_body_medium_desc"),
              value: controller.fontSizeBodyMedium,
              min: 11.0,
              max: 17.0,
            ),
            const Divider(height: 1, indent: 56),
            _buildSliderTile(
              context,
              title: i18n("font_body_large_title"),
              subtitle: i18n("font_body_large_desc"),
              value: controller.fontSizeBodyLarge,
              min: 12.0,
              max: 18.0,
            ),
          ]),
          const SizedBox(height: 20),

          context.buildGroupTitle(i18n("header_typography_group")),
          context.buildModernCard([
            _buildSliderTile(
              context,
              title: i18n("font_title_medium_title"),
              subtitle: i18n("font_title_medium_desc"),
              value: controller.fontSizeTitleMedium,
              min: 13.0,
              max: 20.0,
            ),
            const Divider(height: 1, indent: 56),
            _buildSliderTile(
              context,
              title: i18n("font_title_large_title"),
              subtitle: i18n("font_title_large_desc"),
              value: controller.fontSizeTitleLarge,
              min: 16.0,
              max: 26.0,
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required RxDouble value,
    required double min,
    required double max,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Obx(
                () => Text(
                  "${value.value.toStringAsFixed(1)} px",
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          Obx(
            () => Slider(
              value: value.value,
              min: min,
              max: max,
              activeColor: theme.colorScheme.primary,
              inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              onChanged: (val) => value.value = val,
            ),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults(BuildContext context) {
    controller.fontSizeBodySmall.value = 12.0;
    controller.fontSizeBodyMedium.value = 13.0;
    controller.fontSizeBodyLarge.value = 14.0;
    controller.fontSizeTitleMedium.value = 15.0;
    controller.fontSizeTitleLarge.value = 20.0;
    ToastUtil.show(i18n("settings_saved"));
  }
}
