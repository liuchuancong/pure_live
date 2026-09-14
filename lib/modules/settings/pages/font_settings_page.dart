import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';

class FontSettingsPage extends StatefulWidget {
  const FontSettingsPage({super.key});

  @override
  State<FontSettingsPage> createState() => _FontSettingsPageState();
}

class _FontSettingsPageState extends State<FontSettingsPage> {
  bool _resetBusy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: i18n("font_settings_title"),
          child: Text(i18n("font_settings_title"), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Remix.rest_time_line),
              tooltip: i18n("reset"),
              onPressed: _resetBusy ? null : _resetToDefaults,
            ),
          ),
        ],
      ),
      body: Obx(
        () => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            key: const ValueKey('font-settings-content'),
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: const ValueKey('font-settings-scroll'),
              physics: const PureLiveScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                context.buildGroupTitle(i18n("body_typography_group")),
                context.buildModernCard([
                  context.buildSliderTile(
                    context,
                    icon: Remix.font_size,
                    title: i18n("font_body_small_title"),
                    subtitle: i18n("font_body_small_desc"),
                    value: SettingsService.to.font.fontSizeBodySmall.v,
                    min: FontSettingsController.minFontSizeBodySmall,
                    max: FontSettingsController.maxFontSizeBodySmall,
                    displayValue: "${SettingsService.to.font.fontSizeBodySmall.v.toStringAsFixed(0)}px",
                    onChanged: (newValue) {
                      SettingsService.to.font.fontSizeBodySmall.v = newValue;
                    },
                  ),
                  context.buildSliderTile(
                    context,
                    icon: Remix.text,
                    title: i18n("font_body_medium_title"),
                    subtitle: i18n("font_body_medium_desc"),
                    value: SettingsService.to.font.fontSizeBodyMedium.v,
                    min: FontSettingsController.minFontSizeBodyMedium,
                    max: FontSettingsController.maxFontSizeBodyMedium,
                    displayValue: "${SettingsService.to.font.fontSizeBodyMedium.v.toStringAsFixed(0)}px",
                    onChanged: (newValue) {
                      SettingsService.to.font.fontSizeBodyMedium.v = newValue;
                    },
                  ),
                  context.buildSliderTile(
                    context,
                    icon: Remix.text_wrap,
                    title: i18n("font_body_large_title"),
                    subtitle: i18n("font_body_large_desc"),
                    value: SettingsService.to.font.fontSizeBodyLarge.v,
                    min: FontSettingsController.minFontSizeBodyLarge,
                    max: FontSettingsController.maxFontSizeBodyLarge,
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
                    subtitle: i18n("font_title_medium_desc"),
                    value: SettingsService.to.font.fontSizeTitleMedium.v,
                    min: FontSettingsController.minFontSizeTitleMedium,
                    max: FontSettingsController.maxFontSizeTitleMedium,
                    displayValue: "${SettingsService.to.font.fontSizeTitleMedium.v.toStringAsFixed(0)}px",
                    onChanged: (newValue) {
                      SettingsService.to.font.fontSizeTitleMedium.v = newValue;
                    },
                  ),
                  context.buildSliderTile(
                    context,
                    icon: Remix.bold,
                    title: i18n("font_title_large_title"),
                    subtitle: i18n("font_title_large_desc"),
                    value: SettingsService.to.font.fontSizeTitleLarge.v,
                    min: FontSettingsController.minFontSizeTitleLarge,
                    max: FontSettingsController.maxFontSizeTitleLarge,
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
        ),
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    if (_resetBusy || !mounted) return;
    final font = SettingsService.to.font;
    setState(() => _resetBusy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('font-settings-reset-dialog'),
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Text(i18n('reset'), style: AppTextStyles.t16Bold),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(i18n('font_settings_reset_confirm'), style: AppTextStyles.t14),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
              child: Text(i18n('cancel'), style: AppTextStyles.t14Muted),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
              child: Text(i18n('reset')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || font.isClosed) return;
      font.resetTypography();
      ToastUtil.show(i18n('restore_default'));
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }
}
