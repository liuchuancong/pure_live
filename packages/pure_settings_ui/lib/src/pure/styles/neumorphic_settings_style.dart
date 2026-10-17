import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/pure/styles/pure_settings_base_style.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Neumorphism's settings style.
///
/// Three things about this theme are decided by its own logic rather than
/// copied from the base style, and they are the reason it has a file:
///
/// - A Neumorphic card *is* its shadow. Rows that run to the card's edge cover
///   the ridge, and the card stops being a raised plane and becomes a rectangle.
///   So this is the one style that insets them, by the width of the emboss.
/// - A soft surface has no separator. A hairline is a thing two opaque planes do
///   to each other; pressed between two planes it reads as a scratch, so a
///   Neumorphic group lets the depth do the grouping and draws nothing.
/// - Selection is depth, not fill. This theme states every active thing the same
///   way — the nav bar's destination, a pressed shape — and a card filled with
///   the primary colour would be the one place in it that spoke a different
///   language. `PureListRow` already sinks a selected row into `NeuShape`
///   pressed; the card has nothing to add.
///
/// The palette is the token's: a Neumorphic surface is the page's own base
/// colour pushed up and down in lightness, and `PureConfigProvider` feeds
/// `NeuTheme` that base from the token, so the card and the page cannot drift.
const PureSettingsStyle neumorphicSettingsStyle = PureSettingsStyle(
  name: 'neumorphic',
  palette: pureSettingsTokenPalette,
  cardPadding: EdgeInsets.all(PureSpacing.xs),
  rowDividers: false,
  tintsSelectedCard: false,
);
