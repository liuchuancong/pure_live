import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/shared/shared.dart';

/// The live home menu's destinations: the four content entries the
/// navigation setting shows, hides and orders (the reference's
/// `savedMenuIds`), in the sidebar's default order — favorites, the hot
/// feed, areas and the recording centre.
const List<NavigationItem> kHomeMenuItems = [
  NavigationItem.favorites,
  NavigationItem.hot,
  NavigationItem.zones,
  NavigationItem.record,
];

/// The settings key the home menu's order lives under. It is written by
/// one caller only — the order editor's save. Until then the key does not
/// exist and the menu keeps the default order, no matter how the switches
/// have been flipped. (The legacy `nav.menuIds` key once let the switches
/// write the order too; that history is why it is left unread here.)
const String kNavMenuOrderKey = 'nav.menuOrder';

/// The settings key the hidden home entries live under — the only thing the
/// visibility switches write.
const String kNavHiddenMenuIdsKey = 'nav.hiddenMenuIds';

/// The home menu's visible entries in the viewer's order: the desktop
/// sidebar, the phone drawer and the phone bottom bar all read this one
/// list. At least one entry always stays.
final class NavMenuController extends Notifier<List<NavigationItem>> {
  /// The order this session last saved (or read), so the page never has to
  /// re-read storage mid-flight: a state change triggers the rebuild that
  /// asks for [ordered] before an async store write would have landed.
  List<NavigationItem>? _savedOrder;

  @override
  List<NavigationItem> build() {
    _savedOrder = null;
    try {
      final order = _order();
      _savedOrder = order;
      return _visibleOf(order, _hidden());
    } on Object {
      return List.of(kHomeMenuItems);
    }
  }

  /// The four destinations in their order, hidden ones included: the
  /// settings page lists every row in place, its switch carrying the
  /// visibility, so no row ever moves for a switch.
  List<NavigationItem> get ordered => _savedOrder ?? _order();

  /// Shows or hides [item], writing only the hidden set — the order key is
  /// never touched, so the entries keep their places and a re-shown entry
  /// returns to where it was (the default order until the viewer has saved
  /// an edit). Answers whether it changed; hiding the last visible entry
  /// changes nothing: a home menu with no destination is not a choice the
  /// switch offers.
  Future<bool> setVisible(NavigationItem item, {required bool value}) async {
    if (!kHomeMenuItems.contains(item)) return false;
    final order = ordered;
    final hidden = _hidden();
    if (value) {
      hidden.remove(item);
    } else {
      final remaining = [
        for (final entry in order)
          if (entry != item && !hidden.contains(entry)) entry,
      ];
      if (remaining.isEmpty) return false;
      hidden.add(item);
    }
    try {
      await StoragePrefs.setStringList(kNavHiddenMenuIdsKey, [
        for (final entry in kHomeMenuItems)
          if (hidden.contains(entry)) entry.name,
      ]);
    } on Object {
      // A preference; a closed store loses it.
    }
    state = _visibleOf(order, hidden);
    return true;
  }

  /// Stores the editor's draft as the home menu's order — the one writer of
  /// the order key. The draft carries all four destinations, hidden ones
  /// included (the editor lists every row), so every entry keeps the exact
  /// place the draft puts it. Anything but a full rearrangement is refused.
  /// The store is written before the state moves, so the rebuild the state
  /// change triggers reads the order that was just saved.
  Future<void> setOrder(List<NavigationItem> items) async {
    // Set equality is identity in Dart, so a `.toSet() ==` guard here would
    // always fail and silently swallow every save; the length-plus-members
    // check is the real rearrangement test.
    if (items.length != kHomeMenuItems.length || !items.every(kHomeMenuItems.contains)) return;
    try {
      await StoragePrefs.setStringList(kNavMenuOrderKey, [for (final item in items) item.name]);
    } on Object {
      // A preference; a closed store loses it.
    }
    _savedOrder = items;
    state = _visibleOf(items, _hidden());
  }

  /// The full order every entry has a place in: the saved order when the
  /// viewer has made one, else the default. Entries a future registry adds
  /// rejoin at the end, so no destination is stranded out of the order.
  List<NavigationItem> _order() {
    final stored = normalizeNavMenuIds(StoragePrefs.getStringList(kNavMenuOrderKey));
    return [
      ...stored,
      for (final item in kHomeMenuItems)
        if (!stored.contains(item)) item,
    ];
  }

  /// The hidden home entries as stored.
  Set<NavigationItem> _hidden() {
    final known = {for (final item in kHomeMenuItems) item.name: item};
    return {
      for (final name in StoragePrefs.getStringList(kNavHiddenMenuIdsKey) ?? const <String>[])
        if (known.containsKey(name)) known[name]!,
    };
  }

  /// What the menu lists: the order minus the hidden entries, and the
  /// order's first entry when everything is hidden — the menu never
  /// vanishes.
  List<NavigationItem> _visibleOf(List<NavigationItem> order, Set<NavigationItem> hidden) {
    final visible = [
      for (final item in order)
        if (!hidden.contains(item)) item,
    ];
    return visible.isEmpty ? [order.first] : visible;
  }
}

/// The home menu's visible entries, in the viewer's order.
final navMenuProvider = NotifierProvider<NavMenuController, List<NavigationItem>>(NavMenuController.new);

/// The four destinations in their order, hidden ones included — the
/// settings page's rows, which no switch ever moves.
final navMenuOrderProvider = Provider<List<NavigationItem>>((ref) {
  ref.watch(navMenuProvider);
  return ref.read(navMenuProvider.notifier).ordered;
});

/// [stored] filtered to the known home menu ids, duplicates dropped and the
/// order kept. Absent storage shows every entry; storage that has been
/// emptied falls back to favorites, so the menu never vanishes.
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
