import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS tab strip from a [LanguageTabsSpec] (§9 Tabs).
///
/// Composed, not mapped, and for two measured reasons. `MacosTabView` is a tab
/// *view*: it asserts `controller.length == children.length` and paints a padded,
/// bordered content area under the strip, while this contract's tabs are the
/// strip only — the caller's router owns the body, and this builder paints none of
/// it. `MacosSegmentedControl` is the strip, but its cells are `MacosTab`s,
/// which carry a `label: String` and no icon slot, and a tab that was given a
/// glyph must keep it.
///
/// So the strip is assembled from the library's own pieces: `MacosTab`, the cell
/// `MacosSegmentedControl` renders — it paints the checked chip and its radius
/// itself, so the selected state is the library's visual rather than an
/// approximation — with `MacosIcon` for the glyph and a click cursor, which is the
/// pointer affordance the library's own controls use. The strip is fully
/// controlled: the checked cell is wherever [LanguageTabsSpec.index] says, and a
/// tap only reports an index.
///
/// [LanguageTabsSpec.spacing] has no macOS counterpart — the library's cell carries
/// its own padding and takes none from the caller — so the gap between segments is
/// this widget's fixed 3/2 inset and nothing else.
abstract final class MacosTabBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageTabsSpec spec) {
    final select = spec.enabled ? spec.onChanged : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < spec.tabs.length; index++)
          _TabCell(
            label: spec.tabs[index].label,
            icon: spec.tabs[index].icon,
            selected: index == spec.index,
            onTap: select == null ? null : () => select(index),
          ),
      ],
    );
  }
}

class _TabCell extends StatelessWidget {
  const new({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon case final IconData glyph) ...[
                // The glyph is sized to the cell's own text, which is the only
                // reason it is not the library default.
                macos.MacosIcon(glyph, size: 13),
                const SizedBox(width: 4),
              ],
              macos.MacosTab(label: label, active: selected),
            ],
          ),
        ),
      ),
    );
  }
}
