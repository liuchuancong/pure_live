import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino select control from a [LanguageSelectSpec] (§9 Select).
///
/// Composed of the library's own pull-down menu, because iOS's answer to "choose
/// one of these" is a menu that opens *from* the control rather than a field that
/// expands under it: `cu.CupertinoMenuAnchor` is the fork's pull-down anchor and
/// `cu.CupertinoMenuItem` its row, so the trigger is a `cu.CupertinoButton`
/// carrying the current value (or [LanguageSelectSpec.placeholder] in the
/// secondary colour, which is how iOS marks an empty field) with the library's own
/// `chevron_down`, and the choices open below it with a checkmark on the one that
/// is selected. Nothing here is a Material dropdown.
///
/// [cu.CupertinoPicker] was the other candidate and is the wrong one: it is a
/// wheel that needs a fixed height, shows every option at once and has no trigger
/// to name the current value, so it cannot be the single inline widget this
/// contract asks an adapter to return.
///
/// `enableSwipe` is off — that knob is for a menu opened by pressing and dragging
/// the anchor, and this anchor is an explicit button, so the swipe recogniser would
/// only compete with the tap. [LanguageSelectSpec.enabled] is the library's inert
/// state twice over: a trigger with no callback cannot open, and an item with no
/// callback reads as disabled.
abstract final class CupertinoSelectBuilder {
  /// Builds the select control for [spec].
  static Widget build<T>(BuildContext context, LanguageSelectSpec<T> spec) {
    final theme = LiveTheme.of(context);
    final value = spec.value;
    final select = spec.enabled ? spec.onChanged : null;

    return cu.CupertinoMenuAnchor(
      enableSwipe: false,
      menuChildren: [
        for (final item in spec.items)
          cu.CupertinoMenuItem(
            leading: item == value ? const Icon(cu.CupertinoIcons.checkmark, size: 13) : null,
            onPressed: select == null ? null : () => select(item),
            child: Text(spec.itemLabel(item)),
          ),
      ],
      builder: (context, controller, child) => cu.CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xxs),
        onPressed: select == null ? null : controller.open,
        child: child ?? const SizedBox.shrink(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value == null ? spec.placeholder ?? '' : spec.itemLabel(value), overflow: TextOverflow.ellipsis),
          SizedBox(width: theme.token.scale.sizes.xxs),
          const Icon(cu.CupertinoIcons.chevron_down, size: 11),
        ],
      ),
    );
  }
}
