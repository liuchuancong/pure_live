import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';

/// The platforms the viewer keeps out of the browsing pages (the
/// reference's platform display): an empty set shows everything; the
/// choices persist under `sites.display`.
final class SitesDisplayController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    try {
      final stored = StoragePrefs.getStringList('sites.display');
      return stored == null ? <String>{} : stored.toSet();
    } on Object {
      return <String>{};
    }
  }

  /// Whether the browsing pages show [id]; everything shows when the set
  /// is empty.
  bool shown(String id) => state.isEmpty || state.contains(id);

  /// The browsing pages' platform order — the viewer's own, the registry's
  /// for a platform the order has not met yet — with the hidden ones left
  /// out.
  List<String> visibleIds() {
    final all = ref.read(sitesOrderProvider).order;
    return state.isEmpty ? List.of(all) : all.where(shown).toList();
  }

  /// Flips [id]'s visibility, writing the choice through; answers whether
  /// it changed. Turning the last visible platform off changes nothing: a
  /// browsing page with no platform at all is not a choice the switch
  /// offers, and the caller says so.
  ///
  /// The set stores hidden ids once anything is hidden at all; while nothing
  /// is hidden, the first switch-off starts the set with every id but the
  /// one being hidden.
  Future<bool> toggle(String id) async {
    final currentlyShown = state.isEmpty || !state.contains(id);
    if (currentlyShown && visibleIds().length <= 1) return false;
    final next = state.isEmpty
        ? {
            for (final site in ref.read(sitesProvider).all)
              if (site.manifest.id != id) site.manifest.id,
          }
        : (state.contains(id) ? state.difference({id}) : state.union({id}));
    state = next;
    // Hiding the preferred platform leaves the preference on the first
    // platform still shown, so the browse pages never lead with a hidden
    // one.
    if (currentlyShown) {
      final order = ref.read(sitesOrderProvider);
      if (order.preferred == id) {
        final remaining = visibleIds();
        if (remaining.isNotEmpty) await ref.read(sitesOrderProvider.notifier).setPreferred(remaining.first);
      }
    }
    try {
      await StoragePrefs.setStringList('sites.display', next.toList());
    } on Object {
      // The choice is a preference; a closed store loses it, nothing else.
    }
    return true;
  }
}

/// The platforms the browsing pages show.
final sitesDisplayProvider = NotifierProvider<SitesDisplayController, Set<String>>(SitesDisplayController.new);

/// The browsing pages' platform order and preferred platform: the ordered
/// ids — the registry's until the viewer drags another order — and the one
/// platform the surfaces prefer (3.x's `preferPlatform`).
typedef SitesOrder = ({List<String> order, String preferred});

/// The reference's preferred platform when nothing is stored: Bilibili when
/// the build carries it, the first registered platform otherwise.
String defaultPreferredSiteId(Iterable<String> ids) =>
    ids.contains(SiteIds.bilibili) ? SiteIds.bilibili : (ids.isEmpty ? '' : ids.first);

/// Owns the platform order and the preferred platform. The order persists
/// under `sites.display.order`, the preference under
/// `sites.display.preferred`; a stored id the registry no longer knows is
/// dropped, and a platform the order has not met yet joins at its
/// registry place, so a new site never goes missing.
final class SitesOrderController extends Notifier<SitesOrder> {
  /// Where the order lives in the settings store.
  static const String orderKey = 'sites.display.order';

  /// Where the preferred platform's id lives in the settings store.
  static const String preferredKey = 'sites.display.preferred';

  @override
  SitesOrder build() {
    final ids = [for (final site in ref.watch(sitesProvider).all) site.manifest.id];
    List<String>? storedOrder;
    String? storedPreferred;
    try {
      storedOrder = StoragePrefs.getStringList(orderKey);
      storedPreferred = StoragePrefs.getString(preferredKey);
    } on Object {
      // The store may never have opened; the registry's order stands.
    }
    final order = _sanitize(storedOrder, ids);
    final preferred = storedPreferred != null && ids.contains(storedPreferred)
        ? storedPreferred
        : defaultPreferredSiteId(ids);
    return (order: order, preferred: preferred);
  }

  /// [stored] with the ids the registry no longer knows dropped,
  /// duplicates gone, and every platform the order has not met appended in
  /// registry order.
  static List<String> _sanitize(List<String>? stored, List<String> ids) {
    if (stored == null) return List.of(ids);
    final known = <String>{};
    return [
      for (final id in stored)
        if (ids.contains(id) && known.add(id)) id,
      for (final id in ids)
        if (known.add(id)) id,
    ];
  }

  /// Moves the platform at [from] to [to] — the index it holds after the
  /// move, as the reorderable list reports it — writing the order through.
  Future<void> move(int from, int to) async {
    final order = List.of(state.order);
    if (from < 0 || from >= order.length || to < 0) return;
    final id = order.removeAt(from);
    order.insert(to.clamp(0, order.length), id);
    state = (order: order, preferred: state.preferred);
    await _writeOrder(order);
  }

  /// Puts the platforms back in the registry's order ("restore default");
  /// the preferred platform stays unless the registry no longer knows it.
  Future<void> resetOrder() async {
    final ids = [for (final site in ref.read(sitesProvider).all) site.manifest.id];
    final preferred = ids.contains(state.preferred) ? state.preferred : defaultPreferredSiteId(ids);
    state = (order: ids, preferred: preferred);
    await _writeOrder(ids);
  }

  /// Moves the preferred platform, writing the choice through.
  Future<void> setPreferred(String id) async {
    state = (order: state.order, preferred: id);
    try {
      await StoragePrefs.setString(preferredKey, id);
    } on Object {
      // The choice is a preference; a closed store loses it, nothing else.
    }
  }

  Future<void> _writeOrder(List<String> order) async {
    try {
      await StoragePrefs.setStringList(orderKey, order);
    } on Object {
      // The choice is a preference; a closed store loses it, nothing else.
    }
  }
}

/// The browsing pages' platform order and preferred platform.
final sitesOrderProvider = NotifierProvider<SitesOrderController, SitesOrder>(SitesOrderController.new);

/// The follow list as one JSON document: an array of the rooms' own
/// storage JSON. The export and the import share the shape.
String encodeFollows(List<LiveRoom> rooms) => jsonEncode([for (final room in rooms) room.toJson()]);

/// Parses an exported follows document; answers null when it is not one.
List<LiveRoom>? decodeFollows(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return [
      for (final entry in decoded)
        if (entry is Map) LiveRoom.fromJson(Map<String, Object?>.from(entry)),
    ];
  } on Object {
    return null;
  }
}
