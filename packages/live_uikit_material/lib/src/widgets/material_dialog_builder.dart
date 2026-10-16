import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI dialog surface from a [LanguageDialogSpec] (§9 Dialog).
///
/// Only the surface is built here. `showLiveDialog` owns the route, the barrier
/// colour, the fade-and-scale, the outside tap that dismisses, and the frame the
/// surface is laid into (`Center → Padding → ConstrainedBox(maxWidth)`), so this
/// returns `mu.AlertDialog` as a plain widget instead of calling `showDialog` —
/// verified to be a `StatelessWidget` that needs only Material localizations and a
/// theme, both of which the host and the adapter's own theme scope install — and
/// it passes `insetPadding: EdgeInsets.zero`, because the fork's `Dialog` insets
/// and aligns itself too and its default would inset the surface a second time
/// inside the core's padding.
///
/// The mapping is direct: the fork's four slots are the spec's four fields.
/// * [LanguageDialogSpec.icon] → `icon`, which is a `Widget` slot, so the glyph is
///   wrapped in an `Icon`; `iconColor` takes the token's accent because the token
///   decides what a primary looks like in every language (§8.1). A null icon leaves
///   the slot null and the fork drops its icon padding for it.
/// * [LanguageDialogSpec.title] → `title`, also a `Widget` slot, drawn with the
///   token's title role so a Material heading reads like the rest of the app; null
///   leaves the body to start at the top, which is what the fork's own title
///   padding is written to respond to.
/// * [LanguageDialogSpec.content] → `content`, passed through untouched: the caller
///   owns what is on the body, the language owns only the surface around it. Its
///   text role is the token's body, handed as `contentTextStyle` so a caller that
///   gives no style still gets the token's.
/// * [LanguageDialogSpec.actions] → `actions`, a `List<Widget>` the fork lays out in
///   an end-aligned `OverflowBar` — the same reading order the token renderer uses,
///   and the buttons arrive as dispatched controls so they match the language. An
///   empty list becomes null rather than an empty bar, since the fork omits the
///   slot (and its padding) only for a null `actions`.
/// * [LanguageDialogSpec.dismissible] is the route's promise, not the surface's: the
///   core already read it when it built the barrier, so it is handled there rather
///   than drawn twice here.
///
/// `scrollable: true` is the surface's own guard — the core caps the width but not
/// the height, and the fork needs that flag to put the body in a scroll view
/// instead of overflowing when the content is taller than the screen.
abstract final class MaterialDialogBuilder {
  /// Builds the dialog surface for [spec].
  static Widget build(BuildContext context, LanguageDialogSpec spec) {
    final theme = LiveTheme.of(context);
    final glyph = spec.icon;
    final title = spec.title;
    return mu.AlertDialog(
      icon: glyph == null ? null : Icon(glyph),
      iconColor: theme.colors.primary,
      title: title == null ? null : Text(title, style: theme.text.title.copyWith(color: theme.colors.text)),
      content: spec.content,
      contentTextStyle: theme.text.body.copyWith(color: theme.colors.text),
      actions: spec.actions.isEmpty ? null : spec.actions,
      backgroundColor: theme.colors.bgElevated,
      insetPadding: EdgeInsets.zero,
      scrollable: true,
    );
  }
}
