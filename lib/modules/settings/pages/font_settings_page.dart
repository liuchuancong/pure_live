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
      body: Obx(
        () => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            context.buildGroupTitle(i18n("body_typography_group")),
            context.buildModernCard([
              context.buildSliderTile(
                context,
                icon: Remix.font_size,
                title: i18n("font_body_small_title"),
                value: SettingsService.to.font.fontSizeBodySmall.v,
                min: 9.0,
                max: 15.0,
                displayValue: "${SettingsService.to.font.fontSizeBodySmall.v.toStringAsFixed(0)}px",
                onChanged: (newValue) {
                  SettingsService.to.font.fontSizeBodySmall.v = newValue;
                },
              ),
              context.buildSliderTile(
                context,
                icon: Remix.text,
                title: i18n("font_body_medium_title"),
                value: SettingsService.to.font.fontSizeBodyMedium.v,
                min: 11.0,
                max: 17.0,
                displayValue: "${SettingsService.to.font.fontSizeBodyMedium.v.toStringAsFixed(0)}px",
                onChanged: (newValue) {
                  SettingsService.to.font.fontSizeBodyMedium.v = newValue;
                },
              ),
              context.buildSliderTile(
                context,
                icon: Remix.text_wrap,
                title: i18n("font_body_large_title"),
                value: SettingsService.to.font.fontSizeBodyLarge.v,
                min: 12.0,
                max: 18.0,
                displayValue: "${SettingsService.to.font.fontSizeBodyLarge.v.toStringAsFixed(0)}px",
                onChanged: (newValue) {
                  SettingsService.to.font.fontSizeBodyLarge.v = newValue;
                },
              ),
            ]),
            const SizedBox(height: 20),

            context.buildGroupTitle(i18n("header_typography_group")),
            context.buildModernCard([
              context.buildSliderTile(
                context,
                icon: Remix.heading,
                title: i18n("font_title_medium_title"),
                value: SettingsService.to.font.fontSizeTitleMedium.v,
                min: 13.0,
                max: 20.0,
                displayValue: "${SettingsService.to.font.fontSizeTitleMedium.v.toStringAsFixed(0)}px",
                onChanged: (newValue) {
                  SettingsService.to.font.fontSizeTitleMedium.v = newValue;
                },
              ),
              context.buildSliderTile(
                context,
                icon: Remix.bold,
                title: i18n("font_title_large_title"),
                value: SettingsService.to.font.fontSizeTitleLarge.v,
                min: 16.0,
                max: 26.0,
                displayValue: "${SettingsService.to.font.fontSizeTitleLarge.v.toStringAsFixed(0)}px",
                onChanged: (newValue) {
                  SettingsService.to.font.fontSizeTitleLarge.v = newValue;
                },
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _resetToDefaults(BuildContext context) {
    SettingsService.to.font.fontSizeBodySmall.v = 12.0;
    SettingsService.to.font.fontSizeBodyMedium.v = 13.0;
    SettingsService.to.font.fontSizeBodyLarge.v = 14.0;
    SettingsService.to.font.fontSizeTitleMedium.v = 15.0;
    SettingsService.to.font.fontSizeTitleLarge.v = 20.0;
    ToastUtil.show(i18n("restore_default"));
  }
}
