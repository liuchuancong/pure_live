import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/dialogs/theme_color_dialog.dart'
    show showThemeColorDialog, themeSeedToneLabel;
import 'package:pure_live/features/settings/pages/font_manager_page.dart' show fontFamilyLabel, showFontManagerPage;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';

/// The theme picker at the top of the theme page: the three theme modes as
/// previews. Picking a preview applies it at once, as Windows' theme
/// thumbnails do.
final class ThemePreviewSection extends StatelessWidget {
  const ThemePreviewSection({required this.settings, required this.onChanged, this.dynamicSeed, super.key});

  final AppThemeSettings settings;

  /// The palette seed in force while dynamic colour is on; the previews show
  /// the colours the app actually uses.
  final Color? dynamicSeed;

  final ValueChanged<DsThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    DsThemeData preview(DsThemeMode mode) {
      final brightness = switch (mode) {
        DsThemeMode.light => Brightness.light,
        DsThemeMode.dark => Brightness.dark,
        DsThemeMode.system => platformDark ? Brightness.dark : Brightness.light,
      };
      return DsThemeData(
        brightness: brightness,
        seed: dynamicSeed == null ? settings.seed ?? DsSeed.blue : DsSeed.color(dynamicSeed!),
        contrast: settings.contrast,
        cornerStyle: settings.cornerStyle,
        selectionStyle: settings.selectionStyle,
        autoClashRule: settings.autoClashRule,
        density: settings.density,
        platform: settings.platform,
        adjustColors: settings.adjustColors,
      );
    }

    final ui = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.settings.personalizationChooseTheme, style: ui.typography.heading.copyWith(color: colors.text)),
        DsListSection(
          children: [
            Padding(
              padding: const EdgeInsets.all(DsSpace.s16),
              child: Wrap(
                spacing: DsSpace.s12,
                runSpacing: DsSpace.s12,
                children: [
                  for (final mode in DsThemeMode.values)
                    SizedBox(
                      width: 150,
                      child: ThemeModeTile(
                        theme: preview(mode),
                        selected: settings.mode == mode,
                        label: themeModeLabel(t, mode),
                        onPressed: () => onChanged(mode),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One theme mode as a thumbnail: a window in that theme, the mode's name
/// under it, and the accent edge plus a check while it is the theme in force.
final class ThemeModeTile extends StatelessWidget {
  const ThemeModeTile({
    required this.theme,
    required this.selected,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final DsThemeData theme;
  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      onPressed: onPressed,
      selected: selected,
      semanticLabel: label,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        final focused = states.contains(WidgetState.focused);
        final edge = selected
            ? colors.accent
            : focused
            ? colors.focus
            : hovered
            ? colors.textSubtle
            : colors.border;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            AnimatedContainer(
              duration: ui.motion.toneDuration,
              curve: ui.motion.toneCurve,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ui.radii.card),
                border: Border.all(color: edge, width: selected || focused ? 2 : 1),
              ),
              child: Stack(
                children: [
                  ThemeWindow(theme: theme),
                  if (selected)
                    PositionedDirectional(
                      top: 7,
                      end: 7,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent),
                        child: DsIcon(DsIcons.check, size: 12, color: colors.onAccent),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: ui.typography.caption.copyWith(color: selected ? colors.text : colors.textMuted),
            ),
          ],
        );
      },
    );
  }
}

/// A small app window drawn from one theme's own tokens: chrome, a rail,
/// text bars and an accent action. It is the theme preview, not a picture.
final class ThemeWindow extends StatelessWidget {
  const ThemeWindow({required this.theme, super.key});

  final DsThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colors;
    Widget dot() => Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSubtle.withValues(alpha: 0.55)),
    );
    Widget bar(double width, {double height = 5, Color? color}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color ?? colors.border, borderRadius: BorderRadius.circular(3)),
    );
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: colors.field,
              child: Row(spacing: 4, children: [dot(), dot(), dot()]),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    color: colors.field.withValues(alpha: 0.55),
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [bar(22, height: 4), bar(16, height: 4), bar(20, height: 4), bar(14, height: 4)],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          bar(58, height: 6, color: colors.textMuted.withValues(alpha: 0.6)),
                          bar(96, height: 4),
                          bar(72, height: 4),
                          const Spacer(),
                          Container(
                            width: 44,
                            height: 9,
                            decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The theme page: the three theme modes as previews at the top, then the
/// palette and the design system's own choices — contrast, selection style
/// and the clash rule are as much a setting as light/dark — plus the type
/// that carries them and the app language. One labelled row per choice, the
/// control inline on a wide pane and under the label on a narrow one.
final class ThemePane extends ConsumerWidget {
  const ThemePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final scope = AppThemeScope.of(context);
    final localeScope = AppLocaleScope.of(context);
    final settings = scope.settings;
    String? seedName;
    for (final (name, seed) in kNamedSeeds) {
      if (seed == settings.seed) seedName = name;
    }
    final customSeed = scope.seedColor;
    final dynamicSeed = scope.dynamicSeedColor;
    final textScale = ref.watch(textScaleFactorProvider);
    final dynamicSupported = ref.watch(dynamicColorSeedProvider).value != null;
    final dynamicEnabled = ref.watch(dynamicColorProvider);
    final followTone = ref.watch(backgroundSettingsProvider.select((settings) => settings.followTone));
    final seedDetail = seedName != null
        ? themeSeedToneLabel(t, seedName)
        : customSeed != null
        ? ThemePersistence.encodeSeedColor(customSeed)
        : t.settings.themeSeedSystem;
    void update(AppThemeSettings next) => scope.onChanged(next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        ThemePreviewSection(
          settings: settings,
          dynamicSeed: dynamicSeed,
          onChanged: (mode) {
            if (mode != settings.mode) update(settings.rebuild((b) => b..mode = mode));
          },
        ),
        DsListSection(
          header: Text(t.settings.groupTheme),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.contrast),
              title: Text(t.settings.followBackgroundTone),
              description: Text(t.settings.followBackgroundToneDescription),
              trailing: DsSwitch(
                value: followTone,
                onChanged: (value) => ref.read(backgroundSettingsProvider.notifier).setFollowTone(value: value),
              ),
            ),
            DsListRow(
              leading: dynamicSeed != null
                  ? SeedSwatch.color(dynamicSeed)
                  : seedName != null
                  ? SeedSwatch(seed: settings.seed)
                  : customSeed != null
                  ? SeedSwatch.color(customSeed)
                  : const DsIcon(DsIcons.palette),
              title: Text(t.settings.themeSeed),
              // While dynamic colour is on the wallpaper decides; the picker
              // would write a seed the theme never uses.
              description: Text(
                dynamicSeed != null ? t.settings.themeSeedDynamicDescription : t.settings.themeSeedDescription,
              ),
              detail: Text(dynamicSeed != null ? t.settings.themeSeedDynamic : seedDetail),
              showChevron: dynamicSeed == null,
              onPressed: dynamicSeed == null
                  ? () => unawaited(
                      showThemeColorDialog(
                        context,
                        settings: settings,
                        seedColor: customSeed,
                        onChanged: scope.onChanged,
                      ),
                    )
                  : null,
            ),
            if (dynamicSupported)
              DsListRow(
                leading: const DsIcon(DsIcons.wandSparkles),
                title: Text(t.settings.dynamicColor),
                description: Text(t.settings.dynamicColorDescription),
                trailing: DsSwitch(
                  value: dynamicEnabled,
                  onChanged: (value) => ref.read(dynamicColorProvider.notifier).enabled = value,
                ),
              ),
            SettingsChoiceRow<DsContrast>(
              leading: const DsIcon(DsIcons.contrast),
              title: t.settings.contrast,
              description: t.settings.contrastDescription,
              value: settings.contrast,
              options: [
                DsSelectOption(value: DsContrast.soft, label: t.settings.contrastSoft),
                DsSelectOption(value: DsContrast.standard, label: t.settings.contrastStandard),
              ],
              onChanged: (value) => update(settings.rebuild((b) => b..contrast = value)),
            ),
            SettingsChoiceRow<DsSelectionStyle>(
              leading: const DsIcon(DsIcons.ellipseSelection),
              title: t.settings.selectionStyle,
              description: t.settings.selectionDescription,
              value: settings.selectionStyle,
              options: [
                DsSelectOption(value: DsSelectionStyle.soft, label: t.settings.selectionSoft),
                DsSelectOption(value: DsSelectionStyle.strong, label: t.settings.selectionStrong),
              ],
              onChanged: (value) => update(settings.rebuild((b) => b..selectionStyle = value)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.wandSparkles),
              title: Text(t.settings.autoClash),
              description: Text(t.settings.autoClashDesc),
              trailing: DsSwitch(
                value: settings.autoClashRule,
                onChanged: (value) => update(settings.rebuild((b) => b..autoClashRule = value)),
              ),
            ),
            SettingsChoiceRow<DsCornerStyle>(
              leading: const DsIcon(DsIcons.cornerDownRight),
              title: t.settings.corners,
              value: settings.cornerStyle,
              options: [
                DsSelectOption(value: DsCornerStyle.sharp, label: t.settings.cornersSharp),
                DsSelectOption(value: DsCornerStyle.standard, label: t.settings.cornersStandard),
                DsSelectOption(value: DsCornerStyle.soft, label: t.settings.cornersSoft),
                DsSelectOption(value: DsCornerStyle.pill, label: t.settings.cornersPill),
              ],
              onChanged: (value) => update(settings.rebuild((b) => b..cornerStyle = value)),
            ),
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.rows3),
              title: t.settings.density,
              value: settings.density?.name ?? '',
              options: [
                DsSelectOption(value: '', label: t.settings.densitySystem),
                DsSelectOption(value: 'compact', label: t.settings.densityCompact),
                DsSelectOption(value: 'touch', label: t.settings.densityTouch),
              ],
              onChanged: (value) {
                final density = switch (value) {
                  'compact' => DsDensity.compact,
                  'touch' => DsDensity.touch,
                  _ => null,
                };
                update(settings.rebuild((b) => b..density = density));
              },
            ),
          ],
        ),
        // The language is the other thing this page decides for the whole
        // app, so it gets its own card ahead of the type that carries it.
        DsListSection(
          header: Text(t.settings.groupLanguage),
          children: [
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.languages),
              title: t.settings.language,
              value: localeScope.localeCode ?? '',
              options: [
                DsSelectOption(value: '', label: t.settings.languageSystem),
                DsSelectOption(
                  value: ThemePersistence.localeSimplifiedChinese,
                  label: t.settings.languageSimplifiedChinese,
                ),
                DsSelectOption(value: ThemePersistence.localeEnglish, label: t.settings.languageEnglish),
              ],
              onChanged: (value) => localeScope.onChanged(value.isEmpty ? null : value),
            ),
          ],
        ),
        // The typeface and the overall text scale belong to the theme: they
        // change what every page is drawn with, which is what this page is
        // for. They keep their own card so the colour rows stay one group.
        // The card gaps are not here — they configure the feed grids, so they
        // live on the browsing page with the rest of the cards.
        DsListSection(
          header: Text(t.settings.navTypography),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.type),
              title: Text(t.settings.font),
              description: Text(t.settings.fontDescription),
              detail: Text(
                fontFamilyLabel(
                  t,
                  settings.fontFamily,
                  name: ref.watch(freeFontStoreProvider).nameOf(settings.fontFamily),
                ),
              ),
              showChevron: true,
              onPressed: () => showFontManagerPage(context, ref),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.fontSize),
              title: t.settings.textScale,
              description: t.settings.textScaleDescription,
              detail: Text('${(textScale * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: textScale,
                min: kMinTextScaleFactor,
                max: kMaxTextScaleFactor,
                divisions: ((kMaxTextScaleFactor - kMinTextScaleFactor) / kTextScaleStep).round(),
                onChanged: (value) => ref.read(textScaleFactorProvider.notifier).factor = value,
                semanticLabel: t.settings.textScale,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A seed as a small color dot, so the palette choice reads as a color
/// rather than a word.
final class SeedSwatch extends StatelessWidget {
  const SeedSwatch({required this.seed, super.key}) : color = null;

  const SeedSwatch.color(this.color, {super.key}) : seed = null;

  final DsSeed? seed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dot = color ?? (_seedAccents[seed!] ??= DsThemeData(seed: seed!).colors.accent);
    return Container(
      width: 14,
      height: 14,
      decoration: DsBoxDecoration(color: dot, borderRadius: BorderRadius.circular(7)),
    );
  }
}

/// Generated seed accents, one per named tone (the theme engine's output is
/// stable for one seed).
final Map<DsSeed, Color> _seedAccents = {};
