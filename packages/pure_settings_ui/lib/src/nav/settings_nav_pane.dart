import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/list/settings_list.dart';
import 'package:pure_settings_ui/src/vendor/sections/settings_section.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_compact_pane.dart' show FluentPaneModeScope;
import 'package:pure_settings_ui/src/vendor/split/fluent_split.dart';
import 'package:pure_settings_ui/src/vendor/split/macos_split.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_destination.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_keyboard.dart';
import 'package:pure_settings_ui/src/vendor/split/split_scopes.dart';
import 'package:pure_settings_ui/src/vendor/tiles/settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';

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
///
/// The pane also mounts what the split view wraps its list pane in, the
/// design language's pane scaffolding: without it the rows would draw the
/// same, but the pane's own behaviours live in those wrappers, and a
/// detached pane used to switch with the selection marker jumping where
/// settings slid it (the fluent pill has no previous item to travel from).
class SettingsNavPane extends StatelessWidget {
  /// Builds the column.
  const new({
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.shrinkWrap = false,
    this.compact = false,
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

  /// Whether the pane draws the compact rail — the icon-only cells the
  /// narrow settings window shows, larger glyph, label in the tooltip —
  /// rather than the labelled rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SettingsSplitListScope(
      isSplit: true,
      sidebar: true,
      selectedId: selectedId,
      onOpen: (destination, _) => onSelected(destination.id),
      child: _paneChrome(
        context,
        SettingsList(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const ClampedScrollPhysics() : null,
          // The compact rail owns its width: the list's own side padding
          // (16/24 on Windows) is for the wide pane and would shove a 72
          // rail's cells off centre.
          contentPadding: compact ? const EdgeInsets.symmetric(vertical: 4) : null,
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
      ),
    );
  }

  /// The scaffolding the split view wraps its list pane in, for the design
  /// language this pane resolves to. Resolved the way [SettingsList] below
  /// resolves its own style, so the wrapper and the rows never disagree.
  ///
  /// The fluent wrapper is what makes the selection pill slide: the pane
  /// shares one indicator between its rows, so the newly selected item finds
  /// the old pill's rectangle and travels from there — the settings
  /// behaviour a detached pane must reproduce, not just the row look. The
  /// macOS and GNOME wrappers bring the sidebar's keyboard (the macOS one
  /// under the window-activity dim, selection following the focus as in
  /// System Settings). The other families draw no pane to copy.
  Widget _paneChrome(BuildContext context, Widget list) {
    final platform = const SettingsStyleConfig()
        .inheritFrom(SettingsStyleScope.inheritedConfigOf(context))
        .resolvePlatform(context);
    // The compact flag goes down the fluent scope, whose items answer by
    // drawing icon-only; the other families draw their labelled rows.
    final body = compact
        ? FluentPaneModeScope(compact: true, child: list)
        : list;
    return switch (settingsStyleFamily(platform)) {
      SettingsStyleFamily.fluent => FluentNavigationPane(child: body),
      SettingsStyleFamily.macos => MacosWindowActivity(
        child: SettingsSidebarKeyboard(selectionFollowsFocus: true, child: list),
      ),
      SettingsStyleFamily.adwaita => SettingsSidebarKeyboard(child: list),
      SettingsStyleFamily.cupertino ||
      SettingsStyleFamily.material ||
      SettingsStyleFamily.web ||
      SettingsStyleFamily.pure => list,
    };
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
