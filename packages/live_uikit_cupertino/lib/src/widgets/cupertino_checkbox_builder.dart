import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino checkbox from a [LanguageCheckboxSpec] (§9 Checkbox).
///
/// Mapped: `cu.CupertinoCheckbox` is the library's only checkbox, and it is the
/// one a Cupertino subtree is allowed to use, since any other answer would put a
/// Material box in an iOS page. The fork documents this widget as macOS-styled
/// and notes that the iOS HIG has no checkbox at all (it points at
/// [cu.CupertinoSwitch], which this adapter already renders); the square with the
/// white tick is still what `cupertino_ui` draws for a multi-selection box, so
/// that is what a Cupertino page gets.
///
/// [LanguageCheckboxSpec.enabled] is the library's own inert state — a null
/// `onChanged` greys the box and refuses taps — and the box reports no value of
/// its own, so `tristate` stays off and the null a `ValueChanged<bool?>` may hand
/// back is dropped rather than passed on: the contract has no mixed state.
/// [LanguageCheckboxSpec.label] has no slot on the box, so it travels beside it;
/// it is also given as the box's `semanticLabel`, which is where iOS puts a
/// control's name rather than in its drawing.
abstract final class CupertinoCheckboxBuilder {
  /// Builds the checkbox for [spec].
  static Widget build(BuildContext context, LanguageCheckboxSpec spec) {
    final theme = LiveTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    final box = cu.CupertinoCheckbox(
      value: spec.value,
      onChanged: select == null
          ? null
          : (next) {
              if (next != null) {
                select(next);
              }
            },
      // The fill and the tick follow the token, the geometry and the pressed
      // halo follow the library — the same split the bottom bar makes.
      activeColor: theme.checkbox.checkedBackground,
      checkColor: theme.checkbox.checkedIcon,
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
      semanticLabel: spec.label,
    );

    final label = spec.label;
    if (label == null) {
      return box;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        SizedBox(width: theme.token.scale.sizes.xs),
        Text(label, style: theme.text.body.copyWith(color: theme.colors.text)),
      ],
    );
  }
}
