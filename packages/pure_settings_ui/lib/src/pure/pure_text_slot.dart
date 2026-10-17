import 'package:flutter/widgets.dart';

/// The string of a settings_ui text slot, when it holds one.
///
/// settings_ui's tile slots are widgets, because a style may draw a title with
/// an inline icon or a value inside a badge. pure_uikit's row takes strings,
/// because a row's label is a label in every design language and each library
/// styles its own. A [Text] slot therefore yields its data and the row is the
/// library's own row — forui's `FTile`, glass's `GlassListTile`, the
/// neumorphic and wind compositions — while anything else reports null so the
/// caller can fall back to a row that carries the widget as it is, rather than
/// silently dropping it.
String? pureTextOf(Widget? slot) => switch (slot) {
  final Text text => text.data,
  _ => null,
};

/// Whether every slot in [slots] that is present is a plain [Text].
///
/// A [Text.rich] counts as not text: it carries a span, not a string, so it
/// cannot cross into a row that takes one.
bool pureSlotsAreText(Iterable<Widget?> slots) =>
    slots.every((slot) => slot == null || pureTextOf(slot) != null);
