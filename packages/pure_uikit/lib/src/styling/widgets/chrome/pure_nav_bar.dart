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
import 'package:pure_uikit/src/styling/widgets/layout/pure_box.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// One destination of a bottom navigation bar: what it is called and the glyph
/// that says so. A label is required — an icon-only bar asks a user to memorise
/// five glyphs, which is why the platform bars carry text by default.
@immutable
final class PureNavBarItem {
  /// A destination labelled [label] with [icon].
  const new({required this.label, required this.icon});

  /// The destination's name.
  final String label;

  /// The destination's glyph.
  final IconData icon;

  @override
  bool operator ==(Object other) => other is PureNavBarItem && other.label == label && other.icon == icon;

  @override
  int get hashCode => Object.hash(label, icon);
}

/// The public bottom navigation bar: one widget, every design language.
///
/// A shell passes its destinations here instead of a platform bar, so the
/// bottom of the screen re-skins with the rest of it. There is no adapter and
/// no spec in between: [build] switches on `UiConfig.language` and constructs
/// the library's real bar directly — Material's `NavigationBar`, Cupertino's
/// `CupertinoTabBar`, macOS's `MacosTab` cells (the library has no bottom bar;
/// its own tab cell is the strip it does have), fluent_2's `FluentTabList` and
/// forui's `FBottomNavigationBar`. The languages whose library ships no bar
/// (glass, neumorphic, wind) compose one out of that library's own surfaces,
/// as their package builders did. Switching `UiConfig.language` re-skins every
/// bar.
class PureNavBar extends StatelessWidget {
  /// A bar over [items] with [index] selected.
  const new({required this.items, required this.index, this.onChanged, this.enabled = true, super.key});

  /// The destinations, in order.
  final List<PureNavBarItem> items;

  /// The selected destination.
  final int index;

  /// Called with a destination's index; null renders the bar inert.
  final ValueChanged<int>? onChanged;

  /// Whether the bar responds to input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final select = enabled ? onChanged : null;
    return switch (theme.config.language) {
      // Yaru draws chrome with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different bar.
      PureDesignLanguage.material || PureDesignLanguage.yaru => NavigationBar(
        selectedIndex: index,
        // [enabled] is mapped by disabling the bar — the library's own inert
        // state — rather than dropping the callback.
        onDestinationSelected: select,
        destinations: [for (final item in items) NavigationDestination(icon: Icon(item.icon), label: item.label)],
      ),
      PureDesignLanguage.cupertino => cupertino.CupertinoTabBar(
        items: [for (final item in items) cupertino.BottomNavigationBarItem(icon: Icon(item.icon), label: item.label)],
        currentIndex: index,
        onTap: select,
        // The active tint comes from the token primary; the bar surface keeps
        // the header colour so it reads as chrome over the page.
        activeColor: theme.colors.primary,
        backgroundColor: theme.colors.bgElevated,
      ),
      PureDesignLanguage.macos => Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _MacosDestinationCell(
                label: items[i].label,
                icon: items[i].icon,
                selected: i == index,
                onTap: select == null ? null : () => select(i),
              ),
            ),
        ],
      ),
      PureDesignLanguage.fluent => Align(
        alignment: AlignmentDirectional.center,
        child: f2.FluentTabList<int>(
          selectedValue: index,
          // Null disables every tab — the library's inert state for a list.
          onSelect: select,
          tabs: [
            for (var i = 0; i < items.length; i++)
              f2.FluentTab(
                value: i,
                semanticLabel: items[i].label,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[i].icon),
                    Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
      ),
      PureDesignLanguage.neumorphic => _neumorphicBar(context, theme),
      PureDesignLanguage.glass => _glassBar(context, theme),
      PureDesignLanguage.wind => _windBar(context),
      PureDesignLanguage.forui => forui.FBottomNavigationBar(
        index: index,
        // [enabled] is mapped by handing the library a null `onChange`, its own
        // inert state: the destinations keep their labels and grey out instead
        // of staying live with a swallowed callback.
        onChange: select,
        children: [
          for (final item in items) forui.FBottomNavigationBarItem(icon: Icon(item.icon), label: Text(item.label)),
        ],
      ),
    };
    // The switch above names every design language, so no adapter fallback
    // remains.
  }

  /// Neumorphic composes the bar from the library's own faces — the way the
  /// language's own package builder did — because `NeuBottomNav` asserts at
  /// least two items, takes a non-null callback, hard-wraps itself in a
  /// `SafeArea` plus a floating-pill margin and vibrates on every change. The
  /// active destination is a **dish**: a full-width `NeuContainer` raised at
  /// the theme's depth holds one equal-share cell per destination, and the
  /// chosen cell sinks into `NeuShape.pressed` with its glyph and label in the
  /// theme's accent — that widget's selected-item pair. [enabled] is the
  /// library's inert state: the cells keep their glyphs and lose their
  /// callbacks.
  Widget _neumorphicBar(BuildContext context, PureTheme theme) {
    final surface = neu.NeuTheme.of(context);
    final select = enabled ? onChanged : null;
    final inset = theme.token.scale.sizes.xs;
    final barRadius = surface.borderRadius.resolve(Directionality.of(context));
    final cellRadius = BorderRadius.circular(barRadius.topLeft.x <= inset ? 0.0 : barRadius.topLeft.x - inset);

    return SafeArea(
      top: false,
      child: neu.NeuContainer(
        borderRadius: barRadius,
        baseColor: surface.baseColor,
        depth: surface.depth,
        distance: surface.distance,
        padding: EdgeInsets.symmetric(horizontal: inset, vertical: inset),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NeumorphicCell(
                  item: items[i],
                  selected: i == index,
                  enabled: enabled,
                  onTap: select == null ? null : () => select(i),
                  radius: cellRadius,
                  surface: surface,
                  theme: theme,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Glass composes the strip from the library's own frosted surfaces — the
  /// library ships no bar, so a floating [glass.GlassContainer] sheet holds the
  /// destinations and the active one is a second, brighter sheet inside it, the
  /// idiom glassmorphism marks a selection with everywhere else in this
  /// toolkit. Height and glyph size come from the layout geometry, or from
  /// [PureSizing] when the environment supplies none.
  Widget _glassBar(BuildContext context, PureTheme theme) {
    final glassTheme = glass.GlassTheme.of(context);
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final height = geometry?.navBarHeight ?? PureSizing.navBarHeight;
    final iconSize = geometry?.iconSize ?? 18;
    final select = enabled ? onChanged : null;
    final radius = BorderRadius.circular(glassTheme.borderRadius - theme.token.motion.lineWidth);

    return glass.GlassContainer(
      padding: EdgeInsets.all(theme.token.motion.lineWidth * 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: PureBox(
                  style: (state) => Style(
                    borderRadius: radius,
                    background: switch (state) {
                      InteractionState.hovered || InteractionState.pressed || InteractionState.focused =>
                        glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0)),
                      _ => null,
                    },
                    opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
                  ),
                  onTap: select == null ? null : () => select(i),
                  enabled: enabled,
                  child: _GlassDestination(
                    item: items[i],
                    selected: i == index,
                    radius: radius,
                    iconSize: iconSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Wind composes the strip from the styling library's own parts — it ships no
  /// bar of any kind. A `WDiv` on its elevated surface pair, closed by the
  /// Tailwind top hairline, holds one `WAnchor` cell per destination; the chosen
  /// one takes the fork's `selected:` accent state, and a disabled bar is the
  /// fork's inert state (`isDisabled` on every anchor, so `disabled:opacity-50`
  /// paints and nothing reports). The bar's height comes from the layout
  /// environment; the glyph step stays a class token, because interpolating
  /// `text-[..]` per device is the runtime-into-cache pattern the library warns
  /// against.
  Widget _windBar(BuildContext context) {
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final height = geometry?.navBarHeight ?? 56;
    final select = enabled ? onChanged : null;

    return wind.WDiv(
      className: 'flex flex-col w-full bg-white dark:bg-gray-900 border-t border-gray-200 dark:border-gray-700',
      children: [
        SizedBox(
          height: height,
          child: wind.WDiv(
            className: 'flex flex-row items-center w-full h-full',
            children: [
              for (var i = 0; i < items.length; i++) Expanded(child: _windCell(items[i], i, i == index, select)),
            ],
          ),
        ),
      ],
    );
  }

  /// One Wind destination as the library's own interactive cell. The states are
  /// passed to the styled `WDiv` as well as to the anchor: a `hover:` class
  /// makes `WDiv` wrap itself in a gestureless anchor, and it reads its state
  /// from the nearest provider.
  static Widget _windCell(PureNavBarItem item, int index, bool selected, ValueChanged<int>? select) {
    final states = selected ? _selectedStates : null;
    return wind.WAnchor(
      onTap: select == null ? null : () => select(index),
      isDisabled: select == null,
      states: states,
      child: wind.WDiv(
        className: _windCellClasses,
        states: states,
        child: wind.WDiv(
          className: 'flex flex-col items-center gap-1 w-full',
          children: [
            wind.WIcon(item.icon, className: 'text-lg'),
            wind.WText(item.label, className: 'text-xs truncate w-full text-center'),
          ],
        ),
      ),
    );
  }

  static const Set<String> _selectedStates = <String>{'selected'};

  static const String _windCellClasses =
      'flex flex-col items-center justify-center w-full h-full text-gray-500 dark:text-gray-400'
      ' transition-colors hover:bg-gray-50 dark:hover:bg-gray-800'
      ' selected:text-primary-500 disabled:opacity-50';
}

/// One macOS destination cell: the library's own navigational cell,
/// `MacosTab` — described in its own docs as the item that "moves the user
/// between the views" — with the library's `MacosIcon` in front of it. The
/// checked cell paints its own selection chip, so the accent decision stays
/// with the library, and a disabled bar keeps its labels and stops reporting.
final class _MacosDestinationCell extends StatelessWidget {
  const new({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
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
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sized to the label it leads, not to the library default.
              macos.MacosIcon(icon, size: 13),
              const SizedBox(width: 4),
              Flexible(
                child: macos.MacosTab(label: label, active: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One glass destination: its glyph over its label, on a frosted sheet when it
/// is the one the caller has selected.
final class _GlassDestination extends StatelessWidget {
  const new({required this.item, required this.selected, required this.radius, required this.iconSize});

  final PureNavBarItem item;
  final bool selected;
  final BorderRadius radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final sizes = theme.token.scale.sizes;
    final tint = selected ? theme.colors.primary : theme.colors.textSecondary;

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: iconSize, color: tint),
        SizedBox(height: sizes.xxs),
        Text(
          item.label,
          style: theme.text.caption.copyWith(color: tint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );

    return Semantics(
      selected: selected,
      child: selected
          ? glass.GlassContainer(
              customBorderRadius: radius,
              color: glassTheme.color,
              opacity: (glassTheme.opacity * 2.6).clamp(0.0, 1.0),
              padding: EdgeInsets.symmetric(horizontal: sizes.xs),
              child: label,
            )
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: sizes.xs, vertical: sizes.xxs),
              child: label,
            ),
    );
  }
}

/// One neumorphic destination cell: its glyph over its label, sunk into the bar
/// when it is the one the caller has selected. A disabled bar keeps its labels
/// and stops reporting — the `NeuContainer` has no disabled state to ask for.
final class _NeumorphicCell extends StatelessWidget {
  const new({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final PureNavBarItem item;
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: neu.NeuContainer(
        shape: selected ? neu.NeuShape.pressed : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: selected ? surface.depth : 0.0,
        distance: selected ? surface.distance : 0.0,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: tint, size: theme.text.body.fontSize),
            SizedBox(height: theme.token.scale.sizes.xs / 2.0),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.text.caption.copyWith(color: tint, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
