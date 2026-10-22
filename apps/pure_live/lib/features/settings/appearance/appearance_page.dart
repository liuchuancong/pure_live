import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/navigation/app_router.dart';
import 'package:pure_live/system/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/system/theme/font_recommendations.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The appearance page (3.x `ThemeSettingsPage`, trimmed to the backed
/// controls): the reference's sectioned shape — a themed group, a font group and
/// a text-size group — written as one `SettingsList`, so each design language
/// draws its own cards and rows instead of this page's hand-drawn Material card.
///
/// The controls whose own page this build ships (loading style, room card,
/// page settings) are links here, and the grid gaps are sliders: the appearance
/// page is where the reference groups them, so a viewer looking for them finds
/// them where the reference put them.
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
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appearancePreferencesProvider.notifier).update;
    final updatePreferences = ref.read(appPreferencesProvider.notifier).update;
    return SettingsChrome(
      title: t.settings.appearance,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.groupTheme),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(t.settings.themeMode),
                description: Text(t.settings.themeModeSubtitle),
                onPressed: (_) => unawaited(_chooseThemeMode(context, ref, appearance, update)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.colorize_outlined),
                title: Text(t.settings.accent),
                description: Text(t.settings.accentSubtitle),
                trailing: _accentSwatch(context, appearance.accentColor),
                onPressed: (_) => unawaited(_chooseAccent(context, update)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.wallpaper_outlined),
                title: Text(t.wallpaper.title),
                // The answer, not a subtitle: which surface the app paints on
                // is a state the row reports.
                value: Text(_wallpaperSummary(context, appearance)),
                onPressed: (_) => unawaited(const WallpaperRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.format_line_spacing),
                title: Text(t.settings.density),
                description: Text(t.settings.densitySubtitle),
                onPressed: (_) => unawaited(_chooseDensity(context, ref, appearance, update)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.translate_outlined),
                title: Text(t.settings.language),
                description: Text(t.settings.languageSubtitle),
                value: Text(_languageLabel(context, ref.read(appPreferencesProvider).languageId)),
                onPressed: (_) => unawaited(_chooseLanguage(context, ref)),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('appearance-dynamic-color'),
                leading: const Icon(Icons.color_lens_outlined),
                title: Text(t.settings.dynamicColor),
                description: Text(t.settings.dynamicColorSubtitle),
                initialValue: appearance.dynamicColor,
                onToggle: (value) => update((a) => a.copyWith(dynamicColor: value)),
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.contrast_outlined),
                title: Text(t.settings.pureBlack),
                description: Text(t.settings.pureBlackSubtitle),
                initialValue: appearance.pureBlack,
                onToggle: (value) => update((a) => a.copyWith(pureBlack: value)),
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.blur_off_outlined),
                title: Text(t.settings.reduceTransparency),
                description: Text(t.settings.reduceTransparencySubtitle),
                initialValue: appearance.reduceTransparency,
                onToggle: (value) => update((a) => a.copyWith(reduceTransparency: value)),
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.animation_outlined),
                title: Text(t.settings.animations),
                description: Text(t.settings.animationsSubtitle),
                initialValue: appearance.animations,
                onToggle: (value) => update((a) => a.copyWith(animations: value)),
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.filter_center_focus_outlined),
                title: Text(t.settings.focusOutline),
                description: Text(t.settings.focusOutlineSubtitle),
                initialValue: appearance.focusOutline,
                onToggle: (value) => update((a) => a.copyWith(focusOutline: value)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionFeedDisplay),
            tiles: [
              SettingsTile.navigation(
                key: const ValueKey('appearance-loading-style'),
                leading: const Icon(Icons.animation_outlined),
                title: Text(t.settings.loadingStyle),
                description: Text(t.settings.loadingStyleSubtitle),
                onPressed: (_) => unawaited(const LoadingStyleSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                key: const ValueKey('appearance-room-card'),
                leading: const Icon(Icons.view_agenda_outlined),
                title: Text(t.settings.roomCardSettings),
                description: Text(t.settings.roomCardSettingsSubtitle),
                onPressed: (_) => unawaited(const RoomCardSettingsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                key: const ValueKey('appearance-page-settings'),
                leading: const Icon(Icons.tune_outlined),
                title: Text(t.settings.pageSettings),
                description: Text(t.settings.pageSettingsSubtitle),
                onPressed: (_) => unawaited(const PageSettingsRoute().push<void>(context)),
              ),
              CustomSettingsTile(
                child: SettingsSliderRow(
                  icon: Icons.swap_horiz_outlined,
                  title: t.settings.crossAxisSpacing,
                  subtitle: t.settings.crossAxisSpacingSubtitle,
                  value: preferences.crossAxisSpacing,
                  max: 64,
                  valueLabel: '${preferences.crossAxisSpacing.round()} px',
                  onChanged: (value) => unawaited(updatePreferences((p) => p.copyWith(crossAxisSpacing: value))),
                ),
              ),
              CustomSettingsTile(
                child: SettingsSliderRow(
                  icon: Icons.swap_vert_outlined,
                  title: t.settings.mainAxisSpacing,
                  subtitle: t.settings.mainAxisSpacingSubtitle,
                  value: preferences.mainAxisSpacing,
                  max: 64,
                  valueLabel: '${preferences.mainAxisSpacing.round()} px',
                  onChanged: (value) => unawaited(updatePreferences((p) => p.copyWith(mainAxisSpacing: value))),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.groupFontFamily),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.font_download_outlined),
                title: Text(t.settings.fonts),
                value: Text(_currentFontName(context, ref, appearance)),
                onPressed: (_) => unawaited(const FontManagerRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.groupTextSize),
            tiles: [
              CustomSettingsTile(
                child: SettingsSliderRow(
                  icon: Icons.format_size_outlined,
                  title: t.settings.fontScale,
                  subtitle: t.settings.fontScaleSubtitle,
                  value: appearance.fontScale,
                  min: 0.8,
                  max: 1.4,
                  onChanged: (value) => update((a) => a.copyWith(fontScale: value)),
                ),
              ),
              SettingsTile.navigation(
                key: const ValueKey('appearance-fine-fonts'),
                leading: const Icon(Icons.format_size),
                title: Text(t.settings.fineFontSizes),
                description: Text(t.settings.fineFontSizesSubtitle),
                onPressed: (_) => unawaited(const FontSizesRoute().push<void>(context)),
              ),
              CustomSettingsTile(
                child: SettingsSliderRow(
                  icon: Icons.opacity_outlined,
                  title: t.settings.transparency,
                  subtitle: t.settings.transparencySubtitle,
                  value: appearance.transparency,
                  onChanged: (value) => update((a) => a.copyWith(transparency: value)),
                ),
              ),
              // The preview line is the reference's, and it is the real thing:
              // drawn with the text role the slider above drives.
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(PureSpacing.lg, 18, PureSpacing.lg, 18),
                  child: Text(
                    t.settings.previewText,
                    style: PureTheme.of(context).text.body,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _currentFontName(BuildContext context, WidgetRef ref, AppearancePreferences appearance) {
    final family = appearance.fontFamily;
    if (family == kThemeFontFamily) {
      // Name the family actually drawing, not the sentinel.
      final recommended = recommendedFontFor(ref.read(uiStartupConfigProvider).language);
      return recommended.name.isEmpty
          ? context.t.fonts.followTheme
          : context.t.fonts.followThemeCurrent(name: recommended.name);
    }
    return family.isEmpty ? context.t.fonts.system : family;
  }

  /// One line on what the wallpaper layer currently paints.
  static String _wallpaperSummary(BuildContext context, AppearancePreferences appearance) =>
      switch (appearance.wallpaperKind) {
        WallpaperKind.none => context.t.wallpaper.currentNone,
        WallpaperKind.solid => context.t.wallpaper.currentSolid,
        WallpaperKind.gradient => context.t.wallpaper.currentGradient,
        WallpaperKind.image => context.t.wallpaper.currentImage,
      };

  static Future<void> _chooseThemeMode(
    BuildContext context,
    WidgetRef ref,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) {
    final t = context.t;
    return _choose<AppThemeMode>(
      context,
      ref,
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

  /// The interface language, each name written in its own language — a language
  /// is never translated into the language the user is leaving. The empty id is
  /// the system's answer, so its label comes from the strings.
  static const List<(String, String)> _languages = [('', ''), ('zh', '简体中文'), ('en', 'English')];

  /// The language choice.
  ///
  /// It writes the general preferences — the document the boot reads before the
  /// first frame — and re-translates the running tree at once: slang swaps the
  /// locale under the `TranslationProvider` the app is wrapped in, so this page
  /// repaints in the new language as the dialog closes.
  static Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appPreferencesProvider).languageId;
    final picked = await showSettingsChooser<String>(
      context,
      ref,
      title: context.t.settings.language,
      current: current,
      options: [
        for (final entry in _languages) (entry.$1, entry.$1.isEmpty ? context.t.settings.languageSystem : entry.$2),
      ],
    );
    if (picked == null) {
      return;
    }
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(languageId: picked));
    if (picked.isEmpty) {
      LocaleSettings.useDeviceLocaleSync();
    } else {
      LocaleSettings.setLocaleRawSync(picked);
    }
  }

  static String _languageLabel(BuildContext context, String id) =>
      id.isEmpty ? context.t.settings.languageSystem : _languages.firstWhere((entry) => entry.$1 == id).$2;

  static Future<void> _chooseDensity(
    BuildContext context,
    WidgetRef ref,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) {
    final ids = UiDensity.values.map((density) => density.name).toList();
    return _choose<String>(
      context,
      ref,
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

  /// The chooser: the settings cluster's shared radio-list dialog, then the
  /// write it picked.
  static Future<void> _choose<T>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required T current,
    required List<(T, String)> options,
    required Future<void> Function(T value) onPicked,
  }) async {
    final picked = await showSettingsChooser<T>(context, ref, title: title, current: current, options: options);
    if (picked == null) {
      return;
    }
    await onPicked(picked);
  }

  static Widget _accentSwatch(BuildContext context, int? argb) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: argb == null ? const Color(0xFF888888) : Color(argb),
      shape: BoxShape.circle,
      border: Border.all(color: PureTheme.of(context).colors.onPrimary, width: 3),
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
