import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;
import 'package:pure_uikit/pure_uikit.dart';

/// Neumorphism's settings theme.
///
/// Three things here are decided by this theme's own logic rather than inherited
/// from another, and they are the reason it has a file of its own:
///
/// - A Neumorphic card *is* its shadow. Rows that run to the card's edge cover
///   the ridge, and the card stops being a raised plane and becomes a rectangle.
///   So this is the theme that insets its rows, by the width of the emboss.
/// - A soft surface has no separator. A hairline is a thing two opaque planes do
///   to each other; pressed between two planes it reads as a scratch. A
///   Neumorphic group lets the depth do the grouping and draws nothing.
/// - Selection is depth, not fill. `PureListRow` already sinks a selected row
///   into `NeuShape` pressed and lifts its title in the theme's accent — the
///   same dish the nav bar's active destination uses — so the card has nothing
///   left to say.
///
/// The palette is the token's, unchanged: a Neumorphic surface is the page's own
/// base colour pushed up and down in lightness, and `PureConfigProvider` feeds
/// `NeuTheme` that base from the token, so the card and the page cannot drift
/// apart.
const neumorphicSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.pure,
  style: PureSettingsStyle(
    palette: pureSettingsPalette,
    cardPadding: EdgeInsets.all(PureSpacing.xs),
    cardBordered: false,
    rowDividers: false,
  ),
);
