import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Fluent card from a [LanguageCardSpec] (§9 Card). A non-tap
/// card is a plain [fluent.Card]; an interactive one wraps its content in a
/// pointer-cursor gesture layer so selection/click behavior is preserved without
/// assuming every card is a button.
abstract final class FluentCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) => fluent.Card(
    margin: EdgeInsets.zero,
    child: spec.onTap == null
        ? spec.child
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(onTap: spec.onTap, onLongPress: spec.onLongPress, child: spec.child),
          ),
  );
}
