import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic dialog surface from a [LanguageDialogSpec] (§9 Dialog).
///
/// **Composed, and only the surface.** `flutter_neumorphic_ui_kit` ships no modal:
/// its widgets are all planes a caller places, and nothing in it owns a route, a
/// barrier or a scale-in. Those are the core's — `showLiveDialog` already dims the
/// barrier, fades and scales, and frames the child it is handed
/// (`Center → Padding → ConstrainedBox(maxWidth)`) — so this builder returns a
/// widget that renders inline: no `Navigator`, no overlay, no animated ancestor,
/// and it starts no route of its own. That is why [LanguageDialogSpec.dismissible]
/// is unread here — it is the core's barrier knob, not a thing the surface draws.
///
/// The one thing the language does get to decide is what a floating panel looks
/// like, and the soft answer is depth: the panel is a `NeuContainer` on its domed
/// ([neu.NeuShape.convex]) face at *twice* [neu.NeuThemeData.depth], so it reads as
/// lifted clear off the page rather than resting on it like the flat planes around
/// it — the opposite gesture to `navBar`'s sunk cell and the same dome-when-active
/// reading `tabBar` uses, but for a whole panel instead of a tab. The corner is the
/// theme's [neu.NeuThemeData.borderRadius] and the base its
/// [neu.NeuThemeData.baseColor], so the panel stays on the token through the theme
/// scope. The heading rides in the token's title role and the glyph in the theme's
/// accent — the same readings `TokenDialog` gives the elevated Material card.
/// [LanguageDialogSpec.actions] are already-built, dispatched controls, laid out
/// right-aligned exactly as the token base does, so a dialog's buttons match the
/// language rather than being re-picked here.
abstract final class NeumorphicDialogBuilder {
  /// Builds the dialog surface for [spec].
  static Widget build(BuildContext context, LanguageDialogSpec spec) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final gap = theme.token.scale.sizes.md;

    return neu.NeuContainer(
      shape: neu.NeuShape.convex,
      baseColor: surface.baseColor,
      depth: surface.depth * 2,
      distance: surface.distance,
      borderRadius: surface.borderRadius,
      padding: EdgeInsets.all(theme.card.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (spec.icon case final glyph?) ...[
            Icon(glyph, color: surface.accentColor),
            SizedBox(height: gap),
          ],
          if (spec.title case final t?) ...[
            Text(t, style: theme.text.title.copyWith(color: theme.colors.text)),
            SizedBox(height: gap),
          ],
          ?spec.content,
          if (spec.actions.isNotEmpty) ...[
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final action in spec.actions)
                  Padding(padding: EdgeInsets.only(left: theme.token.scale.sizes.sm), child: action),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
