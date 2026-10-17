import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Fluent tab strip from a [LanguageTabsSpec] (§9 Tabs).
///
/// The library's own tab widget, `TabView`, is a *tab view*: every `Tab` carries
/// a body and the widget paints a content area under the strip. This contract's
/// tabs are a strip only — the caller's router owns the body, exactly as it does
/// for every other language — so the strip is composed here out of Fluent's own
/// building block, `HoverButton` (the one `NavigationListItem` is made of), with
/// the selection drawn the way Fluent draws it: accent text and a short accent
/// underline over the surface colour.
///
/// [LanguageTabsSpec.spacing] has no counterpart in this strip: the cells take the
/// library's own header padding, so the gap knob is documented as unmapped (§15).
abstract final class FluentTabBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageTabsSpec spec) {
    final theme = fluent.FluentTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < spec.tabs.length; index++)
          _TabCell(
            label: spec.tabs[index].label,
            icon: spec.tabs[index].icon,
            selected: index == spec.index,
            accent: theme.accentColor.normal,
            inactive: theme.inactiveColor,
            onTap: select == null ? null : () => select(index),
          ),
      ],
    );
  }
}

class _TabCell extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.inactive,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final Color accent;
  final Color inactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? accent : inactive;
    return fluent.HoverButton(
      onPressed: onTap,
      builder: (context, states) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final IconData glyph) ...[Icon(glyph, color: tint, size: 16), const SizedBox(width: 6)],
                Text(
                  label,
                  style: TextStyle(color: tint, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // The selection mark: Fluent underlines the active header rather
          // than filling it, which is what separates a tab from a segment.
          SizedBox(height: 2, child: selected ? ColoredBox(color: accent) : const SizedBox.shrink()),
        ],
      ),
    );
  }
}
