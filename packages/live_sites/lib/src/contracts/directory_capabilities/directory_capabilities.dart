import 'package:live_sites/src/models/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/live_area/live_area.dart';

/// The area catalogue: the categories and areas a site can be browsed by.
///
/// A capability rather than a method on `LiveSite`, because the contract
/// cannot default it: "this site has no area list" and "this site's area list
/// has not been migrated" are different facts, and only the adapter knows
/// which one applies. A page asks `site is LiveAreaCatalog` before offering a
/// category picker — the same shape as the danmaku and directory
/// capabilities, so a site migrates one area of its API at a time.
///
/// The areas it returns are what `LiveSite.getCategoryRooms` accepts: the ids
/// of the one feed into the other, which is what makes a picker built from
/// this list work without a per-site mapping table.
abstract interface class LiveAreaCatalog {
  /// The site's areas, in the order the site presents them.
  ///
  /// The list is flat: the parent grouping a platform shows (a board, a tab)
  /// lives in [LiveArea.parentId], because a nested structure would force
  /// every picker to know each site's depth.
  Future<List<LiveArea>> getAreas();
}

/// Searching a site for *streamers* rather than for rooms.
///
/// Several platforms search people, live or not; the result is a
/// [LiveAnchor], and the ones who are on air carry the room to open. A site
/// that only searches rooms does not implement this, and a search box that
/// offers an anchor tab asks first.
abstract interface class LiveAnchorSearch {
  /// The anchors matching [keyword], [page] starting at 1.
  Future<LivePage<LiveAnchor>> searchAnchors(String keyword, {int page});
}
