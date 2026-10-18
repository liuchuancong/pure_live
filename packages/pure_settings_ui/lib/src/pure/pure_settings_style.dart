import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// What one design language's settings theme states about itself.
///
/// Every language has its own file under `languages/`, the way `pure_uikit`'s
/// `app/hosts/` has one host per language, and this is the shape they all
/// answer to. A theme's surface, its separators and the space its controls need
/// are that theme's own business: they are declared once, in that theme's file,
/// and never as a case in another theme's branch.
///
/// Only the parts that differ between themes are here. The row, the section and
/// the page bar are shared code, because they are pure_uikit's `PureCard`,
/// `PureListRow` and `PureAppBar` — those already construct the library's own
/// widgets, so a per-language copy of them would be nine files saying the same
/// thing about geometry that the library has already decided.
@immutable
final class PureSettingsStyle {
  /// A style stating its palette, its card padding, its border and its separators.
  const new({required this.palette, required this.cardPadding, required this.cardBordered, required this.rowDividers});

  /// The colours the list paints its page and its hairlines with.
  ///
  /// A function of the resolved theme rather than a constant, because this
  /// family follows the user's accent and brightness — the one thing no
  /// upstream style except Android's and Chrome's does.
  final SettingsThemeData Function(PureTheme theme) palette;

  /// The padding between a card's edge and its rows.
  ///
  /// Zero is right when the card's own surface reaches its border. A language
  /// whose card is embossed or inset needs its rows pulled in so the surface's
  /// edge — its shadow, its stroke, its rounded corner — stays visible around
  /// them.
  final EdgeInsetsGeometry cardPadding;

  /// Whether the card is stroked.
  ///
  /// A card that paints no surface of its own needs the token's border to say
  /// where the group ends; a card that is already a surface would only gain a
  /// second edge.
  final bool cardBordered;

  /// Whether the section draws a separator between two rows.
  final bool rowDividers;
}

/// One design language's place in the settings system.
///
/// The whole of a theme's dispatch — which upstream rendering it borrows, and
/// what its own style says — is one constant, in one file. Nothing here decides
/// anything on another theme's behalf. Which language a constant belongs to is
/// the registry key in `settings_language.dart`, stated once there rather than
/// repeated here, so the two cannot disagree.
@immutable
final class SettingsLanguage {
  /// A language, the style key it draws, and the style it states for itself.
  const new({required this.platform, required this.style});

  /// The vendored style key this language resolves to: one of upstream's own
  /// for the five that have a rendering, `DevicePlatform.pure` for the rest.
  final DevicePlatform platform;

  /// The theme's own style, consulted by the pure rendering.
  final PureSettingsStyle style;
}
