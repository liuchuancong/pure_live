import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/modules/settings/pages/font_settings_page.dart';
import 'package:pure_live/modules/settings/pages/font_family_manager_page.dart';
import 'package:pure_live/modules/settings/pages/loading_style_settings_page.dart';

class ThemeSettingsPage extends GetView<SettingsService> {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("theme_customization"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("theme_customization")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.moon_clear_line,
              title: i18n("change_theme_mode"),
              subtitle: i18n("change_theme_mode_subtitle"),
              onTap: showThemeModeSelectorDialog,
            ),
            context.buildTile(
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
            context.buildSwitchTile(
              title: i18n("enable_dynamic_color"),
              subtitle: i18n("enable_dynamic_color_subtitle"),
              value: controller.enableDynamicTheme,
              icon: Remix.magic_line,
            ),
            context.buildTile(
              icon: Remix.loader_4_line,
              title: i18n("change_loading_style"),
              subtitle: i18n("change_loading_style_subtitle"),
              onTap: () => Get.to(() => const LoadingStyleSettingsPage()),
              trailing: Obx(() {
                final String currentKey = Get.find<SettingsService>().loadingStyle.value;
                final bool isZh = Get.locale?.languageCode == 'zh';
                final Map<String, String> currentItem = AppConsts.allStyles.firstWhere(
                  (item) => item['key'] == currentKey,
                  orElse: () => {'key': 'default', 'nameEn': 'Default Ring', 'nameZh': '默认圆环'},
                );
                final String displayName = isZh ? currentItem['nameZh']! : currentItem['nameEn']!;

                return Text(displayName, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13));
              }),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("grid_spacing_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.arrow_left_right_line,
              title: i18n("cross_axis_spacing"),
              subtitle: i18n("cross_axis_spacing_subtitle"),
              onTap: showCrossAxisSpacingDialog,
            ),
            context.buildTile(
              icon: Remix.arrow_up_down_line,
              title: i18n("main_axis_spacing"),
              subtitle: i18n("main_axis_spacing_subtitle"),
              onTap: showMainAxisSpacingDialog,
            ),
          ]),

          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("localization_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.global_line,
              title: i18n("change_language"),
              subtitle: i18n("change_language_subtitle"),
              onTap: showLanguageSelecterDialog,
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("font_family_settings")),
          context.buildModernCard([
            Obx(
              () => context.buildTile(
                icon: Remix.font_color,
                title: i18n("change_font_family"),
                subtitle: "${i18n("current_font_prefix")}: ${controller.fontFamilyName.value}",
                onTap: () => Get.to(() => const FontFamilyManagerPage()),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("text_size_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.font_size,
              title: i18n("font_settings_title"),
              subtitle: i18n("font_settings_desc"),
              onTap: () => Get.to(() => const FontSettingsPage()),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Icon(Remix.text_spacing, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i18n("text_size_title"), style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Obx(
                          () => Text(
                            "${i18n("current_scale")}: ${controller.textScaleFactor.value.toStringAsFixed(2)}",
                            style: AppTextStyles.t12.copyWith(color: theme.hintColor.withValues(alpha: 0.75)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Obx(
              () => Slider(
                value: controller.textScaleFactor.value,
                min: 0.85,
                max: 1.35,
                divisions: 10,
                label: controller.textScaleFactor.value.toStringAsFixed(2),
                activeColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                onChanged: (val) {
                  controller.textScaleFactor.value = val;
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.center,
                child: Text(i18n("text_size_preview"), style: TextStyle(color: theme.colorScheme.outline)),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
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
    final bool isZh = Get.locale?.languageCode == 'zh';
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
      pickerTypeLabels: <ColorPickerType, String>{
        ColorPickerType.primary: isZh ? "常用色" : "Primary",
        ColorPickerType.accent: isZh ? "鲜艳色" : "Accent",
        ColorPickerType.custom: isZh ? "自定义" : "Custom",
        ColorPickerType.wheel: isZh ? "调色盘" : "Wheel",
      },
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

  void showCrossAxisSpacingDialog() {
    showCustomSpacingDialog(
      title: i18n("cross_axis_spacing"),
      hintText: i18n("cross_axis_spacing_subtitle"),
      currentValue: controller.crossAxisSpacing.value,
      onSelected: (value) => controller.crossAxisSpacing.value = value,
    );
  }

  void showMainAxisSpacingDialog() {
    showCustomSpacingDialog(
      title: i18n("main_axis_spacing"),
      hintText: i18n("main_axis_spacing_subtitle"),
      currentValue: controller.mainAxisSpacing.value,
      onSelected: (value) => controller.mainAxisSpacing.value = value,
    );
  }

  void showCustomSpacingDialog({
    required String title,
    required String hintText,
    required double currentValue,
    required ValueChanged<double> onSelected,
  }) {
    final List<double> quickOptions = [0.0, 4.0, 6.0, 8.0, 12.0, 16.0];
    final textController = TextEditingController(text: currentValue.toStringAsFixed(0));
    double selectedValue = currentValue;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final theme = Theme.of(context);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickOptions.map((value) {
                      final isSelected = value == selectedValue;
                      return ChoiceChip(
                        label: Text("${value.toInt()} px"),
                        selected: isSelected,
                        showCheckmark: false,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              selectedValue = value;
                              textController.text = value.toStringAsFixed(0);
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(hintText, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: SizedBox(
                        width: 32,
                        height: 48,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 22,
                              width: 32,
                              child: InkWell(
                                borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                                onTap: () {
                                  setDialogState(() {
                                    selectedValue = (double.tryParse(textController.text) ?? 0.0) + 1.0;
                                    textController.text = selectedValue.toStringAsFixed(0);
                                  });
                                },
                                child: const Icon(Icons.arrow_drop_up, size: 20),
                              ),
                            ),
                            SizedBox(
                              height: 22,
                              width: 32,
                              child: InkWell(
                                borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                                onTap: () {
                                  setDialogState(() {
                                    double current = double.tryParse(textController.text) ?? 0.0;
                                    selectedValue = current > 0.0 ? current - 1.0 : 0.0;
                                    textController.text = selectedValue.toStringAsFixed(0);
                                  });
                                },
                                child: const Icon(Icons.arrow_drop_down, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 0.0;
                      setDialogState(() {
                        selectedValue = parsed;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n("cancel"))),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          onSelected(selectedValue);
                          Navigator.of(context).pop();
                        },
                        child: Text(i18n("confirm")),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
