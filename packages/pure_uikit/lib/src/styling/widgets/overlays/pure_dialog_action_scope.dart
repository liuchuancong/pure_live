import 'package:flutter/widgets.dart';

/// Marks the buttons inside it as a dialog's **action row**, which each library
/// draws with a widget of its own rather than with its ordinary button.
///
/// iOS puts a `CupertinoDialogAction` in an alert, not a `CupertinoButton`: the
/// action is a band in the alert's hairline-separated footer, at the size that
/// band has and with the default choice set in bold. macOS names its size step
/// outright — its alert row is built from `ControlSize.large` buttons, and a
/// strip of regular ones under a message reads as a different control.
///
/// The row is the dialog's business, not the caller's. The same `PureButton`
/// that serves as a toolbar action must keep the library's ordinary button there,
/// so the form is read from the tree rather than asked for at every call site.
class PureDialogActionScope extends InheritedWidget {
  /// Wraps [child] as a dialog action, the default choice when [isDefault].
  const new({required this.isDefault, required super.child, super.key});

  /// Whether this is the action the dialog answers to — the one macOS draws on
  /// the right and iOS sets in semibold.
  final bool isDefault;

  /// The scope this context sits in, or null when it is not a dialog action.
  static PureDialogActionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PureDialogActionScope>();
  }

  @override
  bool updateShouldNotify(PureDialogActionScope oldWidget) => isDefault != oldWidget.isDefault;
}
