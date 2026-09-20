import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/modules/settings/pages/page_settings.dart';
import 'package:pure_live/modules/settings/pages/font_settings_page.dart';
import 'package:pure_live/modules/settings/pages/font_family_manager_page.dart';
import 'package:pure_live/modules/settings/pages/loading_style_settings_page.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings_page.dart';
import 'package:pure_live/modules/settings/widgets/app_color_picker_dialog.dart';

class ThemeSettingsPage extends GetView<SettingsService> {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("theme_customization"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
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
                  color: SettingsService.to.theme.themeColor,
                  onSelectFocus: false,
                ),
              ),
            ),
            context.buildSwitchTile(
              title: i18n("enable_dynamic_color"),
              subtitle: i18n("enable_dynamic_color_subtitle"),
              value: SettingsService.to.theme.enableDynamicTheme,
              icon: Remix.magic_line,
            ),
            Obx(
              () => context.buildTile(
                iconWidget: SizedBox(
                  key: ValueKey(SettingsService.to.theme.resolvedLoadingStyle),
                  width: 24,
                  child: AppStatusView(
                    type: AppStatusType.loading,
                    title: i18n('refresh_loading'),
                    subtitle: '',
                    isMini: true,
                  ),
                ),
                title: i18n("change_loading_style"),
                subtitle: i18n("change_loading_style_subtitle"),
                onTap: () => Get.to(() => const LoadingStyleSettingsPage()),
                stackTrailingOnNarrow: true,
                trailing: Obx(() {
                  final String currentKey = SettingsService.to.theme.resolvedLoadingStyle;
                  final bool isZh = Get.locale?.languageCode == 'zh';
                  final Map<String, String> currentItem = AppConsts.allStyles.firstWhere(
                    (item) => item['key'] == currentKey,
                    orElse: () => {'key': 'default', 'nameEn': 'Default Ring', 'nameZh': '默认圆环'},
                  );
                  final String displayName = isZh ? currentItem['nameZh']! : currentItem['nameEn']!;

                  return Text(
                    displayName,
                    style: AppTextStyles.t13.copyWith(color: Theme.of(context).colorScheme.outline),
                  );
                }),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('room_card_settings')),
          context.buildModernCard([
            KeyedSubtree(
              key: const ValueKey('room-card-settings-entry'),
              child: context.buildTile(
                icon: Remix.layout_grid_line,
                title: i18n('room_card_settings'),
                subtitle: i18n('room_card_settings_subtitle'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Get.to(() => const RoomCardSettingsPage()),
              ),
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
          if (Get.width > 680) ...[
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n("page_settings")),
            context.buildModernCard([
              context.buildTile(
                icon: Remix.pages_line,
                title: i18n('page_settings'),
                subtitle: i18n('page_settings_subtitle'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Get.to(() => const PageSettingsPage()),
              ),
            ]),
          ],

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
                subtitle:
                    "${i18n("current_font_prefix")}: ${SettingsService.to.font.fontFamilyFileName.v.isNotEmpty ? SettingsService.to.font.fontFamilyFileName.v : SettingsService.to.font.fontFamilyName.v}",
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

            Obx(
              () => context.buildSliderTile(
                context,
                icon: Remix.text_spacing,
                title: i18n("text_size_title"),
                value: SettingsService.to.font.textScaleFactor.v,
                min: FontSettingsController.minTextScaleFactor,
                max: FontSettingsController.maxTextScaleFactor,
                displayValue: SettingsService.to.font.textScaleFactor.v.toStringAsFixed(2),
                onChanged: (val) {
                  SettingsService.to.font.textScaleFactor.v = val;
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

  Future<void> showThemeModeSelectorDialog() async {
    final value = await showDialog<String>(
      context: Get.context!,
      builder: (context) => ThemeChoiceDialog<String>(
        title: i18n('change_theme_mode'),
        value: SettingsService.to.theme.resolvedThemeModeName,
        items: {for (final name in AppConsts.themeModes.keys) name: i18n(AppConsts.themeModeI18n[name]!)},
      ),
    );
    if (value != null) SettingsService.to.theme.changeThemeMode(value);
  }

  Future<bool> colorPickerDialog() async {
    final bool isZh = Get.locale?.languageCode == 'zh';
    final initialColor = SettingsService.to.theme.themeColor;
    return showAppColorPickerDialog(
      context: Get.context!,
      initialColor: initialColor,
      title: i18n('theme_color'),
      enableOpacity: false,
      labels: buildAppColorPickerLabels(translate: (key) => i18n(key), isChinese: isZh, enableOpacity: false),
      customColorSwatchesAndNames: AppConsts.colorsNameMap,
      onColorChanged: (Color color) {
        SettingsService.to.theme.themeColorSwitch.v = color.hex;
        final lightTheme = MyTheme(primaryColor: color).lightThemeData;
        final darkTheme = MyTheme(primaryColor: color).darkThemeData;
        Get.changeTheme(lightTheme);
        Get.changeTheme(darkTheme);
      },
    );
  }

  Future<void> showLanguageSelecterDialog() async {
    final pageContext = Get.context!;
    final value = await showDialog<String>(
      context: pageContext,
      builder: (context) => ThemeChoiceDialog<String>(
        title: i18n('change_language'),
        value: SettingsService.to.theme.resolvedLanguageName,
        items: {for (final name in AppConsts.languages.keys) name: name},
      ),
    );
    if (value != null && pageContext.mounted) {
      await SettingsService.to.theme.changeLanguage(value, pageContext);
    }
  }

  Future<void> showCrossAxisSpacingDialog() {
    return showCustomSpacingDialog(
      title: i18n("cross_axis_spacing"),
      hintText: i18n("cross_axis_spacing_subtitle"),
      currentValue: SettingsService.to.theme.resolvedCrossAxisSpacing,
      onSelected: (value) => SettingsService.to.theme.crossAxisSpacing.v = value,
    );
  }

  Future<void> showMainAxisSpacingDialog() {
    return showCustomSpacingDialog(
      title: i18n("main_axis_spacing"),
      hintText: i18n("main_axis_spacing_subtitle"),
      currentValue: SettingsService.to.theme.resolvedMainAxisSpacing,
      onSelected: (value) => SettingsService.to.theme.mainAxisSpacing.v = value,
    );
  }

  Future<void> showCustomSpacingDialog({
    required String title,
    required String hintText,
    required double currentValue,
    required ValueChanged<double> onSelected,
  }) async {
    final selectedValue = await Get.dialog<double>(
      ThemeSpacingDialog(title: title, hintText: hintText, currentValue: currentValue),
    );
    if (selectedValue != null) onSelected(selectedValue);
  }
}

class ThemeChoiceDialog<T> extends StatelessWidget {
  const ThemeChoiceDialog({super.key, required this.title, required this.value, required this.items});

  final String title;
  final T value;
  final Map<T, String> items;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.width < 420 || mediaQuery.textScaler.scale(13) > 18;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: mediaQuery.size.height - 48),
        child: SingleChildScrollView(
          key: const ValueKey('theme-choice-dialog-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 20, compact ? 12 : 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Tooltip(
                  message: title,
                  child: Text(
                    title,
                    key: const ValueKey('theme-choice-dialog-title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<T>(
                groupValue: value,
                onChanged: (selected) {
                  if (selected != null) Navigator.of(context).pop(selected);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items.entries.map((entry) {
                    return RadioListTile<T>(
                      key: ValueKey('theme-choice-${entry.key}'),
                      title: Tooltip(message: entry.value, child: Text(entry.value)),
                      value: entry.key,
                      activeColor: Theme.of(context).colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class ThemeSpacingPolicy {
  static const double min = ThemeSettingsController.minSpacing;
  static const double max = ThemeSettingsController.maxSpacing;

  static double? tryParse(String rawValue) {
    final value = double.tryParse(rawValue.trim());
    if (value == null || !value.isFinite || value < min || value > max) return null;
    return value;
  }
}

class ThemeSpacingDialog extends StatefulWidget {
  const ThemeSpacingDialog({super.key, required this.title, required this.hintText, required this.currentValue});

  final String title;
  final String hintText;
  final double currentValue;

  @override
  State<ThemeSpacingDialog> createState() => _ThemeSpacingDialogState();
}

class _ThemeSpacingDialogState extends State<ThemeSpacingDialog> {
  static const _quickOptions = <double>[0, 4, 6, 8, 12, 16];

  late final TextEditingController _textController;
  late double _selectedValue;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedValue = ThemeSpacingPolicy.tryParse(_format(widget.currentValue)) ?? 6;
    _textController = TextEditingController(text: _format(_selectedValue));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _format(double value) => value == value.truncateToDouble() ? value.toInt().toString() : value.toString();

  void _select(double value) {
    setState(() {
      _selectedValue = value;
      _errorText = null;
      _textController.value = TextEditingValue(
        text: _format(value),
        selection: TextSelection.collapsed(offset: _format(value).length),
      );
    });
  }

  void _step(double delta) {
    final parsed = ThemeSpacingPolicy.tryParse(_textController.text) ?? _selectedValue;
    _select((parsed + delta).clamp(ThemeSpacingPolicy.min, ThemeSpacingPolicy.max).toDouble());
  }

  void _submit() {
    final value = ThemeSpacingPolicy.tryParse(_textController.text);
    if (value == null) {
      setState(() => _errorText = i18n('spacing_value_invalid'));
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.width < 420 || mediaQuery.textScaler.scale(13) > 18;
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: mediaQuery.size.height - 48),
        child: SingleChildScrollView(
          key: const ValueKey('theme-spacing-dialog-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: widget.title,
                child: Text(
                  widget.title,
                  key: const ValueKey('theme-spacing-dialog-title'),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickOptions.map((value) {
                  return ChoiceChip(
                    key: ValueKey('theme-spacing-preset-${value.toInt()}'),
                    label: Text('${value.toInt()} px'),
                    selected: value == _selectedValue,
                    showCheckmark: false,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (selected) {
                      if (selected) _select(value);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(widget.hintText, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('theme-spacing-input'),
                controller: _textController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  errorText: _errorText,
                  errorMaxLines: 3,
                  suffixIcon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('theme-spacing-increment'),
                        tooltip: '+1',
                        constraints: const BoxConstraints(
                          minWidth: kMinInteractiveDimension,
                          minHeight: kMinInteractiveDimension,
                        ),
                        onPressed: () => _step(1),
                        icon: const Icon(Icons.arrow_drop_up),
                      ),
                      IconButton(
                        key: const ValueKey('theme-spacing-decrement'),
                        tooltip: '-1',
                        constraints: const BoxConstraints(
                          minWidth: kMinInteractiveDimension,
                          minHeight: kMinInteractiveDimension,
                        ),
                        onPressed: () => _step(-1),
                        icon: const Icon(Icons.arrow_drop_down),
                      ),
                    ],
                  ),
                ),
                onChanged: (rawValue) {
                  final value = ThemeSpacingPolicy.tryParse(rawValue);
                  setState(() {
                    _errorText = null;
                    if (value != null) _selectedValue = value;
                  });
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: const ValueKey('theme-spacing-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(i18n('cancel')),
                  ),
                  ElevatedButton(
                    key: const ValueKey('theme-spacing-confirm'),
                    onPressed: _submit,
                    child: Text(i18n('confirm')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
