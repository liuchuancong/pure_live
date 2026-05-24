import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

class ThemeSettingsPage extends GetView<SettingsService> {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("theme_customization"), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildGroupTitle(theme, i18n("theme_customization")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.moon_clear_line,
              title: i18n("change_theme_mode"),
              subtitle: i18n("change_theme_mode_subtitle"),
              onTap: showThemeModeSelectorDialog,
            ),
            _buildTile(
              context,
              icon: Remix.palette_line,
              title: i18n("change_theme_color"),
              subtitle: i18n("change_theme_color_subtitle"),
              onTap: colorPickerDialog,
              trailing: Obx(
                () => ColorIndicator(
                  width: 28,
                  height: 28,
                  borderRadius: 6,
                  color: HexColor(controller.themeColorSwitch.value),
                  onSelectFocus: false,
                ),
              ),
            ),
            _buildSwitchTile(
              context,
              title: i18n("enable_dynamic_color"),
              subtitle: i18n("enable_dynamic_color_subtitle"),
              value: controller.enableDynamicTheme,
              icon: Remix.magic_line,
            ),
          ]),
          const SizedBox(height: 20),
          _buildGroupTitle(theme, i18n("localization_settings")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.global_line,
              title: i18n("change_language"),
              subtitle: i18n("change_language_subtitle"),
              onTap: showLanguageSelecterDialog,
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildModernCard(ThemeData theme, List<Widget> children) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: theme.hintColor.withValues(alpha: 0.75)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required RxBool value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Obx(
      () => SwitchListTile(
        secondary: Icon(icon, size: 22, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: theme.hintColor.withValues(alpha: 0.75)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        value: value.value,
        activeThumbColor: theme.colorScheme.primary,
        onChanged: (val) => value.value = val,
        contentPadding: const EdgeInsets.only(left: 16, top: 2, bottom: 2, right: 8),
      ),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary.withValues(alpha: 0.65),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void showThemeModeSelectorDialog() {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n('change_theme_mode')),
          children: [
            Obx(
              () => RadioGroup<String>(
                groupValue: controller.themeModeName.value,
                onChanged: (String? value) {
                  if (value != null) {
                    controller.changeThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: AppConsts.themeModes.keys.map<Widget>((name) {
                    return RadioListTile<String>(
                      title: Text(i18n(AppConsts.themeModeI18n[name]!)),
                      value: name,
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

  Future<bool> colorPickerDialog() async {
    return ColorPicker(
      color: HexColor(controller.themeColorSwitch.value),
      onColorChanged: (Color color) {
        controller.themeColorSwitch.value = color.hex;
        var themeColor = color;
        var lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
        var darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
        Get.changeTheme(lightTheme);
        Get.changeTheme(darkTheme);
      },
      width: 40,
      height: 40,
      borderRadius: 4,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 155,
      heading: Text(i18n("theme_color"), style: Theme.of(Get.context!).textTheme.titleMedium),
      subheading: Text(i18n("select_opacity"), style: Theme.of(Get.context!).textTheme.titleMedium),
      wheelSubheading: Text(i18n("theme_color_opacity"), style: Theme.of(Get.context!).textTheme.titleMedium),
      showMaterialName: false,
      showColorName: false,
      showColorCode: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(longPressMenu: true),
      materialNameTextStyle: Theme.of(Get.context!).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(Get.context!).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(Get.context!).textTheme.bodyMedium,
      colorCodePrefixStyle: Theme.of(Get.context!).textTheme.bodySmall,
      selectedPickerTypeColor: Theme.of(Get.context!).colorScheme.primary,
      customColorSwatchesAndNames: controller.colorsNameMap,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
    ).showPickerDialog(
      Get.context!,
      actionsPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 480, minWidth: 375, maxWidth: 420),
    );
  }

  void showLanguageSelecterDialog() {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n("change_language")),
          children: [
            RadioGroup<String>(
              groupValue: controller.languageName.value,
              onChanged: (String? value) {
                if (value != null) {
                  controller.changeLanguage(value);
                  Navigator.of(context).pop();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AppConsts.languages.keys.map<Widget>((name) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: name, activeColor: Theme.of(context).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            controller.changeLanguage(name);
                            Navigator.of(context).pop();
                          },
                          child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
                        ),
                      ],
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
