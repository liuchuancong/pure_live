import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// One tab's label and optional icon.
class PureTab {
  /// A tab.
  const new({required this.label, this.icon});

  /// The tab label.
  final String label;

  /// An optional leading icon. Every language with a slot for one shows it;
  /// macOS's `MacosTab` accepts a label string and nothing else.
  final IconData? icon;
}

/// The public tab strip: one widget, every design language.
///
/// Every branch returns a real component from the active library. The three
/// controller-driven widgets get one small state adapter each (Material's
/// `TabBar` and macOS's `MacosSegmentedControl` take a controller, and a live
/// index has to be asserted back onto it); no tab is hand-painted. Libraries
/// that ship no tab strip use Flutter's official Material `TabBar` rather than
/// a bespoke composition.
class PureTabs extends StatelessWidget {
  /// A tab strip.
  const new({
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.spacing = 0,
    this.enabled = true,
    this.isScrollable = false,
    super.key,
  });

  /// The tabs, in order.
  final List<PureTab> tabs;

  /// The selected index.
  final int index;

  /// Called with a tab's index when it is chosen.
  final ValueChanged<int>? onChanged;

  /// The gap between tabs. Kept for source compatibility; the libraries lay
  /// out their own tabs.
  final double spacing;

  /// Whether the strip responds to input.
  final bool enabled;

  /// Whether a long strip scrolls instead of squeezing its tabs.
  ///
  /// Material's own scrollable bar drives the Material family, forui's
  /// `scrollable` drives forui, and the libraries whose strip is a fixed row
  /// (fluent, macOS, Cupertino, wind) are handed the width their tabs ask for
  /// inside a horizontal scroll view. With the flag false every strip fits the
  /// box it was given: the Material family stretches its tabs across it, the
  /// rest squeeze — except macOS, whose cells can do neither, so it scrolls
  /// whatever this says.
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    final select = enabled ? onChanged : null;
    final selected = index.clamp(0, tabs.length - 1);

    return switch (theme.config.language) {
      // Material, Yaru (Material's token tables) and the two surface libraries
      // that ship no tab strip all use Flutter's official Material TabBar.
      // Yaru has a `YaruTabBar`, but it takes neither `isScrollable` nor
      // `tabAlignment`, so it cannot carry this contract's scroll flag.
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru ||
      PureDesignLanguage.glass ||
      PureDesignLanguage.neumorphic => _MaterialTabBar(
        tabs: tabs,
        index: selected,
        onChanged: select,
        isScrollable: isScrollable,
      ),
      // iOS's own segmented strip: a sliding thumb over the library's cells.
      PureDesignLanguage.cupertino => _scrolled(_CupertinoTabBar(tabs: tabs, index: selected, onChanged: select)),
      // macOS's own segmented control, driven by the library controller. Its
      // row cannot shrink and cannot ellipsize — `MacosTab` builds a bare `Text`
      // per cell, so three long labels overflowed a 360dp box by 167px — so it
      // rides the scroll wrapper whatever the caller asked for. A segmented
      // control that sizes to its content is also what macOS itself draws.
      PureDesignLanguage.macos => _scrolled(_MacosTabBar(tabs: tabs, index: selected, onChanged: select), always: true),
      // fluent_2's own tab list.
      PureDesignLanguage.fluent => _scrolled(
        f2.FluentTabList<int>(
          selectedValue: selected,
          onSelect: select,
          // WinUI marks the chosen header with the accent colour as well as the
          // selector bar; the library's own resting foreground leaves every tab
          // reading the same weight.
          style: f2.FluentTabStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? theme.colors.primary : theme.colors.textSecondary,
            ),
          ),
          tabs: [
            for (var i = 0; i < tabs.length; i++)
              f2.FluentTab<int>(
                value: i,
                icon: tabs[i].icon == null ? null : Icon(tabs[i].icon),
                enabled: select != null,
                child: Text(tabs[i].label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        // The strip runs from the leading edge. Centred, it floats in the middle
        // of a wide header with dead space on both sides, and a header title sits
        // nowhere near it.
        leading: true,
      ),
      // forui's own tabs. Its tab view requires a content panel per entry; the
      // router owns the body here, so each entry gets an empty panel.
      PureDesignLanguage.forui => forui.FTabs(
        key: ValueKey<String>('forui-tabs-${tabs.length}'),
        // The caller owns the body; the panel entries are empty, so the
        // bar-to-panel spacing is dead height — zero it or the strip
        // overflows the 48 the bar reserves.
        style: const forui.FTabsStyleDelta.delta(
          spacing: 0,
          padding: forui.EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
        ),
        scrollable: isScrollable,
        control: forui.FTabControl.lifted(index: selected, onChange: (next) => select?.call(next)),
        children: [for (final tab in tabs) forui.FTabEntry(label: _foruiLabel(tab), child: const SizedBox.shrink())],
      ),
      // Wind's own tabs. The fork always builds the active panel; the caller
      // owns the body, so the panel is empty. The strip's grammar — a row of
      // muted labels over a hairline, the selected one in the accent with the
      // underline — is spelled in the fork's utility classes, which is how it
      // ships a tab strip at all.
      PureDesignLanguage.wind => _scrolled(
        wind.WTabs(
          tabs: [for (final tab in tabs) tab.label],
          selectedIndex: selected,
          onChanged: select,
          panelBuilder: (_) => const SizedBox.shrink(),
          listClassName: 'flex flex-row border-b border-gray-200',
          tabClassName: 'flex flex-row items-center px-4 py-2 text-sm text-gray-600 selected:text-blue-600',
          selectedTabClassName: 'border-b-2 border-blue-600',
        ),
      ),
    };
  }

  /// The scroll wrapper for the libraries that lay their tabs in a fixed row.
  ///
  /// `IntrinsicWidth` is not decoration: a scroll view hands its child an
  /// unbounded width, and both wind's flex row and forui's tab view throw
  /// during layout there — measured, the two of them raised 23 and 33
  /// exceptions. Bounding the child to the width its own tabs ask for keeps
  /// the strip scrollable without putting a library container in a shape it
  /// cannot lay out.
  ///
  /// [always] is for the one library that cannot honour the flag's other half:
  /// its cells neither shrink nor ellipsize, so squeezing into the box is not a
  /// state it can be in.
  Widget _scrolled(Widget strip, {bool always = false, bool leading = false}) {
    if (!(always || isScrollable)) {
      return strip;
    }
    final scroll = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicWidth(child: strip),
    );
    return leading ? Align(alignment: AlignmentDirectional.centerStart, child: scroll) : scroll;
  }

  static Widget _foruiLabel(PureTab tab) => switch (tab.icon) {
    final IconData glyph => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(glyph),
        Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
    null => Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
  };
}

/// The page area behind a tab strip.
///
/// The content is a stack of the caller's pages, with only the selected one
/// visible. This is intentionally shared by every language: it owns no visual
/// component, only the page-stack mechanics the routers already rely on.
class PureTabView extends StatelessWidget {
  /// A tab view over [pages].
  const new({required this.index, required this.pages, this.onIndexChanged, super.key});

  /// The visible page index.
  final int index;

  /// The page widgets.
  final List<Widget> pages;

  /// Called when a swipe/page change selects another index.
  final ValueChanged<int>? onIndexChanged;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }
    return IndexedStack(index: index.clamp(0, pages.length - 1), sizing: StackFit.expand, children: pages);
  }
}

/// The official Material TabBar with a controller adapter.
class _MaterialTabBar extends StatefulWidget {
  const new({required this.tabs, required this.index, required this.onChanged, this.isScrollable = false});

  final List<PureTab> tabs;
  final int index;
  final ValueChanged<int>? onChanged;
  final bool isScrollable;

  @override
  State<_MaterialTabBar> createState() => _MaterialTabBarState();
}

class _MaterialTabBarState extends State<_MaterialTabBar> with SingleTickerProviderStateMixin {
  late TabController _controller = _createController();

  TabController _createController() {
    return TabController(
      length: widget.tabs.length,
      initialIndex: widget.index.clamp(0, widget.tabs.length - 1),
      vsync: this,
    )..addListener(_handleChange);
  }

  void _handleChange() {
    if (_controller.indexIsChanging) {
      return;
    }
    widget.onChanged?.call(_controller.index);
  }

  @override
  void didUpdateWidget(covariant _MaterialTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      _controller
        ..removeListener(_handleChange)
        ..dispose();
      _controller = _createController();
      return;
    }
    if (_controller.index != widget.index) {
      _controller.animateTo(widget.index.clamp(0, widget.tabs.length - 1));
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    return IgnorePointer(
      ignoring: !enabled,
      child: TabBar(
        controller: _controller,
        isScrollable: widget.isScrollable,
        // `TabAlignment.start` is only legal on a scrollable bar; on a fixed
        // one the SDK stretches the tabs across the box instead, which is what
        // the caller asked for by leaving [PureTabs.isScrollable] false.
        tabAlignment: widget.isScrollable ? TabAlignment.start : TabAlignment.fill,
        onTap: enabled ? widget.onChanged : null,
        tabs: [
          for (final tab in widget.tabs)
            Tab(
              icon: tab.icon == null ? null : Icon(tab.icon),
              text: tab.icon == null ? tab.label : null,
              child: tab.icon == null ? null : Text(tab.label),
            ),
        ],
      ),
    );
  }
}

/// The official Cupertino sliding segmented control as an in-page tab strip.
class _CupertinoTabBar extends StatelessWidget {
  const new({required this.tabs, required this.index, required this.onChanged});

  final List<PureTab> tabs;
  final int index;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (tabs.length < 2) {
      // CupertinoSlidingSegmentedControl asserts at least two cells. A single
      // tab has nothing to select, so the library's own button cell is inert.
      return cupertino.CupertinoButton(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onPressed: null,
        child: _cupertinoCell(tabs.first),
      );
    }
    final children = <int, Widget>{for (var i = 0; i < tabs.length; i++) i: _cupertinoCell(tabs[i])};
    return cupertino.CupertinoSlidingSegmentedControl<int>(
      children: children,
      groupValue: index,
      disabledChildren: onChanged == null ? children.keys.toSet() : const <int>{},
      onValueChanged: (value) {
        if (value != null) {
          onChanged?.call(value);
        }
      },
    );
  }

  /// An iOS segmented cell: the label, with the tab's icon leading it when the
  /// tab has one. The library takes any widget as a cell, so this stays the
  /// library's control with the library's thumb — only the cell's contents are
  /// composed, the same way the other languages compose their label.
  static Widget _cupertinoCell(PureTab tab) {
    final label = Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final glyph = tab.icon;
    if (glyph == null) {
      return label;
    }
    // The cell's own text is ~13pt, so the default 24pt glyph would grow the
    // control's height by a third for the sake of the icon.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        cupertino.Icon(glyph, size: 14),
        const SizedBox(width: 4),
        Flexible(child: label),
      ],
    );
  }
}

/// The official `MacosSegmentedControl` with its required controller adapter.
class _MacosTabBar extends StatefulWidget {
  const new({required this.tabs, required this.index, required this.onChanged});

  final List<PureTab> tabs;
  final int index;
  final ValueChanged<int>? onChanged;

  @override
  State<_MacosTabBar> createState() => _MacosTabBarState();
}

class _MacosTabBarState extends State<_MacosTabBar> {
  late macos.MacosTabController _controller = _createController();

  /// True while the index change came from this widget rather than from a tap,
  /// so the listener does not report the caller's own value back to it.
  bool _asserting = false;

  macos.MacosTabController _createController() {
    return macos.MacosTabController(
      length: widget.tabs.length,
      initialIndex: widget.index.clamp(0, widget.tabs.length - 1),
    )..addListener(_handleChange);
  }

  void _handleChange() {
    if (_asserting) {
      return;
    }
    widget.onChanged?.call(_controller.index);
  }

  @override
  void didUpdateWidget(covariant _MacosTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      _controller
        ..removeListener(_handleChange)
        ..dispose();
      _controller = _createController();
      return;
    }
    if (_controller.index != widget.index) {
      _asserting = true;
      _controller.index = widget.index.clamp(0, widget.tabs.length - 1);
      _asserting = false;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.onChanged == null,
      child: macos.MacosSegmentedControl(
        controller: _controller,
        // `MacosTab` takes a label string and nothing else — no icon, no widget
        // slot — so a tab's icon has nowhere to go in this library.
        tabs: [for (final tab in widget.tabs) macos.MacosTab(label: tab.label)],
      ),
    );
  }
}
