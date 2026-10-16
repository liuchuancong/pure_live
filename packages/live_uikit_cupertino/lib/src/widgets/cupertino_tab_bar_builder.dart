import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino tab strip from a [LanguageTabsSpec] (§9 Tabs).
///
/// Composed, not mapped: `cu.CupertinoTabBar` is the only strip in the library
/// that is controlled by an index and reports an index, and it is the *bottom*
/// bar — a full-width surface with its own background, its top hairline and its
/// destination geometry — which is why this package gives it to `navBar`. A tab
/// strip is not that: iOS draws the in-page strip (Music's Overview/Songs, News's
/// Today/Following) as a left-aligned row of plain text buttons in which the
/// current tab is bold and tinted and the others are secondary. So the row is
/// composed here out of the library's own press target, `cu.CupertinoButton` with
/// its minimum tap size and fill taken off, and the selection drawn the way iOS
/// draws it rather than by falling through to the shared renderer's Material tabs
/// with their ink bar.
///
/// [LanguageTabsSpec.enabled] is the library's inert state: a button with no
/// callback keeps its label and loses its tap. [LanguageTabsSpec.spacing] is the
/// token renderer's knob and has no counterpart — a Cupertino strip spaces its
/// tabs by the buttons' own padding.
abstract final class CupertinoTabBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageTabsSpec spec) {
    final theme = LiveTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < spec.tabs.length; index++)
          cu.CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.symmetric(
              horizontal: theme.token.scale.sizes.sm,
              vertical: theme.token.scale.sizes.xxs,
            ),
            foregroundColor: index == spec.index ? theme.tabs.itemSelectedColor : theme.tabs.itemColor,
            onPressed: select == null ? null : () => select(index),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (spec.tabs[index].icon case final IconData glyph) ...[
                  Icon(glyph, size: 15),
                  const SizedBox(width: 4),
                ],
                Text(
                  spec.tabs[index].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: index == spec.index ? FontWeight.w600 : FontWeight.w400),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
