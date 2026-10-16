import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds the Fluent dialog surface for a [LanguageDialogSpec] (§9 Dialog).
///
/// Mapped, not composed: `ContentDialog` is the library's own dialog surface and
/// it works as a plain widget. Verified against fluent_ui 4.16.1
/// (`lib/src/controls/flyouts/content_dialog.dart`): its `build` only asserts
/// `debugCheckHasFluentTheme` — it needs a `FluentTheme` ancestor, which
/// [LanguageAdapter.wrap] installs, never a `Navigator` or a route — so the
/// adapter can hand it straight to the core's route instead of falling back to
/// the theme values.
///
/// The division of labour: the surface belongs to the adapter, the route, the
/// barrier, the fade-and-scale and the dismissal belong to core's
/// `showLiveDialog`, which already frames the child it is given
/// (`Center → Padding → ConstrainedBox(maxWidth)`). This builder therefore starts
/// no `fluent.showDialog` and adds no `Center`; [LanguageDialogSpec.dismissible]
/// is the core's barrier knob and is deliberately not drawn here.
///
/// `spec.icon` has no slot in the library widget, so the glyph rides over the
/// heading inside the title widget, which `ContentDialog` still paints with its
/// own title text style. The surface keeps the library's
/// `kDefaultContentDialogConstraints` (the 368px Windows guideline); where core's
/// frame is narrower, the tighter constraint wins.
abstract final class FluentDialogBuilder {
  /// Builds the surface for [spec].
  static Widget build(BuildContext context, LanguageDialogSpec spec) {
    final theme = fluent.FluentTheme.of(context);

    final title = switch ((spec.title, spec.icon)) {
      (null, null) => null,
      (final String heading, null) => Text(heading),
      (final String? heading, final IconData glyph) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(glyph, color: theme.accentColor.normal),
          if (heading != null) ...[const SizedBox(height: 8), Text(heading)],
        ],
      ),
    };

    return fluent.ContentDialog(
      title: title,
      content: spec.content,
      // An absent action row is null for the library widget — an empty list would
      // paint the action band with nothing in it.
      actions: spec.actions.isEmpty ? null : spec.actions,
    );
  }
}
