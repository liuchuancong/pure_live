import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted dialog surface from a [LanguageDialogSpec] (§9 Dialog).
///
/// Composed, not mapped: `glass_morphism_plus` 0.1.0 ships no dialog, no alert
/// and no sheet — its whole widget set is `GlassContainer`, `GlassTile`,
/// `GlassDivider` plus `GlassButton`/`GlassCard`/`GlassTextField`/`GlassListTile`
/// and a Material `GlassAppBar` (`lib/src/` is eight files, none of them an
/// overlay). The panel is therefore assembled out of the library's own surface:
/// a [glass.GlassContainer] whose blur, tint, opacity, corner radius, stroke and
/// shadow it reads from [glass.GlassTheme] (§8), holding the glyph, the heading,
/// the body and the action row in the token's text roles. iOS raises its alert
/// as a single floating slab with the buttons inside it, so the actions stay a
/// trailing row on the sheet rather than a separate band.
///
/// Only the surface is built here. The route, the barrier colour, the
/// fade-and-scale, the outside tap and the timeout belong to the core's
/// `showLiveDialog`, which already frames what it is given
/// (`Center → Padding → ConstrainedBox(maxWidth)`) — so this builder starts no
/// `Navigator`, adds no `Center` of its own, and deliberately does not read
/// [LanguageDialogSpec.dismissible], which is the core's barrier knob.
///
/// The panel is not interactive, so it is the library's plain [glass.GlassContainer]:
/// a `GlassContainer` with a tap callback wraps its child in its own
/// `Material`/`InkWell` and gives away focus, which would put Material ink and a
/// second focus path inside a glass page (§15). Nothing here needs either.
abstract final class GlassDialogBuilder {
  /// Builds the dialog surface for [spec].
  static Widget build(BuildContext context, LanguageDialogSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final sizes = theme.token.scale.sizes;
    final gap = sizes.md;

    // A dialog floats *over* the page rather than on it, so the library's sheet
    // opacity — tuned for surfaces that sit behind content — has to be floored
    // or the barrier shows through the body text.
    final opacity = glassTheme.opacity < 0.6 ? 0.72 : glassTheme.opacity;

    return glass.GlassContainer(
      // Blur, stroke width and the shadow colour are left unset so the container
      // inherits them from the same [glass.GlassTheme] the rest of the language
      // reads; only the values a floating panel must differ on are passed.
      blur: glassTheme.blur,
      opacity: opacity,
      borderRadius: glassTheme.borderRadius,
      color: theme.colors.bgElevated,
      elevation: glassTheme.elevation ?? 12,
      shadowColor: glassTheme.shadowColor ?? theme.colors.shadowBase,
      padding: EdgeInsets.all(theme.card.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (spec.icon case final glyph?) ...[
            Center(child: Icon(glyph, color: theme.colors.primary)),
            SizedBox(height: gap),
          ],
          if (spec.title case final heading?) ...[
            Text(
              heading,
              style: theme.text.title.copyWith(color: theme.colors.text),
              textAlign: spec.icon == null ? TextAlign.start : TextAlign.center,
            ),
            SizedBox(height: gap),
          ],
          ?spec.content,
          if (spec.actions.isNotEmpty) ...[
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final action in spec.actions)
                  Padding(padding: EdgeInsets.only(left: sizes.sm), child: action),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
