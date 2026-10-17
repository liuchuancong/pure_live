import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Fluent destination strip from a [LanguageNavBarSpec] (§9 NavBar).
///
/// Fluent has no bottom bar: the library's destinations live in a
/// `NavigationView` pane, which is a shell and not a control, so a page that asks
/// for a strip of destinations gets the library's own mutually-exclusive control
/// instead — a row of `ToggleButton`s, one checked, each carrying its icon over
/// its label. That keeps the strip inside `FluentTheme`'s metrics and accent
/// rather than in a bar shape some other library drew.
///
/// [LanguageNavBarSpec.enabled] is the library's inert state: the buttons keep
/// their labels and lose their callback.
abstract final class FluentNavBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageNavBarSpec spec) {
    final select = spec.enabled ? spec.onChanged : null;
    return Row(
      children: [
        for (var index = 0; index < spec.items.length; index++)
          Expanded(
            child: fluent.ToggleButton(
              checked: index == spec.index,
              semanticLabel: spec.items[index].label,
              onChanged: select == null ? null : (_) => select(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(spec.items[index].icon),
                  Text(
                    spec.items[index].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
