import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// One tab's label and optional icon.
class LiveTab {
  /// A tab.
  const new({required this.label, this.icon});

  /// The tab label.
  final String label;

  /// An optional leading icon.
  final IconData? icon;
}

/// The public tab strip: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` renders tabs with the real library's control
/// (Material's `TabBar`) or the token base.
class LiveTabs extends StatelessWidget {
  /// A tab strip.
  const new({
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.spacing = 0,
    this.enabled = true,
    super.key,
  });

  /// The tabs, in order.
  final List<LiveTab> tabs;

  /// The selected index.
  final int index;

  /// Called with a tab's index when it is chosen.
  final ValueChanged<int>? onChanged;

  /// The gap between tabs.
  final double spacing;

  /// Whether the strip responds to input.
  final bool enabled;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.tabBar(
    context,
    LanguageTabsSpec(tabs: tabs, index: index, onChanged: onChanged, spacing: spacing, enabled: enabled),
  );
}

class _TabButton extends StatefulWidget {
  const new({required this.tab, required this.selected, required this.onTap});

  final LiveTab tab;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  final FocusNode _focus = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final tabs = theme.tabs;
    final color = widget.selected
        ? tabs.itemSelectedColor
        : _hovered
        ? tabs.itemHoverColor
        : tabs.itemColor;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.tab.icon case final icon?) ...[
          Icon(icon, size: theme.text.label.fontSize, color: color),
          SizedBox(width: theme.token.scale.sizes.xs),
        ],
        Text(widget.tab.label, style: theme.text.label.copyWith(color: color)),
      ],
    );

    return Focus(
      focusNode: _focus,
      canRequestFocus: widget.onTap != null,
      onKeyEvent: (node, event) {
        if (widget.onTap == null) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap!.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          // The strip is a Row, so a tab is laid out with an unbounded main-axis
          // width; `stretch` below would then force an infinite width. Bounding it
          // by the label's intrinsic width is what makes the ink bar span the tab.
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tabs.horizontalPadding, vertical: tabs.verticalGap),
                  child: Center(child: label),
                ),
                // The ink bar: full-width when selected, transparent otherwise.
                AnimatedContainer(
                  duration: theme.duration,
                  height: theme.token.motion.lineWidthBold,
                  color: widget.selected || _focused ? tabs.inkBarColor : const Color(0x00000000),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The page switcher under a [LiveTabs] strip, dispatched to the active language.
///
/// It takes the same index the strip reports, so a page pair looks like:
/// ```dart
/// Column(
///   children: [
///     LiveTabs(tabs: tabs, index: index, onChanged: (i) => setState(() => index = i)),
///     Expanded(child: LiveTabView(index: index, pages: pages, onIndexChanged: (i) => setState(() => index = i))),
///   ],
/// )
/// ```
/// Whether the pages swipe, fade or simply replace is the language's decision —
/// [LiveTabView] passes the index and the callback down and paints nothing itself.
class LiveTabView extends StatelessWidget {
  /// A tab view over [pages] at [index].
  const new({
    required this.pages,
    required this.index,
    this.onIndexChanged,
    this.duration = const Duration(milliseconds: 300),
    super.key,
  });

  /// The pages, in the order of the strip's tabs.
  final List<Widget> pages;

  /// The visible page.
  final int index;

  /// Called with a page's index when the viewer moves it by swiping.
  final ValueChanged<int>? onIndexChanged;

  /// How long a page change takes where the language animates one.
  final Duration duration;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.tabView(
    context,
    LanguageTabViewSpec(pages: pages, index: index, onIndexChanged: onIndexChanged, duration: duration),
  );
}
