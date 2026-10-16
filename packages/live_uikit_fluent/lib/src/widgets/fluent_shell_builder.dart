import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Fluent application shell from a [LanguageShellSpec] (§ surfaces).
///
/// `NavigationView` is the library's own structural widget: a pane of
/// `PaneItem`s down the left, the selection an index it paints with the sticky
/// indicator, and the content in the open area. The spec's destinations map onto
/// the pane one-for-one, and because the app's router — not the pane — decides
/// what the body shows, the body comes from the library's `paneBodyBuilder`
/// rather than from a per-item `body`, which is the shape the library documents
/// for routed apps.
///
/// Two fields have no counterpart and are handled rather than dropped:
/// [LanguageShellSpec.placement] (the pane is vertical, so a `bottom` request
/// takes `PaneDisplayMode.top` — Windows' horizontal navigation strip — and an
/// `adaptive` one takes the library's own responsive `auto`) and
/// [LanguageShellSpec.trailing] (the pane has no free-form footer widget slot,
/// only further pane items, so a shell asked for one drops the trailing content
/// and the app moves that entry into the page's own actions).
abstract final class FluentShellBuilder {
  /// Builds the shell for [spec].
  static Widget build(BuildContext context, LanguageShellSpec spec) {
    final selected = spec.destinations.indexWhere((destination) => destination.id == spec.selectedId);
    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: selected < 0 ? null : selected,
        displayMode: switch (spec.placement) {
          LiveShellPlacement.bottom => fluent.PaneDisplayMode.top,
          LiveShellPlacement.rail => fluent.PaneDisplayMode.compact,
          LiveShellPlacement.adaptive || LiveShellPlacement.none => fluent.PaneDisplayMode.auto,
        },
        onChanged: (index) {
          final destination = spec.destinations[index];
          // A disabled destination is refused here rather than handed to the
          // pane, which has no per-item disabled state to draw.
          if (destination.enabled) {
            spec.onSelected?.call(destination.id);
          }
        },
        items: [
          for (final destination in spec.destinations)
            fluent.PaneItem(
              icon: Icon(destination.icon),
              title: Text(destination.label),
              body: const SizedBox.shrink(),
            ),
        ],
      ),
      // The router owns the body; the pane owns the choice. Giving each item a
      // body of its own would put a second, competing copy of the page tree
      // inside the shell.
      paneBodyBuilder: (context, item) => spec.child,
    );
  }
}
