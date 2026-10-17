import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// One destination of a bottom navigation bar: what it is called and the glyph
/// that says so. A label is required — an icon-only bar asks a user to memorise
/// five glyphs, which is why the platform bars carry text by default.
@immutable
final class LiveNavBarItem {
  /// A destination labelled [label] with [icon].
  const new({required this.label, required this.icon});

  /// The destination's name.
  final String label;

  /// The destination's glyph.
  final IconData icon;

  @override
  bool operator ==(Object other) => other is LiveNavBarItem && other.label == label && other.icon == icon;

  @override
  int get hashCode => Object.hash(label, icon);
}

/// The public bottom navigation bar: a thin dispatcher to the active language
/// adapter. A shell passes its destinations here instead of a platform bar, so
/// the bottom of the screen re-skins with the rest of it.
class LiveNavBar extends StatelessWidget {
  /// A bar over [items] with [index] selected.
  const new({required this.items, required this.index, this.onChanged, this.enabled = true, super.key});

  /// The destinations, in order.
  final List<LiveNavBarItem> items;

  /// The selected destination.
  final int index;

  /// Called with a destination's index; null renders the bar inert.
  final ValueChanged<int>? onChanged;

  /// Whether the bar responds to input.
  final bool enabled;

  @override
  Widget build(BuildContext context) =>
      LiveTheme.of(context).adapter
          .navBar(context, LanguageNavBarSpec(items: items, index: index, onChanged: onChanged, enabled: enabled));
}
