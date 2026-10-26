import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/shared/shared.dart';

/// The live home menu's destinations: the four content entries the
/// navigation setting shows, hides and orders (the reference's
/// `savedMenuIds`).
const List<NavigationItem> kHomeMenuItems = [
  NavigationItem.favorites,
  NavigationItem.hot,
  NavigationItem.zones,
  NavigationItem.record,
];

/// The settings key the home menu's visible entries and their order live
/// under.
const String kNavMenuIdsKey = 'nav.menuIds';

/// The shell's entry toggles (the reference's navigation-bar controls),
/// persisted under `nav.*` so the sidebar and the settings row agree from
/// the first frame.
final class ShowMultiviewController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool('nav.multiview') ?? true;
    } on Object {
      return true;
    }
  }

  /// Shows or hides the multi-view entry.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool('nav.multiview', value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Whether the sidebar offers the multi-view entry.
final showMultiviewProvider = NotifierProvider<ShowMultiviewController, bool>(ShowMultiviewController.new);

/// The home menu's visible entries, in the viewer's order (the reference's
/// `savedMenuIds`): the desktop sidebar, the phone drawer and the phone
/// bottom bar all read this one list. At least one entry always stays.
final class NavMenuController extends Notifier<List<NavigationItem>> {
  @override
  List<NavigationItem> build() {
    try {
      return normalizeNavMenuIds(StoragePrefs.getStringList(kNavMenuIdsKey));
    } on Object {
      return List.of(kHomeMenuItems);
    }
  }

  /// Whether the home menu currently lists [item].
  bool shown(NavigationItem item) => state.contains(item);

  /// Shows or hides [item], writing the choice through; answers whether it
  /// changed. Hiding the last visible entry changes nothing: a home menu
  /// with no destination is not a choice the switch offers.
  Future<bool> setVisible(NavigationItem item, {required bool value}) async {
    if (!kHomeMenuItems.contains(item)) return false;
    final shown = state.contains(item);
    if (shown == value) return true;
    if (!value && state.length <= 1) return false;
    final next = value
        ? [...state, item]
        : [
            for (final entry in state)
              if (entry != item) entry,
          ];
    await _write(next);
    return true;
  }

  /// Moves the entry at [from] to [to] — the index it holds after the
  /// move, as the reorderable list reports it.
  Future<void> move(int from, int to) async {
    if (from < 0 || from >= state.length || to < 0 || to >= state.length || from == to) return;
    final next = List.of(state);
    next.insert(to, next.removeAt(from));
    await _write(next);
  }

  Future<void> _write(List<NavigationItem> items) async {
    state = items;
    try {
      await StoragePrefs.setStringList(kNavMenuIdsKey, [for (final item in items) item.name]);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The home menu's visible entries, in the viewer's order.
final navMenuProvider = NotifierProvider<NavMenuController, List<NavigationItem>>(NavMenuController.new);

/// [stored] filtered to the known home menu ids, duplicates dropped and the
/// order kept. Absent storage shows every entry; storage that has been
/// emptied keeps the reference's first entry, so the menu never vanishes.
List<NavigationItem> normalizeNavMenuIds(List<String>? stored) {
  if (stored == null) return List.of(kHomeMenuItems);
  final known = <String, NavigationItem>{for (final item in kHomeMenuItems) item.name: item};
  final normalized = <NavigationItem>[];
  for (final name in stored) {
    final item = known[name];
    if (item != null && !normalized.contains(item)) normalized.add(item);
  }
  return normalized.isEmpty ? [NavigationItem.favorites] : normalized;
}
