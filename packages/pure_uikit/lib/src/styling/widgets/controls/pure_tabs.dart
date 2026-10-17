import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart' show InteractionState, Style;
import 'package:pure_uikit/src/styling/widgets/layout/pure_box.dart';

/// One tab's label and optional icon.
class PureTab {
  /// A tab.
  const new({required this.label, this.icon});

  /// The tab label.
  final String label;

  /// An optional leading icon.
  final IconData? icon;
}

/// The public tab strip: one widget, every theme and density. [build] switches
/// on `UiConfig.language` and constructs the language's own strip directly —
/// Material's `TabBar`, iOS's row of the library's own press targets drawn the
/// way iOS draws an in-page strip, macOS's segment cells, fluent_2's
/// `FluentTabList` — so what the user sees is exactly what that library's own
/// documentation shows. Switching `UiConfig.language` re-skins every strip.
class PureTabs extends StatelessWidget {
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
  final List<PureTab> tabs;

  /// The selected index.
  final int index;

  /// Called with a tab's index when it is chosen.
  final ValueChanged<int>? onChanged;

  /// The gap between tabs.
  final double spacing;

  /// Whether the strip responds to input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    // A null callback is every library's inert state, so folding `enabled`
    // into it once serves all the branches below.
    final select = enabled ? onChanged : null;

    return switch (theme.config.language) {
      // The strip is driven by a `TabController` rather than by an index, so
      // the controller lives in [_MaterialTabBar] and the spec's index is
      // asserted onto it on every change; the strip stays controlled.
      PureDesignLanguage.material => _MaterialTabBar(spec: this),
      PureDesignLanguage.cupertino => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++)
            cupertino.CupertinoButton(
              minimumSize: Size.zero,
              padding: EdgeInsets.symmetric(
                horizontal: theme.token.scale.sizes.sm,
                vertical: theme.token.scale.sizes.xxs,
              ),
              foregroundColor: i == index ? theme.tabs.itemSelectedColor : theme.tabs.itemColor,
              onPressed: select == null ? null : () => select(i),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tabs[i].icon case final IconData glyph) ...[Icon(glyph, size: 15), const SizedBox(width: 4)],
                  Text(
                    tabs[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: i == index ? FontWeight.w600 : FontWeight.w400),
                  ),
                ],
              ),
            ),
        ],
      ),
      PureDesignLanguage.macos => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _MacosTabCell(
              label: tabs[i].label,
              icon: tabs[i].icon,
              selected: i == index,
              onTap: select == null ? null : () => select(i),
            ),
        ],
      ),
      // fluent_2's own tab list — one tab stop, arrows inside, the selection
      // bar that is what separates a Fluent tab from a segment. The list spaces
      // its tabs by its own padding, so `spacing` has no counterpart here.
      PureDesignLanguage.fluent => f2.FluentTabList<int>(
        selectedValue: index >= 0 && index < tabs.length ? index : null,
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
      // The library's own tab widget, in its lifted control — the index is
      // what the strip shows and a tap only reports it, so a refused tap is
      // undone by the next rebuild. One honest cost: every `FTabEntry` carries
      // a content panel, because forui's tabs are a tab view and the caller's
      // router owns the body here — each entry gets an empty box, which is
      // what buys the library's own indicator, label weight and focus ring.
      // The library keeps one controller for the widget's lifetime and does
      // not resize it when the tab count changes, so a changed count remounts
      // the strip; the strip pads its own tabs, so `spacing` has no slot; and
      // an empty list is drawn as nothing at all, because `FTabs` asserts on
      // it.
      PureDesignLanguage.forui => _ForuiTabBar(spec: this),
      // Hand-rolled glass-style composition: the library has no tab widget at
      // all, so the active tab is a raised frosted sheet — a lit surface under
      // the label, the idiom glassmorphism uses for whatever is selected —
      // closed by a short primary rule along its bottom edge, while the
      // inactive tabs are bare labels. Everything visible comes from
      // [glass.GlassTheme]; taps and the hover tint go through the core's
      // [PureBox]. The sheets are rounded, so adjacent tabs would otherwise
      // read as one panel — `spacing` is the gap between them here.
      PureDesignLanguage.glass => _GlassTabBar(spec: this),
      // Hand-rolled neumorphic-style composition: the library's only strip
      // widget is `NeuBottomNav`, and it cannot be this control — it asserts
      // at least two items, requires an icon widget per item and docks itself
      // as a bottom bar — so the strip is one `NeuContainer` cell per tab, the
      // selected one raised as a dome ([neu.NeuShape.convex]) at the theme's
      // depth and labelled in the accent, the others flat on the surface. That
      // depth-plus-accent reading is the same one the library uses for its own
      // active destination, and the reason a Neumorphic tab needs no ink bar.
      PureDesignLanguage.neumorphic => _NeumorphicTabBar(spec: this),
      // Hand-rolled wind-style composition: the fork has `WTabs`, but it is a
      // tab view — the row is welded to a content panel and paints a bare
      // `WText` per tab, so a caller who already owns the body gets an empty
      // panel and the icon has nowhere to go. The strip is made of the parts
      // `WTabs` itself is made of: a `WAnchor` per tab over a `WDiv`, the
      // active one carrying the library's own `selected:` tokens, on a
      // rule-drawn list. The `selected:` set is passed to the styled `WDiv` as
      // well as to the anchor — a `WDiv` reads its state from the nearest
      // provider, so the tokens only fire on a double pass.
      PureDesignLanguage.wind => _WindTabBar(spec: this),
      // Yaru IS Material theming — its character comes from the host theme, not
      // from a different strip.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _MaterialTabBar(spec: this),
    };
  }
}

/// The forui strip: the library's own `FTabs` in its lifted control, with an
/// empty content panel per entry (see the [PureTabs] forui branch).
class _ForuiTabBar extends StatelessWidget {
  const new({required this.spec});

  final PureTabs spec;

  @override
  Widget build(BuildContext context) {
    final count = spec.tabs.length;
    if (count == 0) {
      return const SizedBox.shrink();
    }
    final select = spec.enabled ? spec.onChanged : null;

    return forui.FTabs(
      key: ValueKey('forui-tabs-$count'),
      control: forui.FTabControl.lifted(
        index: spec.index.clamp(0, count - 1),
        onChange: (index) => select?.call(index),
      ),
      children: [for (final tab in spec.tabs) forui.FTabEntry(label: _label(tab), child: const SizedBox.shrink())],
    );
  }

  static Widget _label(PureTab tab) => switch (tab.icon) {
    final IconData glyph => Column(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(glyph), Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis)],
    ),
    null => Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
  };
}

/// The glass strip: a hand-rolled glassmorphism composition (see the
/// [PureTabs] glass branch).
class _GlassTabBar extends StatelessWidget {
  const new({required this.spec});

  final PureTabs spec;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    final radius = BorderRadius.circular(glassTheme.borderRadius);
    final lineWidth = theme.token.motion.lineWidthBold;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < spec.tabs.length; index++)
          Padding(
            padding: EdgeInsets.only(right: index == spec.tabs.length - 1 ? 0 : spec.spacing),
            child: PureBox(
              style: (state) => Style(
                borderRadius: radius,
                background: switch (state) {
                  InteractionState.hovered ||
                  InteractionState.pressed ||
                  InteractionState.focused => glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0)),
                  _ => null,
                },
                opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
              ),
              onTap: select == null ? null : () => select(index),
              enabled: spec.enabled,
              child: _GlassTab(
                tab: spec.tabs[index],
                selected: index == spec.index,
                radius: radius,
                lineWidth: lineWidth,
              ),
            ),
          ),
      ],
    );
  }
}

/// One glass tab: its label and optional glyph, on a frosted sheet when it is
/// the active one, with the primary rule that says so. A glass sheet cannot
/// shade itself enough to carry a tab on its own, so the strip also rules the
/// accent, as every language in this contract does.
class _GlassTab extends StatelessWidget {
  const new({required this.tab, required this.selected, required this.radius, required this.lineWidth});

  final PureTab tab;
  final bool selected;
  final BorderRadius radius;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final tint = selected ? theme.tabs.itemSelectedColor : theme.tabs.itemColor;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tab.icon case final glyph?) ...[
          Icon(glyph, size: theme.text.label.fontSize, color: tint),
          SizedBox(width: theme.token.scale.sizes.xs),
        ],
        Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.text.label.copyWith(color: tint)),
      ],
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.tabs.horizontalPadding, vertical: theme.tabs.verticalGap),
      child: selected
          ? DefaultTextStyle(style: const TextStyle(fontWeight: FontWeight.w600), child: label)
          : label,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected)
          glass.GlassContainer(
            customBorderRadius: radius,
            color: glassTheme.color,
            opacity: (glassTheme.opacity * 2.4).clamp(0.0, 1.0),
            child: content,
          )
        else
          content,
        SizedBox(height: lineWidth, child: selected ? ColoredBox(color: theme.tabs.inkBarColor) : null),
      ],
    );
  }
}

/// The neumorphic strip: a hand-rolled neumorphic composition (see the
/// [PureTabs] neumorphic branch). [PureTabs.spacing] is honoured as the gap
/// between cells; a disabled strip keeps its labels and loses its callbacks.
class _NeumorphicTabBar extends StatelessWidget {
  const new({required this.spec});

  final PureTabs spec;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    final radius = surface.borderRadius.resolve(Directionality.of(context));
    final cellRadius = BorderRadius.circular(radius.topLeft.x / 2.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < spec.tabs.length; index++) ...[
          if (index > 0) SizedBox(width: spec.spacing),
          _NeumorphicTabCell(
            tab: spec.tabs[index],
            selected: index == spec.index,
            enabled: spec.enabled,
            onTap: select == null ? null : () => select(index),
            radius: cellRadius,
            surface: surface,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

/// One cell of the neumorphic strip: the library's own plane, domed out
/// ([neu.NeuShape.convex]) when it is the selected tab, labelled in the
/// library's accent the way its bottom bar tints the active destination.
class _NeumorphicTabCell extends StatelessWidget {
  const new({
    required this.tab,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final PureTab tab;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final neu.NeuThemeData surface;
  final PureTheme theme;

  @override
  Widget build(BuildContext context) {
    final Color tint;
    if (!enabled) {
      tint = theme.colors.textDisabled;
    } else if (selected) {
      tint = surface.accentColor;
    } else {
      tint = theme.colors.textSecondary;
    }
    final glyph = tab.icon;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: neu.NeuContainer(
        shape: selected ? neu.NeuShape.convex : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: selected ? surface.depth : 0.0,
        distance: selected ? surface.distance : 0.0,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph case final IconData icon) ...[
              Icon(icon, color: tint, size: theme.text.body.fontSize),
              SizedBox(width: theme.token.scale.sizes.xs),
            ],
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.body.copyWith(color: tint, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wind strip: a hand-rolled wind-style composition (see the [PureTabs]
/// wind branch). [PureTabs.spacing] belongs to the core's own laying-out; the
/// strip uses the library's own tab padding.
class _WindTabBar extends StatelessWidget {
  const new({required this.spec});

  final PureTabs spec;

  @override
  Widget build(BuildContext context) {
    final select = spec.enabled ? spec.onChanged : null;
    return wind.WDiv(
      className: 'flex flex-row w-full border-b border-gray-200 dark:border-gray-700',
      children: [
        for (var index = 0; index < spec.tabs.length; index++)
          _tab(spec.tabs[index], index, index == spec.index, select),
      ],
    );
  }

  static Widget _tab(PureTab tab, int index, bool selected, ValueChanged<int>? select) {
    const selectedStates = <String>{'selected'};
    const tabClasses =
        'px-4 py-2 text-sm border-b-2 border-transparent text-gray-600 dark:text-gray-400 transition-colors'
        ' hover:text-primary-500'
        ' selected:text-primary-500 selected:border-primary-500'
        ' disabled:opacity-50';
    final states = selected ? selectedStates : null;
    return wind.WAnchor(
      onTap: select == null ? null : () => select(index),
      isDisabled: select == null,
      states: states,
      semanticLabel: tab.label,
      child: wind.WDiv(
        className: tabClasses,
        states: states,
        child: wind.WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            if (tab.icon case final icon?) wind.WIcon(icon, className: 'text-xs'),
            wind.WText(tab.label, className: 'truncate'),
          ],
        ),
      ),
    );
  }
}

/// One cell of the macOS strip: the library's own `MacosTab` — the cell
/// `MacosSegmentedControl` renders, which paints the checked chip and its
/// radius itself — with `MacosIcon` for the glyph and the click cursor the
/// library's own controls use.
class _MacosTabCell extends StatelessWidget {
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

/// The Material strip: the `TabController` it is driven by lives here, seeded
/// from the spec and re-asserted on every change, so a tap reports the index
/// and the caller's next rebuild moves the indicator to wherever the spec says.
class _MaterialTabBar extends StatefulWidget {
  const new({required this.spec});

  final PureTabs spec;

  @override
  State<_MaterialTabBar> createState() => _MaterialTabBarState();
}

class _MaterialTabBarState extends State<_MaterialTabBar> with SingleTickerProviderStateMixin {
  late TabController _controller = _make();

  TabController _make() => TabController(length: widget.spec.tabs.length, vsync: this);

  @override
  void didUpdateWidget(_MaterialTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.tabs.length != widget.spec.tabs.length) {
      _controller.dispose();
      _controller = _make();
    }
    final index = widget.spec.index;
    if (index >= 0 && index < widget.spec.tabs.length && _controller.index != index) {
      _controller.index = index;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final select = spec.enabled ? spec.onChanged : null;
    return TabBar(
      controller: _controller,
      isScrollable: spec.tabs.length > 5,
      tabs: [for (final tab in spec.tabs) Tab(text: tab.label, icon: tab.icon == null ? null : Icon(tab.icon))],
      onTap: select,
    );
  }
}

/// The page switcher under a [PureTabs] strip.
///
/// It takes the same index the strip reports, so a page pair looks like:
/// ```dart
/// Column(
///   children: [
///     PureTabs(tabs: tabs, index: index, onChanged: (i) => setState(() => index = i)),
///     Expanded(child: PureTabView(index: index, pages: pages, onIndexChanged: (i) => setState(() => index = i))),
///   ],
/// )
/// ```
/// [build] switches on `UiConfig.language` and constructs the language's own
/// page change directly — Material's sliding `TabBarView`, iOS's swiping
/// `PageView` under the library's scroll chrome, macOS's indexed pane, and
/// Fluent's in-place cross-fade — so what the user sees is exactly what that
/// library's own documentation shows.
class PureTabView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);

    return switch (theme.config.language) {
      // The view is driven by a `TabController` of its own — `tabBar` and
      // `tabView` are two controls, each controlled by its own spec — with the
      // spec's duration on the controller and a swipe reported back through
      // [onIndexChanged].
      PureDesignLanguage.material => _MaterialTabView(spec: this),
      PureDesignLanguage.cupertino => _CupertinoTabView(spec: this),
      // A macOS pane is never dragged: the strip (and only the strip) moves
      // the page, through the caller. The pane is the library's own numbers —
      // its radius, hairline and per-brightness fill — over an `IndexedStack`
      // that keeps every page mounted so its state survives a change of index.
      PureDesignLanguage.macos => _MacosTabPane(spec: this),
      // Windows replaces a tab body in place with a cross-fade, never sliding
      // the pages sideways, so the view is an `AnimatedSwitcher` keyed by the
      // page index and nothing more.
      PureDesignLanguage.fluent => pages.isEmpty
          ? const SizedBox.shrink()
          : AnimatedSwitcher(
              duration: duration,
              // Clamp rather than throw: the strip and the view are driven
              // separately, and a frame where the two disagree briefly must
              // not take the window down.
              child: KeyedSubtree(
                key: ValueKey<int>(index.clamp(0, pages.length - 1)),
                child: pages[index.clamp(0, pages.length - 1)],
              ),
            ),
      // Composed, not mapped: in 0.27.5 forui has no content-side page widget.
      // Its only one is `FTabs`, and that is a pair — every `FTabEntry` carries
      // the panel under its own tab, so the strip owns the body, and re-using
      // it here would mean inventing a second strip. The view is the
      // widgets-layer `PageView` — the pages stay exactly what the caller
      // passed — animated to the spec's index over [duration], reporting a
      // swipe through [onIndexChanged].
      PureDesignLanguage.forui => _ForuiTabView(spec: this),
      // Hand-rolled glass-style composition: the library ships no page
      // switcher — 0.1.0 publishes surfaces, four controls and a Material app
      // bar, and nothing that pages or slides. iOS *swipes* between tab pages
      // and this language is the frosted reading of iOS, so the view keeps the
      // shape change and rides the widgets-layer `PageView` on a frosted
      // [glass.GlassContainer] sheet. The view is the surface only: the index
      // stays the caller's, animated to over [duration], and a swipe is
      // reported through [onIndexChanged] because a glass viewer can move a
      // page with a finger.
      PureDesignLanguage.glass => _GlassTabView(spec: this),
      // Hand-rolled neumorphic-style composition: the library ships no page
      // view, so the content is slid with the widgets-layer `PageView`, and
      // what the language adds is the surface it swipes across — the pages sit
      // inside a `NeuContainer` on its recessed ([neu.NeuShape.concave]) face,
      // a well the content drops into. That recess is the inverse of the
      // strip's dome: press the dome above, see the plate. A swipe is only
      // wired where the caller can hear about it.
      PureDesignLanguage.neumorphic => _NeumorphicTabView(spec: this),
      // Hand-rolled wind-style composition: the fork's `WTabs` welds the strip
      // to the panel it paints, and this contract hands the two separately, so
      // the view is the widgets-layer `PageView` — the mechanism Wind has no
      // class for — inside the library's own full-size column container, whose
      // `bg-white dark:bg-gray-900` pair is the panel surface and every other
      // pixel of chrome stays the library's.
      PureDesignLanguage.wind => _WindTabView(spec: this),
      // Yaru IS Material theming — its character comes from the host theme, not
      // from a different view.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _MaterialTabView(spec: this),
    };
  }
}

/// The forui view: the widgets-layer `PageView` kept in step with the spec's
/// index, animated over the spec's duration (see the [PureTabView] forui
/// branch).
class _ForuiTabView extends StatefulWidget {
  const new({required this.spec});

  final PureTabView spec;

  @override
  State<_ForuiTabView> createState() => _ForuiTabViewState();
}

class _ForuiTabViewState extends State<_ForuiTabView> {
  late final PageController _controller = PageController(initialPage: widget.spec.index);

  @override
  void didUpdateWidget(_ForuiTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.spec.index;
    if (oldWidget.spec.index != index && !_atPage(index)) {
      _controller.animateToPage(index, duration: widget.spec.duration, curve: Curves.easeInOutCubic);
    }
  }

  bool _atPage(int index) => _controller.hasClients && _controller.page == index.toDouble();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;
    return PageView(
      controller: _controller,
      physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
      onPageChanged: swipeable ? (index) => spec.onIndexChanged?.call(index) : null,
      children: spec.pages,
    );
  }
}

/// The glass view: the widgets-layer `PageView` inside the library's own frosted
/// sheet (see the [PureTabView] glass branch).
class _GlassTabView extends StatefulWidget {
  const new({required this.spec});

  final PureTabView spec;

  @override
  State<_GlassTabView> createState() => _GlassTabViewState();
}

class _GlassTabViewState extends State<_GlassTabView> {
  late final PageController _controller = PageController(initialPage: _clamped(widget.spec));

  int _clamped(PureTabView spec) => spec.pages.isEmpty ? 0 : spec.index.clamp(0, spec.pages.length - 1);

  @override
  void didUpdateWidget(_GlassTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final spec = widget.spec;
    if (spec.pages.isEmpty || oldWidget.spec.index == spec.index) {
      return;
    }
    final target = _clamped(spec);
    if (_controller.hasClients && _controller.page != target.toDouble()) {
      _controller.animateToPage(target, duration: spec.duration, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    // A swipe is the point of this view, so it is only allowed where the
    // caller can hear about it and there is more than one page to reach.
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;

    return glass.GlassContainer(
      blur: glassTheme.blur,
      opacity: glassTheme.opacity,
      borderRadius: glassTheme.borderRadius,
      color: glassTheme.color,
      elevation: glassTheme.elevation,
      shadowColor: glassTheme.shadowColor ?? theme.colors.shadowBase,
      padding: EdgeInsets.all(theme.token.scale.sizes.sm),
      child: PageView(
        controller: _controller,
        physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        onPageChanged: swipeable ? spec.onIndexChanged : null,
        children: spec.pages,
      ),
    );
  }
}

/// The neumorphic view: the widgets-layer `PageView` inside the library's
/// recessed well (see the [PureTabView] neumorphic branch).
class _NeumorphicTabView extends StatefulWidget {
  const new({required this.spec});

  final PureTabView spec;

  @override
  State<_NeumorphicTabView> createState() => _NeumorphicTabViewState();
}

class _NeumorphicTabViewState extends State<_NeumorphicTabView> {
  late final PageController _controller = PageController(initialPage: _clampedIndex);

  int get _clampedIndex {
    final pages = widget.spec.pages;
    if (pages.isEmpty) {
      return 0;
    }
    return widget.spec.index.clamp(0, pages.length - 1);
  }

  @override
  void didUpdateWidget(_NeumorphicTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _clampedIndex;
    if (oldWidget.spec.index != index && !_atPage(index)) {
      _controller.animateToPage(index, duration: widget.spec.duration, curve: Curves.easeInOutCubic);
    }
  }

  bool _atPage(int index) => _controller.hasClients && _controller.page == index.toDouble();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final surface = neu.NeuTheme.of(context);
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;

    return neu.NeuContainer(
      shape: neu.NeuShape.concave,
      baseColor: surface.baseColor,
      depth: surface.depth,
      distance: surface.distance,
      borderRadius: surface.borderRadius,
      padding: EdgeInsets.all(surface.depth),
      child: PageView(
        controller: _controller,
        physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        onPageChanged: swipeable ? (index) => spec.onIndexChanged?.call(index) : null,
        children: spec.pages,
      ),
    );
  }
}

/// The wind view: the widgets-layer `PageView` inside the library's own
/// full-size column container (see the [PureTabView] wind branch).
class _WindTabView extends StatefulWidget {
  const new({required this.spec});

  final PureTabView spec;

  @override
  State<_WindTabView> createState() => _WindTabViewState();
}

class _WindTabViewState extends State<_WindTabView> {
  late final PageController _controller = PageController(initialPage: _page(widget.spec));

  static int _page(PureTabView spec) {
    if (spec.pages.isEmpty) {
      return 0;
    }
    return spec.index.clamp(0, spec.pages.length - 1);
  }

  @override
  void didUpdateWidget(covariant _WindTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _page(widget.spec);
    if (oldWidget.spec.pages.length != widget.spec.pages.length) {
      // The controller cannot re-page a list that changed shape under it.
      _controller.jumpToPage(page);
      return;
    }
    if (_controller.hasClients && _controller.page != page.toDouble()) {
      _controller.animateToPage(page, duration: widget.spec.duration, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;
    return wind.WDiv(
      className: 'flex flex-col w-full h-full bg-white dark:bg-gray-900',
      children: [
        Expanded(
          child: PageView(
            controller: _controller,
            physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
            onPageChanged: swipeable ? spec.onIndexChanged : null,
            children: spec.pages,
          ),
        ),
      ],
    );
  }
}

/// The Material view: a `TabController` of its own, re-asserted from the spec
/// on every change, with the swipe reported back through
/// [PureTabView.onIndexChanged].
class _MaterialTabView extends StatefulWidget {
  const new({required this.spec});

  final PureTabView spec;

  @override
  State<_MaterialTabView> createState() => _MaterialTabViewState();
}

class _MaterialTabViewState extends State<_MaterialTabView> with SingleTickerProviderStateMixin {
  late TabController _controller = _make();

  TabController _make() => TabController(
    length: widget.spec.pages.length,
    initialIndex: _inRange(widget.spec.index, widget.spec.pages.length),
    animationDuration: widget.spec.duration,
    vsync: this,
  )..addListener(_reportSwipe);

  /// The controller asserts an in-range initial index; a spec from a shrinking
  /// page list is clamped rather than allowed to crash the view.
  static int _inRange(int index, int length) => length == 0 ? 0 : index.clamp(0, length - 1);

  void _reportSwipe() {
    final index = _controller.index;
    if (index != widget.spec.index) {
      widget.spec.onIndexChanged?.call(index);
    }
  }

  @override
  void didUpdateWidget(_MaterialTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.pages.length != widget.spec.pages.length ||
        oldWidget.spec.duration != widget.spec.duration) {
      _controller.dispose();
      _controller = _make();
    }
    final index = _inRange(widget.spec.index, widget.spec.pages.length);
    if (_controller.index != index) {
      _controller.index = index;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_reportSwipe);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;
    return TabBarView(
      controller: _controller,
      physics: swipeable ? null : const NeverScrollableScrollPhysics(),
      children: spec.pages,
    );
  }
}

/// The Cupertino view: a `PageView` given the library's own scroll chrome — no
/// overscroll glow and a scrollbar where a desktop shows one — with the page
/// changes from the caller animated across in the spec's duration.
class _CupertinoTabView extends StatefulWidget {
  const new({required this.spec});

  final PureTabView spec;

  @override
  State<_CupertinoTabView> createState() => _CupertinoTabViewState();
}

class _CupertinoTabViewState extends State<_CupertinoTabView> {
  late final PageController _controller = PageController(initialPage: _page(widget.spec));

  /// The index clamped into the pages actually given, so a stale index from the
  /// caller cannot throw inside the controller.
  static int _page(PureTabView spec) => spec.pages.isEmpty ? 0 : spec.index.clamp(0, spec.pages.length - 1);

  @override
  void didUpdateWidget(_CupertinoTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _page(widget.spec);
    if (_page(oldWidget.spec) == page || !_controller.hasClients || _controller.page == page.toDouble()) {
      return;
    }
    _controller.animateToPage(page, duration: widget.spec.duration, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;
    return ScrollConfiguration(
      behavior: const cupertino.CupertinoScrollBehavior(),
      child: PageView(
        controller: _controller,
        // Paging stays the page physics — the library behaviour above supplies
        // the overscroll and the scrollbar, not the snap.
        physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        onPageChanged: swipeable ? (page) => spec.onIndexChanged?.call(page) : null,
        children: spec.pages,
      ),
    );
  }
}

/// The macOS pane: the pane `MacosTabView` shows, assembled from the library's
/// own numbers and holding every page alive in an [IndexedStack].
class _MacosTabPane extends StatelessWidget {
  const new({required this.spec});

  final PureTabView spec;

  @override
  Widget build(BuildContext context) {
    final pages = spec.pages;
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final index = spec.index.clamp(0, pages.length - 1);
    final brightness = macos.MacosTheme.brightnessOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: brightness.resolve(const Color(0xFFE6E9EA), const Color(0xFF2B2E33)),
        border: Border.all(color: brightness.resolve(const Color(0xFFE1E2E4), const Color(0xFF3E4045))),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: IndexedStack(index: index, children: pages)),
    );
  }
}
