import 'package:flutter/widgets.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;

/// Missevan's verified two-state category icons (the reference's
/// `_missevanSpriteStems`): the same picture twice, one coloured state in
/// each half, so a tile must show the half it wants instead of the middle.
const Set<String> _spriteStems = {
  '/live/catalog/icon/104',
  '/live/catalog/icon/105',
  '/live/catalog/icon/115',
  '/live/catalog/icon/116',
  '/live/catalog/icon/122',
  '/live/tags/icon/001_20210322112121',
};

/// Which part of a category picture to show: Missevan's two-state icons'
/// coloured half (the top of the `-web.png` cut, the bottom of the mobile
/// one), everything else centred.
Alignment areaArtworkAlignment(String? source) {
  final uri = Uri.tryParse(source?.trim() ?? '');
  if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host != 'static.maoercdn.com') {
    return Alignment.center;
  }
  final web = uri.path.endsWith('-web.png');
  final suffix = web ? '-web.png' : '.png';
  if (!uri.path.endsWith(suffix) || !_spriteStems.contains(uri.path.substring(0, uri.path.length - suffix.length))) {
    return Alignment.center;
  }
  return web ? Alignment.topCenter : Alignment.bottomCenter;
}

/// Whether [source] is a two-state icon rather than artwork that may be lent
/// to another platform's area of the same name.
bool isCategoryIconSprite(String? source) => areaArtworkAlignment(source) != Alignment.center;

/// Pictures of areas by name, lent to areas without one — the reference's
/// `AreaPicMapper`: every catalogue that loads teaches its pictures, and an
/// area without one borrows the picture of the same name (case ignored) or of
/// a name that contains or is contained by it.
///
/// The runtime map is the whole store here: a restart starts empty and the
/// first catalogue load teaches it again. The reference kept the map in the
/// store's meta table; that persistence is not carried yet, because a stale
/// picture is exactly the kind of document the backup wave has to agree on.
final class AreaPictures {
  /// The registry; one per app run.
  new();

  /// The app's registry.
  static final AreaPictures instance = AreaPictures();

  final Map<String, String> _pictures = {};

  /// Teaches the pictures [areas] carry. Two-state icons are not taught —
  /// they are a platform's own state glyphs, not artwork.
  void remember(Iterable<LiveArea> areas) {
    for (final area in areas) {
      final url = area.iconUrl?.trim();
      if (url == null || url.isEmpty || isCategoryIconSprite(url)) {
        continue;
      }
      _pictures.putIfAbsent(_key(area.areaName), () => url);
    }
  }

  /// The picture to show for [area]: its own, else the one a loaded
  /// catalogue taught under a matching name.
  String? pictureFor(LiveArea area) {
    final own = area.iconUrl?.trim();
    if (own != null && own.isNotEmpty) {
      return own;
    }
    final name = _key(area.areaName);
    final exact = _pictures[name];
    if (exact != null) {
      return exact;
    }
    // A containing name: 「英雄联盟」 borrows 「英雄联盟赛事」 and vice versa.
    // The shortest matching name wins, so the closest reading decides.
    String? best;
    String? bestName;
    for (final entry in _pictures.entries) {
      if (!entry.key.contains(name) && !name.contains(entry.key)) {
        continue;
      }
      if (bestName == null || entry.key.length < bestName.length) {
        best = entry.value;
        bestName = entry.key;
      }
    }
    return best;
  }

  static String _key(String name) => name.trim().toLowerCase();
}
