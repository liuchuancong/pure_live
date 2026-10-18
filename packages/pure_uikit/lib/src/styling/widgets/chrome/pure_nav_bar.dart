import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
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
          for (final item in items) forui.FBottomNavigationBarItem(icon: Icon(item.icon), label: Text(item.label)),
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
