import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The design token read onto the settings vocabulary.
///
/// This is a colour *mapping*, not a theme: the page is the layout background, a
/// card is the container background, a hairline is the secondary border, a
/// pressed row is the secondary fill, a section title is the primary colour in
/// the caption role. Each theme in `languages/` starts from it and states what
/// it wants differently, in its own file.
SettingsThemeData pureSettingsPalette(PureTheme theme) {
  final colors = theme.colors;
  return SettingsThemeData(
    settingsListBackground: colors.bgLayout,
    settingsSectionBackground: colors.bgContainer,
    dividerColor: colors.borderSecondary,
    tileHighlightColor: colors.fillSecondary,
    titleTextColor: colors.primary,
    titleTextStyle: theme.text.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
    settingsTileTextColor: colors.text,
    tileTextStyle: theme.text.body,
    tileDescriptionTextColor: colors.textSecondary,
    tileDescriptionTextStyle: theme.text.caption,
    trailingTextColor: colors.textTertiary,
    leadingIconsColor: colors.textSecondary,
    inactiveTitleColor: colors.textQuaternary,
    inactiveSubtitleColor: colors.textQuaternary,
    inactiveSwitchColor: colors.textQuaternary,
    listPaneBackground: colors.bgLayout,
    selectedTileColor: colors.primary,
    selectedTileTextColor: colors.textLightSolid,
    selectedTileIconColor: colors.textLightSolid,
  );
}
