import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI dialog surface from a [LanguageDialogSpec] (§9 Dialog).
///
/// Mapped onto `FDialog`, which is the library's own dialog frame in 0.27.5 — the
/// older `FAlertDialog` is gone and what is left is a frame plus a builder. It is
/// returned as a plain widget and it asks for two ancestors only: an `FTheme`
/// (`context.theme`, installed by this package's `wrap`) and a `MediaQuery`, both of
/// which the routed tree already provides. What it does *not* need is an overlay:
/// the route, the barrier, the fade-and-scale and the dismissal are forui's
/// `FDialogRoute`/`showFDialog`, and those are the core's job here — `showLiveDialog`
/// owns them and frames the surface it hands to this builder, so nothing in here
/// pushes a route.
///
/// `FDialog` supplies the decoration, the width constraints and the two text roles
/// (`titleTextStyle`/`bodyTextStyle`), and the title and the body are handed to those
/// roles rather than re-styled by hand. Three of the library's behaviours are turned
/// down because the core already does them: the library's `insetPadding` is zeroed —
/// the shared frame insets the surface itself — and its `animation` is left null, so
/// the entrance stays the core's fade-and-scale instead of a second one inside it.
///
/// The rest is composed, because the library's frame has no slot for it: it ships no
/// content padding at all, so the token card padding wraps the column (the same number
/// the shared surface uses), and it has no action area, so [LanguageDialogSpec.actions]
/// arrive as a right-aligned row of the widgets the caller already dispatched — the
/// frame must not re-pick the language's button. [LanguageDialogSpec.icon] keeps the
/// token's own accent for the same reason the toast does (§9/ADR 0004).
/// [LanguageDialogSpec.dismissible] is the barrier's question, not the surface's, so it
/// is not read here.
abstract final class ForuiDialogBuilder {
  /// Builds the dialog surface for [spec].
  static Widget build(BuildContext context, LanguageDialogSpec spec) {
    final theme = LiveTheme.of(context);
    final gap = theme.token.scale.sizes.md;

    return forui.FDialog(
      // The core centres, insets and caps the surface, so the library's own inset —
      // which exists to keep a full-screen dialog off the viewport edges — is dropped
      // rather than stacked on top of the shared one.
      style: const forui.FDialogStyleDelta.delta(
        insetPadding: forui.EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
      ),
      builder: (context, style) => Padding(
        padding: EdgeInsets.all(theme.card.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (spec.icon case final glyph?) ...[
              Icon(glyph, color: theme.colors.primary),
              SizedBox(height: gap),
            ],
            if (spec.title case final title?) ...[
              DefaultTextStyle(style: style.titleTextStyle, child: Text(title)),
              SizedBox(height: gap),
            ],
            if (spec.content case final content?)
              DefaultTextStyle(style: style.bodyTextStyle, child: content),
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
      ),
    );
  }
}
