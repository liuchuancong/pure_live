import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;

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

  /// The browsing pages' platform order, the registry's, with the hidden
  /// ones left out.
  List<String> visibleIds() {
    final all = [for (final site in ref.read(sitesProvider).all) site.manifest.id];
    return state.isEmpty ? all : all.where(shown).toList();
  }

  /// Flips [id]'s visibility, writing the choice through. The set stores
  /// hidden ids once anything is hidden at all; while nothing is hidden,
  /// the first switch-off starts the set with every id but the one being
  /// hidden.
  Future<void> toggle(String id) async {
    final next = state.isEmpty
        ? {
            for (final site in ref.read(sitesProvider).all)
              if (site.manifest.id != id) site.manifest.id,
          }
        : (state.contains(id) ? state.difference({id}) : state.union({id}));
    state = next;
    try {
      await StoragePrefs.setStringList('sites.display', next.toList());
    } on Object {
      // The choice is a preference; a closed store loses it, nothing else.
    }
  }
}

/// The platforms the browsing pages show.
final sitesDisplayProvider = NotifierProvider<SitesDisplayController, Set<String>>(SitesDisplayController.new);

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
