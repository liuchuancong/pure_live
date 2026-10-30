import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';

/// The platforms the viewer keeps out of the browsing pages (the
/// reference's platform display): the set holds the hidden ids, so an empty
/// set — nothing hidden — shows everything; the choices persist under
/// [hiddenKey].
final class SitesDisplayController extends Notifier<Set<String>> {
  /// Where the hidden ids live now.
  static const String hiddenKey = 'sites.display.hidden';

  /// The key the hidden ids used before the set was stored as hidden ids: a
  /// non-empty list there held the *shown* ids, read once and translated.
  static const String legacyKey = 'sites.display';

  @override
  Set<String> build() {
    try {
      final stored = StoragePrefs.getStringList(hiddenKey);
      if (stored != null) return stored.toSet();
      final legacy = StoragePrefs.getStringList(legacyKey);
      if (legacy == null || legacy.isEmpty) return <String>{};
      final ids = [for (final site in ref.read(sitesProvider).all) site.manifest.id];
      return {
        for (final id in ids)
          if (!legacy.contains(id)) id,
      };
    } on Object {
      return <String>{};
    }
  }

  /// Whether the browsing pages show [id]; everything shows when the set
  /// is empty.
  bool shown(String id) => state.isEmpty || !state.contains(id);

  /// The browsing pages' platform order — the viewer's own, the registry's
  /// for a platform the order has not met yet — with the hidden ones left
  /// out.
  List<String> visibleIds() {
    final all = ref.read(sitesOrderProvider).order;
    return state.isEmpty ? List.of(all) : all.where(shown).toList();
  }

  /// Turns every platform on or off at once — the table's two bulk buttons,
  /// where the switches would otherwise be flipped one row at a time.
  ///
  /// Turning all off keeps exactly one platform shown: the preferred one when
  /// it still shows, the first shown otherwise, and the preference follows it
  /// so the browse pages never lead with a hidden platform. Answers whether
  /// the choice changed; a caller that asked for all off with only one left
  /// shown is the page's 「至少保留一个平台」 case.
  Future<bool> setAllShown({required bool value}) async {
    if (value) {
      if (state.isEmpty) return false;
      state = <String>{};
      await _persist();
      return true;
    }
    final visible = visibleIds();
    if (visible.length <= 1) return false;
    final order = ref.read(sitesOrderProvider);
    final keep = visible.contains(order.preferred) ? order.preferred : visible.first;
    if (keep != order.preferred) await ref.read(sitesOrderProvider.notifier).setPreferred(keep);
    state = {
      for (final id in order.order)
        if (id != keep) id,
    };
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    try {
      await StoragePrefs.setStringList(hiddenKey, state.toList());
    } on Object {
      // The choice is a preference; a closed store loses it, nothing else.
    }
  }

  /// Flips [id]'s visibility, writing the choice through; answers whether
  /// it changed. Turning the last visible platform off changes nothing: a
  /// browsing page with no platform at all is not a choice the switch
  /// offers, and the caller says so.
  ///
  /// The set holds the hidden ids; an empty set — nothing hidden — shows
  /// everything, so the first switch-off adds just that platform.
  Future<bool> toggle(String id) async {
    final currentlyShown = !state.contains(id);
    if (currentlyShown && visibleIds().length <= 1) return false;
    final next = state.contains(id) ? state.difference({id}) : state.union({id});
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
    await _persist();
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

  /// Stores [ids] as the platform order. Only a full rearrangement of the
  /// platforms now ordered is accepted: the order editor hands back the same
  /// list it was shown, and anything else would drop a platform.
  Future<void> setOrder(List<String> ids) async {
    // Set equality is identity in Dart, so a `.toSet() ==` guard here would
    // always fail and silently swallow every save; the length-plus-members
    // check is the real rearrangement test.
    if (ids.length != state.order.length || !ids.every(state.order.contains)) return;
    state = (order: ids, preferred: state.preferred);
    await _writeOrder(ids);
  }

  /// Back to this build's own answer: the registry's order and its default
  /// preferred platform — what the platform page's 重置 does together with
  /// showing every platform again.
  Future<void> reset() async {
    final ids = [for (final site in ref.read(sitesProvider).all) site.manifest.id];
    final preferred = defaultPreferredSiteId(ids);
    state = (order: ids, preferred: preferred);
    await _writeOrder(ids);
    try {
      await StoragePrefs.setString(preferredKey, preferred);
    } on Object {
      // The choice is a preference; a closed store loses it, nothing else.
    }
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

/// The site the viewer names as their own: the preferred platform, resolved
/// against the registry so a caller always gets a live site. A registry that
/// has lost the preferred id — a platform removed, or a preference from
/// another build — falls back to the first one, the same way the old
/// per-surface default did.
///
/// This is the single answer to "which platform do I mostly watch": the
/// areas' room list opens on it, and the desktop search box hands it to the
/// search page as the starting scope.
final preferredSiteProvider = Provider<LiveSite>((ref) {
  final sites = ref.watch(sitesProvider);
  return sites.getById(ref.watch(sitesOrderProvider).preferred) ?? sites.all.first;
});

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
