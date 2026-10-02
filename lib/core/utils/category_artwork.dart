import 'package:flutter/painting.dart';
import 'package:pure_live/core/utils/network_image_url.dart';

// Verified meta/data assets, not a heuristic for arbitrary tall covers. New
// filenames keep the ordinary cover layout until their frame contract is known.
const _missevanSpriteStems = {
  '/live/catalog/icon/104',
  '/live/catalog/icon/105',
  '/live/catalog/icon/115',
  '/live/catalog/icon/116',
  '/live/catalog/icon/122',
  '/live/tags/icon/001_20210322112121',
};

/// Select the full-color square frame in the verified vertical two-state icons.
/// Mobile assets are gray/color; web assets are color/white. Both category
/// renderers use square viewports and BoxFit.cover. Stored favorites retain
/// their original URLs; no image rewriting or settings migration is needed.
Alignment categoryArtworkAlignment(String? source) {
  final uri = Uri.tryParse(normalizeNetworkImageUrl(source));
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host != 'static.maoercdn.com' ||
      uri.userInfo.isNotEmpty ||
      uri.port != (uri.scheme == 'https' ? 443 : 80)) {
    return Alignment.center;
  }
  final web = uri.path.endsWith('-web.png');
  final suffix = web ? '-web.png' : '.png';
  if (!uri.path.endsWith(suffix) ||
      !_missevanSpriteStems.contains(uri.path.substring(0, uri.path.length - suffix.length))) {
    return Alignment.center;
  }
  return web ? Alignment.topCenter : Alignment.bottomCenter;
}

/// State icons are not reusable artwork for unrelated platforms with a similar
/// category name. Apply this both to new entries and the persisted legacy map.
bool isCategoryIconSprite(String? source) => categoryArtworkAlignment(source) != Alignment.center;
