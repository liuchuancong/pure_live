// Module: lib/src/domain/home_tab.dart
// Purpose: The home tab model: ordered tabs, visibility, and the persisted
// ordering rules.
// Author: liuchuancong
// Created: 2026-10-10

/// A tab on the home surface.
final class HomeTab {
  const HomeTab({required this.id, required this.label, this.visible = true});

  /// Stable id persisted in the tab order, for example 'live', 'vod', 'music'.
  final String id;
  final String label;
  final bool visible;

  HomeTab withVisible(bool value) => HomeTab(id: id, label: label, visible: value);
}

/// Orders and filters the home tabs from the full set plus the user's saved
/// order. Unknown saved ids are ignored (the tab was removed since), tabs the
/// user never ordered keep their default position after the ordered ones, and
/// hidden tabs stay in the list with visible=false so settings can re-show
/// them without re-adding.
final class HomeTabOrganizer {
  HomeTabOrganizer({required this.defaults});

  final List<HomeTab> defaults;

  List<HomeTab> organize({List<String>? savedOrder, Set<String>? hidden}) {
    final byId = {for (final tab in defaults) tab.id: tab};
    final out = <HomeTab>[];
    final seen = <String>{};
    for (final id in savedOrder ?? const <String>[]) {
      final tab = byId[id];
      if (tab != null && !seen.contains(id)) {
        out.add(tab.withVisible(!(hidden ?? const <String>{}).contains(id)));
        seen.add(id);
      }
    }
    for (final tab in defaults) {
      if (!seen.contains(tab.id)) {
        out.add(tab.withVisible(!(hidden ?? const <String>{}).contains(tab.id)));
      }
    }
    return out;
  }
}
