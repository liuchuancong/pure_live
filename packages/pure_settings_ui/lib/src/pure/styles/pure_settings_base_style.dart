import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The palette every pure-family language starts from, and the neutral style
/// for a `platform: DevicePlatform.pure` forced under a language that has an
/// upstream rendering of its own.
///
/// The colours are the resolved design token's own vocabulary read onto the
/// settings one: the page is the layout background, a card is the container
/// background, a hairline is the secondary border, a pressed row is the
/// secondary fill, and a section title is the primary colour in the caption
/// role — the same choices the app's hand-built settings sections made before
/// this package existed.
///
/// A language that disagrees copies the result in its own file; nothing here
/// is a special case of anything.
SettingsThemeData pureSettingsTokenPalette(PureTheme theme) {
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

/// The neutral pure style: the token's surface reaches its own border, so the
/// rows go edge to edge and separate with a hairline.
const PureSettingsStyle pureSettingsBaseStyle = PureSettingsStyle(
  name: 'pure',
  palette: pureSettingsTokenPalette,
);
