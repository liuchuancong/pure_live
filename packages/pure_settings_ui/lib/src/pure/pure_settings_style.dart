import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/styles/forui_settings_style.dart';
import 'package:pure_settings_ui/src/pure/styles/glass_settings_style.dart';
import 'package:pure_settings_ui/src/pure/styles/neumorphic_settings_style.dart';
import 'package:pure_settings_ui/src/pure/styles/pure_settings_base_style.dart';
import 'package:pure_settings_ui/src/pure/styles/wind_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// What one design language's settings style states.
///
/// Each language has its own file under `styles/`, the way `pure_uikit`'s
/// `app/hosts/` has one host per language: a theme's surface, its separators
/// and the space its controls need are that theme's business, and folding four
/// of them into one switch would make every one of them a special case of a
/// style that belongs to none.
///
/// Only the parts that actually differ are here. The row, the section and the
/// page bar are shared, because they are pure_uikit's `PureCard`, `PureListRow`
/// and `PureAppBar` — those already construct the library's own widgets, so a
/// per-language copy of them would be four files saying the same thing.
@immutable
final class PureSettingsStyle {
  /// A style naming itself, painting its own palette and spacing its own card.
  const PureSettingsStyle({
    required this.name,
    required this.palette,
    this.cardPadding = EdgeInsets.zero,
    this.cardBordered = false,
    this.rowDividers = true,
    this.tintsSelectedCard = true,
  });

  /// The language this style draws, for failures worth reading.
  final String name;

  /// The colours the list paints its page and its hairlines with.
  ///
  /// A function of the resolved theme rather than a constant, because the pure
  /// style follows the user's accent and brightness — the one thing no upstream
  /// style except Android's and Chrome's does.
  final SettingsThemeData Function(PureTheme theme) palette;

  /// The padding between a card's edge and its rows.
  ///
  /// Zero is right when the card's own surface reaches its border, as forui's
  /// `FCard` does. A language whose card is embossed or frosted needs inset
  /// rows so the surface's edge — its shadow, its blur, its stroke — stays
  /// visible around them.
  final EdgeInsetsGeometry cardPadding;

  /// Whether the card is stroked.
  ///
  /// A library whose card paints no surface of its own needs the token's
  /// border to say where the group ends; a library whose card is already a
  /// surface would only gain a second edge.
  final bool cardBordered;

  /// Whether the section draws a separator between two rows.
  final bool rowDividers;

  /// Whether a selected card takes the token's selected tint.
  ///
  /// A card defined by its depth has no fill to recolour, so it states
  /// selection the way its own library does and this stays false.
  final bool tintsSelectedCard;
}

/// The settings style of [language].
///
/// The five languages that have an upstream rendering never reach it:
/// `devicePlatformOf` sends them to that rendering, and the dispatch switches
/// in the vendored tree route them there before this is asked. It answers for
/// them only when a caller forces `platform: DevicePlatform.pure` — and then
/// with the neutral base, since there is nothing language-specific to say.
PureSettingsStyle pureSettingsStyleOf(PureDesignLanguage language) => switch (language) {
  PureDesignLanguage.forui => foruiSettingsStyle,
  PureDesignLanguage.glass => glassSettingsStyle,
  PureDesignLanguage.neumorphic => neumorphicSettingsStyle,
  PureDesignLanguage.wind => windSettingsStyle,
  PureDesignLanguage.material ||
  PureDesignLanguage.cupertino ||
  PureDesignLanguage.macos ||
  PureDesignLanguage.fluent ||
  PureDesignLanguage.yaru => pureSettingsBaseStyle,
};

/// The style the list resolves for the subtree around [context].
PureSettingsStyle pureSettingsStyle(BuildContext context) =>
    pureSettingsStyleOf(PureTheme.of(context).config.language);
