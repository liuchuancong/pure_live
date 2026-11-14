import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The room a dialog's words keep even when they are one line: below it a
/// bare confirm reads as a strip, not a card.
const double kAppDialogContentFloor = 96;

/// The app's dialog: the kit's [DsDialog] without the tone disk over the
/// title, and a floor under the words — a one-line confirmation still reads
/// as a card. Open one with [showAppDialog]; for a yes/no question use
/// [showAppConfirm].
class AppDialog extends StatelessWidget {
  /// Creates a dialog.
  const AppDialog({
    required this.title,
    super.key,
    this.description,
    this.actions = const [],
    this.alert = false,
    this.semanticLabel,
    this.style,
  });

  /// The question or heading.
  final Widget title;

  /// What happens, in a sentence or two.
  final Widget? description;

  /// Buttons, laid out side by side with equal widths, or stacked at full
  /// width when one would not fit its share. Put the safe choice first.
  final List<Widget> actions;

  /// Announces the dialog as an alert dialog: it needs an answer before
  /// anything else (a confirmation).
  final bool alert;

  /// Names the dialog for screen readers. Defaults to the [title]'s text.
  final String? semanticLabel;

  /// Style laid over the theme and defaults.
  final DsDialogStyle? style;

  @override
  Widget build(BuildContext context) {
    final body = description;
    return DsDialog(
      title: title,
      alert: alert,
      semanticLabel: semanticLabel,
      style: style,
      // The floor sits under the words, not around them: the Align hands the
      // description its natural height and the box holds the card open
      // beneath it — with no description at all the card keeps the floor on
      // its own, so a bare confirm never collapses to a strip.
      description: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kAppDialogContentFloor),
        child: Align(alignment: AlignmentDirectional.topStart, child: body ?? const SizedBox.shrink()),
      ),
      actions: actions,
    );
  }
}

/// Shows a dialog built by [builder] over the scrim. Escape, a tap on the
/// scrim and system back close it (returning null) when [dismissible].
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
  DsScrim scrim = DsScrim.dim,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) => showDsDialog<T>(
  context: context,
  builder: builder,
  dismissible: dismissible,
  scrim: scrim,
  useRootNavigator: useRootNavigator,
  routeSettings: routeSettings,
);

/// Asks a yes/no question and returns whether the user confirmed. The safe
/// choice ([cancelLabel]) comes first and has focus; Escape, a tap on the
/// scrim or system back answer no.
Future<bool> showAppConfirm({
  required BuildContext context,
  required String title,
  String? description,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  bool useRootNavigator = true,
}) {
  final l10n = DsLocalizations.of(context);
  return showAppDialog<bool>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (context) => AppDialog(
      alert: true,
      title: Text(title),
      description: description == null ? null : Text(description),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel ?? l10n.cancel),
        ),
        DsButton(
          variant: destructive ? DsButtonVariant.danger : DsButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? l10n.confirm),
        ),
      ],
    ),
  ).then((confirmed) => confirmed ?? false);
}
