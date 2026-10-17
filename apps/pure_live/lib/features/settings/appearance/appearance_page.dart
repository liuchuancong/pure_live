import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/settings/settings_routes.dart';
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The appearance page (3.x `ThemeSettingsPage`, trimmed to the backed
/// controls): the reference's sectioned shape — a themed group, a font group
/// and a text-size group over rounded cards of rows — with every control
/// writing straight into the persisted appearance, so the app re-skins under
/// the viewer's finger.
///
/// The reference's chooser rows open dialogs; the same interaction lives here
/// as a chooser dialog over the uikit's rows. The controls the reference ships
/// without a backing in this build (dynamic colour, loading style, room card,
/// grid spacing, page settings, language) stay out.
final class AppearancePage extends ConsumerWidget {
  /// The appearance page.
  const new({super.key});

  /// The accent presets the chooser offers; null is the design language's own.
  static const List<int?> _accentPresets = <int?>[
    null,
    0xFF0A84FF,
    0xFF30D158,
    0xFFFF9F0A,
    0xFFFF375F,
    0xFFBF5AF2,
    0xFF64D2FF,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final appearance = ref.watch(appearancePreferencesProvider);
    final update = ref.read(appearancePreferencesProvider.notifier).update;
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.appearance),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection.card(
            label: t.settings.groupTheme,
            tiles: [
              SettingsEntryTile(
                icon: Icons.dark_mode_outlined,
                title: t.settings.themeMode,
                subtitle: t.settings.themeModeSubtitle,
                onTap: () => _chooseThemeMode(context, appearance, update),
              ),
              SettingsEntryTile(
                icon: Icons.style_outlined,
                title: t.settings.designLanguage,
                subtitle: t.settings.designLanguageSubtitle,
                onTap: () => _chooseDesignLanguage(context, appearance, update),
              ),
              SettingsEntryTile(
                icon: Icons.colorize_outlined,
                title: t.settings.accent,
                subtitle: t.settings.accentSubtitle,
                trailing: _accentSwatch(context, appearance.accentColor, selected: true),
                onTap: () => _chooseAccent(context, update),
              ),
              SettingsEntryTile(
                icon: Icons.format_line_spacing,
                title: t.settings.density,
                subtitle: t.settings.densitySubtitle,
                onTap: () => _chooseDensity(context, appearance, update),
              ),
              SettingsSwitchTile(
                icon: Icons.contrast_outlined,
                title: t.settings.pureBlack,
                subtitle: t.settings.pureBlackSubtitle,
                value: appearance.pureBlack,
                onChanged: (value) => update((a) => a.copyWith(pureBlack: value)),
              ),
              SettingsSwitchTile(
                icon: Icons.blur_off_outlined,
                title: t.settings.reduceTransparency,
                subtitle: t.settings.reduceTransparencySubtitle,
                value: appearance.reduceTransparency,
                onChanged: (value) => update((a) => a.copyWith(reduceTransparency: value)),
              ),
              SettingsSwitchTile(
                icon: Icons.animation_outlined,
                title: t.settings.animations,
                subtitle: t.settings.animationsSubtitle,
                value: appearance.animations,
                onChanged: (value) => update((a) => a.copyWith(animations: value)),
              ),
              SettingsSwitchTile(
                icon: Icons.filter_center_focus_outlined,
                title: t.settings.focusOutline,
                subtitle: t.settings.focusOutlineSubtitle,
                value: appearance.focusOutline,
                onChanged: (value) => update((a) => a.copyWith(focusOutline: value)),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.groupFontFamily,
            tiles: [
              SettingsEntryTile(
                icon: Icons.font_download_outlined,
                title: t.settings.fonts,
                subtitle: t.settings.fontFamilyCurrent(name: _currentFontName(context, appearance)),
                onTap: () => const FontManagerRoute().push<void>(context),
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection(
            label: t.settings.groupTextSize,
            children: [
              SettingsSliderCard(
                icon: Icons.format_size_outlined,
                title: t.settings.fontScale,
                subtitle: t.settings.fontScaleSubtitle,
                child: PureSlider(
                  value: appearance.fontScale,
                  min: 0.8,
                  max: 1.4,
                  onChanged: (value) => update((a) => a.copyWith(fontScale: value)),
                ),
              ),
              SettingsSliderCard(
                icon: Icons.opacity_outlined,
                title: t.settings.transparency,
                subtitle: t.settings.transparencySubtitle,
                child: PureSlider(
                  value: appearance.transparency,
                  onChanged: (value) => update((a) => a.copyWith(transparency: value)),
                ),
              ),
              PureCard(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    t.settings.previewText,
                    style: PureTheme.of(context).text.body,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _currentFontName(BuildContext context, AppearancePreferences appearance) {
    final family = appearance.fontFamily;
    return (family == null || family.isEmpty) ? context.t.fonts.system : family;
  }

  static Future<void> _chooseThemeMode(
    BuildContext context,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) {
    final t = context.t;
    return _choose<AppThemeMode>(
      context,
      title: t.settings.themeMode,
      current: appearance.themeMode,
      options: [
        (AppThemeMode.system, t.theme.system),
        (AppThemeMode.light, t.theme.light),
        (AppThemeMode.dark, t.theme.dark),
      ],
      onPicked: (mode) => update((a) => a.copyWith(themeMode: mode)),
    );
  }

  static Future<void> _chooseDesignLanguage(
    BuildContext context,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) {
    final registered = PureDesignLanguage.values.map((language) => language.name).toList()..sort();
    final ids = ['', ...registered];
    return _choose<String>(
      context,
      title: context.t.settings.designLanguage,
      current: appearance.designLanguageId,
      options: [for (final id in ids) (id, _designLanguageLabel(context, id))],
      onPicked: (id) => update((a) => a.copyWith(designLanguageId: id)),
    );
  }

  static String _designLanguageLabel(BuildContext context, String id) =>
      id.isEmpty ? context.t.design.defaultLanguage : PureDesignLanguage.values.byName(id).name;

  static Future<void> _chooseDensity(
    BuildContext context,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) {
    final ids = UiDensity.values.map((density) => density.name).toList();
    return _choose<String>(
      context,
      title: context.t.settings.density,
      current: appearance.densityId,
      options: [for (final id in ids) (id, id.isEmpty ? context.t.settings.defaultOption : id)],
      onPicked: (id) => update((a) => a.copyWith(densityId: id)),
    );
  }

  static Future<void> _chooseAccent(
    BuildContext context,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) async {
    final picked = await showPureDialog<int>(
      context: context,
      title: context.t.settings.accent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (var i = 0; i < _accentPresets.length; i++) _AccentSwatch(index: i, argb: _accentPresets[i])],
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    await update((a) => a.copyWith(accentColor: _accentPresets[picked]));
  }

  /// The chooser dialog: the reference's radio-list interaction over the
  /// uikit's rows — the current choice marked by its leading check.
  static Future<void> _choose<T>(
    BuildContext context, {
    required String title,
    required T current,
    required List<(T, String)> options,
    required Future<void> Function(T value) onPicked,
  }) async {
    final picked = await showPureDialog<T>(
      context: context,
      title: title,
      // A Builder so a row's submit pops the dialog route, not the page under
      // it — the dialog builds on the root navigator.
      child: Builder(
        builder: (dialogContext) => ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++)
                  PureListRow(
                    title: options[i].$2,
                    leading: Icon(
                      options[i].$1 == current ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: options[i].$1 == current ? PureTheme.of(context).colors.primary : null,
                    ),
                    selected: options[i].$1 == current,
                    onTap: () => Navigator.of(dialogContext).pop(options[i].$1),
                    divided: i < options.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    await onPicked(picked);
  }

  static Widget _accentSwatch(BuildContext context, int? argb, {required bool selected}) => Container(
    width: selected ? 26 : 34,
    height: selected ? 26 : 34,
    decoration: BoxDecoration(
      color: argb == null ? const Color(0xFF888888) : Color(argb),
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? PureTheme.of(context).colors.onPrimary : Colors.white24,
        width: selected ? 3 : 1,
      ),
    ),
    child: argb == null ? const Icon(Icons.block_outlined, size: 14, color: Colors.white70) : null,
  );
}

/// One accent choice in the chooser; pops with its index in the preset list.
final class _AccentSwatch extends StatelessWidget {
  const new({required this.index, required this.argb});

  final int index;
  final int? argb;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final color = argb;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(index),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color == null ? const Color(0xFF888888) : Color(color),
          shape: BoxShape.circle,
          border: Border.all(color: theme.colors.onPrimary),
        ),
        child: color == null ? const Icon(Icons.block_outlined, size: 16, color: Colors.white70) : null,
      ),
    );
  }
}
