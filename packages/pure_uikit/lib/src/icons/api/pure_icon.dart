import 'package:flutter/material.dart';
import 'package:pure_uikit/src/icons/api/pure_icon_key.dart';
import 'package:pure_uikit/src/icons/api/pure_icon_registry.dart';
import 'package:pure_uikit/src/icons/api/pure_icon_style.dart';
import 'package:pure_uikit/src/icons/registry/icon_mapping.dart';
import 'package:pure_uikit/src/icons/rendering/icon_render_context.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart' show PureTheme;

/// The unified icon draw: a semantic key in, the registered glyph out.
///
/// Business widgets state only the meaning (`PureIcon(AppIconKey.follow)`)
/// plus optional overrides; the resource comes from [PureIconRegistry]'s
/// four tiers, the size defaults to Fluent's icon measure and the colour
/// from the theme tokens, and the state fades from the shared disabled
/// rule. Which icon library answered is nobody's business below the app's
/// registration.
class PureIcon extends StatelessWidget {
  /// Draws [iconKey]; the outer `key` stays free for widget identity.
  const new(this.iconKey, {this.size, this.role, this.state = PureIconState.normal, this.style, super.key});

  /// The semantic key to answer.
  final PureIconKey iconKey;

  /// Overrides the themed size.
  final double? size;

  /// Overrides the palette role (a selected destination passes accent).
  final PureIconColorRole? role;

  /// The owner's interaction state.
  final PureIconState state;

  /// A full style override (components that already computed one).
  final PureIconStyle? style;

  /// The Fluent resting icon measure — the one set the kit draws, so the
  /// default size no longer follows the design language.
  static const double defaultSize = 16;

  @override
  Widget build(BuildContext context) {
    final registry = PureIconRegistry.current;
    final language = PureTheme.of(context).config.language;
    final platform = Theme.of(context).platform;
    final resolution = registry.resolve(iconKey, platform: platform, language: language);
    final size = this.size ?? style?.size ?? defaultSize;
    final role =
        this.role ??
        style?.role ??
        (state == PureIconState.selected ? PureIconColorRole.accent : PureIconColorRole.foreground);
    final color = _colorFor(context, role);
    final opacity = style?.opacity ?? (state == PureIconState.disabled ? 0.38 : 1);
    final tinted = color == null || opacity == 1 ? color : color.withValues(alpha: color.a * opacity);
    return switch (resolution.source) {
      PureIconGlyph(:final glyph) => Icon(glyph, size: size, color: tinted),
      PureIconWidget(:final builder) => builder(
        context,
        PureIconRenderContext(
          key: iconKey,
          language: language,
          platform: platform,
          state: state,
          style: PureIconStyle(size: size, role: role, opacity: opacity),
        ),
      ),
    };
  }

  /// The theme colour for [role]; null for [PureIconColorRole.preserve],
  /// which means "do not tint the artwork".
  static Color? _colorFor(BuildContext context, PureIconColorRole role) {
    if (role == PureIconColorRole.preserve) return null;
    final colors = PureTheme.of(context).colors;
    return switch (role) {
      PureIconColorRole.foreground => colors.text,
      PureIconColorRole.accent => colors.primary,
      PureIconColorRole.tertiary => colors.textTertiary,
      PureIconColorRole.preserve => null,
    };
  }
}
