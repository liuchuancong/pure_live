import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/player/media_bar_button.dart';

/// The tier the player's bars are drawn at.
///
/// A TV has no pointer and the viewer sits far from the screen: the bars'
/// controls grow, the gaps widen, labels take the next type size up and the
/// focused control draws a ring, so the remote's position is readable from the
/// sofa (§10.5). Everywhere else the bars keep the app's control sizes.
///
/// It is published once around a player's whole surface, so a bar's buttons
/// read their own size from the tier instead of threading a `tv` flag through
/// every widget that draws one — the reason the live room, the VOD page and the
/// hongguo page can share one rule instead of three.
final class PlayerBarTier extends InheritedWidget {
  /// Sizes the player's bars for a TV screen when [tv].
  const PlayerBarTier({required this.tv, required super.child, super.key});

  /// Whether the bars under this tier are drawn for a TV screen.
  final bool tv;

  /// Whether an ancestor [PlayerBarTier] sized the bars for a TV.
  static bool tvOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PlayerBarTier>()?.tv ?? false;

  /// The box a bar control occupies under this tier — the number an overlay
  /// that parks itself under a strip needs, so the strip's height is derived
  /// from the same source as its controls instead of being remembered as a
  /// literal that a tier change silently invalidates.
  static double controlSize(BuildContext context) =>
      tvOf(context) ? DsTheme.of(context).sizes.lg : DsTheme.of(context).sizes.sm;

  @override
  bool updateShouldNotify(PlayerBarTier oldWidget) => tv != oldWidget.tv;
}

/// One button on a player's bar over a picture.
///
/// It is the bar's only button widget: the glyph, the name a screen reader
/// announces and the tooltip's words, the selected state's tint, and — under
/// [PlayerBarTier]'s TV tier — the grown control, the larger glyph and the
/// focus ring a remote needs. A call site that pins its own [size] or
/// [iconSize] keeps that choice; the tier only fills in what is absent.
final class PlayerBarButton extends StatelessWidget {
  /// The control showing [icon], or the bundled svg glyph at [iconAsset].
  const PlayerBarButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.selected = false,
    this.autofocus = false,
    this.size,
    this.iconSize,
    this.focusNode,
    super.key,
  }) : assert((icon == null) != (iconAsset == null), 'give exactly one glyph source: icon or iconAsset');

  final DsIconData? icon;

  /// A bundled svg glyph drawn instead of [icon].
  final String? iconAsset;
  final String label;
  final VoidCallback? onPressed;

  /// Draws the glyph at full strength: a control that is on.
  final bool selected;

  /// Takes the focus when first built (a TV room's first control).
  final bool autofocus;

  /// A pinned box size, past which the TV tier does not reach.
  final double? size;

  /// A pinned glyph size.
  final double? iconSize;

  /// The remote's focus slot, when the page owns one.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tv = PlayerBarTier.tvOf(context);
    final sizes = DsTheme.of(context).sizes;
    return MediaBarButton(
      icon: icon,
      iconAsset: iconAsset,
      label: label,
      onPressed: onPressed,
      selected: selected,
      autofocus: autofocus,
      focusNode: focusNode,
      size: size ?? (tv ? sizes.lg : null),
      iconSize: iconSize ?? (tv ? sizes.iconLg : null),
      focusRing: tv,
    );
  }
}
