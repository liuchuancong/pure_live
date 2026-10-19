import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:forui/forui.dart' as forui;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

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
      PureDesignLanguage.material || PureDesignLanguage.yaru => _materialBar(),
      PureDesignLanguage.cupertino => cupertino.CupertinoTabBar(
        items: [for (final item in items) cupertino.BottomNavigationBarItem(icon: Icon(item.icon), label: item.label)],
        currentIndex: index,
        onTap: select,
        // The active tint comes from the token primary; the bar surface keeps
        // the header colour so it reads as chrome over the page.
        activeColor: theme.colors.primary,
        backgroundColor: theme.colors.bgElevated,
      ),
      PureDesignLanguage.macos => _MacosBar(items: items, index: index, select: select, theme: theme),
      // Windows 11's own bottom bar (the NavigationView's footer items, as the
      // Store and Media Player draw them): an even row of two-line cells on
      // the chrome surface under a hairline, the selected cell in the accent
      // under a 6x3 pill at the row's top edge. `FluentTabList` is a tab
      // strip — its underline grammar and centred width say "settings page",
      // not "app navigation" — so the bar composes from the library's own
      // typography and the token surfaces instead.
      PureDesignLanguage.fluent => _FluentBar(items: items, index: index, select: select, theme: theme),
      // The library's own bottom navigation bar, in its floating-pill form.
      PureDesignLanguage.neumorphic =>
        items.length < 2
            ? _materialBar()
            : IgnorePointer(
                ignoring: select == null,
                child: neu.NeuBottomNav(
                  currentIndex: index.clamp(0, items.length - 1),
                  onTap: (next) => select?.call(next),
                  items: [for (final item in items) neu.NeuBottomNavItem(icon: Icon(item.icon), label: item.label)],
                ),
              ),
      // glass_morphism_plus ships no navigation bar. Use Flutter's official
      // Material NavigationBar rather than a hand-composed glass strip.
      PureDesignLanguage.glass => _materialBar(),
      // fluttersdk_wind ships no navigation bar; use the official Material bar.
      PureDesignLanguage.wind => _materialBar(),
      PureDesignLanguage.forui => forui.FBottomNavigationBar(
        index: index,
        // [enabled] is mapped by handing the library a null `onChange`, its own
        // inert state: the destinations keep their labels and grey out instead
        // of staying live with a swallowed callback.
        onChange: select,
        children: [
          for (final item in items)
            forui.FBottomNavigationBarItem(
              icon: Icon(item.icon),
              // The library sizes and weights its own nav labels; only the family the
              // viewer picked has to be added, or it never reaches them.
              label: Text(item.label, style: TextStyle(fontFamily: PureTheme.of(context).text.label.fontFamily)),
            ),
        ],
      ),
    };
    // The switch above names every design language, so no adapter fallback
    // remains.
  }

  /// Flutter's official Material navigation bar, shared by Material, Yaru and
  /// the surface libraries that ship no bar.
  Widget _materialBar() {
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: enabled ? onChanged : null,
      destinations: [for (final item in items) NavigationDestination(icon: Icon(item.icon), label: item.label)],
    );
  }
}

/// Windows 11's footer navigation: even two-line cells on the chrome surface,
/// the selected one in the accent with the 6x3 pill at the bar's top edge.
final class _FluentBar extends StatelessWidget {
  const new({required this.items, required this.index, required this.select, required this.theme});

  final List<PureNavBarItem> items;
  final int index;
  final ValueChanged<int>? select;
  final PureTheme theme;

  @override
  Widget build(BuildContext context) {
    final accent = theme.colors.primary;
    final inert = select == null;
    return ColoredBox(
      color: theme.colors.bgElevated,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colors.borderSecondary)),
        ),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _FluentFooterCell(
                      item: items[i],
                      selected: i == index && !inert,
                      onTap: inert ? null : () => select!(i),
                      accent: accent,
                      inactive: theme.colors.textSecondary,
                      labelStyle: f2.FluentTheme.of(context).typography.caption1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _FluentFooterCell extends StatefulWidget {
  const new({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.inactive,
    required this.labelStyle,
  });

  final PureNavBarItem item;
  final bool selected;
  final VoidCallback? onTap;
  final Color accent;
  final Color inactive;
  final TextStyle labelStyle;

  @override
  State<_FluentFooterCell> createState() => _FluentFooterCellState();
}

class _FluentFooterCellState extends State<_FluentFooterCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.selected ? widget.accent : widget.inactive;
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          selected: widget.selected,
          button: true,
          label: widget.item.label,
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: [
              if (_hovered && widget.onTap != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: widget.selected ? widget.accent.withValues(alpha: 0.06) : const Color(0x0A000000),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The pill sits at the bar's top edge over the cell, as the
                  // NavigationView footer draws it.
                  SizedBox(
                    height: 6,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: widget.selected ? 6 : 0,
                        height: 3,
                        decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(1.5)),
                      ),
                    ),
                  ),
                  Icon(widget.item.icon, size: 16, color: tint),
                  Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.labelStyle.copyWith(color: tint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// macOS's answer to a bottom bar: the library has none, so the strip keeps
/// its own even-cell grammar — icon over label, the selected cell in the
/// accent on a rounded selection chip, like the sidebar rows it shares.
final class _MacosBar extends StatelessWidget {
  const new({required this.items, required this.index, required this.select, required this.theme});

  final List<PureNavBarItem> items;
  final int index;
  final ValueChanged<int>? select;
  final PureTheme theme;

  @override
  Widget build(BuildContext context) {
    final inert = select == null;
    return ColoredBox(
      color: theme.colors.bgElevated,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colors.borderSecondary)),
        ),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _MacosDestinationCell(
                      label: items[i].label,
                      icon: items[i].icon,
                      selected: i == index && !inert,
                      onTap: inert ? null : () => select!(i),
                      accent: theme.colors.primary,
                      inactive: theme.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One macOS destination cell: the library's icon-over-label grammar, the pair
/// in the accent while selected, on a rounded selection chip — the same answer
/// the library's sidebar rows give.
final class _MacosDestinationCell extends StatefulWidget {
  const new({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.inactive,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color accent;
  final Color inactive;

  @override
  State<_MacosDestinationCell> createState() => _MacosDestinationCellState();
}

class _MacosDestinationCellState extends State<_MacosDestinationCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.selected ? widget.accent : widget.inactive;
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          selected: widget.selected,
          button: true,
          label: widget.label,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? widget.accent.withValues(alpha: 0.14)
                      : _hovered && widget.onTap != null
                      ? widget.inactive.withValues(alpha: 0.12)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(widget.icon, size: 16, color: tint),
              ),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The dense label size is this tile's own answer; the family is
                // the theme's, and without it the picked font never appears here.
                style: TextStyle(fontSize: 10.5, color: tint, fontFamily: PureTheme.of(context).text.label.fontFamily),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
