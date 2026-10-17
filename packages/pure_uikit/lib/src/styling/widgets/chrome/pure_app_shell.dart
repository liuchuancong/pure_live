import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/scales/sizing.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_nav_bar.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_shell_types.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_box.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The public application shell: one widget, every design language.
///
/// It sits between the host and the page — the routing layer's `ShellRoute` in
/// an app — and takes only neutral data: the destinations, the selected id,
/// the callback and the body. There is no adapter and no spec in between:
/// [build] switches on `UiConfig.language` and draws the navigation with the
/// library's own structural widget — Material's `NavigationRail`, macOS's
/// `SidebarItems` and forui's `FSidebar` — or, where the library ships no
/// navigation column (cupertino, fluent, glass, neumorphic, wind), composes one
/// out of that library's own surfaces. Switching `UiConfig.language` re-skins
/// the shell.
class PureAppShell extends StatelessWidget {
  /// A shell around [child].
  const new({
    required this.child,
    this.destinations = const <PureShellDestination>[],
    this.selectedId,
    this.onSelected,
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

  /// Content pinned at the end of a navigation column; the bottom-strip form
  /// has no such slot and drops it rather than inventing a place for it.
  final Widget? trailing;

  /// Where the caller wants the navigation.
  final PureShellPlacement placement;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return switch (theme.config.language) {
      // Yaru draws chrome with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different shell.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _materialShell(context),
      PureDesignLanguage.cupertino => _cupertinoShell(context),
      PureDesignLanguage.macos => _macosShell(context, theme),
      PureDesignLanguage.fluent => _fluentShell(context),
      PureDesignLanguage.neumorphic => _neumorphicShell(context, theme),
      PureDesignLanguage.glass => _glassShell(context, theme),
      PureDesignLanguage.wind => _windShell(context),
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
  /// the two forms cannot drift apart. `trailing` has no slot in a strip and
  /// is dropped, as the contract documents.
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
    return Row(
      children: [
        f2.FluentNavDrawer(
          open: true,
          type: f2.FluentDrawerType.inline,
          separator: true,
          footer: [if (trailing case final Widget footer) footer],
          child: f2.FluentNav(
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
          ),
        ),
        Expanded(child: child),
      ],
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

  /// Glass composes the column out of the same frosted pieces the nav bar is
  /// made of — the library ships no navigation structure at all. One
  /// full-height [glass.GlassContainer] is the track, and a second, brighter
  /// sheet behind the selected destination is the idiom glassmorphism marks a
  /// selection with everywhere else in this toolkit. Every visible value comes
  /// from [glass.GlassTheme]; the layout geometry takes [PureSizing]'s numbers
  /// when the environment supplies none.
  ///
  /// Interaction goes through the core's [PureBox], not a tappable
  /// [glass.GlassContainer]: the library's `onTap` installs its own transparent
  /// `Material` wrapping an `InkWell` with a focus node of its own, and that
  /// fights the dispatch system's focus order — so the cell stays a [PureBox]
  /// and the frosted sheets are purely paint. [trailing] is pinned to the foot
  /// of the composed column; the bottom form has no such slot and drops it.
  Widget _glassShell(BuildContext context, PureTheme theme) {
    if (_standsAside) {
      return child;
    }
    if (!_wantsRail(placement, context)) {
      return _bottomStrip();
    }
    final glassTheme = glass.GlassTheme.of(context);
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    // The track and its cells share one radius, inset by the library's stroke
    // so the brighter sheet sits inside the frosted track rather than on its
    // border.
    final radius = BorderRadius.circular(glassTheme.borderRadius - theme.token.motion.lineWidth);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: geometry?.railWidth ?? PureSizing.railWidth,
          // One frosted sheet for the whole column: the library's own surface,
          // blurring whatever the page paints behind the rail.
          child: glass.GlassContainer(
            padding: EdgeInsets.all(theme.token.motion.lineWidth * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final destination in destinations)
                  _GlassRailCell(
                    destination: destination,
                    selected: destination.id == selectedId,
                    iconSize: geometry?.iconSize ?? 18,
                    radius: radius,
                    onSelected: onSelected,
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

  /// Neumorphic composes the column from the library's own faces, turned
  /// vertical — the library's one navigation widget, `NeuBottomNav`, is a
  /// horizontal floating pill that asserts at least two items, takes a
  /// non-null callback and vibrates on every change. One full-height
  /// `NeuContainer` on its default flat face at the theme's depth is the track,
  /// and the chosen cell sinks into `NeuShape.pressed` with its glyph and label
  /// in the theme's accent, the others left flat at zero depth — the same
  /// pressed reading the docked nav-bar slab gives, drawn as a column beside
  /// the page. A disabled destination keeps its cell, takes the token's
  /// disabled text role and loses its callback.
  Widget _neumorphicShell(BuildContext context, PureTheme theme) {
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
          child: _NeumorphicRail(
            destinations: destinations,
            selectedId: selectedId,
            iconSize: geometry?.iconSize ?? 18,
            trailing: trailing,
            onSelected: (id) => onSelected?.call(id),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// Wind composes the rail from the styling library's own parts — it ships no
  /// navigation structure of any kind. A `WDiv` surface on its
  /// `bg-white dark:bg-gray-900` pair, closed by the Tailwind side hairline,
  /// holds `WAnchor` cells over a `WDiv` column carrying `WIcon` over `WText`.
  /// The accent reaches this subtree flat through the host's `WindTheme`, so
  /// `selected:text-primary-500` is the token accent. The states are passed to
  /// the styled `WDiv` as well as to the anchor: a `hover:` class makes `WDiv`
  /// wrap itself in a gestureless anchor and read its state from the nearest
  /// provider. A disabled destination is the fork's inert state (`isDisabled`),
  /// not a local refusal, and the glyph step is a class token — interpolating
  /// `text-[..]` per device is the runtime-into-cache pattern the library warns
  /// against.
  Widget _windShell(BuildContext context) {
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
          child: wind.WDiv(
            className: 'flex flex-col w-full h-full bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700',
            children: [
              for (final destination in destinations)
                _windShellCell(destination, selected: destination.id == selectedId, onSelected: onSelected),
              if (trailing case final Widget footer) ...[
                const Expanded(child: SizedBox.shrink()),
                Align(alignment: Alignment.bottomCenter, child: footer),
              ],
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// One Wind destination as the library's own interactive column cell.
  static Widget _windShellCell(PureShellDestination destination, {required bool selected, required ValueChanged<String>? onSelected}) {
    final enabled = destination.enabled;
    final states = selected ? _selectedStates : null;
    return Semantics(
      selected: selected,
      child: wind.WAnchor(
        // A disabled destination is the fork's inert state, not a local
        // refusal: `isDisabled` paints `disabled:opacity-50` and ignores the
        // gesture, and the tap closure is not built for it either, so the look
        // and its own label builder cannot disagree.
        isDisabled: !enabled,
        onTap: enabled && onSelected != null ? () => onSelected(destination.id) : null,
        states: states,
        semanticLabel: destination.label,
        child: wind.WDiv(
          className: _windCellClasses,
          states: states,
          child: wind.WDiv(
            className: 'flex flex-col items-center gap-1 w-full',
            children: [
              wind.WIcon(destination.icon, className: 'text-lg'),
              wind.WText(destination.label, className: 'text-xs truncate w-full text-center'),
            ],
          ),
        ),
      ),
    );
  }

  static const Set<String> _selectedStates = <String>{'selected'};

  static const String _windCellClasses =
      'flex flex-col items-center justify-center w-full px-2 py-3'
      ' text-gray-500 dark:text-gray-400 transition-colors'
      ' hover:bg-gray-50 dark:hover:bg-gray-800'
      ' selected:text-primary-500 selected:bg-gray-100 dark:selected:bg-gray-800'
      ' disabled:opacity-50';
}

/// One glass rail destination: its glyph over its label, on a brighter frosted
/// sheet when the caller has selected it. A hover or press tints the cell
/// through the core's [PureBox]; a disabled one keeps its row, dims, and takes
/// no tap, because a tappable [glass.GlassContainer] would bring its own ink
/// and focus node into the tree.
final class _GlassRailCell extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.iconSize,
    required this.radius,
    this.onSelected,
  });

  final PureShellDestination destination;
  final bool selected;
  final double iconSize;
  final BorderRadius radius;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final sizes = theme.token.scale.sizes;
    final enabled = destination.enabled;
    final tint = !enabled
        ? theme.colors.textDisabled
        : selected
        ? theme.colors.primary
        : theme.colors.textSecondary;

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(destination.icon, size: iconSize, color: tint),
        SizedBox(height: sizes.xxs),
        Text(
          destination.label,
          style: theme.text.caption.copyWith(color: tint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );

    return Semantics(
      selected: selected,
      child: PureBox(
        style: (state) => Style(
          borderRadius: radius,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: sizes.xs),
          background: enabled && (state == InteractionState.hovered || state == InteractionState.pressed)
              ? glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0))
              : null,
          opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
        ),
        enabled: enabled,
        onTap: enabled ? () => onSelected?.call(destination.id) : null,
        child: selected
            ? glass.GlassContainer(
                customBorderRadius: radius,
                color: glassTheme.color,
                opacity: (glassTheme.opacity * 2.6).clamp(0.0, 1.0),
                padding: EdgeInsets.symmetric(horizontal: sizes.sm, vertical: sizes.xs),
                child: label,
              )
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: sizes.sm),
                child: label,
              ),
      ),
    );
  }
}

/// The neumorphic composed column: the theme's flat plane, and one sunk cell
/// per destination. Radius is read off the theme and inset for the cells so the
/// dishes nest inside the plane instead of cutting it.
final class _NeumorphicRail extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selectedId,
    required this.iconSize,
    required this.onSelected,
    this.trailing,
  });

  final List<PureShellDestination> destinations;
  final String? selectedId;
  final double iconSize;
  final ValueChanged<String> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final inset = theme.token.scale.sizes.xs;
    final barRadius = surface.borderRadius.resolve(Directionality.of(context));
    final cellRadius = BorderRadius.circular(barRadius.topLeft.x <= inset ? 0.0 : barRadius.topLeft.x - inset);

    return neu.NeuContainer(
      borderRadius: barRadius,
      baseColor: surface.baseColor,
      depth: surface.depth,
      distance: surface.distance,
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final destination in destinations) ...[
            _NeumorphicRailCell(
              destination: destination,
              selected: destination.id == selectedId,
              enabled: destination.enabled,
              iconSize: iconSize,
              onTap: destination.enabled ? () => onSelected(destination.id) : null,
              radius: cellRadius,
              surface: surface,
              theme: theme,
            ),
            SizedBox(height: inset),
          ],
          if (trailing case final Widget footer) ...[
            const Spacer(),
            Align(alignment: Alignment.bottomCenter, child: footer),
          ],
        ],
      ),
    );
  }
}

/// One neumorphic rail destination: the chosen one sunk into
/// [neu.NeuShape.pressed], the others left flat at zero depth.
final class _NeumorphicRailCell extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.enabled,
    required this.iconSize,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final PureShellDestination destination;
  final bool selected;
  final bool enabled;
  final double iconSize;
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

    return Semantics(
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: neu.NeuContainer(
          shape: selected ? neu.NeuShape.pressed : neu.NeuShape.flat,
          borderRadius: radius,
          baseColor: surface.baseColor,
          depth: selected ? surface.depth : 0.0,
          distance: selected ? surface.distance : 0.0,
          padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.xs, vertical: theme.token.scale.sizes.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, color: tint, size: iconSize),
              SizedBox(height: theme.token.scale.sizes.xxs),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.text.caption.copyWith(
                  color: tint,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
