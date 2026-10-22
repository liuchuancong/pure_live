import 'package:flutter/widgets.dart' show TargetPlatform;
import 'package:pure_uikit/src/icons/api/pure_icon_key.dart';
import 'package:pure_uikit/src/icons/api/pure_icon_style.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';

/// The inputs a custom icon source is given when it renders.
///
/// SVG and brand artwork need everything the theme decided — size, tint
/// rule, interaction state — to honour it (or, for a coloured logo, to
/// ignore the tint deliberately).
class PureIconRenderContext {
  /// Builds the render context for one draw.
  const new({
    required this.key,
    required this.language,
    required this.platform,
    required this.state,
    required this.style,
  });

  /// The semantic key being drawn.
  final PureIconKey key;

  /// The design language currently in force.
  final PureDesignLanguage language;

  /// The platform the widget tree reports (`Theme.of(context).platform`).
  final TargetPlatform platform;

  /// The interaction state of the owner.
  final PureIconState state;

  /// The resolved visual spec (size and colour already themed).
  final PureIconStyle style;
}
