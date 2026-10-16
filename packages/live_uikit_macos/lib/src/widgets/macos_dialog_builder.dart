import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds the macOS dialog surface for a [LanguageDialogSpec] (§9 Dialog).
///
/// Mapped wherever the library's widget can carry the spec, composed where it
/// cannot. The surface is [macos.MacosAlertDialog] — verified against
/// `macos_ui` 2.2.2 (`lib/src/dialogs/macos_alert_dialog.dart`): it is a plain
/// `StatelessWidget` whose `build` only asserts `debugCheckHasMacosTheme` (which
/// [LanguageAdapter.wrap] installs) plus its own button-shape asserts, so — like
/// the library's `MacosSheet` — it needs no `Navigator` and no route of its own
/// and can be handed straight to core's [showLiveDialog]. This builder therefore
/// starts no `showMacosAlertDialog`, pushes no route and adds no `Center`: the
/// route, the barrier, the fade-and-scale, the inset and the width cap are
/// core's, and [LanguageDialogSpec.dismissible] is the core's barrier knob, so it
/// is deliberately not drawn here.
///
/// The mapping is exact only when the library's slots exist for the spec, and
/// three of them are strict: `appIcon`, `title` and `message` are required
/// widgets, and the two action slots are typed `PushButton` with an asserted
/// `ControlSize.large`, in a fixed 260px column that takes the *last* action as
/// the default one (`primaryButton`, drawn right) and the *first* as
/// `secondaryButton`. So a spec with one or two actions that are exactly that
/// shape becomes the library's alert, and its icon rides the `appIcon` slot at
/// the 64pt the widget documents.
///
/// Everything else — no actions at all (inventing an OK button the caller never
/// asked for is not the adapter's to do), three or more actions, an action that
/// is not a `PushButton` or not `large` — has no slot in that widget, and the
/// surface is composed out of the library's own panel instead, the same
/// `MacosSheet` the card and the toast take, with its 140/48 dialog-route
/// `insetPadding` zeroed because core's frame already insets the surface. There
/// the glyph goes over the heading and the actions keep the row and the order the
/// spec asked for. A null `title` or `content` becomes an empty slot in the
/// alert — the library requires a widget there and reserves the space whatever is
/// given it — and the heading of the composed surface is the token's, the way the
/// other macOS surfaces take their type.
abstract final class MacosDialogBuilder {
  /// Builds the surface for [spec].
  static Widget build(BuildContext context, LanguageDialogSpec spec) {
    if (_alertSlots(spec.actions) case final _AlertSlots slots) {
      return macos.MacosAlertDialog(
        appIcon: switch (spec.icon) {
          null => const SizedBox.shrink(),
          final IconData glyph => macos.MacosIcon(glyph, size: 64),
        },
        title: spec.title == null ? const SizedBox.shrink() : Text(spec.title!),
        message: spec.content ?? const SizedBox.shrink(),
        primaryButton: slots.primary,
        secondaryButton: slots.secondary,
      );
    }

    final theme = LiveTheme.of(context);
    final gap = theme.token.scale.sizes.md;
    return macos.MacosSheet(
      insetPadding: EdgeInsets.zero,
      backgroundColor: theme.colors.bgElevated,
      child: Padding(
        padding: EdgeInsets.all(theme.card.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (spec.icon case final IconData glyph) ...[
              macos.MacosIcon(glyph, size: 22, color: theme.colors.primary),
              SizedBox(height: gap),
            ],
            if (spec.title case final String heading) ...[
              Text(heading, style: theme.text.title.copyWith(color: theme.colors.text)),
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
      ),
    );
  }

  /// The library's two action slots for [actions], or null when it cannot take
  /// them: an empty row, more than two buttons, or a button whose shape the
  /// widget's asserts would refuse.
  static _AlertSlots? _alertSlots(List<Widget> actions) {
    final buttons = <macos.PushButton>[];
    for (final action in actions) {
      if (action is! macos.PushButton || action.controlSize != macos.ControlSize.large) {
        return null;
      }
      buttons.add(action);
    }
    if (buttons.isEmpty || buttons.length > 2) {
      return null;
    }
    // macOS puts the default button on the right, and the library draws
    // `secondaryButton` before `primaryButton`, which is the spec's order.
    return (primary: buttons.last, secondary: buttons.length == 2 ? buttons.first : null);
  }
}

/// The library widget's action slots, named so [MacosDialogBuilder.build] can
/// read them as a pattern.
typedef _AlertSlots = ({macos.PushButton primary, macos.PushButton? secondary});
