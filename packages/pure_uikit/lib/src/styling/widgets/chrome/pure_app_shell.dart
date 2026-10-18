import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/scales/sizing.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_nav_bar.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_shell_types.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The public application shell: one widget, every design language.
///
/// It sits between the host and the page — the routing layer's `ShellRoute` in
/// an app — and takes only neutral data: the destinations, the selected id,
/// the callback and the body. There is no adapter and no spec in between:
/// [PureAppShellState.build] switches on `UiConfig.language` and draws the navigation with the
/// library's own structural widget — Material's `NavigationRail`, macOS's
/// `SidebarItems`, Fluent's `FluentNavDrawer`, forui's `FSidebar`, and
/// Cupertino's own list section — while glass, neumorphic and wind, which ship
/// no navigation column, use Flutter's official Material
/// `NavigationRail`/`NavigationBar`. Switching `UiConfig.language` re-skins
/// the shell.
class PureAppShell extends StatefulWidget {
  /// A shell around [child].
  const new({
    required this.child,
    this.destinations = const <PureShellDestination>[],
    this.selectedId,
    this.onSelected,
    this.leading,
    this.trailing,
    this.placement = PureShellPlacement.adaptive,
    super.key,
  });

  /// The page content.
  final Widget child;

  /// The destinations, in order.
  final List<PureShellDestination> destinations;

  /// The selected destination's id.
  final String? selectedId;

  /// Called with a destination's id.
  final ValueChanged<String>? onSelected;

  /// Content pinned at the head of a navigation column, above the
  /// destinations — the entries a rail carries that are not destinations
  /// (a menu, a search, a tool that opens its own page).
  final Widget? leading;

  /// Content pinned at the end of a navigation column; the bottom-strip form
  /// has neither a head nor a foot slot and drops both rather than inventing a
  /// place for them.
  final Widget? trailing;

  /// Where the caller wants the navigation.
  final PureShellPlacement placement;

  @override
  PureAppShellState createState() => PureAppShellState();
}

/// The shell's state: only the fluent narrow form keeps any — whether its
/// overlay drawer is showing. Every other form is a pure function of the
/// placement and the destinations, so the configuration below reads exactly
/// as it did when the whole shell was stateless.
class PureAppShellState extends State<PureAppShell> {
  /// Whether the fluent narrow form's overlay drawer is showing.
  bool _fluentDrawerOpen = false;

  /// The page content.
  Widget get child => widget.child;

  /// The destinations, in order.
  List<PureShellDestination> get destinations => widget.destinations;

  /// The selected destination's id.
  String? get selectedId => widget.selectedId;

  /// Called with a destination's id.
  ValueChanged<String>? get onSelected => widget.onSelected;

  /// Content pinned at the head of a navigation column.
  Widget? get leading => widget.leading;

  /// Content pinned at the end of a navigation column.
  Widget? get trailing => widget.trailing;

  /// Where the caller wants the navigation.
  PureShellPlacement get placement => widget.placement;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return switch (theme.config.language) {
      // Yaru draws chrome with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different shell. Glass, neumorphic
      // and wind ship no navigation structure, so Flutter's official Material
      // NavigationRail/NavigationBar is the shared fallback.
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru ||
      PureDesignLanguage.glass ||
      PureDesignLanguage.neumorphic ||
      PureDesignLanguage.wind => _materialShell(context),
      PureDesignLanguage.cupertino => _cupertinoShell(context),
      PureDesignLanguage.macos => _macosShell(context, theme),
      PureDesignLanguage.fluent => _fluentShell(context),
      PureDesignLanguage.forui => _foruiShell(context),
    };
  }

  /// One destination is not a navigation choice, and a shell asked for none:
  /// the frame is the page's own and the shell stands aside.
  bool get _standsAside => placement == PureShellPlacement.none || destinations.length < 2;

  /// Whether the rail form is drawn for [placement]: `rail` always, `bottom`
  /// never, and `adaptive` whenever the environment reports a rail width above
  /// zero — the same width rule every language reads, so the form switch
  /// happens at one breakpoint across the family.
  static bool _wantsRail(PureShellPlacement placement, BuildContext context) => switch (placement) {
    PureShellPlacement.rail => true,
    PureShellPlacement.bottom || PureShellPlacement.none => false,
    PureShellPlacement.adaptive =>
      (PureEnvironmentScope.maybeOf(context)?.geometry.railWidth ?? PureSizing.railWidth) > 0,
  };

  /// The bottom-strip form: the shell delegates to [PureNavBar] — the same
  /// dispatched control a page names — rather than drawing a second strip, so
  /// the two forms cannot drift apart. `leading` and `trailing` have no slot in
  /// a strip and are dropped, as the contract documents.
  Widget _bottomStrip() {
    return Column(
      children: [
        Expanded(child: child),
        PureNavBar(
          items: [
            for (final destination in destinations) PureNavBarItem(label: destination.label, icon: destination.icon),
          ],
          index: destinations.indexWhere((destination) => destination.id == selectedId),
          onChanged: (index) {
            final destination = destinations[index];
            if (destination.enabled) {
              onSelected?.call(destination.id);
            }
          },
        ),
      ],
    );
  }

  /// The selection as an index, or -1 when nothing matches.
  int get _selectedIndex => destinations.indexWhere((destination) => destination.id == selectedId);

  /// Material: `NavigationRail` is the library's own structural navigation —
  /// a destination is an icon over a label, the selection is painted with the
  /// Material 3 indicator pill, and a destination can be `disabled` — the one
  /// shell library that models it. The rail is only the strip: Material
  /// composes it beside the body, and the page frame stays the language's
  /// `scaffold`.
  Widget _materialShell(BuildContext context) {
    if (_standsAside) {
      return child;
    }
    if (!_wantsRail(placement, context)) {
      return _bottomStrip();
    }
    return Row(
      children: [
        NavigationRail(
          // Out of range is "nothing selected": the rail asserts a null index
          // rather than an index into a list it has not been given.
          selectedIndex: _selectedIndex < 0 ? null : _selectedIndex,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (index) {
            final destination = destinations[index];
            if (destination.enabled) {
              onSelected?.call(destination.id);
            }
          },
          destinations: [
            for (final destination in destinations)
              NavigationRailDestination(
                icon: Icon(destination.icon),
                label: Text(destination.label),
                disabled: !destination.enabled,
              ),
          ],
          leading: leading,
          trailing: trailing,
          trailingAtBottom: trailing != null,
        ),
        Expanded(child: child),
      ],
    );
  }

  /// Cupertino: composed, not mapped — the library ships no navigation column.
  /// The rail is assembled out of the library's own surface pieces: a
  /// `CupertinoListSection` (its grouped-surface background and hairline
  /// separators) of `CupertinoListTile` rows (leading glyph, title, inert when
  /// given no `onTap`) — the same pieces iOS draws its sidebars out of.
  ///
  /// The tinting is the library's, not the token's. The selected row takes the
  /// accent: the accent role is the ambient `CupertinoTheme`'s `primaryColor`,
  /// with `primaryContrastingColor` for what sits on the fill. A live but
  /// unselected row uses `CupertinoColors.secondaryLabel`, a disabled one
  /// `tertiaryLabel`, and the disabled row is refused here — its `onTap` is
  /// null — because the tile has no disabled state of its own.
  Widget _cupertinoShell(BuildContext context) {
    if (_standsAside) {
      return child;
    }
    if (!_wantsRail(placement, context)) {
      return _bottomStrip();
    }
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    return Row(
      children: [
        SizedBox(
          width: geometry?.railWidth ?? PureSizing.railWidth,
          child: ColoredBox(
            color: cupertino.CupertinoColors.systemGroupedBackground.resolveFrom(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading case final Widget head)
                  Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 0), child: head),
                cupertino.CupertinoListSection(
                  // The section paints the surface; the column behind it
                  // already is that surface, so the rows sit on it without a
                  // second fill.
                  backgroundColor: cupertino.CupertinoColors.transparent,
                  margin: EdgeInsets.zero,
                  children: [
                    for (final destination in destinations)
                      _cupertinoTile(context, destination, destination.id == selectedId),
                  ],
                ),
                if (trailing case final Widget footer) ...[
                  const Spacer(),
                  Align(alignment: Alignment.bottomCenter, child: footer),
                ],
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// One destination as the library's own row: accent when selected, inert
  /// when the caller says it cannot be taken.
  Widget _cupertinoTile(BuildContext context, PureShellDestination destination, bool selected) {
    final cupertinoTheme = cupertino.CupertinoTheme.of(context);
    final enabled = destination.enabled;
    final tint = !enabled
        ? cupertino.CupertinoColors.tertiaryLabel.resolveFrom(context)
        : selected
        ? cupertinoTheme.primaryContrastingColor
        : cupertino.CupertinoColors.secondaryLabel.resolveFrom(context);
    final iconSize = PureEnvironmentScope.maybeOf(context)?.geometry.iconSize ?? 18;

    return Semantics(
      selected: selected,
      child: cupertino.CupertinoListTile(
        leading: Icon(destination.icon, size: iconSize, color: tint),
        title: Text(
          destination.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tint, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
        ),
        // A disabled destination keeps its row so the column does not shift
        // when it opens, and keeps no tap: the tile has no disabled state to
        // ask for.
        onTap: enabled ? () => onSelected?.call(destination.id) : null,
        backgroundColor: selected ? cupertinoTheme.primaryColor : null,
      ),
    );
  }

  /// macOS: the narrowest rail this shell draws before `SidebarItems`' row —
  /// a fixed `134 + visualDensity.horizontal` inside a list padded 10 —
  /// shrinks and its label ellipsis out of usefulness.
  static const double _minMacosRailWidth = 154;

  /// macOS: `SidebarItems` is the library's own navigation list — a scrollable
  /// column whose rows it paints itself, the selected one with the
  /// system-accent chip — and the spec's destinations become its descriptors
  /// one-for-one, so the accent decision, the row metrics and the selection
  /// painting all stay the library's. The column *around* those rows is
  /// composed: this rail is not drag-resizable and has no window-breakpoint
  /// auto-hide, because those are `MacosWindow` behaviours, and the window
  /// frame belongs to the language's `scaffold`.
  Widget _macosShell(BuildContext context, PureTheme theme) {
    if (_standsAside) {
      return child;
    }
    if (!_wantsRail(placement, context)) {
      return _bottomStrip();
    }
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final requested = geometry?.railWidth ?? PureSizing.railWidth;
    final railWidth = requested < _minMacosRailWidth ? _minMacosRailWidth : requested;

    return Row(
      children: [
        SizedBox(
          width: railWidth,
          child: ColoredBox(
            // The library's own surface colour: `MacosWindow` paints the
            // sidebar over its vibrancy layer, which a shell has no business
            // installing.
            color: macos.MacosTheme.of(context).canvasColor,
            child: Column(
              children: [
                if (leading case final Widget head)
                  Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 0), child: head),
                // Expanded because the list scrolls: `SidebarItems` is a
                // `ListView`, and a sidebar that cannot scroll is not a macOS
                // sidebar.
                Expanded(
                  child: macos.SidebarItems(
                    items: [
                      for (final destination in destinations)
                        macos.SidebarItem(
                          leading: macos.MacosIcon(destination.icon),
                          label: Text(
                            destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // `label` is a widget the library wraps in its own
                            // text style, so only the disabled tint is set:
                            // the row keeps the library's size and weight for
                            // every other state.
                            style: TextStyle(color: destination.enabled ? null : theme.colors.textDisabled),
                          ),
                        ),
                    ],
                    // The pane has no "nothing selected": its constructor
                    // asserts `currentIndex >= 0`. An id that matches nothing
                    // therefore selects the first row — a degenerate case (the
                    // router always reports an id it is showing), handled by
                    // complying with the library rather than crashing in it.
                    currentIndex: _selectedIndex < 0 ? 0 : _selectedIndex,
                    onChanged: (index) {
                      final destination = destinations[index];
                      // Refused here: the row itself is always enabled because
                      // the library has no way to draw it otherwise.
                      if (destination.enabled) {
                        onSelected?.call(destination.id);
                      }
                    },
                    cursor: SystemMouseCursors.click,
                  ),
                ),
                if (trailing != null)
                  // Composed footer: `SidebarItems` ends with its last row, so
                  // the trailing entry is pinned below the list by this
                  // column, padded to the list's own 10-unit inset.
                  Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: trailing),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// fluent_2 ships no `NavigationView`; the rail composes the drawer the
  /// library does ship — inline and pinned open — around its own `FluentNav`,
  /// so the row metrics, the selection indicator and the accent stay the
  /// library's. The drawer keeps fluent's own width: the caller's rail width
  /// decides the rail-versus-strip *form*, not the pane's geometry.
  ///
  /// `trailing` has a slot here that the library models as the drawer's
  /// footer, so it is pinned there; the bottom strip has no such slot and
  /// drops it, which is what the contract documents for a strip.
  Widget _fluentShell(BuildContext context) {
    if (_standsAside) {
      return child;
    }
    if (!_wantsRail(placement, context)) {
      return _bottomStrip();
    }
    // Windows 11 Settings grammar: the pane stands beside the content while
    // there is room, and below the breakpoint the pane is gone entirely —
    // a hamburger strip takes its place and the nav comes back as an
    // overlay drawer. The buckets come from the shared [PureBreakpoints]
    // qualification (720/1024), the same source every dynamic layout reads.
    return PureAdaptiveLayout(
      child: child,
      mobile: (context, child) => _fluentNarrow(context, child!),
      tablet: (context, child) => _fluentWide(context, child!),
      desktop: (context, child) => _fluentWide(context, child!),
    );
  }

  /// The wide forms: the nav pane stands inline beside the page.
  Widget _fluentWide(BuildContext context, Widget child) {
    return Row(
      children: [
        f2.FluentNavDrawer(
          open: true,
          type: f2.FluentDrawerType.inline,
          separator: true,
          footer: [if (trailing case final Widget footer) footer],
          child: _fluentNavWithLeading(context),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// The narrow form: the pane is gone — a hamburger strip takes its place
  /// and the nav comes back as an overlay drawer over the full-width page.
  Widget _fluentNarrow(BuildContext context, Widget child) {
    return Stack(
      children: [
        Column(
          children: [
            _fluentTopStrip(context),
            Expanded(child: child),
          ],
        ),
        f2.FluentNavDrawer(
          open: _fluentDrawerOpen,
          onDismiss: () => setState(() => _fluentDrawerOpen = false),
          footer: [if (trailing case final Widget footer) footer],
          child: _fluentNavWithLeading(context),
        ),
      ],
    );
  }

  /// The pane's content: a leading column above the nav. `FluentNavDrawer`
  /// models a footer but no header, so the head is composed rather than
  /// promised to the library.
  Widget _fluentNavWithLeading(BuildContext context) {
    final head = leading;
    if (head == null) {
      return _fluentNav(context);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(child: _fluentNav(context)),
      ],
    );
  }

  /// The nav both fluent forms share: one [f2.FluentNav] whose items map the
  /// destinations one-for-one, a disabled destination refused before it ever
  /// reaches the nav.
  Widget _fluentNav(BuildContext context) {
    return f2.FluentNav(
      selectedValue: selectedId,
      onSelect: (value) {
        for (final destination in destinations) {
          // A disabled destination is refused here rather than handed
          // to the nav, which marks its row inert but answers selection
          // all the same.
          if (destination.id == value && destination.enabled) {
            onSelected?.call(destination.id);
          }
        }
      },
      children: [
        for (final destination in destinations)
          f2.FluentNavItem(
            value: destination.id,
            enabled: destination.enabled,
            icon: Icon(destination.icon),
            child: Text(destination.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }

  /// The narrow form's top strip: the hamburger that summons the overlay
  /// drawer, over the theme's own surface.
  Widget _fluentTopStrip(BuildContext context) {
    final colors = PureTheme.of(context).colors;
    return SizedBox(
      height: 40,
      child: Material(
        color: colors.bgContainer,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: f2.FluentHamburger(onPressed: () => setState(() => _fluentDrawerOpen = true), semanticLabel: '菜单'),
          ),
        ),
      ),
    );
  }

  /// forui: `FSidebar` is the library's own structural navigation column, and
  /// it is usable on its own — an `FSidebarItem` resolves its style through
  /// `FSidebarData` to the theme's `sidebarStyle` even with no `FSidebarGroup`
  /// around it, and the sidebar paints nothing but its own header/content/
  /// footer strip. It does *not* carry a body area — the router-owned page
  /// stays outside it — so the shell composes the row around it, exactly as
  /// Material composes its rail. The library's default column width is kept
  /// rather than the token's rail metric: the form rules are the contract's,
  /// and the column's own look is the language's.
  ///
  /// `FSidebarItem` models a `selected` state but never a disabled one, so a
  /// disabled destination is refused the way the Fluent pane has to refuse it:
  /// the item keeps its place in the column, inert, with its label still
  /// readable. [trailing] has a real slot — the sidebar's sticky footer; the
  /// bottom strip has none and drops it.
  Widget _foruiShell(BuildContext context) {
    if (_standsAside) {
      return child;
    }
    if (!_wantsRail(placement, context)) {
      return _bottomStrip();
    }
    return Row(
      children: [
        forui.FSidebar(
          // The sticky footer is the library's own name for this contract's
          // trailing slot.
          footer: trailing,
          children: [
            if (leading case final Widget head) head,
            for (final destination in destinations)
              forui.FSidebarItem(
                icon: Icon(destination.icon),
                label: Text(destination.label),
                selected: destination.id == selectedId,
                // A disabled destination — or a shell with no callback at all —
                // gets a null onPress, which is how the library spells "inert";
                // it has no dimmed disabled state of its own to map onto.
                onPress: destination.enabled && onSelected != null ? () => onSelected!(destination.id) : null,
              ),
          ],
        ),
        Expanded(child: child),
      ],
    );
  }
}
