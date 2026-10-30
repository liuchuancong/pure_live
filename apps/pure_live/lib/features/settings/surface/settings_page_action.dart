import 'package:flutter/widgets.dart';

/// The header slot a pushed settings page offers its body.
///
/// A body that owns an action over the whole page — the order lists' edit
/// toggle, say — puts it in this slot, and the page header shows it at its
/// end, beside the back arrow and the title: the page's own top-right corner,
/// not a row of the body. Pages shown in place (a desktop window's settings
/// pane has no header of its own) find no slot and draw the action themselves.
final class SettingsPageActionScope extends InheritedWidget {
  /// Offers [slot] to the body under it.
  const SettingsPageActionScope({required this.slot, required super.child, super.key});

  /// The header's end slot: null clears it.
  final ValueNotifier<Widget?> slot;

  /// The slot above [context], if this page has a header to fill.
  static ValueNotifier<Widget?>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsPageActionScope>()?.slot;

  @override
  bool updateShouldNotify(SettingsPageActionScope oldWidget) => oldWidget.slot != slot;
}
