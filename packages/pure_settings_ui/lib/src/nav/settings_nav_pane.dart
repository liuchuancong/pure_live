import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/list/settings_list.dart';
import 'package:pure_settings_ui/src/vendor/sections/settings_section.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_destination.dart';
import 'package:pure_settings_ui/src/vendor/split/split_scopes.dart';
import 'package:pure_settings_ui/src/vendor/tiles/settings_tile.dart';

/// One row of a [SettingsNavPane].
class SettingsNavItem {
  /// Builds the row.
  const new({required this.id, required this.label, this.icon});

  /// The identity [SettingsNavPane.onSelected] reports.
  final String id;

  /// The row's text.
  final String label;

  /// The row's leading glyph, dropped by narrow Android panes like in
  /// settings.
  final IconData? icon;
}

/// The settings list pane, detached: the same rows `SettingsSplitView`
/// draws down its left column — destination tiles under the split scope,
/// selected by id — as a standalone navigation column.
///
/// The app's home shell mounts it in place of its own sidebar so the two
/// columns are one visual system: each design language draws its real
/// settings pane (Windows' NavigationView rows, the macOS sidebar, the
/// grouped cards), and the selected row is marked exactly as settings
/// marks it. The `builder` of the internal destinations is never called:
/// selection is reported through [onSelected], not by pushing pages.
class SettingsNavPane extends StatelessWidget {
  /// Builds the column.
  const new({
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.shrinkWrap = false,
    super.key,
  });

  /// The rows.
  final List<SettingsNavItem> items;

  /// The row drawn selected; null draws none.
  final String? selectedId;

  /// A row was tapped.
  final ValueChanged<String> onSelected;

  /// Whether the list sizes itself to its content (inside a column that
  /// scrolls elsewhere).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return SettingsSplitListScope(
      isSplit: true,
      sidebar: true,
      selectedId: selectedId,
      onOpen: (destination, _) => onSelected(destination.id),
      child: SettingsList(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const ClampedScrollPhysics() : null,
        sections: [
          SettingsSection(
            tiles: [
              for (final item in items)
                SettingsTile.navigation(
                  key: ValueKey('settings-nav-${item.id}'),
                  leading: item.icon == null ? null : Icon(item.icon),
                  title: Text(item.label),
                  destination: SettingsDestination(
                    id: item.id,
                    title: Text(item.label),
                    builder: (context) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A scroll physics that never overscrolls a detached pane's own scroll.
class ClampedScrollPhysics extends ScrollPhysics {
  /// The detached-pane physics.
  const new({super.parent});

  @override
  ClampedScrollPhysics applyTo(ScrollPhysics? ancestor) => ClampedScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => false;
}
