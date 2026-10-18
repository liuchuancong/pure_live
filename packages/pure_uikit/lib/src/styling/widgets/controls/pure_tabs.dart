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

  /// An optional leading icon.
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

  /// Whether a long strip scrolls instead of squeezing its tabs. The
  /// Material family gets the TabBar's own scroll; the libraries that ship
  /// no scrollable strip keep their shrink-to-fit row — the strip must then
  /// sit in a bounded width, never an unbounded scroll view.
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
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru ||
      PureDesignLanguage.glass ||
      PureDesignLanguage.neumorphic => _MaterialTabBar(tabs: tabs, index: selected, onChanged: select, isScrollable: isScrollable),
      // iOS's own segmented strip: a sliding thumb over the library's cells.
      PureDesignLanguage.cupertino => _CupertinoTabBar(tabs: tabs, index: selected, onChanged: select),
      // macOS's own segmented control, driven by the library controller.
      PureDesignLanguage.macos => _MacosTabBar(tabs: tabs, index: selected, onChanged: select),
      // fluent_2's own tab list.
      PureDesignLanguage.fluent => f2.FluentTabList<int>(
        selectedValue: selected,
        onSelect: select,
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
        control: forui.FTabControl.lifted(index: selected, onChange: (next) => select?.call(next)),
        children: [for (final tab in tabs) forui.FTabEntry(label: _foruiLabel(tab), child: const SizedBox.shrink())],
      ),
      // Wind's own tabs. The fork always builds the active panel; the caller
      // owns the body, so the panel is empty.
      PureDesignLanguage.wind => wind.WTabs(
        tabs: [for (final tab in tabs) tab.label],
        selectedIndex: selected,
        onChanged: select,
        panelBuilder: (_) => const SizedBox.shrink(),
      ),
    };
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
        isScrollable: true,
        tabAlignment: TabAlignment.start,
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
        child: Text(tabs.first.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    final children = <int, Widget>{
      for (var i = 0; i < tabs.length; i++) i: Text(tabs[i].label, maxLines: 1, overflow: TextOverflow.ellipsis),
    };
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

  macos.MacosTabController _createController() {
    return macos.MacosTabController(
      length: widget.tabs.length,
      initialIndex: widget.index.clamp(0, widget.tabs.length - 1),
    )..addListener(_handleChange);
  }

  void _handleChange() {
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
      _controller.index = widget.index.clamp(0, widget.tabs.length - 1);
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
        tabs: [for (final tab in widget.tabs) macos.MacosTab(label: tab.label)],
      ),
    );
  }
}
