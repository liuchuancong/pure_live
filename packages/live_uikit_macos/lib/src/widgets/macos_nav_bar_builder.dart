import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS destination strip from a [LanguageNavBarSpec] (§9 NavBar).
///
/// Composed, because macOS has no bottom bar: the library's destinations are
/// `Sidebar` / `SidebarItems`, which belong to a window frame and build a
/// scrollable `ListView` sized for a column as tall as the window — not a strip
/// under a page, and not this control but the shell surface. What the library does
/// have is its own navigational cell, `MacosTab`, described in its own docs as the
/// item that "moves the user between the views" of a tab view, and that is what a
/// horizontal row of destinations is.
///
/// So each destination is the library's cell with the library's `MacosIcon` in
/// front of it, one cell checked — the checked cell paints its own selection chip,
/// so the accent decision stays with the library. Every destination shares the
/// row's width the way a macOS toolbar group does, and a disabled bar keeps its
/// labels and stops reporting, which is the inert state the other adapters use.
abstract final class MacosNavBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageNavBarSpec spec) {
    final select = spec.enabled ? spec.onChanged : null;
    return Row(
      children: [
        for (var index = 0; index < spec.items.length; index++)
          Expanded(
            child: _DestinationCell(
              label: spec.items[index].label,
              icon: spec.items[index].icon,
              selected: index == spec.index,
              onTap: select == null ? null : () => select(index),
            ),
          ),
      ],
    );
  }
}

class _DestinationCell extends StatelessWidget {
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
              Flexible(child: macos.MacosTab(label: label, active: selected)),
            ],
          ),
        ),
      ),
    );
  }
}
