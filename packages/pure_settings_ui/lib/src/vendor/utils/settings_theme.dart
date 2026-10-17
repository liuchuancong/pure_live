import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';

/// The resolved colors and style of the `SettingsList` above.
///
/// `SettingsList` puts it above its sections; a `CustomSettingsTile` or
/// `CustomSettingsSection` can read it with [SettingsTheme.of].
class SettingsTheme extends InheritedWidget {
  /// The colors and text styles: the style's defaults merged with the list's
  /// `lightTheme` or `darkTheme`.
  final SettingsThemeData themeData;

  /// The resolved style, never [DevicePlatform.device].
  final DevicePlatform platform;

  /// Used by `SettingsList`; apps don't need to create one.
  const SettingsTheme({
    super.key,
    required this.themeData,
    required this.platform,
    required super.child,
  });

  @override
  bool updateShouldNotify(SettingsTheme oldWidget) => true;

  /// The nearest [SettingsTheme]. Call it only below a `SettingsList`: it
  /// throws when there is none.
  static SettingsTheme of(BuildContext context) {
    final SettingsTheme? result = context
        .dependOnInheritedWidgetOfExactType<SettingsTheme>();
    return result!;
  }
}

/// Colors and text styles of a `SettingsList`.
///
/// Pass it as the list's `lightTheme` or `darkTheme`. Fields left null keep
/// the style's defaults.
class SettingsThemeData {
  /// Creates a theme; every field is optional.
  const SettingsThemeData({
    this.trailingTextColor,
    this.settingsListBackground,
    this.settingsSectionBackground,
    this.dividerColor,
    this.tileHighlightColor,
    this.titleTextColor,
    this.leadingIconsColor,
    this.tileDescriptionTextColor,
    this.settingsTileTextColor,
    this.inactiveTitleColor,
    this.inactiveSubtitleColor,
    this.inactiveSwitchColor,
    this.titleTextStyle,
    this.tileTextStyle,
    this.tileDescriptionTextStyle,
    this.selectedTileColor,
    this.selectedTileTextColor,
    this.selectedTileIconColor,
    this.listPaneBackground,
  });

  /// Background of the whole list.
  final Color? settingsListBackground;

  /// Color of a tile's `value` in the iOS, macOS, Windows and GNOME styles.
  final Color? trailingTextColor;

  /// Leading and trailing icons, and the chevron.
  final Color? leadingIconsColor;

  /// Background of the cards.
  final Color? settingsSectionBackground;

  /// Line between tiles (iOS, macOS, GNOME and web styles), card border
  /// (Windows style).
  final Color? dividerColor;

  /// `description` and `value` text color in the Android and web styles;
  /// `description` and `titleDescription` in the macOS, Windows and GNOME
  /// styles.
  final Color? tileDescriptionTextColor;

  /// Pressed tile. The GNOME style also hovers with 3/8 of its opacity.
  final Color? tileHighlightColor;

  /// Section header text color. In the iOS style also `titleDescription` and
  /// `description`.
  ///
  /// The iOS, Android, web, Windows and GNOME styles always draw the header
  /// in this color (the style's own default when it is null), also when
  /// [titleTextStyle] has a color. The macOS style uses it only when
  /// [titleTextStyle] has no color.
  ///
  /// In the list pane of a [SettingsSplitView] with two panes, the web menu
  /// and the Windows pane color their headers with
  /// [tileDescriptionTextColor] instead, and the macOS sidebar with a grey
  /// of its own. The GNOME sidebar uses this color only when
  /// [titleTextStyle] has none.
  final Color? titleTextColor;

  /// Tile title text color.
  final Color? settingsTileTextColor;

  /// Title and icon color of a disabled tile. In the iOS style also its
  /// `value` and `titleDescription`, in the macOS style its `value`.
  final Color? inactiveTitleColor;

  /// `description`, `titleDescription` and `value` color of a disabled tile
  /// in the Windows and GNOME styles, its `description` and `value` in the
  /// Android and web styles, and its `titleDescription` in the macOS style.
  final Color? inactiveSubtitleColor;

  /// Color of the switch of a disabled tile: its track when on in the iOS,
  /// macOS and GNOME styles (drawn paler or half transparent); in the
  /// Windows style its fill when on, and its outline and knob when off.
  ///
  /// Without it, the iOS style uses [inactiveTitleColor], and the macOS,
  /// Windows and GNOME styles draw their own disabled switch: a paler accent
  /// like System Settings, the Windows disabled colors, the accent at half
  /// opacity. In the Android and web styles a disabled Material `Switch`
  /// keeps its own colors.
  final Color? inactiveSwitchColor;

  /// Override the text style for section titles.
  ///
  /// Its color shows only in the macOS style, and in the headers of the
  /// macOS, Windows and GNOME sidebars of a [SettingsSplitView]. Everywhere
  /// else the header's color comes from the theme, whatever color this style
  /// has: see [titleTextColor].
  final TextStyle? titleTextStyle;

  /// Override the text style for tile titles.
  final TextStyle? tileTextStyle;

  /// Override the text style of a tile's `description` in every style, of
  /// its `titleDescription` in the macOS, Windows and GNOME styles, and of
  /// its `value` in the Android, web and GNOME styles.
  final TextStyle? tileDescriptionTextStyle;

  /// Fill of the selected tile in the list pane of a [SettingsSplitView]:
  /// the tile whose page shows in the detail pane.
  final Color? selectedTileColor;

  /// Title and value color of the selected tile in a [SettingsSplitView].
  final Color? selectedTileTextColor;

  /// Leading icon color of the selected tile in a [SettingsSplitView], and
  /// of its trailing icon in the iOS, web, Windows and GNOME styles. A
  /// selected tile has no chevron.
  final Color? selectedTileIconColor;

  /// Background of a [SettingsSplitView]'s list pane when it shows two panes:
  /// the tinted iPad sidebar, the surface-dim Android homepage. The GNOME
  /// sidebar has it in one pane too. Defaults to [settingsListBackground] on
  /// the web.
  final Color? listPaneBackground;

  /// This theme with the non-null fields of [theme] on top.
  SettingsThemeData merge({SettingsThemeData? theme}) {
    if (theme == null) return this;

    return copyWith(
      leadingIconsColor: theme.leadingIconsColor,
      tileDescriptionTextColor: theme.tileDescriptionTextColor,
      dividerColor: theme.dividerColor,
      trailingTextColor: theme.trailingTextColor,
      settingsListBackground: theme.settingsListBackground,
      settingsSectionBackground: theme.settingsSectionBackground,
      settingsTileTextColor: theme.settingsTileTextColor,
      tileHighlightColor: theme.tileHighlightColor,
      titleTextColor: theme.titleTextColor,
      inactiveTitleColor: theme.inactiveTitleColor,
      inactiveSubtitleColor: theme.inactiveSubtitleColor,
      inactiveSwitchColor: theme.inactiveSwitchColor,
      titleTextStyle: theme.titleTextStyle,
      tileTextStyle: theme.tileTextStyle,
      tileDescriptionTextStyle: theme.tileDescriptionTextStyle,
      selectedTileColor: theme.selectedTileColor,
      selectedTileTextColor: theme.selectedTileTextColor,
      selectedTileIconColor: theme.selectedTileIconColor,
      listPaneBackground: theme.listPaneBackground,
    );
  }

  /// A copy of this theme with the given fields replaced.
  SettingsThemeData copyWith({
    Color? settingsListBackground,
    Color? trailingTextColor,
    Color? leadingIconsColor,
    Color? settingsSectionBackground,
    Color? dividerColor,
    Color? tileDescriptionTextColor,
    Color? tileHighlightColor,
    Color? titleTextColor,
    Color? settingsTileTextColor,
    Color? inactiveTitleColor,
    Color? inactiveSubtitleColor,
    Color? inactiveSwitchColor,
    TextStyle? titleTextStyle,
    TextStyle? tileTextStyle,
    TextStyle? tileDescriptionTextStyle,
    Color? selectedTileColor,
    Color? selectedTileTextColor,
    Color? selectedTileIconColor,
    Color? listPaneBackground,
  }) {
    return SettingsThemeData(
      settingsListBackground:
          settingsListBackground ?? this.settingsListBackground,
      trailingTextColor: trailingTextColor ?? this.trailingTextColor,
      leadingIconsColor: leadingIconsColor ?? this.leadingIconsColor,
      settingsSectionBackground:
          settingsSectionBackground ?? this.settingsSectionBackground,
      dividerColor: dividerColor ?? this.dividerColor,
      tileDescriptionTextColor:
          tileDescriptionTextColor ?? this.tileDescriptionTextColor,
      tileHighlightColor: tileHighlightColor ?? this.tileHighlightColor,
      titleTextColor: titleTextColor ?? this.titleTextColor,
      inactiveTitleColor: inactiveTitleColor ?? this.inactiveTitleColor,
      inactiveSubtitleColor:
          inactiveSubtitleColor ?? this.inactiveSubtitleColor,
      settingsTileTextColor:
          settingsTileTextColor ?? this.settingsTileTextColor,
      inactiveSwitchColor: inactiveSwitchColor ?? this.inactiveSwitchColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      tileTextStyle: tileTextStyle ?? this.tileTextStyle,
      tileDescriptionTextStyle:
          tileDescriptionTextStyle ?? this.tileDescriptionTextStyle,
      selectedTileColor: selectedTileColor ?? this.selectedTileColor,
      selectedTileTextColor:
          selectedTileTextColor ?? this.selectedTileTextColor,
      selectedTileIconColor:
          selectedTileIconColor ?? this.selectedTileIconColor,
      listPaneBackground: listPaneBackground ?? this.listPaneBackground,
    );
  }
}
