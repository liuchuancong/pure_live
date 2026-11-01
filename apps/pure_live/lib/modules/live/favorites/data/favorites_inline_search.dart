import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

/// The favorites page's inline search word, handed by the toolbar's field:
/// the page narrows the follows it is showing to the ones whose title or
/// anchor answers the word — no navigation away, the page stays put. Null
/// is browsing.
final class FavoritesInlineSearchController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Narrows the shown follows to [word] (null or empty returns to all).
  void search(String? word) => state = (word == null || word.trim().isEmpty) ? null : word.trim();

  /// Returns to every follow.
  void clear() => state = null;
}

/// Whether [room] answers [query] by its title or its anchor's name;
/// [query] is already lower-cased, and empty matches everything.
bool followMatchesQuery(LiveRoom room, String query) {
  if (query.isEmpty) return true;
  if (room.content.title.toLowerCase().contains(query)) return true;
  return (room.anchor?.name ?? '').toLowerCase().contains(query);
}

/// The favorites page's inline search word.
final favoritesInlineSearchProvider = NotifierProvider<FavoritesInlineSearchController, String?>(
  FavoritesInlineSearchController.new,
);
