import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino dialog surface from a [LanguageDialogSpec] (§9 Dialog).
///
/// Mapped, and only the surface. `cu.CupertinoAlertDialog` is the fork's own
/// alert — the blurred [cu.CupertinoPopupSurface] card, iOS' fixed 270pt column,
/// the hairline above the action strip and the pressed-state tint — and it is an
/// ordinary widget with no route inside it, so it can be handed back for the core
/// to frame: `showLiveDialog` keeps the route, the barrier, the fade-and-scale and
/// the dismissal. Its ancestor requirements are a `MediaQuery` and a
/// `cu.CupertinoLocalizations` (for the alert's semantics label), which
/// `cupertinoLocalizationsDelegates` supplies — no `CupertinoApp`, which is why
/// the same surface also renders under a Material host during a style switch.
///
/// The three fields a Cupertino alert has no slot for, each handled rather than
/// dropped:
///  * [LanguageDialogSpec.icon]: iOS puts no glyph in an alert (that is the action
///    sheet, which this contract does not ask for), so the glyph is drawn above
///    the body inside the alert's own content section, tinted with the library's
///    `secondaryLabel` because that is the colour the alert's message text uses.
///  * [LanguageDialogSpec.dismissible]: the barrier and the route belong to the
///    core, exactly as [LanguageToastSpec.duration] does, so it is not read here.
///  * the core frame's width cap: the alert fixes its own width and insets
///    itself off the keyboard with an `AnimatedPadding`, which is the iOS answer;
///    the core's `ConstrainedBox` still holds it, so nothing is re-applied here.
///
/// [LanguageDialogSpec.actions] go in exactly as the caller built them — dispatched
/// controls, so a Cupertino dialog's buttons are this package's `button` — since
/// the action section takes any widget and inserts its own dividers and pressed
/// backgrounds around it. The title and the body are plain widgets: the alert
/// merges its own iOS heading and message styles over each slot, so putting a
/// token text style here would overwrite the very thing the widget is used for.
abstract final class CupertinoDialogBuilder {
  /// Builds the dialog surface for [spec].
  static Widget build(BuildContext context, LanguageDialogSpec spec) {
    final gap = LiveTheme.of(context).token.scale.sizes.xs;
    final glyph = spec.icon;
    final heading = spec.title;

    // An icon with no body still has to reach the content section, or the glyph
    // would be dropped along with the section that could have carried it.
    final body = glyph == null
        ? spec.content
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(glyph, size: 22, color: cu.CupertinoColors.secondaryLabel.resolveFrom(context)),
              if (spec.content case final content?) ...[SizedBox(height: gap), content],
            ],
          );

    return cu.CupertinoAlertDialog(
      title: heading == null ? null : Text(heading),
      content: body,
      actions: spec.actions,
    );
  }
}
