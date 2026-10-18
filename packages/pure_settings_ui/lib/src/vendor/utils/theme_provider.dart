import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/pure/settings_language.dart';
import 'package:pure_settings_ui/src/vendor/utils/fluent_tokens.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/unresolved_platform.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureTheme;

// iPadOS 27 Settings, measured in the simulator: the sidebar's tint and the
// filled capsule of the selected row.
const _iPadSidebarBackgroundLight = Color(0xFFE2E6F0);
const _iPadSidebarBackgroundDark = Color(0xFF181D20);
const _iPadSelectedTileColorLight = Color(0xFF0080F5);
const _iPadSelectedTileColorDark = Color(0xFF13A4FF);

class ThemeProvider {
  static SettingsThemeData getTheme({
    required BuildContext context,
    required DevicePlatform platform,
    required Brightness brightness,
  }) {
    switch (platform) {
      case DevicePlatform.android:
      case DevicePlatform.fuchsia:
        return _androidTheme(context: context, brightness: brightness);
      case DevicePlatform.linux:
        return _adwaitaTheme(brightness: brightness);
      case DevicePlatform.macOS:
        return _macosTheme(brightness: brightness);
      case DevicePlatform.iOS:
        return _iosTheme(context: context, brightness: brightness);
      case DevicePlatform.windows:
        return _fluentTheme(brightness: brightness);
      case DevicePlatform.web:
        return _webTheme(context: context, brightness: brightness);
      case DevicePlatform.pure:
        // One file per language: forui's, glass's, neumorphic's and wind's own
        // style, each stating its own palette rather than a shared switch.
        return pureSettingsStyleOf(PureTheme.of(context).config.language)
            .palette(PureTheme.of(context));
      case DevicePlatform.device:
        throwUnresolvedPlatform('ThemeProvider.getTheme');
    }
  }

  /// The app's [ColorScheme] when it has [brightness]. Otherwise, in a list
  /// forced to the other brightness (`SettingsList.brightness`), a scheme of
  /// [brightness] made from the app's primary color, so the Android and web
  /// styles really turn light or dark.
  static ColorScheme colorSchemeOf(
    BuildContext context,
    Brightness brightness,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (scheme.brightness == brightness) return scheme;
    // Building a scheme from a seed is not free, and every list and tile of
    // a forced list asks for the same one.
    final cached = _derivedScheme;
    if (cached != null &&
        cached.seed == scheme.primary &&
        cached.scheme.brightness == brightness) {
      return cached.scheme;
    }
    final derived = ColorScheme.fromSeed(
      seedColor: scheme.primary,
      brightness: brightness,
    );
    _derivedScheme = (seed: scheme.primary, scheme: derived);
    return derived;
  }

  static ({Color seed, ColorScheme scheme})? _derivedScheme;

  /// Puts [child] under the app's Material theme with the colors of
  /// [colorSchemeOf] when the list around [context] is forced to the other
  /// brightness than the app's. The Android and web styles draw Material
  /// widgets (switches, ink, dividers, cards) that read the [Theme], so they
  /// then match the list, and so do Material widgets in custom tiles.
  /// Returns [child] as it is otherwise.
  static Widget withListColorScheme(BuildContext context, Widget child) {
    final brightness = SettingsStyleScope.brightnessOf(context);
    if (brightness == null) return child;
    final theme = Theme.of(context);
    if (theme.colorScheme.brightness == brightness) return child;
    final colorScheme = colorSchemeOf(context, brightness);
    return Theme(
      data: theme.copyWith(
        colorScheme: colorScheme,
        textTheme: theme.textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
      ),
      child: child,
    );
  }

  /// The Material 3 text, icon and highlight colors that the Android and
  /// web styles both take from the active [ColorScheme].
  static SettingsThemeData _materialTheme(ColorScheme colorScheme) {
    return SettingsThemeData(
      tileHighlightColor: colorScheme.secondaryContainer,
      settingsTileTextColor: colorScheme.onSurface,
      tileDescriptionTextColor: colorScheme.onSurfaceVariant,
      leadingIconsColor: colorScheme.onSurfaceVariant,
      inactiveTitleColor: colorScheme.onSurface.withValues(alpha: 0.38),
      inactiveSubtitleColor: colorScheme.onSurface.withValues(alpha: 0.22),
    );
  }

  /// Derives Material 3 colors from the active [ColorScheme], like Android
  /// 16+ settings: a tinted page with lighter cards for the tiles.
  static SettingsThemeData _androidTheme({
    required BuildContext context,
    required Brightness brightness,
  }) {
    final colorScheme = colorSchemeOf(context, brightness);
    final listBackground = colorScheme.surfaceContainer;

    return _materialTheme(colorScheme).copyWith(
      settingsListBackground: listBackground,
      settingsSectionBackground: brightness == Brightness.light
          ? colorScheme.surfaceBright
          : colorScheme.surfaceContainerHighest,
      titleTextColor: colorScheme.primary,
      // AOSP two-pane Settings: the homepage cards sit on surface dim, and
      // the selected card takes the detail pane's color (the page
      // background), so it looks joined to the page next to it.
      listPaneBackground: colorScheme.surfaceDim,
      selectedTileColor: listBackground,
      selectedTileTextColor: colorScheme.onSurface,
      selectedTileIconColor: colorScheme.onSurfaceVariant,
    );
  }

  /// macOS 26/27 System Settings (a SwiftUI grouped `Form`): a white or
  /// #1E1E1E window background with #F7F7F7 or #252525 cards, and the
  /// translucent `NSColor` label colors, which blend with whatever is behind
  /// them like AppKit's do. Like the iOS style, it ignores [ColorScheme].
  static SettingsThemeData _macosTheme({required Brightness brightness}) {
    final isLight = brightness == Brightness.light;

    // labelColor, secondaryLabelColor and tertiaryLabelColor.
    const lightLabel = Color(0xD8000000);
    const darkLabel = Color(0xD8FFFFFF);
    const lightSecondaryLabel = Color(0x7F000000);
    const darkSecondaryLabel = Color(0x8CFFFFFF);
    const lightTertiaryLabel = Color(0x42000000);
    const darkTertiaryLabel = Color(0x3FFFFFFF);

    final label = isLight ? lightLabel : darkLabel;
    final secondaryLabel = isLight ? lightSecondaryLabel : darkSecondaryLabel;
    final tertiaryLabel = isLight ? lightTertiaryLabel : darkTertiaryLabel;

    return SettingsThemeData(
      // windowBackgroundColor, without the wallpaper tint of macOS 26+.
      settingsListBackground: isLight
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF1E1E1E),
      settingsSectionBackground: isLight
          ? const Color(0xFFF7F7F7)
          : const Color(0xFF252525),
      // 1pt separators: black 5% or white 4.7% over the card.
      dividerColor: isLight ? const Color(0xFFEBEBEB) : const Color(0xFF2F2F2F),
      // A pressed row: a light fill over the card.
      tileHighlightColor: isLight
          ? const Color(0x0F000000)
          : const Color(0x14FFFFFF),
      titleTextColor: label,
      settingsTileTextColor: label,
      trailingTextColor: secondaryLabel,
      tileDescriptionTextColor: secondaryLabel,
      leadingIconsColor: secondaryLabel,
      inactiveTitleColor: tertiaryLabel,
      inactiveSubtitleColor: tertiaryLabel,
      // The System Settings sidebar: its flat (non-glass) fill, and the
      // accent-filled selected row with a white label.
      listPaneBackground: isLight
          ? const Color(0xFFEDEDED)
          : const Color(0xFF282828),
      selectedTileColor: isLight
          ? const Color(0xFF0070F5)
          : const Color(0xFF007AFF),
      selectedTileTextColor: const Color(0xFFFFFFFF),
      selectedTileIconColor: const Color(0xFFFFFFFF),
    );
  }

  /// Uses Cupertino system colors for iOS — these are not
  /// derived from [ColorScheme] because Cupertino doesn't use Material theming.
  static SettingsThemeData _iosTheme({
    required BuildContext context,
    required Brightness brightness,
  }) {
    const lightSettingsListBackground = Color.fromRGBO(242, 242, 247, 1);
    const darkSettingsListBackground = CupertinoColors.black;

    const lightSettingSectionColor = CupertinoColors.white;
    const darkSettingSectionColor = Color.fromARGB(255, 28, 28, 30);

    const lightSettingsTitleColor = Color.fromRGBO(60, 60, 67, 0.6);
    const darkSettingsTitleColor = CupertinoColors.systemGrey;

    const lightDividerColor = Color.fromARGB(255, 238, 238, 238);
    const darkDividerColor = Color.fromARGB(255, 40, 40, 42);

    const lightTrailingTextColor = Color.fromARGB(255, 138, 138, 142);
    const darkTrailingTextColor = Color.fromARGB(255, 152, 152, 159);

    const lightTileHighlightColor = Color.fromARGB(255, 209, 209, 214);
    const darkTileHighlightColor = Color.fromARGB(255, 58, 58, 60);

    const lightSettingsTileTextColor = CupertinoColors.black;
    const darkSettingsTileTextColor = CupertinoColors.white;

    const lightLeadingIconsColor = CupertinoColors.inactiveGray;
    const darkLeadingIconsColor = CupertinoColors.inactiveGray;

    final isLight = brightness == Brightness.light;

    return SettingsThemeData(
      tileHighlightColor: isLight
          ? lightTileHighlightColor
          : darkTileHighlightColor,
      settingsListBackground: isLight
          ? lightSettingsListBackground
          : darkSettingsListBackground,
      settingsSectionBackground: isLight
          ? lightSettingSectionColor
          : darkSettingSectionColor,
      titleTextColor: isLight
          ? lightSettingsTitleColor
          : darkSettingsTitleColor,
      dividerColor: isLight ? lightDividerColor : darkDividerColor,
      trailingTextColor: isLight
          ? lightTrailingTextColor
          : darkTrailingTextColor,
      settingsTileTextColor: isLight
          ? lightSettingsTileTextColor
          : darkSettingsTileTextColor,
      leadingIconsColor: isLight
          ? lightLeadingIconsColor
          : darkLeadingIconsColor,
      inactiveTitleColor: CupertinoColors.inactiveGray,
      inactiveSubtitleColor: CupertinoColors.inactiveGray,
      listPaneBackground: isLight
          ? _iPadSidebarBackgroundLight
          : _iPadSidebarBackgroundDark,
      selectedTileColor: isLight
          ? _iPadSelectedTileColorLight
          : _iPadSelectedTileColorDark,
      selectedTileTextColor: CupertinoColors.white,
      selectedTileIconColor: CupertinoColors.white,
    );
  }

  /// GNOME (libadwaita 1.10) colors, like GNOME Settings 51. As in the
  /// libadwaita stylesheet, most colors are the foreground color at some
  /// strength: `rgba(0, 0, 6, 0.8)` in light mode and white in dark mode.
  /// Like the iOS style, this ignores the [ColorScheme].
  static SettingsThemeData _adwaitaTheme({required Brightness brightness}) {
    final isLight = brightness == Brightness.light;
    final foreground = isLight
        ? const Color.fromRGBO(0, 0, 6, 0.8)
        : const Color(0xFFFFFFFF);
    Color dim(double opacity) =>
        foreground.withValues(alpha: foreground.a * opacity);

    return SettingsThemeData(
      // --window-bg-color
      settingsListBackground: isLight
          ? const Color(0xFFFAFAFB)
          : const Color(0xFF222226),
      // --card-bg-color
      settingsSectionBackground: isLight
          ? const Color(0xFFFFFFFF)
          : const Color.fromRGBO(255, 255, 255, 0.08),
      // --card-shade-color, between rows
      dividerColor: isLight
          ? const Color.fromRGBO(0, 0, 6, 0.07)
          : const Color.fromRGBO(0, 0, 6, 0.36),
      titleTextColor: foreground,
      settingsTileTextColor: foreground,
      leadingIconsColor: foreground,
      // .dim-label (opacity 0.55) for subtitles and values
      tileDescriptionTextColor: dim(0.55),
      trailingTextColor: dim(0.55),
      // Pressed rows; hovered rows use 3/8 of it (3%).
      tileHighlightColor: dim(0.08),
      // Disabled rows are drawn at opacity 0.5.
      inactiveTitleColor: dim(0.5),
      inactiveSubtitleColor: dim(0.55 * 0.5),
      // The GNOME Settings sidebar (--sidebar-bg-color); a selected row is
      // the foreground at 10% over it, not the accent, and keeps its text
      // color. Light mode uses that result as a flat color: over a white
      // card, 10% would look like the sidebar itself.
      listPaneBackground: isLight
          ? const Color(0xFFEBEBED)
          : const Color(0xFF2E2E32),
      selectedTileColor: isLight ? const Color(0xFFD8D8DB) : dim(0.10),
      selectedTileTextColor: foreground,
      selectedTileIconColor: foreground,
    );
  }

  /// Windows 11 Settings colors (WinUI 3 theme resources): the Mica
  /// fallback page, near-white (#2B2B2B dark) cards with a hairline border,
  /// and the Windows text colors. Like the iOS style, it does not read the
  /// app's [ColorScheme].
  static SettingsThemeData _fluentTheme({required Brightness brightness}) {
    final tokens = FluentTokens.of(brightness);
    return SettingsThemeData(
      settingsListBackground: tokens.page,
      settingsSectionBackground: tokens.card,
      dividerColor: tokens.cardStroke,
      tileHighlightColor: tokens.cardPressed,
      titleTextColor: tokens.textPrimary,
      settingsTileTextColor: tokens.textPrimary,
      tileDescriptionTextColor: tokens.textSecondary,
      trailingTextColor: tokens.textSecondary,
      leadingIconsColor: tokens.textPrimary,
      inactiveTitleColor: tokens.textDisabled,
      inactiveSubtitleColor: tokens.textDisabled,
      // The NavigationView pane of Windows Settings: on the page itself, with
      // a neutral fill for the selected item.
      listPaneBackground: tokens.page,
      selectedTileColor: tokens.navItemSelected,
      selectedTileTextColor: tokens.textPrimary,
      selectedTileIconColor: tokens.textPrimary,
    );
  }

  /// Web theme follows desktop Chrome settings: white page and cards (the
  /// card shadow separates them) and near-black section titles.
  static SettingsThemeData _webTheme({
    required BuildContext context,
    required Brightness brightness,
  }) {
    final colorScheme = colorSchemeOf(context, brightness);
    final isLight = brightness == Brightness.light;

    final listBackground = isLight
        ? colorScheme.surfaceContainerLowest
        : colorScheme.surface;

    return _materialTheme(colorScheme).copyWith(
      settingsListBackground: listBackground,
      settingsSectionBackground: isLight
          ? colorScheme.surfaceContainerLowest
          : colorScheme.surfaceContainerLow,
      titleTextColor: colorScheme.onSurface,
      // Chrome's settings menu: a light tint of the accent with accent text
      // (#E8F0FE / #1967D2), and the light accent with dark text in dark
      // mode (#8AB4F8 / #202124).
      selectedTileColor: isLight
          ? Color.alphaBlend(
              colorScheme.primary.withValues(alpha: 0.1),
              listBackground,
            )
          : colorScheme.primary,
      selectedTileTextColor: isLight
          ? colorScheme.primary
          : colorScheme.onPrimary,
      selectedTileIconColor: isLight
          ? colorScheme.primary
          : colorScheme.onPrimary,
    );
  }
}
